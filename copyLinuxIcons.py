#!python3
# -*- coding: utf-8 -*-

import sys, os, re, pathlib, shutil, tempfile, argparse, time
from datetime import datetime, timezone
from typing import Any, List, Pattern, Tuple, Iterator, Dict
#from tabulate import tabulate	# https://pypi.org/project/tabulate/
from operator import attrgetter, itemgetter
import hashlib

from ackPyHelpers import LogHelper, FileHelpers, RunProcessHelper

def main():
	parser = argparse.ArgumentParser()
	subparsers = parser.add_subparsers(dest="commandName", title="subcommands")		# 'commandName' will be set to values passed to add_parser

	mainCmd = subparsers.add_parser("createIcons", aliases=['c'], help="copy PNGs and/or create ICOs")
	mainCmd.add_argument("-th", "--theme", help="copy only the specified theme (e.g. 'breeze' or 'Yaru')")
	mainCmd.add_argument("-t", "--type", help="copy only the specified type (e.g. 'mimetypes' or 'actions')")
	mainCmd.add_argument("-n", "--name", action="append", help="copy only the specified icon names (e.g. 'text-plain'); can be specified multiple times")
	mainCmd.add_argument("-no", "--noOptimize", action="store_true", help="skip optimizing output PNG files")
	mainCmd.add_argument("-i", "--createIcosOnly", action="store_true", help="skip recopying the PNG files, just create ICOs")
	mainCmd.add_argument("-p", "--copyPngsOnly", action="store_true", help="skip creating the ICO files, just copy PNGs")
	mainCmd.add_argument("-b", "--backup", action="store_true", help="back up existing PNGs and ICOs instead of overwriting them by appending the file's timestamp")
	mainCmd.add_argument("-tmp", "--tempFolder", default=str(Constants.WorkingFolder), help="override temp folder location")
	mainCmd.add_argument("-w", "--whatIf", action="store_true", help="enable test mode")
	mainCmd.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	mainCmd.set_defaults(func=processCreateIconsCommand)

	renameBackupsCmd = subparsers.add_parser("renameBackups", aliases=['r'], help="no new files, just rename any backup files created before with an '@' at the front so they're all together")
	renameBackupsCmd.add_argument("-f", "--fromAt", action="store_true", help="reverse: remove the '@' from any backup files so the file's will be next to the file that replaced them for comparison")
	renameBackupsCmd.add_argument("-i", "--renameIcosOnly", action="store_true", help="skip renaming the PNG files, just rename ICOs")
	renameBackupsCmd.add_argument("-p", "--renamePngsOnly", action="store_true", help="skip renaming the ICO files, just rename PNGs")
	renameBackupsCmd.add_argument("-w", "--whatIf", action="store_true", help="enable test mode")
	renameBackupsCmd.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	renameBackupsCmd.set_defaults(func=processRenameBackupsCommand)

	args = parser.parse_args()

	LogHelper.Init(args.verbose)

	args.func(args)

def processCreateIconsCommand(args : argparse.Namespace):
	Helpers.LogVerbose('processing createIcons command')
	Helpers.EnableWhatIf = args.whatIf
	Helpers.EnableBackup = args.backup
	Helpers.OptimizePngs = not args.noOptimize
	tempPath = pathlib.Path(args.tempFolder)
	iconsToCopy = IconsToCopy(Constants.IconsSourceBasePath, Constants.PngsOutputPath, Constants.IconsOutputPath, tempPath)
	iconsToCopy.process(args.createIcosOnly, args.copyPngsOnly, args.theme, args.type, (args.name if args.name else []))

def processRenameBackupsCommand(args : argparse.Namespace):
	Helpers.LogVerbose('processing renameBackups command')
	Helpers.EnableWhatIf = args.whatIf
	Helpers.EnableBackup = False	# does any of this get reused if we run script multiple times ??
	BackupsHelper.RenameBackupFiles(args.fromAt, args.renameIcosOnly, args.renamePngsOnly)

class Helpers:
	EnableBackup = False
	EnableWhatIf = False
	OptimizePngs = True
	InputBasePath = None
	PngsBasePath = None
	IconsBasePath = None
	TempPath = None
	_hashBufferSize = 256*1024

	class _TempFile:
		def __init__(self, prefix : str, ext : str):
			self._path : pathlib.Path = None
			self._prefix = prefix
			self._suffix = ext

		def __enter__(self) -> pathlib.Path:
			tmp = tempfile.mkstemp(prefix=self._prefix, suffix=self._suffix)
			self._path = pathlib.Path(tmp[1])
			os.close(tmp[0])
			return self._path

		def __exit__(self, excep_type, excep_value, traceback):
			if (self._path is not None and self._path.exists()):
				retryCount = 0
				while True:
					try:
						self._path.unlink()
						break
					except PermissionError:
						++retryCount
						if retryCount >= 5:
							raise
						LogHelper.Warning(f"error trying to delete file \"{self._path}\"; will wait and retry")
						time.sleep(1)
			return False	# propagate any exceptions

	@staticmethod
	def LogVerbose(msg : str):	# could get rid of this but there's a lot using it...
		LogHelper.Verbose(msg)

	@staticmethod
	def VerifyFolderExists(folder : pathlib.Path):
		FileHelpers.VerifyFolderExists(folder, whatIf=Helpers.EnableWhatIf)

	@staticmethod
	def RunProcess(args : List, description : str, ignoreWhatIf : bool = False) :#-> Helpers.RunProcessResults:
		if not Helpers.EnableWhatIf or ignoreWhatIf:
			LogHelper.Verbose("command line = |{0}|", lambda: ' '.join(str(a) for a in args))
			result = RunProcessHelper.runProcess(args)
		else:
			LogHelper.WhatIf(f"{description}:{os.linesep}  command line = |{' '.join(str(a) for a in args)}|")
			result = RunProcessHelper.RunProcessResults()
		return result

	@staticmethod
	def CopyFile(sourceFile : pathlib.Path, targetFile : pathlib.Path, description : str, ignoreWhatIf : bool = False):
		FileHelpers.CopyFile(sourceFile, targetFile, whatIf=(Helpers.EnableWhatIf and not ignoreWhatIf), whatifDescription=description)

	@staticmethod
	def MoveFile(sourceFile : pathlib.Path, targetFile : pathlib.Path, whatifDescription : str):
		if Helpers.EnableBackup and targetFile.exists():
			backupFile = BackupsHelper.GetBackupName(targetFile)
			if backupFile != None and not backupFile.exists():
				msg = f"creating backup file '{backupFile}'"
				LogHelper.Message3(msg)
				FileHelpers.MoveFile(targetFile, backupFile, Helpers.EnableWhatIf, msg)
		FileHelpers.MoveFile(sourceFile, targetFile, Helpers.EnableWhatIf, whatifDescription)

	@staticmethod
	def GetSha1(file : pathlib.Path) -> bytes:
		return FileHelpers.GetSha1(file)

	@staticmethod
	def GetTempFile(prefix : str = None, fileExtension : str = None) -> _TempFile:
		return Helpers._TempFile(prefix, fileExtension)

	@staticmethod
	def GetRelativePath(path : pathlib.Path):
		if path.is_relative_to(Constants.IconsSourceBasePath):
			return path.relative_to(Constants.IconsSourceBasePath)
		elif path.is_relative_to(Constants.PngsOutputPath):
			return path.relative_to(Constants.PngsOutputPath)
		elif path.is_relative_to(Constants.IconsOutputPath):
			return path.relative_to(Constants.IconsOutputPath)
		elif Helpers.TempPath is not None and path.is_relative_to(Helpers.TempPath):
			return path.relative_to(Helpers.TempPath)
		return path

	@staticmethod
	def AddExtension(file : pathlib.Path, newExtension : str) -> pathlib.Path:
		if existingExtension := file.suffix:
			return file.with_suffix(existingExtension + newExtension)
		else:
			return file.with_suffix(newExtension)

	@staticmethod
	def UpdateFileIfNeeded(tempSourceFile : pathlib.Path, primUpdateTargetFile : pathlib.Path, altUpdateTargetFile : pathlib.Path = None,
							originalSourceFile : pathlib.Path = None, isIco : bool = False, messageSuffix : str = ""):
		def logOperation(operation : str, updatePath : pathlib.Path, origSourcePath : pathlib.Path, isIco : bool, msgSuffix : str):
			if isIco:
				LogHelper.Message2(f"{operation} file '{Helpers.GetRelativePath(updatePath)}'{messageSuffix}")
			else:
				if origSourcePath:
					LogHelper.Message(f"{operation} '{Helpers.GetRelativePath(origSourcePath)}' to '{Helpers.GetRelativePath(updatePath)}'{msgSuffix}")
				else:
					LogHelper.Message(f"{operation} file '{Helpers.GetRelativePath(updatePath)}'{messageSuffix}")

		# TODO: existing code here assumes we've already checked that primUpdateTargetFile does exist (checked by caller), but altUpdateTargetFile
		# 		has NOT been checked yet; maybe that could be made more consistent ???
		tempFileHash = Helpers.GetSha1(tempSourceFile)
		targetHash = Helpers.GetSha1(primUpdateTargetFile)
		if tempFileHash != targetHash:
			Helpers.LogVerbose(f"primary file exists, but hashes do not match (tempFile = '{tempFileHash.hex()}', primary file = '{targetHash.hex()}')")
			if not altUpdateTargetFile:
				logOperation("updating", primUpdateTargetFile, originalSourceFile, isIco, messageSuffix)
				Helpers.MoveFile(tempSourceFile, primUpdateTargetFile, f"moving temp file '{Helpers.GetRelativePath(tempSourceFile)}' to '{Helpers.GetRelativePath(primUpdateTargetFile)}'")
			elif not altUpdateTargetFile.exists():
				Helpers.LogVerbose(f"alternate file does NOT exist, creating it")
				logOperation("creating", altUpdateTargetFile, originalSourceFile, isIco, messageSuffix)
				Helpers.MoveFile(tempSourceFile, altUpdateTargetFile, f"moving temp file '{Helpers.GetRelativePath(tempSourceFile)}' to '{Helpers.GetRelativePath(altUpdateTargetFile)}'")
			else:
				Helpers.LogVerbose(f"comparing alternate files")
				targetHash = Helpers.GetSha1(altUpdateTargetFile)
				if tempFileHash != targetHash:
					Helpers.LogVerbose(f"alternate file exists, but hashes do not match (tempFile = '{tempFileHash.hex()}', target = '{targetHash.hex()}'): updating file")
					logOperation("updating", altUpdateTargetFile, originalSourceFile, isIco, messageSuffix)
					Helpers.MoveFile(tempSourceFile, altUpdateTargetFile, f"moving temp file '{Helpers.GetRelativePath(tempSourceFile)}' to '{Helpers.GetRelativePath(altUpdateTargetFile)}'")
				else:
					Helpers.LogVerbose(f"alternate file exists, but hashes match ('{targetHash.hex()}'): NOT updating anything")
		else:
			Helpers.LogVerbose(f"primary file exists, but hashes match ('{targetHash.hex()}'): NOT updating anything")

	@staticmethod
	def FindOnPath(exe : str) -> pathlib.Path:
		return FileHelpers.FindOnPath(exe)

class Constants:
	FldrScheme_SizeType = 0
	FldrScheme_TypeSize = 1

	# D: is my external large drive, so using that for the beaucoups of source files, and for temp files, instead of the small SSD:
	bigDriveTemp = pathlib.Path('D:/').joinpath(*(pathlib.Path(os.path.expandvars("%UserProfile%/temp")).parts[1:]))
	WorkingFolder = bigDriveTemp / "linux/icons/_staging"
	IconsSourceBasePath = bigDriveTemp / "linux/icons"
	PngsOutputPath = bigDriveTemp / "linux/icons/_staging"
	IconsOutputPath = pathlib.Path(os.path.expandvars("%UserProfile%/icons/linux"))

	PathToInkscape = Helpers.FindOnPath('inkscape.exe')
	PathToImageMagick = Helpers.FindOnPath('magick.exe')
	PathToOptipng = Helpers.FindOnPath('optipng.exe')

	AllSupportedExtensions = ['.png', '.svg']
	UpscaleSupportedExtensions = ['.svg']
	PseudoLinkMaxFileSize = 256
	ValidSvgStartUtf8WithSig = b'\xef\xbb\xbf<svg'
	ValidXmlStartUtf8NoSig = b'<?xml '
	ValidXmlStartUtf8WithSig = b'\xef\xbb\xbf<?xml '
	ValidPngStart = b'\x89PNG\x0d\x0a\x1a\x0a'
	ValidSvgStartUtf8NoSig = b'<svg'

	LargeDivider = "################################################################################"
	MediumDivider = "================================================================================"
	SmallDivider = "--------------------------------------------------------------------------------"
	XSmallDivider = "················································································"

