#!python3
# -*- coding: utf-8 -*-
import sys
if sys.version_info < (3, 9):
	sys.exit("python version 3.9 or higher if required")
import os, re, pathlib, shutil, subprocess, urllib.request, json, argparse, tarfile, zipfile
from typing import Iterator#, Self#, List, Dict#, Any, Pattern, Tuple
from io import BytesIO
from loghelper import LogHelper
from githubHelper import GithubRelease
if sys.platform == "win32":
	import fontTools.ttLib
	import ctypes
	from ctypes import wintypes
	import winreg

def main() -> int:
	# https://www.nerdfonts.com/font-downloads
	# https://github.com/ryanoasis/nerd-fonts/releases/latest
	# https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/
	parser = initArgParser()
	args = parser.parse_args()
	verboseLogging = args.verbose
	testMode = args.test
	forceInstall = args.force

	LogHelper.Init(verboseLogging)

	osHelper = OSHelper(testMode) if sys.platform != "win32" else OSHelperWin(testMode)	# is there a better way to do this? IoC, something?

	LogHelper.Verbose(f"using userFontsFolder = |{osHelper.fontsFldr}|")

	if not checkPrereqs(osHelper): return 1

	# get latest release info for NerdFonts on GitHub:
	ghRelease : GithubRelease = GithubRelease.GetLatestRelease("ryanoasis", "nerd-fonts")
	# get version string, and compare that to version file in the NerdFonts folders:
	currVerStr = getNerdFontsVerStr(ghRelease)
	if not forceInstall:
		for f in osHelper.fontsFldr.glob("@version_*"):
			if f.name >= currVerStr:
				LogHelper.Message("latest version of NerdFonts already installed")
				return 0

	print("")
	LogHelper.Message2("################################################")
	LogHelper.Message2(f"installing version {ghRelease.tag} of NerdFonts")
	LogHelper.Message2("################################################")
	fontsToInstall = initFontsToInstall(ghRelease)
	removeOldFonts(osHelper)
	for nfd in fontsToInstall.fonts:
		installFont(nfd, osHelper)
	# create version file:
	(osHelper.fontsFldr / currVerStr).touch()
	rebuildFontCache(osHelper)

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	parser.add_argument("-t", "--test", action="store_true", help="enable test mode (won't actually install fonts)")
	parser.add_argument("-f", "--force", action="store_true", help="force download and install, even if we already have latest version")
	return parser

class OSHelper:
	def __init__(self, testMode : bool = False):
		self._testMode = testMode
		if testMode:
			tmp = "temp" if sys.platform == "win32" else "tmp"
			self._fontsFldr = pathlib.Path(os.path.expandvars(f"$HOME/{tmp}/fonts/NerdFonts"))
		elif sys.platform == "linux":
			self._fontsFldr = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts/NerdFonts"))
		elif sys.platform == "darwin":
			self._fontsFldr = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts/NerdFonts"))
		elif sys.platform == "win32":
			# for per-user fonts, have to be installed to %LocalAppData%/Microsoft/Windows/Fonts, can be in a subfolder
			self._fontsFldr = pathlib.Path(os.path.expandvars("%LocalAppData%/Microsoft/Windows/Fonts/NerdFonts"))
		else:
			raise RuntimeError(f"invalid/unrecognized OS: '{sys.platform}'")

	def installFont(self, fontpath : pathlib.Path) -> None: pass

	def uninstallFont(self, fontpath : pathlib.Path) -> None: pass

	@property
	def testMode(self) -> bool:
		return self._testMode

	@property
	def fontsFldr(self) -> pathlib.Path:
		return self._fontsFldr

