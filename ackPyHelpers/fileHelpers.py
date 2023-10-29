#!python3
# -*- coding: utf-8 -*-

import pathlib, shutil, hashlib
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
	def GetSha1(file: pathlib.Path) -> bytes:
		if not file.exists() and FileHelpers._enableWhatIf:
			return hashlib.sha1("").digest()
		hSha1 = hashlib.sha1()
		with open(file, 'rb', buffering=0) as f:
			for chunk in iter(lambda: f.read(FileHelpers._hashBufferSize), b''):
				hSha1.update(chunk)
		return hSha1.digest()

	@staticmethod
	def FindOnPath(exe: str) -> pathlib.Path:
		exepath = shutil.which(exe)
		if exepath:
			return pathlib.Path(exepath)
		return None

	@staticmethod
	def _shouldProcess(whatIf : bool, whatIfDesc : str) -> bool:
		if whatIf:
			LogHelper.WhatIf(whatIfDesc)
		return not whatIf