class Executables:
	@staticmethod
	def ConvertFile(sourceFile : pathlib.Path, targetFile : pathlib.Path, targetSize : int = None, ignoreWhatIf : bool = False) -> RunProcessHelper.RunProcessResults:
		# using Inkscape to do these conversions and resizings; should be able to use ImageMagick, which we're using to create the ICO files below, but am getting really crappy results:
		args = [Constants.PathToInkscape, "--without-gui", sourceFile, "--export-filename", targetFile]
		if targetSize is not None and targetSize > 0:
			args.extend(["--export-width", str(targetSize), "--export-height", str(targetSize)])
		return Helpers.RunProcess(args, f"converting '{Helpers.GetRelativePath(sourceFile)}' to '{targetFile}'", ignoreWhatIf)

	@staticmethod
	def CreateIcoFile(sourceImgs : Iterator[pathlib.Path], icoOutputFile : pathlib.Path, ignoreWhatIf : bool = False) -> RunProcessHelper.RunProcessResults:
		args = [Constants.PathToImageMagick, "convert"]
		for img in sourceImgs:
			args.append(img)
		args.append(icoOutputFile)
		return Helpers.RunProcess(args, f"creating ICO file '{Helpers.GetRelativePath(icoOutputFile)}'", ignoreWhatIf)

	@staticmethod
	def OptimizePng(pngFilepath : pathlib.Path, ignoreWhatIf : bool = False) -> RunProcessHelper.RunProcessResults:
		args = [Constants.PathToOptipng, "-o7", "-nx", "-strip", "all"]
		#if not Helpers.EnableVerbose:
		#args.append("-quiet")
		args.append(pngFilepath)
		return Helpers.RunProcess(args, f"optimizing PNG file '{Helpers.GetRelativePath(pngFilepath)}'", ignoreWhatIf=ignoreWhatIf)

class SourceImageSizeFolderMap:
	def __init__(self, names16 : List[str], names24 : List[str], names32 : List[str], names48 : List[str], names64 : List[str], names96 : List[str],
					names128 : List[str], names192 : List[str], names256 : List[str], names512 : List[str], names1024 : List[str]):
		self._dict : Dict = { "16": names16, "24": names24, "32": names32, "48": names48, "64": names64, "96": names96,
						"128": names128, "192": names192, "256": names256, "512": names512, "1024": names1024 }

	def __iter__(self) -> Iterator:
		return iter(self._dict)

	def __len__(self) -> int:
		return len(self._dict)

	def __contains__(self, size : str) -> bool:
		return size in self._dict

	def __getitem__(self, size : str) -> List[str]:
		return self._dict[size]

class TargetPngLookupData:
	def __init__(self, name : str, targetSize : int, sourceSize : int):
		self._name : int = name
		self._targetSize : int = targetSize
		self._targetName : str = str(targetSize)
		self._sourceSize : int = sourceSize
		self._sourceName : int = str(sourceSize)

	def __str__(self):
		return f"(name: '{self.name}', targetSize: '{self.targetSize}', sourceSize: '{self.sourceSize}')"

	@property
	def name(self) -> int:
		return self._name

	@property
	def targetSize(self) -> int:
		return self._targetSize

	@property
	def targetName(self) -> str:
		return self._targetName

	@property
	def sourceSize(self) -> int:
		return self._sourceSize

	@property
	def sourceName(self) -> str:
		return self._sourceName

	@property
	def isResize(self) -> bool:
		return self._targetSize != self._sourceSize

	@property
	def isUpscale(self) -> bool:
		return self._targetSize > self._sourceSize

class TargetPngSize:
	def __init__(self, baseSize : int, includeInPngs : bool = True, includeInIco : bool = True, noResizeForPng : bool = False):
		self._baseSize : int = baseSize
		self._baseSizeName : str = str(baseSize)
		self._includeInPngs : bool = includeInPngs
		self._includeInIco : bool = includeInIco
		self._noResizeForPng : bool = noResizeForPng
		self._lookupOrder : List[TargetPngLookupData] = []

	@property
	def baseSize(self) -> int:
		return self._baseSize

	@property
	def baseSizeName(self) -> str:
		return self._baseSizeName

	@property
	def includeInPngs(self) -> bool:
		return self._includeInPngs

	@property
	def includeInIco(self) -> bool:
		return self._includeInIco

	@property
	def noResizeForPng(self) -> bool:
		return self._noResizeForPng

	@property
	def lookupOrder(self) -> List[TargetPngLookupData]:
		return self._lookupOrder

	def initLookupOrder(self, allSizes : List) -> None:		# allSizes is List[TargetPngSize] but python classes can't reference themselves ???
		# create list of sizes to try looking for with fallbacks, in preferred order, preferring downscaling to upscaling
		# first try the actual size we're looking for:
		self._lookupOrder.append(TargetPngLookupData(self.baseSizeName, self.baseSize, self.baseSize))
		# following are the larger sizes, in case we need to downscale one:
		self._lookupOrder.extend(sorted([TargetPngLookupData(s.baseSizeName, self.baseSize, s.baseSize) for s in allSizes if s.baseSize > self.baseSize], key=lambda s: s.sourceSize))
		# add this one by default:
		self._lookupOrder.append(TargetPngLookupData("scalable", self.baseSize, 1000000))
		# following are smaller sizes, and if we have to use them, would thus be upscaling, and will be limited to .svg's when we look for files later:
		self._lookupOrder.extend(sorted([TargetPngLookupData(s.baseSizeName, self.baseSize, s.baseSize) for s in allSizes if s.baseSize < self.baseSize], key=lambda s: s.sourceSize, reverse=True))
		#Helpers.LogVerbose(f"lookupOrder for IconSize baseSize = '{self.baseSize}': {','.join([str(lo) for lo in self._lookupOrder])}")

class SourceFileSearchLookupData:
	def __init__(self, sourceFolderName : str, iconSizeLookupData : TargetPngLookupData):
		self._sourceFolderName : str = sourceFolderName
		self._iconSizeLookupData : TargetPngLookupData = iconSizeLookupData

	def __str__(self):
		return f"(sourceFolderName: '{self.sourceFolderName}', targetSize: '{self.targetSize}', sourceSize: '{self.sourceSize}')"

	@property
	def sourceFolderName(self) -> str:
		return self._sourceFolderName

	@property
	def targetSize(self) -> int:
		return self._iconSizeLookupData.targetSize

	@property
	def targetName(self) -> str:
		return self._iconSizeLookupData.targetName

	@property
	def sourceSize(self) -> int:
		return self._iconSizeLookupData.sourceSize

	@property
	def sourceName(self) -> str:
		return self._iconSizeLookupData.name

	@property
	def isResize(self) -> bool:
		return self._iconSizeLookupData.isResize

	@property
	def isUpscale(self) -> bool:
		return self._iconSizeLookupData.isUpscale

class SourceFileSearchMap:
	def __init__(self, targetPngSize : TargetPngSize, sourceFolderMap : SourceImageSizeFolderMap):
		self._targetPngSize : TargetPngSize = targetPngSize
		self._searchList : List[SourceFileSearchLookupData] = SourceFileSearchMap._createSearchList(targetPngSize, sourceFolderMap)

	@staticmethod
	def _createSearchList(targetPngSize : TargetPngSize, sourceFolderMap : SourceImageSizeFolderMap) -> List[SourceFileSearchLookupData]:
		results = []
		for size in targetPngSize.lookupOrder:
			if size.name == "scalable":
				results.append(SourceFileSearchLookupData(size.name, size))
			else:
				folders = sourceFolderMap[size.sourceName]
				if folders:
					results.extend([SourceFileSearchLookupData(f, size) for f in folders])
		#Helpers.LogVerbose(f"IconSizeSearcher for targetPngSize '{targetPngSize.baseSize}': {','.join([str(iss) for iss in results])}")
		return results

	def __len__(self):
		return len(self._searchList)

	def __iter__(self):
		return iter(self._searchList)

	@property
	def baseSize(self) -> int:
		return self._targetPngSize.baseSize

	@property
	def includeInPngs(self) -> bool:
		return self._targetPngSize.includeInPngs

	@property
	def includeInIco(self) -> bool:
		return self._targetPngSize.includeInIco

class TemplateHandler:
	def __init__(self, pngPrimTemplate : str, pngAltTemplate : str, icoPrimTemplate : str, icoAltTemplate : str, *, other : Dict = None, **params):
		self._pngPrimTemplate : str = pngPrimTemplate
		self._pngAltTemplate : str = pngAltTemplate
		self._icoPrimTemplate : str = icoPrimTemplate
		self._icoAltTemplate : str = icoAltTemplate
		self._isAlternate : bool = False
		if other:
			self._dict = other.copy()
		elif params:
			self._dict = params
		else:
			self._dict = dict()

	def __len__(self) -> int:
		return len(self._dict)

	def __iter__(self) -> Iterator:
		return iter(self._dict)

	def __getitem__(self, key : str) -> str:
		return self._dict[key]

	def __setitem__(self, key : str, value : str) -> None:
		self._dict[key] = value

	def __str__(self) -> str:
		return f"isAlternate: '{self._isAlternate}' / pngPrim: '{self._pngPrimTemplate}' / pngAlt: '{self._pngAltTemplate}' / icoPrim: '{self._icoPrimTemplate}' / icoAlt: '{self._icoAltTemplate}' / len(params) = '{len(self._dict)}'"

	@property
	def isAlternate(self) -> bool:
		return self._isAlternate

	def copy(self): # -> TemplateHandler:	# why can't it reference itself ?????
		newHandler = TemplateHandler(self._pngPrimTemplate, self._pngAltTemplate, self._icoPrimTemplate, self._icoAltTemplate, other=self._dict)
		newHandler._isAlternate = self._isAlternate
		return newHandler

	def formattedPngName(self) -> pathlib.Path:
		template = self._pngAltTemplate if self._isAlternate else self._pngPrimTemplate
		return pathlib.Path(template.format(**self._dict))

	def formattedIcoName(self) -> pathlib.Path:
		template = self._icoAltTemplate if self._isAlternate else self._icoPrimTemplate
		return pathlib.Path(template.format(**self._dict))

	def formattedIcoPrimName(self) -> pathlib.Path:
		return pathlib.Path(self._icoPrimTemplate.format(**self._dict))

	def formattedIcoAltName(self) -> pathlib.Path:
		return pathlib.Path(self._icoAltTemplate.format(**self._dict)) if self._isAlternate else None

	def updateIconNames(self, primaryName : str, altName : str, isAlternate : bool):
		self._isAlternate : bool = isAlternate
		self._dict["primaryName"] = primaryName
		self._dict["alternateName"] = altName

class ResolvedSourceFile:
	def __init__(self, sourceFile : pathlib.Path, actualFile : pathlib.Path, targetSize : int, isResize : bool, includeInIco : bool, templateParams : TemplateHandler):
		self._sourceFile : pathlib.Path = sourceFile
		self._actualFile : pathlib.Path = actualFile
		self._targetSize : int = targetSize
		self._isResize : bool = isResize
		self._includeInIco : bool = includeInIco
		self._templateParams : TemplateHandler = templateParams
		self._sourceIsLink : bool = sourceFile != actualFile
		self._actualFileExists : bool = actualFile.exists()

	@property
	def sourceFilePath(self) -> pathlib.Path:
		return self._sourceFile

	@property
	def actualFilePath(self) -> pathlib.Path:
		return self._actualFile

	@property
	def sourceIsLink(self) -> bool:
		return self._sourceIsLink

	@property
	def actualFileExists(self) -> bool:
		return self._actualFileExists

	@property
	def templateParams(self) -> TemplateHandler:
		return self._templateParams

	@property
	def targetSize(self) -> int:
		return self._targetSize

	@property
	def isResize(self) -> bool:
		return self._isResize

	@property
	def includeInIco(self) -> bool:
		return self._includeInIco