if sys.platform == "win32":
	class OSHelperWin(OSHelper):
		# fonts have to be installed to this reg location in order to stay registered after rebooting;
		_FontsRegPath = r'Software\Microsoft\Windows NT\CurrentVersion\Fonts'
		_HWND_BROADCAST = 0xFFFF
		_SMTO_ABORTIFHUNG = 0x0002
		_WM_FONTCHANGE = 0x001D

		def __init__(self, testMode : bool = False):
			super().__init__(testMode)

			if not hasattr(wintypes, 'LPDWORD'):
				wintypes.LPDWORD = ctypes.POINTER(wintypes.DWORD)

			self._user32 = ctypes.WinDLL('user32', use_last_error=True)
			self._gdi32 = ctypes.WinDLL('gdi32', use_last_error=True)

			# https://learn.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-sendmessagetimeoutw
			self._user32.SendMessageTimeoutW.restype = wintypes.LPVOID
			self._user32.SendMessageTimeoutW.argtypes = (wintypes.HWND, wintypes.UINT, wintypes.LPVOID, wintypes.LPVOID, wintypes.UINT, wintypes.UINT, wintypes.LPVOID)
			# https://learn.microsoft.com/en-us/windows/win32/api/wingdi/nf-wingdi-addfontresourcew
			self._gdi32.AddFontResourceW.argtypes = (wintypes.LPCWSTR,) # lpszFilename
			#self._gdi32.RemoveFontResourceW.restype = wintypes.BOOL	# no actual change...
			self._gdi32.RemoveFontResourceW.argtypes = (wintypes.LPCWSTR,) # lpszFilename

		def installFont(self, fontpath : pathlib.Path) -> None:
			fontname = self._getTtfFontName(fontpath)
			self._addFontToRegistry(fontpath, fontname)
			self._addFontResource(fontpath)
			self._sendNotification()

		def uninstallFont(self, fontpath : pathlib.Path) -> None:
			fontname = self._getTtfFontName(fontpath)
			self._removeFontFromRegistry(fontname)
			self._removeFontResource(fontpath)
			self._sendNotification()

		def _getTtfFontName(self, fontpath : pathlib.Path) -> str:
			tt = fontTools.ttLib.TTFont(fontpath)
			fontName = tt['name'].getBestFullName()
			# isTtf = if it has a table named 'glyf' ("glyph outlines drawn with quadratic beziers")
			# isOtf = if it has a table named 'CFF ' or 'CFF2' ("glyph outlines drawn with cubic beziers")
			if ('glyf' in tt) or ('CFF ' in tt or 'CFF2' in tt): # but we're going to call them both 'TrueType' anyway (right ???)
				fontName += ' (TrueType)'
			return fontName

		def _sendNotification(self) -> None:
			logmsg = "sending WM_FONTCHANGE notification"
			if self._testMode:
				LogHelper.WhatIf(logmsg)
				return
			LogHelper.Verbose(logmsg)
			self._user32.SendMessageTimeoutW(OSHelperWin._HWND_BROADCAST, OSHelperWin._WM_FONTCHANGE, 0, 0, OSHelperWin._SMTO_ABORTIFHUNG, 1000, None)

		def _addFontResource(self, fontpath : pathlib.Path) -> int:
			logmsg = f"calling AddFontResource for font path |{fontpath}|"
			if self._testMode:
				LogHelper.WhatIf(logmsg)
				return 1
			LogHelper.Verbose(logmsg)
			return self._gdi32.AddFontResourceW(str(fontpath))

		def _removeFontResource(self, fontpath : pathlib.Path) -> bool:
			logmsg = f"calling RemoveFontResource for font path |{fontpath}|"
			if self._testMode:
				LogHelper.WhatIf(logmsg)
				return True
			LogHelper.Verbose(logmsg)
			return self._gdi32.RemoveFontResourceW(str(fontpath))

		def _addFontToRegistry(self, fontpath : pathlib.Path, fontname : str) -> None:
			logmsg = f"adding fontname |{fontname}| to registry"
			if self._testMode:
				LogHelper.WhatIf(logmsg)
				return
			LogHelper.Verbose(logmsg)
			with winreg.OpenKey(winreg.HKEY_CURRENT_USER, OSHelperWin._FontsRegPath, 0, winreg.KEY_SET_VALUE) as key:
				winreg.SetValueEx(key, fontname, 0, winreg.REG_SZ, str(fontpath))

		def _removeFontFromRegistry(self, fontname : str) -> None:
			logmsg = f"removing fontname |{fontname}| from registry"
			if self._testMode:
				LogHelper.WhatIf(logmsg)
				return
			LogHelper.Verbose(logmsg)
			with winreg.OpenKey(winreg.HKEY_CURRENT_USER, OSHelperWin._FontsRegPath, 0, winreg.KEY_SET_VALUE) as key:
				try: winreg.DeleteValue(key, fontname)
				except FileNotFoundError: pass

