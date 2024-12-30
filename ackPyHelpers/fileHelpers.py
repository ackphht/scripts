#!python3
# -*- coding: utf-8 -*-

import pathlib, shutil, hashlib
from typing import Iterable
from .loghelper import LogHelper

class FileHelpers:
	"""
	class to help with some file operations. If you want to enable a 'whatIf' mode, call the static Init() method and pass the flag.
	"""

	_enableWhatIf = False
	_hashBufferSize = 256*1024

	@staticmethod
	def VerifyFolderExists(folder: pathlib.Path, whatIf: bool = False, whatifDescription: str = None) -> None:
		if not folder.exists():
			if FileHelpers._shouldProcess(whatIf, (whatifDescription if whatifDescription else f'creating folder "{folder}"')):
				folder.mkdir(parents=True)

	@staticmethod
	def CopyFile(sourceFile: pathlib.Path, targetFile: pathlib.Path, whatIf: bool = False, whatifDescription: str = None) -> None:
		if FileHelpers._shouldProcess(whatIf, (whatifDescription if whatifDescription else f'copying "{sourceFile}" to "{targetFile}"')):
			shutil.copyfile(sourceFile, targetFile)

	@staticmethod
	def MoveFile(sourceFile: pathlib.Path, targetFile: pathlib.Path, whatIf: bool = False, whatifDescription: str = None) -> None:
		desc = f'moving file "{sourceFile}" to "{targetFile}"'
		LogHelper.Verbose(desc)
		if FileHelpers._shouldProcess(whatIf, (whatifDescription if whatifDescription else desc)):
			#shutil.move(sourceFile, targetFile)	# will throw on Windows if target exists
			#sourceFile.rename(targetFile)			# will throw on Windows if target exists
			#os.replace(sourceFile, targetFile)
			if targetFile.exists():
				targetFile.unlink()
			shutil.move(sourceFile, targetFile)

	@staticmethod
	def GetRelPath(fromFile: pathlib.Path, toFolder: pathlib.Path) -> pathlib.Path:
		if fromFile.is_relative_to(toFolder):
			return fromFile.relative_to(toFolder).as_posix()
		# if it's not relative, just keep original:
		return fromFile

	@staticmethod
	def GetMd5(file: pathlib.Path) -> bytes:
		return FileHelpers._getFileHash(file, "md5")

	@staticmethod
	def GetSha1(file: pathlib.Path) -> bytes:
		return FileHelpers._getFileHash(file, "sha1")

	@staticmethod
	def GetSha256(file: pathlib.Path) -> bytes:
		return FileHelpers._getFileHash(file, "sha256")

	@staticmethod
	def FindOnPath(exe: str) -> pathlib.Path:
		exepath = shutil.which(exe)
		if exepath:
			return pathlib.Path(exepath)
		return None

	@staticmethod
	def MultiGlob(folder: pathlib.Path, globs: list[str], caseSensitive: bool|None = None) -> Iterable[pathlib.Path]:
		for g in globs:
			for f in folder.glob(g, case_sensitive=caseSensitive):
				yield f

	@staticmethod
	def _getFileHash(file: pathlib.Path, hashName: str) -> bytes:
		if not file.exists() and FileHelpers._enableWhatIf:
			return hashlib.new(hashName, "").digest()

		hasher = hashlib.new(hashName)
		with open(file, 'rb', buffering=0) as f:
			for chunk in iter(lambda: f.read(FileHelpers._hashBufferSize), b''):
				hasher.update(chunk)
		return hasher.digest()

	@staticmethod
	def _shouldProcess(whatIf : bool, whatIfDesc : str) -> bool:
		if whatIf:
			LogHelper.WhatIf(whatIfDesc)
		return not whatIf