class ThemeTypeSourceFileSearcher:
	def __init__(self, pathScheme : int, themeSourcePath : pathlib.Path, typeName : str, searchers : List[SourceFileSearchMap]):
		self._pathScheme : int = pathScheme
		self._themeSourcePath : pathlib.Path = themeSourcePath
		self._typeName : str = typeName
		self._searchers : List[SourceFileSearchMap] = searchers

	@property
	def pathScheme(self) -> int:
		return self._pathScheme

	@property
	def themeSourcePath(self) -> pathlib.Path:
		return self._themeSourcePath

	@property
	def typeName(self) -> str:
		return self._typeName

	def buildFileList(self, iconSourceName : str, templateParams : TemplateHandler) -> List[ResolvedSourceFile]:
		results : List[ResolvedSourceFile] = []
		for iconSizeSearcher in self._searchers:
			if not iconSizeSearcher.includeInPngs:
				continue
			for searchLookupData in iconSizeSearcher:
				sourceFilePath,actualFilePath = self._findSourceFileInfo(searchLookupData, iconSourceName)
				if actualFilePath:
					parms = templateParams.copy()
					parms['size'] = searchLookupData.targetName
					results.append(ResolvedSourceFile(sourceFilePath, actualFilePath, searchLookupData.targetSize, searchLookupData.isResize, iconSizeSearcher.includeInIco, parms))
					break
		return results

	def _getThemeFolder(self, name : str) -> pathlib.Path:
		if self._pathScheme == Constants.FldrScheme_SizeType:
			return self._themeSourcePath / name / self._typeName
		elif self._pathScheme == Constants.FldrScheme_TypeSize:
			return self._themeSourcePath / self._typeName / name
		else:
			raise ValueError(f"invalid value for PathScheme: {self._pathScheme}")

	def _findSourceFileInfo(self, searchLookupData : SourceFileSearchLookupData, inputName : str) -> Tuple[pathlib.Path, pathlib.Path]:
		themeFolder = self._getThemeFolder(searchLookupData.sourceFolderName)
		baseFilepath = (themeFolder / inputName)
		sourceFilepath = self._findFile(baseFilepath, searchLookupData.isUpscale)
		target = None
		if not sourceFilepath:
			Helpers.LogVerbose(f"    targetSize {searchLookupData.targetName}: no supported files found for '{Helpers.GetRelativePath(baseFilepath)}'; skipping")
		elif sourceFilepath.is_symlink():
			Helpers.LogVerbose(f"    targetSize {searchLookupData.targetName}: file '{Helpers.GetRelativePath(sourceFilepath)}' is a symlink")
			# if this is a link to a link to a link to ..., the .resolve() will take care of all that:
			target = sourceFilepath.resolve()
		elif self._isPseudoLink(sourceFilepath):
			Helpers.LogVerbose(f"    targetSize {searchLookupData.targetName}: file '{Helpers.GetRelativePath(sourceFilepath)}' looks like a pseudo-link file")
			target = self._resolvePseudoLink(sourceFilepath)
		else:
			#Helpers.LogVerbose(f"    file '{sourceFilepath}' is not a link")
			Helpers.LogVerbose(f"    targetSize {searchLookupData.targetName}: file '{Helpers.GetRelativePath(sourceFilepath)}' is a real file")
			target = sourceFilepath
		return (sourceFilepath, target)

	def _findFile(self, baseFilepath : pathlib.Path, isUpscale : bool) -> pathlib.Path:
		extensions = Constants.UpscaleSupportedExtensions if isUpscale else Constants.AllSupportedExtensions
		for ext in extensions:
			maybePath = Helpers.AddExtension(baseFilepath, ext)
			#LogVerbose(f"    checking for file '{maybePath}'")
			if maybePath.exists():
				#LogVerbose(f"    file '{maybePath}' exists, returning it")
				return maybePath
		return None

	def _isPseudoLink(self, filePath : pathlib.Path) -> bool:
		stat = filePath.stat()
		if stat.st_size < Constants.PseudoLinkMaxFileSize:
			fileExt = filePath.suffix
			with filePath.open(mode = "rb") as f:
				if fileExt == '.png':
					bytes = f.read(8)
					if bytes != Constants.ValidPngStart:
						return True
				elif fileExt == '.svg':
					bytes = f.read(9)
					if bytes[:4] != Constants.ValidSvgStartUtf8NoSig and bytes[:7] != Constants.ValidSvgStartUtf8WithSig and \
							bytes[:6] != Constants.ValidXmlStartUtf8NoSig and bytes != Constants.ValidXmlStartUtf8WithSig:
						return True
				else:
					raise NotImplementedError(strerror = f"file type '{fileExt}' not supported (yet)")
		return False

	def _resolvePseudoLink(self, file : pathlib.Path):
		# assuming it's already been checked and we know it's one of those weird pseudo link file where the contents is a relative path to another file:
		link = file.read_text()
		newFile = (file.parent / link).resolve()
		if not newFile.exists():
			Helpers.LogVerbose(f"    file '{Helpers.GetRelativePath(file)}' is pseudolink to file '{Helpers.GetRelativePath(newFile)}', but that file does not exist")
			return None
		# sometimes the contents of the pseudo-link is a relative path to another folder; and it's possible the new file could be a symlink;
		# the resolve() above will take care of both of those, so just need to check if the new file is itself another pseudo-link:
		if self._isPseudoLink(newFile):
			return self._resolvePseudoLink(newFile)
		# we've resolved it:
		return newFile

class IcoSourceFilesList:
	_joinSeparator = os.linesep  + "    "

	def __init__(self, pngSizeRegex : Pattern, iconSizes : Dict[int, TargetPngSize]):
		self._pngSizeRegex : Pattern = pngSizeRegex
		self._iconSizes : Dict[int, TargetPngSize] = iconSizes
		self._filelist : List[Tuple(pathlib.Path, int)] = []

	def __iter__(self) -> Iterator[pathlib.Path]:
		return (f[0] for f in self._filelist)

	def __len__(self) -> int:
		return len(self._filelist)

	def __str__(self):
		return IcoSourceFilesList._joinSeparator + IcoSourceFilesList._joinSeparator.join(str(f) for f in self)

	def addIfSizeIncluded(self, file : pathlib.Path, targetSize : int = None) -> bool:
		if file:
			imgSize = self._getImageSize(file) if targetSize is None or targetSize <= 0 else targetSize
			if imgSize <= 0 or (imgSize in self._iconSizes and self._iconSizes[imgSize].includeInIco):
				self._filelist.append((file, imgSize))
				self._filelist.sort(key=itemgetter(1), reverse=True)
				return True
		return False

	def _getImageSize(self, file : pathlib.Path) -> int:
		# for now, at least, just figure out size from the filename:
		#if _enableWhatIf:
		match = self._pngSizeRegex.search(file.stem)
		if match:
			return int(match.group(1))
		#else:
		#	# load image, get size and maybe try to figure out color depth(?), then save tuple of size, file path, etc, to _filelist
		#	pass
		return -1

class PngFilesHelper:
	@staticmethod
	def CopyPngsToTargetFolder(sourceFilesList : List[ResolvedSourceFile], pngTargetFolder : pathlib.Path, pngSizeRegex : Pattern, iconSizes : Dict[int, TargetPngSize]) -> IcoSourceFilesList:
		results = IcoSourceFilesList(pngSizeRegex, iconSizes)
		for f in sourceFilesList:
			pngFilePath = PngFilesHelper._copyPngToTarget(f.actualFilePath, pngTargetFolder, f.targetSize, f.isResize, f.templateParams)
			results.addIfSizeIncluded(pngFilePath, f.targetSize)
		return results

	@staticmethod
	def _copyPngToTarget(sourceFilepath : pathlib.Path, targetFolder : pathlib.Path, targetSize : int, isResize : bool, templateParams : TemplateHandler) -> pathlib.Path:
		convertToPng = False
		targetExt = sourceFilepath.suffix
		if targetExt == ".svg":
			convertToPng = True
			targetExt = ".png"
		targetFilename = pathlib.Path(Helpers.AddExtension(templateParams.formattedPngName(), targetExt))
		#Helpers.LogVerbose(f"targetFilename = '{targetFilename}' / template: '{templateParams}'")
		targetFilepath = targetFolder / targetFilename

		if convertToPng or (isResize and targetSize is not None and targetSize > 0):
			if not PngFilesHelper._convertOrResizeFile(sourceFilepath, targetFilepath, targetSize, targetExt):
				return None
		else:
			if not PngFilesHelper._copySourceToTarget(sourceFilepath, targetFilepath, targetExt):
				return None

		return targetFilepath

	@staticmethod
	def _copySourceToTarget(sourceFilepath : pathlib.Path, targetFilepath : pathlib.Path, targetExt : str) -> bool:
		if not targetFilepath.exists():
			# if target file does not exist yet, just create it in place:
			Helpers.LogVerbose("target does not exist: copying source to target")
			LogHelper.MessageGray(f"copying '{Helpers.GetRelativePath(sourceFilepath)}' to '{Helpers.GetRelativePath(targetFilepath)}'")
			Helpers.CopyFile(sourceFilepath, targetFilepath, f"copying '{Helpers.GetRelativePath(sourceFilepath)}' to '{Helpers.GetRelativePath(targetFilepath)}'")
			if Helpers.OptimizePngs and targetExt == ".png":
				if not PngFilesHelper._optimizePng(targetFilepath):
					return False
		elif not (Helpers.OptimizePngs and targetExt == ".png"):
			Helpers.LogVerbose(f"optimizing disabled, checking hashes of source '{Helpers.GetRelativePath(sourceFilepath)}' and target '{tempFile}'")
			Helpers.UpdateFileIfNeeded(sourceFilepath, targetFilepath, None, sourceFilepath)
		else:
			# target file does exist, create in temp location and only update target if there was a change:
			with Helpers.GetTempFile(prefix="ack", fileExtension=targetExt) as tempFile:
				Helpers.LogVerbose(f"copying source '{Helpers.GetRelativePath(sourceFilepath)}' to temp file '{Helpers.GetRelativePath(tempFile)}'")
				Helpers.CopyFile(sourceFilepath, tempFile, f"copying '{Helpers.GetRelativePath(sourceFilepath)}' to temp file '{Helpers.GetRelativePath(tempFile)}'", ignoreWhatIf=True)
				if Helpers.OptimizePngs and targetExt == ".png":
					if not PngFilesHelper._optimizePng(tempFile, ignoreWhatIf=True):
						return False
				Helpers.UpdateFileIfNeeded(tempFile, targetFilepath, None, sourceFilepath)
		return True

	@staticmethod
	def _convertOrResizeFile(sourceFilepath : pathlib.Path, targetFilepath : pathlib.Path, targetSize : int, targetExt : str) -> bool:
		if not targetFilepath.exists():
			# if target file does not exist yet, just create it in place:
			Helpers.LogVerbose("target does not exist: converting source to target")
			LogHelper.MessageGray(f"converting '{Helpers.GetRelativePath(sourceFilepath)}' to '{Helpers.GetRelativePath(targetFilepath)}'")
			if not PngFilesHelper._convertFile(sourceFilepath, targetFilepath, targetSize):
				return False
			if Helpers.OptimizePngs and targetExt == ".png":
				if not PngFilesHelper._optimizePng(targetFilepath):
					return False
		else:
			# target file does exist, create in temp location and only update target if there was a change:
			with Helpers.GetTempFile(prefix="ack", fileExtension=targetExt) as tempFile:
				Helpers.LogVerbose(f"converting source '{Helpers.GetRelativePath(sourceFilepath)}' to temp file '{Helpers.GetRelativePath(tempFile)}' (targetSize = {targetSize})")
				if not PngFilesHelper._convertFile(sourceFilepath, tempFile, targetSize, ignoreWhatIf=True):
					return False
				if Helpers.OptimizePngs and targetExt == ".png":
					if not PngFilesHelper._optimizePng(tempFile, ignoreWhatIf=True):
						return False
				Helpers.UpdateFileIfNeeded(tempFile, targetFilepath, None, sourceFilepath)
		return True

	@staticmethod
	def _optimizePng(targetFilepath : pathlib.Path, ignoreWhatIf : bool = False) -> bool:
		Helpers.LogVerbose(f"optimizing file '{Helpers.GetRelativePath(targetFilepath)}'")
		results = Executables.OptimizePng(targetFilepath, ignoreWhatIf)
		if results.exitCode != 0:
			LogHelper.Error(f"failed optimizing file '{targetFilepath}' (exit code: {results.exitCode}):{os.linesep}{results.getCombinedStdoutStderr()}")
			return False
		return True

	@staticmethod
	def _convertFile(sourceFile : pathlib.Path, targetFile : pathlib.Path, targetSize : int, ignoreWhatIf : bool = False):
		results = Executables.ConvertFile(sourceFile, targetFile, targetSize, ignoreWhatIf)
		if results.exitCode != 0:
			LogHelper.Error(f"failed converting file '{Helpers.GetRelativePath(sourceFile)}' to png (exit code: {results.exitCode}):{os.linesep}{results.getCombinedStdoutStderr()}")
			return False
		if not targetFile.exists():
			LogHelper.Error(f"converting file '{Helpers.GetRelativePath(sourceFile)}' to png returned success but target file was not created:{os.linesep}{results.getCombinedStdoutStderr()}")
			return False
		return True