class NerdFontDefn:
	DownloadTypeTarXz = "tarxz"
	DownloadTypeZip = "zip"

	def __init__(self, assetName : str, patternsToExtract : list[str]):
		self._assetName : str = assetName
		self._patterns : list[re.Pattern] = []
		for p in patternsToExtract:
			self._patterns.append(re.compile(p))
		self._downloadUrl : str = ""
		self._downloadType : str = ""

	@property
	def assetName(self) -> str:
		return self._assetName

	@property
	def downloadUrl(self) -> str:
		return self._downloadUrl

	@property
	def downloadType(self) -> str:
		return self._downloadType

	def updateDownloadUrl(self, url : str, type : str) -> None:
		# prefer .tar.xz:
		if type == NerdFontDefn.DownloadTypeTarXz:
			self._downloadUrl = url
			self._downloadType = type
		elif type == NerdFontDefn.DownloadTypeZip and not self._downloadUrl:
			self._downloadUrl = url
			self._downloadType = type

	def shouldExtract(self, filename : str) -> bool:
		for r in self._patterns:
			if r.search(filename):
				return True
		return False

class NerdFontCollection:
	def __init__(self):
		self._fonts : dict[str, NerdFontDefn] = dict()

	@property
	def fonts(self) -> Iterator[NerdFontDefn]:
		return [self._fonts[k] for k in self._fonts]

	def addFontDefn(self, fontName : str, fontFilenameBases : list[str]):
		if fontName not in self._fonts:
			patternsToExtract : list[str] = []
			for f in fontFilenameBases:
				patternsToExtract.append(f"{f}-.+\.(?:t|o)tf")
			self._fonts[fontName] = NerdFontDefn(fontName, patternsToExtract)

	def processAsset(self, asset : GithubRelease.GithubReleaseAsset):
		# currently, at least, none of the font names have dots, so split at first dot into font name and extension
		dotPos = asset.name.find(".")
		if (dotPos >= 0):
			fontname = asset.name[:dotPos]
			if fontname in self._fonts:
				extension = asset.name[dotPos:].lower()
				if extension == ".tar.xz":
					self._fonts[fontname].updateDownloadUrl(asset.downloadUrl, NerdFontDefn.DownloadTypeTarXz)
				elif extension == ".zip":
					self._fonts[fontname].updateDownloadUrl(asset.downloadUrl, NerdFontDefn.DownloadTypeZip)

def checkPrereqs(osHelper : OSHelper) -> bool:
	#if not shutil.which("wget"):
	#	LogHelper.Error("could not find command 'wget'")
	#	return False

	# make sure font directory userFontsFldr exists
	if not osHelper.fontsFldr.exists():
		osHelper.fontsFldr.mkdir(parents=True)

	return True

def getNerdFontsVerStr(releaseInfo : GithubRelease) -> str:
	# tag name/version not reliably comparable, so use id first, since that should
	# be always incrementing (right?), then include tag name/version for my readability:
	return f"@version_{releaseInfo.id:>012}_{releaseInfo.tag}"

def initFontsToInstall(ghRelease : GithubRelease) -> NerdFontCollection:
	fontsToInstall : NerdFontCollection = NerdFontCollection()
	fontsToInstall.addFontDefn("FantasqueSansMono", ["FantasqueSansMNerdFont"])#, "FantasqueSansMNerdFontMono"])
	fontsToInstall.addFontDefn("CascadiaCode", ["CaskaydiaCoveNerdFont"])#, "CaskaydiaCoveNerdFontMono"])
	fontsToInstall.addFontDefn("Meslo", ["MesloLGSNerdFont"])#, "MesloLGSNerdFontMono"])
	if sys.platform == "win32":
		fontsToInstall.addFontDefn("ComicShannsMono", ["ComicShannsMonoNerdFont"])
		fontsToInstall.addFontDefn("JetBrainsMono", ["JetBrainsMonoNerdFont"])
		fontsToInstall.addFontDefn("Lilex", ["LilexNerdFont"])
		fontsToInstall.addFontDefn("Monofur", ["MonofurNerdFont"])
		fontsToInstall.addFontDefn("SpaceMono", ["SpaceMonoNerdFont"])
		fontsToInstall.addFontDefn("ShareTechMono", ["ShureTechMonoNerdFont"])
		#fontsToInstall.addFontDefn("XXXXXXXX", ["XXXXXXXX"])
	for a in ghRelease.assets:
		fontsToInstall.processAsset(a)
	return fontsToInstall