class IcoFilesHelper:
	@staticmethod
	def CreateIcoFileFromSources(sourceImgs : IcoSourceFilesList, icoOutputFolder : pathlib.Path, templateParams : TemplateHandler):
		primOutputFile = (icoOutputFolder / Helpers.AddExtension(templateParams.formattedIcoPrimName(), ".ico"))
		altOutputFile = (icoOutputFolder / Helpers.AddExtension(templateParams.formattedIcoAltName(), ".ico")) if templateParams.isAlternate else ""
		altSourceNameMsg = f" (source = '{altOutputFile.stem}')" if templateParams.isAlternate else ""
		nameForLogging = f"{Helpers.GetRelativePath(primOutputFile)} (altName = '{altOutputFile.stem}')" if templateParams.isAlternate else Helpers.GetRelativePath(primOutputFile)
		Helpers.LogVerbose(f"creating ICO file {{{nameForLogging}}} from {len(sourceImgs)} files:{sourceImgs}")
		if not primOutputFile.exists():
			# create an icon in place using the primary name, and we're done
			Helpers.LogVerbose("icon with primary name does not exist: converting source to target")
			LogHelper.MessageCyan(f"creating ICO file '{Helpers.GetRelativePath(primOutputFile)}'{altSourceNameMsg}")
			if not IcoFilesHelper._createIcoFile(sourceImgs, primOutputFile):
				return False
		else:
			with Helpers.GetTempFile(prefix="ack", fileExtension=".ico") as tempFile:
				# create icon in temp location and then move to final location if file actually updated:
				Helpers.LogVerbose(f"icon with primary name exists, creating temp ICO file '{Helpers.GetRelativePath(tempFile)}'")
				if not IcoFilesHelper._createIcoFile(sourceImgs, tempFile, ignoreWhatIf=True):
					return False
				Helpers.UpdateFileIfNeeded(tempFile, primOutputFile, altOutputFile, isIco=True, messageSuffix=altSourceNameMsg)
		return True

	@staticmethod
	def _createIcoFile(sourceImgs : IcoSourceFilesList, icoOutputFile : pathlib.Path, ignoreWhatIf : bool = False):
		results = Executables.CreateIcoFile(sourceImgs, icoOutputFile, ignoreWhatIf)
		if results.exitCode != 0:
			LogHelper.Error(f"failed creating ICO file '{icoOutputFile}' (exit code: {results.exitCode}):{os.linesep}{results.getCombinedStdoutStderr()}")
			return False
		return True

class Icon:
	#region helper classes
	class CopyPngsAndCreateIcoWorkUnit:
		def __init__(self, fileSearcher : ThemeTypeSourceFileSearcher, iconSizes : Dict[int, TargetPngSize], pngsBasePath : pathlib.Path, iconsBasePath : pathlib.Path,
				pngPrimaryNameTemplate : str, pngAltNameTemplate : str, pngPrimarySizeRegexPattern : Pattern, pngAltSizeRegexPattern : Pattern,
				icoPrimaryNameTemplate : str, icoAltNameTemplate : str, copyPngsOnly : bool, themeName : str, distroName : str):
			self._fileSearcher : ThemeTypeSourceFileSearcher = fileSearcher
			self._iconSizes : Dict[int, TargetPngSize] = iconSizes
			self._pngsBasePath : pathlib.Path = pngsBasePath
			self._iconsBasePath : pathlib.Path = iconsBasePath
			self._pngPrimaryNameTemplate : str = pngPrimaryNameTemplate
			self._pngAltNameTemplate : str = pngAltNameTemplate
			self._pngPrimarySizeRegex : Pattern = pngPrimarySizeRegexPattern
			self._pngAltSizeRegex : Pattern = pngAltSizeRegexPattern
			self._icoPrimaryNameTemplate : str = icoPrimaryNameTemplate
			self._icoAltNameTemplate : str = icoAltNameTemplate
			self._copyPngsOnly : bool = copyPngsOnly
			self._themeName : str = themeName
			self._distroName : str = distroName

		#region properties
		@property
		def fileSearcher(self) -> ThemeTypeSourceFileSearcher:
			return self._fileSearcher

		@property
		def iconSizes(self) -> Dict[int, TargetPngSize]:
			return self._iconSizes

		@property
		def pngsBasePath(self) -> pathlib.Path:
			return self._pngsBasePath

		@property
		def iconsBasePath(self) -> pathlib.Path:
			return self._iconsBasePath

		@property
		def pngPrimaryNameTemplate(self) -> str:
			return self._pngPrimaryNameTemplate

		@property
		def pngAltNameTemplate(self) -> str:
			return self._pngAltNameTemplate

		@property
		def pngPrimarySizeRegex(self) -> Pattern:
			return self._pngPrimarySizeRegex

		@property
		def pngAltSizeRegex(self) -> Pattern:
			return self._pngAltSizeRegex

		@property
		def icoPrimaryNameTemplate(self) -> str:
			return self._icoPrimaryNameTemplate

		@property
		def icoAltNameTemplate(self) -> str:
			return self._icoAltNameTemplate

		@property
		def copyPngsOnly(self) -> bool:
			return self._copyPngsOnly

		@property
		def themeName(self) -> str:
			return self._themeName

		@property
		def typeName(self) -> str:
			return self._fileSearcher.typeName

		@property
		def distroName(self) -> str:
			return self._distroName
		#endregion

	class CreateIcoWorkUnit:
		def __init__(self, iconSizes : Dict[int, TargetPngSize], pngsBasePath : pathlib.Path, iconsBasePath : pathlib.Path,
				pngPrimaryNameTemplate : str, pngAltNameTemplate : str, pngPrimarySizeRegexPattern : Pattern, pngAltSizeRegexPattern : Pattern,
				icoPrimaryNameTemplate : str, icoAltNameTemplate : str, themeName : str, typeName : str, distroName : str):
			self._iconSizes : Dict[int, TargetPngSize] = iconSizes
			self._pngsBasePath : pathlib.Path = pngsBasePath
			self._iconsBasePath : pathlib.Path = iconsBasePath
			self._pngPrimaryNameTemplate : str = pngPrimaryNameTemplate
			self._pngAltNameTemplate : str = pngAltNameTemplate
			self._pngPrimarySizeRegex : Pattern = pngPrimarySizeRegexPattern
			self._pngAltSizeRegex : Pattern = pngAltSizeRegexPattern
			self._icoPrimaryNameTemplate : str = icoPrimaryNameTemplate
			self._icoAltNameTemplate : str = icoAltNameTemplate
			self._themeName : str = themeName
			self._typeName : str = typeName
			self._distroName : str = distroName

		#region properties
		@property
		def iconSizes(self) -> Dict[int, TargetPngSize]:
			return self._iconSizes

		@property
		def pngsBasePath(self) -> pathlib.Path:
			return self._pngsBasePath

		@property
		def iconsBasePath(self) -> pathlib.Path:
			return self._iconsBasePath

		@property
		def pngPrimaryNameTemplate(self) -> str:
			return self._pngPrimaryNameTemplate

		@property
		def pngAltNameTemplate(self) -> str:
			return self._pngAltNameTemplate

		@property
		def pngPrimarySizeRegex(self) -> Pattern:
			return self._pngPrimarySizeRegex

		@property
		def pngAltSizeRegex(self) -> Pattern:
			return self._pngAltSizeRegex

		@property
		def icoPrimaryNameTemplate(self) -> str:
			return self._icoPrimaryNameTemplate

		@property
		def icoAltNameTemplate(self) -> str:
			return self._icoAltNameTemplate

		@property
		def themeName(self) -> str:
			return self._themeName

		@property
		def typeName(self) -> str:
			return self._typeName

		@property
		def distroName(self) -> str:
			return self._distroName
		#endregion
	#endregion

	def __init__(self, primaryName : str, alternateNames : List[str] = None, extensions : List[str] = None):
		self._primaryName : str = primaryName
		self._alternateNames : List[str] = alternateNames

	#region properties
	@property
	def names(self) -> Iterator[Tuple[str, str, str, bool]]:
		yield (self._primaryName, self._primaryName, None, False)
		if self._alternateNames:
			for alt in self._alternateNames:
				yield (alt, self._primaryName, alt, True)

	@property
	def primaryName(self) -> str:
		return self._primaryName

	@property
	def alternateNames(self) -> List[str]:
		return self._alternateNames if self._alternateNames else []
	#endregion

	def copyPngsAndCreateIco(self, workUnit : CopyPngsAndCreateIcoWorkUnit):
		templateParms = TemplateHandler(workUnit.pngPrimaryNameTemplate, workUnit.pngAltNameTemplate, workUnit.icoPrimaryNameTemplate, workUnit.icoAltNameTemplate,
										primaryName='', alternateName='', theme=workUnit.themeName, size='', type=workUnit.typeName, distro=workUnit.distroName)

		Helpers.LogVerbose(Constants.SmallDivider)
		pastPrimary = False
		for inputName,primaryName,altName,isAlternate in self.names:
			if pastPrimary:
				Helpers.LogVerbose(Constants.XSmallDivider)
			logName = f"{primaryName} (altName = '{altName}')" if isAlternate else primaryName
			Helpers.LogVerbose(f"processing icon {{{logName}}}")
			pastPrimary = True
			templateParms.updateIconNames(primaryName, altName, isAlternate)
			sourceFiles : List[ResolvedSourceFile] = workUnit.fileSearcher.buildFileList(inputName, templateParms)

			if len(sourceFiles) == 0:
				Helpers.LogVerbose(f"no files found to copy to PNG folder for '{logName}'; returning")
				continue
			# there are icon packages (e.g. Tela) where for some sizes, a file is a real image, but other sizes, it's a link;
			# so we'll have to first find the file info's, and if all are links, then we can ignore like we were doing before,
			# but if some are links and some are real files, then go ahead and copy it and make an ICO out of it
			allAreLinks = allAreReal = True
			for f in sourceFiles:
				if f.sourceIsLink: allAreReal = False
				else: allAreLinks = False
			# if all are real files, or if we have a mixture, copy files:
			iconFiles : IcoSourceFilesList = None
			if allAreReal or not allAreLinks:
				Helpers.LogVerbose(f"copying {len(sourceFiles)} source files to png folder: (allAreReal = '{allAreReal}', allAreLinks = '{allAreLinks}')")
				pngSizeRegex = workUnit.pngAltSizeRegex if isAlternate else workUnit.pngPrimarySizeRegex
				iconFiles = PngFilesHelper.CopyPngsToTargetFolder(sourceFiles, workUnit.pngsBasePath, pngSizeRegex, workUnit.iconSizes)
			else:
				Helpers.LogVerbose(f"NOT copying any source files to png folder: (count = {len(sourceFiles)}, allAreReal = '{allAreReal}', allAreLinks = '{allAreLinks}')")
				#for f in sourceFiles:
				#	Helpers.LogVerbose(f"    source = |{f.sourceFile.relative_to(workUnit.sizeTypeFolders.themeSourcePath)}|, target = |{f.targetFile.relative_to(workUnit.sizeTypeFolders.themeSourcePath)}|")

			if workUnit.copyPngsOnly:
				if iconFiles is not None and len(iconFiles) > 0:
					Helpers.LogVerbose(f"copyPngsOnly set, but would have created ICO file from {len(iconFiles)} files:{iconFiles}")
				continue
			if iconFiles is None or len(iconFiles) == 0:
				Helpers.LogVerbose(f"no files to create an ICO file from for '{logName}'; returning")
				continue

			IcoFilesHelper.CreateIcoFileFromSources(iconFiles, workUnit.iconsBasePath, templateParms)

	def createIcoFromPngs(self, workUnit : CreateIcoWorkUnit):
		templateParms = TemplateHandler(workUnit.pngPrimaryNameTemplate, workUnit.pngAltNameTemplate, workUnit.icoPrimaryNameTemplate, workUnit.icoAltNameTemplate,
										primaryName='', alternateName='', size='', theme=workUnit.themeName, type=workUnit.typeName, distro=workUnit.distroName)
		Helpers.LogVerbose(Constants.SmallDivider)
		pastPrimary = False
		for inputName,primaryName,altName,isAlternate in self.names:
			if pastPrimary:
				Helpers.LogVerbose(Constants.XSmallDivider)
			logName = f"{primaryName} (altName = '{altName}')" if isAlternate else primaryName
			Helpers.LogVerbose(f"processing icon {{{logName}}}")
			pastPrimary = True
			templateParms.updateIconNames(primaryName, altName, isAlternate)
			pngSizeRegex = workUnit.pngAltSizeRegex if isAlternate else workUnit.pngPrimarySizeRegex
			iconFiles = IcoSourceFilesList(pngSizeRegex, workUnit.iconSizes)
			for sz in workUnit.iconSizes:
				iconSize = workUnit.iconSizes[sz]
				if not iconSize.includeInIco:
					continue
				templateParms['size'] = iconSize.baseSizeName
				maybeFile = (workUnit.pngsBasePath / Helpers.AddExtension(templateParms.formattedPngName(), ".png"))
				if maybeFile.exists():
					iconFiles.addIfSizeIncluded(maybeFile)

			if len(iconFiles) == 0:
				Helpers.LogVerbose(f"no files found to create an ICO file from for '{logName}'")
				continue
			templateParms['size'] = ''
			#Helpers.LogVerbose(f"testing: would have created ICO file from {len(iconFiles)} files:{iconFiles}")
			IcoFilesHelper.CreateIcoFileFromSources(iconFiles, workUnit.iconsBasePath, templateParms)

class IconTypeList:
	def __init__(self, typeName : str, typeNameOverrides : Dict, icons : List[Icon]):
		self._icons = icons
		self._defaultTypeName = typeName
		self._typeNameOverrides = typeNameOverrides

	def __iter__(self) -> Iterator[Icon]:
		return iter(self._icons)

	@property
	def baseTypeName(self):
		return self._defaultTypeName

	def getThemeTypename(self, themeName : str) -> str:
		return self._typeNameOverrides.get(themeName, self._defaultTypeName) if self._typeNameOverrides else self._defaultTypeName

	def getOutputTypename(self, themeName : str):
		return self._defaultTypeName

class IconThemeDefinition:
	class WorkUnit:
		def __init__(self, inputBasePath : pathlib.Path, pngsBasePath : pathlib.Path, iconsBasePath : pathlib.Path,
				createIcosOnly : bool, copyPngsOnly : bool, onlyType : str, onlyNames : List[str],
				iconTypeList : List[IconTypeList], iconSizes : List[TargetPngSize]):
			self._inputBasePath : pathlib.Path = inputBasePath
			self._pngsBasePath : pathlib.Path = pngsBasePath
			self._iconsBasePath : pathlib.Path = iconsBasePath
			self._createIcosOnly : bool = createIcosOnly
			self._copyPngsOnly : bool = copyPngsOnly
			self._onlyType : str = onlyType
			self._onlyNames : List[str] = onlyNames
			self._iconTypeList : List[IconTypeList] = iconTypeList
			self._iconSizes : List[TargetPngSize] = iconSizes

		@property
		def inputBasePath(self) -> pathlib.Path:
			return self._inputBasePath

		@property
		def pngsBasePath(self) -> pathlib.Path:
			return self._pngsBasePath

		@property
		def iconsBasePath(self) -> pathlib.Path:
			return self._iconsBasePath

		@property
		def iconTypeList(self) -> List[IconTypeList]:
			return self._iconTypeList

		@property
		def createIcosOnly(self) -> bool:
			return self._createIcosOnly

		@property
		def copyPngsOnly(self) -> bool:
			return self._copyPngsOnly

		@property
		def onlyType(self) -> str:
			return self._onlyType

		@property
		def onlyNames(self) -> List[str]:
			return self._onlyNames

		@property
		def iconSizes(self) -> List[TargetPngSize]:
			return self._iconSizes

	def __init__(self, themeName : str, distroName : str, iconsFolder : str, pathScheme : int,
				foldersMap : SourceImageSizeFolderMap, outputFolderTemplate: str = "{theme}/{type}",
				pngPrimaryNameTemplate : str = "{primaryName} [{size}]", pngAltNameTemplate : str = "{primaryName} [{alternateName}] [{size}]",
				pngPrimarySizeRegex : str = r"^.+ \[(\d+)\].*$", pngAltSizeRegex : str = r"^.+ \[(\d+)\].*$",
				icoPrimaryNameTemplate : str = "{primaryName} [{theme}]", icoAltNameTemplate : str = "{primaryName} [{theme}] [{alternateName}]"):
		self.themeName = themeName
		self.distroName = distroName
		self.iconsFolder = iconsFolder
		self.pathScheme = pathScheme
		self.outputFolderTemplate = outputFolderTemplate
		self.pngPrimaryNameTemplate = pngPrimaryNameTemplate
		self.pngAltNameTemplate = pngAltNameTemplate
		self.pngPrimarySizeRegexPattern = pngPrimarySizeRegex
		self.pngAltSizeRegexPattern = pngAltSizeRegex
		self.icoPrimaryNameTemplate = icoPrimaryNameTemplate
		self.icoAltNameTemplate = icoAltNameTemplate
		self.foldersMap : SourceImageSizeFolderMap = foldersMap

	def process(self, workUnit : WorkUnit):
		# create some vars here outside of loop below so they're only done once:
		themeSourcePath = (pathlib.Path(workUnit.inputBasePath) / self.iconsFolder) if self.iconsFolder else (pathlib.Path(workUnit.inputBasePath) / self.distroName / self.themeName)
		searchMaps = [SourceFileSearchMap(size, self.foldersMap) for size in workUnit.iconSizes] if not workUnit.createIcosOnly else None
		iconSizesDict = { sz.baseSize: sz for sz in workUnit.iconSizes } #if workUnit.createIcosOnly else None
		pngPrimarySizeRegex = re.compile(self.pngPrimarySizeRegexPattern)
		pngAltSizeRegex = re.compile(self.pngAltSizeRegexPattern)
		# now can loop thru icons:
		pastFirstOne = False
		for iconList in workUnit.iconTypeList:
			if pastFirstOne:
				Helpers.LogVerbose(Constants.MediumDivider)
			pastFirstOne = True
			if workUnit.onlyType and iconList.baseTypeName != workUnit.onlyType:
				Helpers.LogVerbose(f"skipping iconType for '{iconList.baseTypeName}' (doesn't match --type option '{workUnit.onlyType}')")
				continue
			elif workUnit.onlyType:
				Helpers.LogVerbose(f"processing iconType '{iconList.baseTypeName}'")
			else:
				LogHelper.MessageGreen(f"processing iconType '{iconList.baseTypeName}'")
			pngsOutputPath = workUnit.pngsBasePath / self.outputFolderTemplate.format(theme = self.themeName, distro = self.distroName, type = iconList.getOutputTypename(self.themeName))
			iconOutputPath = workUnit.iconsBasePath / iconList.getOutputTypename(self.themeName)

			Helpers.VerifyFolderExists(pngsOutputPath)
			Helpers.VerifyFolderExists(iconOutputPath)

			if not workUnit.createIcosOnly:
				fileSearcher = ThemeTypeSourceFileSearcher(self.pathScheme, themeSourcePath, iconList.getThemeTypename(self.themeName), searchMaps)
				iconTypeWorkUnit = Icon.CopyPngsAndCreateIcoWorkUnit(fileSearcher, iconSizesDict, pngsOutputPath, iconOutputPath,
											self.pngPrimaryNameTemplate, self.pngAltNameTemplate, pngPrimarySizeRegex, pngAltSizeRegex,
											self.icoPrimaryNameTemplate, self.icoAltNameTemplate, workUnit.copyPngsOnly, self.themeName, self.distroName)
				for icon in iconList:
					#Helpers.LogVerbose(f"checking icon '{icon.inputName}'")
					if (not workUnit.onlyNames) or (icon.primaryName in workUnit.onlyNames):
						icon.copyPngsAndCreateIco(iconTypeWorkUnit)
					#else:
					#	Helpers.LogVerbose(f"skipping icon '{icon.inputName}' (not in --name list)")
			else:
				iconTypeWorkUnit = Icon.CreateIcoWorkUnit(iconSizesDict, pngsOutputPath, iconOutputPath,
											self.pngPrimaryNameTemplate, self.pngAltNameTemplate, pngPrimarySizeRegex, pngAltSizeRegex,
											self.icoPrimaryNameTemplate, self.icoAltNameTemplate, self.themeName, iconList.getThemeTypename(self.themeName), self.distroName)
				for icon in iconList:
					if not workUnit.onlyNames or icon.primaryName in workUnit.onlyNames:
						icon.createIcoFromPngs(iconTypeWorkUnit)
					#else:
					#	Helpers.LogVerbose(f"skipping icon '{icon.inputName}' (not in --name list)")