def removeOldFonts(osHelper : OSHelper) -> None:
	# putting nerd fonts in their own folder, can just delete everything in there:
	cleanUpOldFile("*.ttf", osHelper)
	cleanUpOldFile("*.otf", osHelper)
	cleanUpOldFile("@version_*", osHelper)

def cleanUpOldFile(fontNameGlob : str, osHelper : OSHelper) -> None:
	for f in osHelper.fontsFldr.glob(fontNameGlob):
		LogHelper.Message3(f'removing old file "{f}"')
		if f.suffix in ('.ttf', '.otf'):
			osHelper.uninstallFont(f)
		f.unlink()

def installFont(fontDfn : NerdFontDefn, osHelper : OSHelper) -> None:
	if not fontDfn.downloadUrl or not fontDfn.downloadType:
		LogHelper.Warning(f"font \"{fontDfn.assetName}\" is missing either url and/or type: url = |{fontDfn.downloadUrl}|, type = |{fontDfn.downloadType}|")
		return
	print("")
	LogHelper.Message("------------------------------------------------")
	LogHelper.Message(f"installing font \"{fontDfn.assetName}\"")
	LogHelper.Message("------------------------------------------------")
	if fontDfn.downloadType == NerdFontDefn.DownloadTypeTarXz:
		installFontFromTarXz(fontDfn, osHelper)
	elif fontDfn.downloadType == NerdFontDefn.DownloadTypeZip:
		installFontFromZip(fontDfn, osHelper)
	else:
		LogHelper.Warning(f"font \"{fontDfn.assetName}\" has unrecognized type: |{fontDfn.downloadType}|")

def installFontFromTarXz(fontDfn : NerdFontDefn, osHelper : OSHelper) -> None:
	LogHelper.Verbose(f"installing .tar.xz: url = |{fontDfn.downloadUrl}|")
	with urllib.request.urlopen(fontDfn.downloadUrl) as resp:
		tf = tarfile.open(fileobj=BytesIO(resp.read()), mode='r:xz')
	for f in tf.getnames():
		if fontDfn.shouldExtract(f):
			LogHelper.Message(f"installing font |{f}|")
			tf.extract(f, path=osHelper.fontsFldr)
			osHelper.installFont(osHelper.fontsFldr / f)
		else:
			LogHelper.Verbose(f"skipping font file |{f}|")

def installFontFromZip(fontDfn : NerdFontDefn, osHelper : OSHelper) -> None:
	LogHelper.Verbose(f"installing .zip: url = |{fontDfn.downloadUrl}|")
	with urllib.request.urlopen(fontDfn.downloadUrl) as resp:
		zf = zipfile.ZipFile(BytesIO(resp.read()))
	for f in zf.namelist():
		if fontDfn.shouldExtract(f):
			LogHelper.Message(f"installing font |{f}|")
			zf.extract(f, path=osHelper.fontsFldr)
			osHelper.installFont(osHelper.fontsFldr / f)
		else:
			LogHelper.Verbose(f"skipping font file |{f}|")

def runApp(appAndArgs : list[str]) -> int:
	process = subprocess.run(appAndArgs)
	if process.returncode != 0:
		LogHelper.Error(f'app {appAndArgs[0]} returned non-zero exit code: {process.returncode}')
	return process.returncode

def rebuildFontCache(osHelper : OSHelper) -> None:
	if osHelper.testMode or sys.platform == "win32":
		return
	print("")
	LogHelper.Message3("------------------------------------------------")
	LogHelper.Message3("rebuilding font cache")
	LogHelper.Message3("------------------------------------------------")
	if sys.platform == "linux":
		runApp(["fc-cache", "--force", "--verbose"])
	elif sys.platform == "darwin":
		# ???
		retCode = runApp(["atsutil", "databases", "-removeUser"])
		if retCode == 0:
			retCode = runApp(["atsutil", "server", "-shutdown"])
		if retCode == 0:
			retCode = runApp(["atsutil", "server", "-ping"])

if __name__ == "__main__":
	sys.exit(main())