class IconsToCopy:
	def __init__(self, inputPath : pathlib.Path, pngsBasePath : pathlib.Path, iconsBasePath : pathlib.Path, tempPath : pathlib.Path):
		self._inputBasePath = inputPath
		self._pngsBasePath = pngsBasePath
		self._iconsBasePath = iconsBasePath
		self._tempPath = tempPath
		self._targetPngSizes : List[TargetPngSize] = [
			# ones in here that have 'includeInPngs' are here for resizing purposes (if we can't find another size we're looking for, it can be considered for resizing)
			TargetPngSize(16), TargetPngSize(24), TargetPngSize(32), TargetPngSize(48), TargetPngSize(64, includeInIco=False),
			TargetPngSize(96, includeInIco=False), TargetPngSize(128, includeInIco=False, includeInPngs=False),
			TargetPngSize(192, includeInIco=False, includeInPngs=False), TargetPngSize(256),
			TargetPngSize(512, includeInIco=False, includeInPngs=False), TargetPngSize(1024, includeInIco=False, includeInPngs=False)
		]
		self._themeDefinitions : List[IconThemeDefinition] = [
			IconThemeDefinition("breeze", "NA", "_oss/breeze-icons/icons", Constants.FldrScheme_TypeSize,
				SourceImageSizeFolderMap(["16"], ["22"], ["32"], ["48"], ["64"], None, None, None, None, None, None)),
			IconThemeDefinition("Deepin", "NA", "_oss/Deepin-icon-theme", Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24"], ["32x32"], ["48x48"], ["64x64"], None, None, None, None, None, None)),
			IconThemeDefinition("Mint-X", "NA", "_oss/mint-x-icons/usr/share/icons/Mint-X", Constants.FldrScheme_TypeSize,
				SourceImageSizeFolderMap(["16"], ["24", "22"], ["32"], ["48"], None, ["96"], None, None, None, None, None)),
			IconThemeDefinition("Mint-Y", "NA", "_oss/mint-y-icons/usr/share/icons/Mint-Y", Constants.FldrScheme_TypeSize,
				SourceImageSizeFolderMap(["16"], ["24"], ["32", "16@2x"], ["48", "24@2x"], ["64", "32@2x"], ["96", "48@2x"], ["128", "64@2x"], ["96@2x"], ["256", "128@2x"], ["256@2x"], None)),
			IconThemeDefinition("Mint-L", "NA", "_oss/mint-l-icons/usr/share/icons/Mint-L", Constants.FldrScheme_TypeSize,
				SourceImageSizeFolderMap(["16"], ["24", "22"], ["32", "16@2x"], ["48", "24@2x"], ["64", "32@2x"], ["96", "48@2x"], ["128", "64@2x"], ["96@2x"], ["256", "128@2x"], ["256@2x"], None)),
			IconThemeDefinition("oxygen", "NA", "_oss/oxygen-icons5", Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["22x22"], ["32x32"], ["48x48"], ["64x64"], None, ["128x128"], None, ["256x256"], None, None)),
			IconThemeDefinition("Paper", "NA", "_oss/paper-icon-theme/Paper", Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32", "16x16@2x"], ["48x48", "24x24@2x"], ["32x32@2x"], ["48x48@2x"], None, None, None, ["512x512"], ["512x512@2x"])),
			IconThemeDefinition("Papirus", "NA", "_oss/papirus-icon-theme/Papirus", Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32"], ["48x48"], ["64x64"], None, None, None, None, None, None)),
			IconThemeDefinition("Tela", "NA", "_oss/Tela_consolidated", Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16"], ["24", "22"], ["32"], None, None, None, None, None, None, None, None)),
			IconThemeDefinition("Yaru", "NA", "_oss/yaru/icons/Yaru", Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32", "16x16@2x"], ["48x48", "24x24@2x"], ["32x32@2x"], ["48x48@2x"], None, None, ["256x256"], ["256x256@2x"], None)),
			# ??? think Zorin is just a fork of Paper (or maybe other way around ??)...
			#IconThemeDefinition("Zorin", "NA", "_oss/zorin-icon-themes/Zorin", Constants.FldrScheme_SizeType,
			#	SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32", "16x16@2x"], ["48x48", "24x24@2x"], ["32x32@2x"], ["48x48@2x"], None, None, None, ["512x512"], ["512x512@2x"])),
			# found repo for 'Adwaita', but it's weird: bigger filesize, but much fewer files, so ??
			IconThemeDefinition("Adwaita", "fedora_39", None, Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32"], ["48x48"], ["64x64"], ["96x96"], None, None, ["256x256"], ["512x512"], None)),
			IconThemeDefinition("gnome", "mint_21.2", None, Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32"], ["48x48"], ["64x64"], None, ["128x128"], None, ["256x256"], ["512x512"], None)),
			# found repo for 'mate', but it seems to have less in it ??
			IconThemeDefinition("mate", "mint_21.2", None, Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16x16"], ["24x24", "22x22"], ["32x32"], ["48x48"], None, None, None, None, ["256x256"], None, None)),
			IconThemeDefinition("Numix", "mint_21.2", None, Constants.FldrScheme_SizeType,
				SourceImageSizeFolderMap(["16"], ["24", "22"], ["32"], ["48"], ["64"], None, None, None, None, None, None)),
			IconThemeDefinition("Humanity", "ubuntu_22.10", None, Constants.FldrScheme_TypeSize,
				SourceImageSizeFolderMap(["16"], ["24"], ["32"], ["48"], ["64"], None, ["128"], ["192"], ["256"], None, None)),
		]
		self._iconTypeLists : List[IconTypeList] = [
			IconTypeList("mimetypes", { "Humanity": "mimes" }, [
				Icon("application-atom+xml", extensions=["atom"]),
				Icon("application-epub+zip"),
				Icon("application-gzip", ["application-x-gzip"], ["gz"]),
				Icon("application-javascript", ["text-javascript", "application-x-javascript", "text-x-javascript"], ["js"]),
				Icon("application-json", ["text-json"], ["json"]),
				Icon("application-octet-stream"),
				Icon("application-pdf", extensions=["pdf"]),
				Icon("application-postscript", extensions=["ps"]),
				Icon("application-rss+xml", ["application-x-rss+xml", "application-rss_xml"], ["rss"]),
				Icon("application-rtf", extensions=["rtf"]),
				Icon("application-sql", ["text-x-sql", "application-x-sqlite3", "application-x-sqlite2", "application-vnd.oasis.opendocument.database"], ["sql"]),
				Icon("application-toml", extensions=["toml"]),
				Icon("application/vnd.coffeescript"),
				Icon("application-vnd.rar", ["application-x-rar"], ["rar"]),
				Icon("application-x-7z-compressed", ["application-x-7zip-compressed", "application-x-7zip", "application-7z"], ["7z"]),
				Icon("application-x-asp"),
				Icon("application-x-bittorrent"),
				Icon("application-x-bzip-compressed-tar", extensions=["tar.bz2", "tar.bz", "tbz2", "tbz"]),
				Icon("application-x-bzip", extensions=["bz2", "bz"]),
				Icon("application-x-cd-image", ["application-x-iso9660-image", "application-x-iso"], ["iso"]),
				Icon("application-x-compress", extensions=["z"]),
				Icon("application-x-compressed-tar", ["application-x-gzip-compressed-tar"], ["tar.gz", "tgz"]),
				Icon("application-x-java", extensions=["class"]),
				Icon("application-x-perl", extensions=["pl", "perl"]),
				Icon("application-x-php", ["text-x-php"], ["php"]),
				Icon("application-x-python-bytecode", extensions=["pyc", "pyo"]),
				Icon("application-x-python"),		# not listed in mime type xmls; not sure what this is supposed to be, doesn't look the same as text-x-python
				Icon("application-x-ruby", ["text-x-ruby"], ["rb"]),
				Icon("application-x-shellscript", ["shellscript"]),
				Icon("application-x-tar"),
				Icon("application-x-tarz"),
				Icon("application-x-trash", ["text-x-bak"], ["bak", "old"]),
				Icon("application-x-yaml", ["text-x-yaml"], ["yaml", "yml"]),
				Icon("application-xhtml+xml", ["text-xhtml", "text-xhtml+xml"], ["xhtml", "xht"]),
				Icon("application-xml", ["text-xml"], ["xml"]),
				Icon("application-zip", ["application-x-zip", "application-archive-zip"], ["zip"]),
				Icon("audio-aac", ["audio-x-aac"], ["aac", "adts"]),
				Icon("audio-ac3", extensions=["ac3"]),
				Icon("audio-flac", ["audio-x-flac"], ["flac"]),
				Icon("audio-midi", ["audio-x-midi"], ["mid", "midi"]),
				Icon("audio-mp2", ["audio-x-mp2"], extensions=["mp2"]),
				Icon("audio-mpeg", ["audio-mp3", "audio-x-mpeg", "audio-x-mp3"], ["mp3", "mpga"]),
				Icon("audio-mp4", ["audio-m4a", "audio-x-mp4", "audio-x-m4a"], extensions=["m4a"]),
				Icon("audio-ogg", ["audio-x-vorbis+ogg", "audio-x-ogg"], ["oga", "ogg", "opus"]),
				Icon("audio-webm"),
				Icon("audio-x-generic", ["media-audio"]),
				Icon("audio-x-matroska", extensions=["mka"]),
				Icon("audio-x-mod", extensions=["mod", "669"]),
				Icon("audio-x-mpegurl", ["playlist", "application-audio-playlist"], ["m3u", "m3u8"]),
				Icon("audio-x-ms-asx", ["audio-x-ms-wax"], ["asx", "wax"]),
				Icon("audio-x-ms-wma", ["audio-wma"], ["wma"]),
				Icon("audio-x-wav", ["audio-wav"], ["wav"]),
				Icon("font-x-generic", ["font-x-generic"], extensions=["ttf"]),
				Icon("font-ttf", ["application-x-font-ttf"], extensions=["ttf"]),
				Icon("font-otf", ["application-x-font-otf"], extensions=["otf"]),
				Icon("font-collection", extensions=["ttc"]),
				Icon("font-woff", extensions=["woff"]),
				Icon("font-woff2", extensions=["woff2"]),
				Icon("application-x-font-afm", extensions=["afm"]),
				Icon("application-x-font-type1", extensions=["pfa", "pfb"]),
				Icon("image-bmp", ["image-x-bmp", "application-image-bmp"], ["bmp", "dib"]),
				Icon("image-gif", ["application-image-gif"], ["gif"]),
				Icon("image-jpeg", ["application-image-jpeg", "application-image-jpg"], ["jpeg", "jpg"]),
				Icon("image-png", ["application-image-png"], ["png"]),
				Icon("image-svg+xml", ["application-image-svg+xml", "application-vector"], ["svg"]),
				Icon("image-tiff", ["application-image-tiff"], ["tif", "tiff"]),
				Icon("image-webp", extensions=["webp"]),
				Icon("image-vnd.djvu", ["djvu"], extensions=["djvu"]),	# more of a document format than an image, right?
				Icon("image-x-generic", ["application-images", "image", "media-image"]),
				Icon("message-news"),
				Icon("message-rfc822", extensions=["eml"]),
				Icon("package-x-generic", ["application-x-package-generic"]),		# target name is not real (but neither is the source name), but want this to show up near the other package types
				Icon("text-css", extensions=["css"]),
				Icon("text-csv", ["text-x-csv", "text-x-comma-separated-values"], ["csv"]),
				Icon("text-html", ["application-html", "application-x-mswinurl"], ["htm", "html"]),
				Icon("text-less"),		# this doesn't show up in the mime list xml files; and not sure if there are any aliases or if this should be 'application-less' ??
				Icon("text-markdown", ["text-x-markdown"], ["md", "markdown", "mkd"]),
				Icon("text-plain", ["text-x-generic", "ascii"], ["txt"]),
				Icon("text-richtext", extensions=["rtx"]),		# apparently not the same as 'application-rtf' ??
				Icon("text-rust", extensions=["rs"]),
				Icon("text-vbscript", ["text-x-vbscript"], ["vbs"]),
				Icon("text-x-c++hdr", extensions=["hpp", "hh", "hxx", "h++"]),
				Icon("text-x-c++src", ["text-x-cpp"], ["cpp", "cxx", "cc", "c++"]),
				Icon("text-x-changelog"),
				Icon("text-x-chdr", extensions=["h"]),
				Icon("text-x-cmake", extensions=["cmake"]),
				Icon("text-x-cobol", extensions=["cob", "cbl"]),
				Icon("text-x-csharp", ["text-csharp"], ["cs"]),
				Icon("text-x-csrc", ["text-x-c"], ["c"]),
				Icon("text-x-diff"),
				Icon("text-x-erlang", extensions=["erl"]),
				Icon("text-x-fortran", extensions=["for"]),
				Icon("text-x-go", extensions=["go"]),
				Icon("text-x-gradle", extensions=["gradle"]),
				Icon("text-x-haskell", extensions=["hs"]),
				Icon("text-x-hex"),
				Icon("text-x-java", extensions=["java", "jav"]),
				Icon("text-x-kotlin", extensions=["kt"]),
				Icon("text-x-log", extensions=["log"]),
				Icon("text-x-lua", extensions=["lua"]),
				Icon("text-x-makefile", extensions=["mak", "mk"]),
				Icon("text-x-opml+xml", ["text-x-opml"], ["opml"]),
				Icon("text-x-pascal", extensions=["pas", "p"]),
				Icon("text-x-python", ["text-x-python3"], ["py"]),
				Icon("text-x-python"),
				Icon("text-x-python3", "text-x-python"),
				Icon("text-x-r", ["text-r"]),	# not registered, not in mime type xml files
				Icon("text-x-readme", ["readme"]),
				Icon("text-x-sass", extensions=["sass"]),
				Icon("text-x-scala", extensions=["scala"]),
				Icon("text-x-scheme", extensions=["scm", "ss"]),
				Icon("text-x-script"),
				Icon("text-x-scss", extensions=["scss"]),
				Icon("text-x-typescript", extensions=["ts"]),	# not registered, not in mime type xml files
				Icon("video-mp4", ["video-x-mp4", "video-x-m4v"], ["mp4", "m4v"]),
				Icon("video-mpeg", ["video-x-mpeg"], ["mpeg", "mpg", "mp2", "vob"]),
				Icon("video-quicktime", ["video-x-mov"], ["mov", "qt"]),
				Icon("video-webm", extensions=["webm"]),
				Icon("video-x-flv", ["application-x-shockwave-flash", "application-x-flash-video"], ["flv"]),
				Icon("video-x-generic", ["media-video"]),
				Icon("video-x-matroska", extensions=["mkv"]),
				Icon("video-x-ms-wmv", ["video-x-wmv"], extensions=["wmv"]),
				Icon("video-x-msvideo", ["video-x-avi", "video-avi", "video-msvideo"], ["avi", "divx"]),
				Icon("video-x-ogm+ogg", ["video-x-ogm"], ["ogm"]),
				Icon("video-x-theora+ogg", ["video-x-theora"], ["ogg"]),
				Icon("x-dia-diagram"),
				Icon("x-media-podcast", ["podcast"]),
				Icon("x-ms-regedit", extensions=["reg"]),
				Icon("x-office-address-book"),
				Icon("x-office-calendar"),
				Icon("x-office-contact"),
				Icon("x-office-document"),
				Icon("x-office-drawing"),
				Icon("x-office-presentation"),
				Icon("x-office-spreadsheet"),
			]),
			IconTypeList("apps", None, [
				Icon("accessories-calculator"),
				Icon("accessories-camera"),
				Icon("accessories-character-map"),
				Icon("accessories-clipboard"),
				Icon("accessories-clock"),
				Icon("accessories-dictionary"),
				Icon("accessories-document-viewer"),
				Icon("accessories-ebook-reader"),
				Icon("accessories-maps"),
				Icon("accessories-media-converter"),
				Icon("accessories-notes"),
				Icon("accessories-paint"),
				Icon("accessories-painting"),
				Icon("accessories-podcast"),
				Icon("accessories-screenshot"),
				Icon("accessories-system-cleaner"),
				Icon("accessories-text-editor"),
				Icon("acetoneiso"),
				Icon("acroread"),
				Icon("address-book-app"),
				Icon("addressbook"),
				Icon("alarm-clock"),
				Icon("alienarena", ["alien-arena"]),
				Icon("alienfx"),
				Icon("androidstudio", ["android-studio"]),
				Icon("app-launcher"),
				Icon("applets-screenshooter"),
				Icon("applications-office"),
				Icon("arts"),
				Icon("atom"),
				Icon("audio-equalizer"),
				Icon("audio-recorder"),
				Icon("authy"),
				Icon("boxes"),
				Icon("brackets"),
				Icon("brasero"),
				Icon("btsync-gui"),
				Icon("caffeine"),
				Icon("calc"),
				Icon("calculator-app"),
				Icon("calendar"),
				Icon("calendar-app"),
				Icon("calibre"),
				Icon("camera-app"),
				Icon("cantata"),
				Icon("chat"),
				Icon("checkbox"),
				Icon("chrome-app-list"),
				Icon("clipgrab"),
				Icon("clipit"),
				Icon("clock"),
				Icon("clock-app"),
				Icon("cmake"),
				Icon("codeblocks"),
				Icon("color-picker"),
				Icon("config-users"),
				Icon("configurator-app"),
				Icon("cs-general"),
				Icon("cs-network"),
				Icon("cs-workspaces"),
				Icon("darktable"),
				Icon("dconf-editor"),
				Icon("deluge"),
				Icon("dictionary"),
				Icon("digikam"),
				Icon("direct-connect"),
				Icon("disk-burner"),
				Icon("disk-usage-app"),
				Icon("disk-utility-app"),
				Icon("disks"),
				Icon("documents-app"),
				Icon("docviewer-app"),
				Icon("dvdrip"),
				Icon("dvdstyler"),
				Icon("ebook-reader-app"),
				Icon("elasticsearch"),
				Icon("electron"),
				Icon("evolution"),
				Icon("evolution-calendar"),
				Icon("evolution-tasks"),
				Icon("exaile"),
				Icon("extensions"),
				Icon("fbreader"),
				Icon("fedy"),
				Icon("filemanager-app"),
				Icon("fingerprint-gui"),
				Icon("five-or-more"),
				Icon("fluxgui"),
				Icon("four-in-a-row"),
				Icon("gallery-app"),
				Icon("gedit"),
				Icon("git"),
				Icon("gmpc"),
				Icon("gmusicbrowser"),
				Icon("gnac"),
				Icon("gnome-books"),
				Icon("gnome-character-map"),
				Icon("gnome-clocks"),
				Icon("gnome-commander"),
				Icon("gnome-documents"),
				Icon("gnome-mixer"),
				Icon("gnome-mplayer"),
				Icon("gnome-mpv"),
				Icon("gnome-nettool"),
				Icon("gnome-photos"),
				Icon("gnome-power-manager"),
				Icon("gnome-power-statistics"),
				Icon("gnome-screenshot"),
				Icon("gnome-software"),
				Icon("gnome-sound-recorder"),
				Icon("gnome-todo"),
				Icon("gnome-tweak-tool"),
				Icon("gnome-weather"),
				Icon("gnumeric"),
				Icon("goobox"),
				Icon("gparted"),
				Icon("gpick"),
				Icon("grsync"),
				Icon("gtg"),
				Icon("gthumb"),
				Icon("gtkhash"),
				Icon("gvbam"),
				Icon("help-browser"),
				Icon("hexchat"),
				Icon("hexedit"),
				Icon("homebank"),
				Icon("image-viewer-app"),
				Icon("internet-mail"),
				Icon("internet-news-reader"),
				Icon("internet-web-browser"),
				Icon("isomaster"),
				Icon("jack"),
				Icon("jamin"),
				Icon("juk"),
				Icon("leafpad"),
				Icon("log-viewer-app"),
				Icon("login"),
				Icon("logview"),
				Icon("logviewer"),
				Icon("mail-app"),
				Icon("maps-app"),
				Icon("mathematica"),
				Icon("mediaplayer-app"),
				Icon("menu-editor"),
				Icon("messaging-app"),
				Icon("mintinstall"),
				Icon("mintupload"),
				Icon("mpd"),
				Icon("mplayer"),
				Icon("mpv"),
				Icon("multimedia-audio-player"),
				Icon("multimedia-photo-viewer"),
				Icon("multimedia-video-player"),
				Icon("music-app"),
				Icon("musique"),
				Icon("nautilus"),
				Icon("nemo"),
				Icon("netbeans"),
				Icon("notes-app"),
				Icon("okteta"),
				Icon("okular"),
				Icon("openshot"),
				Icon("password"),
				Icon("passwords"),
				Icon("passwords-app"),
				Icon("picard"),
				Icon("podcasts-app"),
				Icon("power-statistics"),
				Icon("preferences-color", ["cs-color"]),
				Icon("preferences-desktop-accessibility", ["cs-universal-access"]),
				Icon("preferences-desktop-font"),
				Icon("preferences-desktop-hotcorners", ["cs-overview", "preferences-system-hotcorners"]),
				Icon("preferences-desktop-keyboard"),
				Icon("preferences-desktop-keyboard-shortcuts"),
				Icon("preferences-desktop-online-accounts", ["cs-online-accounts"]),
				Icon("preferences-desktop-sound"),
				Icon("preferences-desktop-theme"),
				Icon("preferences-desktop-user", ["cs-user"]),
				Icon("preferences-desktop-user-accounts", ["cs-user-accounts"]),
				Icon("preferences-desktop-user-password"),
				Icon("preferences-desktop-wallpaper", ["cs-backgrounds"]),
				Icon("preferences-system"),
				Icon("preferences-system-login", ["cs-login"]),
				Icon("preferences-system-notifications", ["cs-notifications"]),
				Icon("preferences-system-performance"),
				Icon("preferences-system-power", ["cs-power"]),
				Icon("preferences-system-privacy"),
				Icon("preferences-system-search"),
				Icon("preferences-system-sharing"),
				Icon("preferences-system-sound"),
				Icon("preferences-system-time", ["cs-date-time"]),
				Icon("preferences-system-windows"),
				Icon("preferences-web-browser"),
				Icon("python"),
				Icon("quassel"),
				Icon("quiterss"),
				Icon("redshift"),
				Icon("scanner"),
				Icon("screenshot-app"),
				Icon("scribus"),
				Icon("shotwell"),
				Icon("shutter"),
				Icon("smartgit"),
				Icon("smuxi"),
				Icon("sqldeveloper"),
				Icon("sqlitebrowser"),
				Icon("sunflower"),
				Icon("system-error"),
				Icon("system-file-manager"),
				Icon("system-monitor-app"),
				Icon("system-remixer"),
				Icon("system-settings"),
				Icon("system-software-install"),
				Icon("system-software-update"),
				Icon("system-users"),
				Icon("terminal-app"),
				Icon("to-do-app"),
				Icon("totem"),
				Icon("transmageddon"),
				Icon("transmission"),
				Icon("tweaks-app"),
				Icon("ubuntu-sdk"),
				Icon("ufraw"),
				Icon("unity-lens-photos"),
				Icon("unity-scope-gdrive"),
				Icon("update-manager"),
				Icon("usage-app"),
				Icon("user-info"),
				Icon("utilities-system-monitor"),
				Icon("utilities-terminal"),
				Icon("utilities-terminal-alt"),
				Icon("virtualbox"),
				Icon("vlc"),
				Icon("vocal"),
				Icon("weather-app"),
				Icon("web-browser"),
				Icon("webbrowser-app"),
				Icon("wine-browser"),
				Icon("wine-folder"),
				Icon("wine-notepad"),
				Icon("winecfg"),
				Icon("xchat"),
				Icon("xdiagnose"),
				Icon("xfburn"),
				Icon("yast"),
			]),
			IconTypeList("actions", None, [
				Icon("address-book-new"),
				Icon("application-exit"),
				Icon("appointment-new"),
				Icon("bookmark-new"),
				Icon("call-start"),
				Icon("call-stop"),
				Icon("cancel"),
				Icon("configure"),
				Icon("dialog-apply"),
				Icon("document-new"),
				Icon("document-open"),
				Icon("document-open-recent"),
				Icon("document-page-setup"),
				Icon("document-print"),
				Icon("document-properties"),
				Icon("document-revert"),
				Icon("document-save"),
				Icon("document-save-as"),
				Icon("edit-clear"),
				Icon("edit-copy"),
				Icon("edit-cut"),
				Icon("edit-delete"),
				Icon("edit-find"),
				Icon("edit-find-replace"),
				Icon("edit-paste"),
				Icon("edit-redo"),
				Icon("edit-select-all"),
				Icon("edit-undo"),
				Icon("fileprint"),
				Icon("folder-new"),
				Icon("format-indent-less"),
				Icon("format-indent-more"),
				Icon("format-justify-center"),
				Icon("format-justify-fill"),
				Icon("format-justify-left"),
				Icon("format-text-bold"),
				Icon("format-text-italic"),
				Icon("format-text-strikethrough"),
				Icon("format-text-underline"),
				Icon("go-bottom"),
				Icon("go-down"),
				Icon("go-first"),
				Icon("go-home"),
				Icon("go-jump"),
				Icon("go-last"),
				Icon("go-next"),
				Icon("go-previous"),
				Icon("go-top"),
				Icon("go-up"),
				Icon("help-about"),
				Icon("help-contents"),
				Icon("help-faq"),
				Icon("help-info"),
				Icon("insert-image"),
				Icon("insert-link"),
				Icon("insert-object"),
				Icon("insert-text"),
				Icon("list-add"),
				Icon("list-remove"),
				Icon("mail-attachment"),
				Icon("mail-forward"),
				Icon("mail-inbox"),
				Icon("mail-mark-important"),
				Icon("mail-mark-important"),
				Icon("mail-mark-junk"),
				Icon("mail-mark-notjunk"),
				Icon("mail-mark-read"),
				Icon("mail-mark-unread"),
				Icon("mail-message-new"),
				Icon("mail-outbox"),
				Icon("mail-read"),
				Icon("mail-reply-all"),
				Icon("mail-reply-sender"),
				Icon("mail-send"),
				Icon("mail-send-receive"),
				Icon("mail-sent"),
				Icon("mail-unread"),
				Icon("mark-location"),
				Icon("media-eject"),
				Icon("media-import-audio-cd"),
				Icon("media-optical-audio-new"),
				Icon("media-optical-burn"),
				Icon("media-optical-copy"),
				Icon("media-playback-pause"),
				Icon("media-playback-start"),
				Icon("media-playback-stop"),
				Icon("media-record"),
				Icon("media-seek-backward"),
				Icon("media-seek-forward"),
				Icon("media-skip-backward"),
				Icon("media-skip-forward"),
				Icon("object-flip-horizontal"),
				Icon("object-flip-vertical"),
				Icon("object-rotate-left"),
				Icon("object-rotate-right"),
				Icon("open-menu"),
				Icon("process-stop"),
				Icon("system-hibernate"),
				Icon("system-lock-screen"),
				Icon("system-log-out"),
				Icon("system-reboot"),
				Icon("system-run"),
				Icon("system-search"),
				Icon("system-shutdown"),
				Icon("system-suspend"),
				Icon("tools-check-spelling"),
				Icon("view-fullscreen"),
				Icon("view-refresh"),
				Icon("view-restore"),
				Icon("view-sort-ascending"),
				Icon("view-sort-descending"),
				Icon("window-close"),
				Icon("window-new"),
				Icon("zoom-fit-best"),
				Icon("zoom-in"),
				Icon("zoom-original"),
				Icon("zoom-out"),
			]),
			IconTypeList("categories", None, [
				Icon("application-community"),
				Icon("applications-3D"),
				Icon("applications-arcade"),
				Icon("applications-astronomy"),
				Icon("applications-biology"),
				Icon("applications-boardgames"),
				Icon("applications-cardgames"),
				Icon("applications-chat"),
				Icon("applications-debugging"),
				Icon("applications-drawing"),
				Icon("applications-education"),
				Icon("applications-electronics"),
				Icon("applications-filesharing"),
				Icon("applications-fonts"),
				Icon("applications-geography"),
				Icon("applications-geology"),
				Icon("applications-ide"),
				Icon("applications-interfacedesign"),
				Icon("applications-libraries"),
				Icon("applications-lisp"),
				Icon("applications-mail"),
				Icon("applications-monodevelopment"),
				Icon("applications-painting"),
				Icon("applications-perl"),
				Icon("applications-photography"),
				Icon("applications-php"),
				Icon("applications-physics"),
				Icon("applications-profiling"),
				Icon("applications-publishing"),
				Icon("applications-roleplaying"),
				Icon("applications-simulation"),
				Icon("applications-sports"),
				Icon("applications-versioncontrol"),
				Icon("applications-viewers"),
				Icon("configuration_section"),
				Icon("preferences-color"),
				Icon("preferences-desktop-accessibility"),
				Icon("preferences-desktop-applications"),
				Icon("preferences-desktop-default-applications"),
				Icon("preferences-desktop-display"),
				Icon("preferences-desktop-font"),
				Icon("preferences-desktop-keyboard-shortcuts"),
				Icon("preferences-desktop-personal"),
				Icon("preferences-desktop-tweaks"),
				Icon("preferences-desktop-wallpaper"),
				Icon("preferences-system-bluetooth"),
				Icon("preferences-system-brightness-lock"),
				Icon("preferences-system-parental-controls"),
				Icon("preferences-system-sharing"),
				Icon("preferences-system-sound"),
				Icon("preferences-system-time"),
				Icon("preferences-system-users"),
				Icon("system-component-addon"),
				Icon("system-component-application"),
				Icon("system-component-codecs"),
				Icon("system-component-driver"),
				Icon("system-component-input-sources"),
				Icon("system-component-os-updates"),
			]),
			IconTypeList("devices", None, [
				Icon("ac-adapter"),
				Icon("audio-card"),
				Icon("audio-headphones"),
				Icon("audio-headset"),
				Icon("audio-speakers"),
				Icon("blueman-device"),
				Icon("bluetooth"),
				Icon("camera-video"),
				Icon("camera"),
				Icon("display"),
				Icon("drive-cdrom"),
				Icon("drive-harddisk-ieee1394"),
				Icon("drive-harddisk-usb"),
				Icon("drive-multidisk"),
				Icon("gnome-dev-harddisk"),
				Icon("gnome-dev-jazdisk"),
				Icon("gnome-dev-keyboard"),
				Icon("gnome-dev-removable"),
				Icon("input-audio-microphone"),
				Icon("input-dialpad"),
				Icon("input-gaming"),
				Icon("input-tablet"),
				Icon("input-touchpad"),
				Icon("joystick"),
				Icon("keyboard"),
				Icon("media-flash"),
				Icon("media-removable"),
				Icon("media-tape"),
				Icon("modem"),
				Icon("mouse"),
				Icon("multimedia-player-ipod-touch"),
				Icon("multimedia-player-ipod"),
				Icon("network-vpn"),
				Icon("network-wired"),
				Icon("network-wireless"),
				Icon("printer-network"),
				Icon("scanner"),
				Icon("system"),
				Icon("uninterruptible-power-supply"),
				Icon("video-display"),
			]),
			#IconTypeList("emblems", None, []),
			#IconTypeList("places", None, []),
			#IconTypeList("status", None, []),
		]

		Helpers.TempPath = self._tempPath

	#region properties
	@property
	def inputBasePath(self) -> pathlib.Path:
		return self._inputBasePath

	@property
	def pngsBasePath(self) -> pathlib.Path:
		return self._pngsBasePath

	@property
	def iconsBasePath(self) -> pathlib.Path:
		return self._iconsBasePath

	@property
	def tempPath(self) -> pathlib.Path:
		return self._tempPath

	@property
	def themeDefinitions(self) -> List[IconThemeDefinition]:
		return self._themeDefinitions

	@property
	def iconTypeLists(self) -> List[IconTypeList]:
		return self._iconTypeLists

	@property
	def targetPngSizes(self) -> List[TargetPngSize]:
		return self._targetPngSizes
	#endregion

	def process(self, createIcosOnly : bool, copyPngsOnly: bool, onlyTheme : str, onlyType : str, onlyNames : List[str]):
		#region some checks:
		Helpers.LogVerbose(f"starting processing of iconsToCopy (contains {len(self.themeDefinitions)} themes)")
		Helpers.LogVerbose(f"    createIcosOnly = {createIcosOnly}, copyPngsOnly = {copyPngsOnly}, onlyTheme = |{onlyTheme}|, onlyType = |{onlyType}|, onlyNames = |{', '.join(onlyNames)}|")

		if createIcosOnly and copyPngsOnly:
			# TODO: is there some way to do this above in the arg parsing definition/parsing??
			msg = "cannot specify both createIcosOnly and createIcosOnly"
			LogHelper.Error(msg)
			raise argparse.ArgumentError(message=msg)

		if not createIcosOnly:
			if not self.inputBasePath.exists():
				msg = f"base input folder '{self.inputBasePath}' does not exist"
				LogHelper.Error(msg)
				raise FileNotFoundError(filename = self.inputBasePath, strerror = msg)

		Helpers.VerifyFolderExists(self.pngsBasePath)
		if not copyPngsOnly:
			Helpers.VerifyFolderExists(self.iconsBasePath)
		Helpers.VerifyFolderExists(self.tempPath)

		if not Constants.PathToInkscape or not Constants.PathToInkscape.exists():
			msg = f"Inkscape exe '{Constants.PathToInkscape}' not found, or does not exist at path"
			LogHelper.Error(msg)
			raise FileNotFoundError(filename = Constants.PathToInkscape, strerror = msg)
		if not Constants.PathToImageMagick or not Constants.PathToImageMagick.exists():
			msg = f"Imagemagick exe '{Constants.PathToImageMagick}' not found, or does not exist at path"
			LogHelper.Error(msg)
			raise FileNotFoundError(filename = Constants.PathToImageMagick, strerror = msg)
		if not Constants.PathToOptipng or not Constants.PathToOptipng.exists():
			msg = f"optipng exe '{Constants.PathToOptipng}' not found, or does not exist at path"
			LogHelper.Error(msg)
			raise FileNotFoundError(filename = Constants.PathToOptipng, strerror = msg)
		#endregion

		for iconSize in self.targetPngSizes:
			iconSize.initLookupOrder(self.targetPngSizes)

		origTempdir = tempfile.tempdir
		try:
			tempfile.tempdir = self.tempPath
			for th in self.themeDefinitions:
				if onlyTheme and th.themeName != onlyTheme:
					Helpers.LogVerbose(f"skipping iconTheme for '{th.themeName}', doesn't match --theme option '{onlyTheme}'")
					continue
				elif onlyTheme:
					Helpers.LogVerbose(f"{Constants.LargeDivider}{os.linesep}processing theme '{th.themeName}'")
				else:
					LogHelper.MessageMagenta(f"{Constants.LargeDivider}{os.linesep}processing theme '{th.themeName}'")
				workUnit = IconThemeDefinition.WorkUnit(self.inputBasePath, self.pngsBasePath, self.iconsBasePath, createIcosOnly,
														copyPngsOnly, onlyType, onlyNames, self.iconTypeLists, self.targetPngSizes)
				th.process(workUnit)
		finally:
			tempfile.tempdir = origTempdir

class BackupsHelper:
	@staticmethod
	def GetBackupName(file : pathlib.Path) -> pathlib.Path:
		if file != None and file.exists():
			#ts = datetime.fromtimestamp(targetFile.stat().st_mtime, tz=timezone.utc).strftime('%Y%m%d_%H%M')
			ts = datetime.fromtimestamp(file.stat().st_mtime).strftime('%Y%m%d_%H%M')	# use local time
			return file.parent / f'{file.stem}.{ts}{file.suffix}'
		return None

	@staticmethod
	def RenameBackupFiles(reverseNaming : bool, renameIcosOnly : bool, renamePngOnly : bool):
		if reverseNaming:
			# find filenames starting with '@' and with timestamp on end:
			pattern = re.compile(r'^@.+\.\d{8}_\d{4}$')
		else:
			# find filenames NOT starting with '@' and with timestamp on end:
			pattern = re.compile(r'^[^@].+\.\d{8}_\d{4}$')
		if not renameIcosOnly:
			BackupsHelper._renameFiles(Constants.PngsOutputPath, '.png', pattern, reverseNaming)
		if not renamePngOnly:
			BackupsHelper._renameFiles(Constants.IconsOutputPath, '.ico', pattern, reverseNaming)

	@staticmethod
	def _renameFiles(baseFolder : pathlib.Path, extension : str, pattern : re.Pattern, reverseNaming: bool):
		filesToRename : List[pathlib.Path] = []	# don't rename while we're iterating the files; not sure what that'll do
		for file in baseFolder.glob(f'**/*{extension}'):
			if pattern.search(file.stem):
				filesToRename.append(file)
				#if len(filesToRename) > 10: break
		for file in filesToRename:
			oldBasename = file.stem
			newBasename = oldBasename[1:] if reverseNaming else '@' + oldBasename
			targetFilepath = file.parent / f"{newBasename}{file.suffix}"
			msg = f"renaming backup from '{Helpers.GetRelativePath(file)}' to '{Helpers.GetRelativePath(targetFilepath)}'"
			LogHelper.Message(msg)
			Helpers.MoveFile(file, targetFilepath, msg)

if __name__ == "__main__":
	sys.exit(main())
