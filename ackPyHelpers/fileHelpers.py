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
	def Init(whatIf: bool = False):
		FileHelpers._enableWhatIf = whatIf

	@staticmethod
	def VerifyFolderExists(folder: pathlib.Path):
		if not folder.exists():
			if not FileHelpers._enableWhatIf:
				folder.mkdir(parents=True)
			else:
				LogHelper.WhatIf(f"creating folder '{folder}'")

	@staticmethod
	def CopyFile(sourceFile: pathlib.Path, targetFile: pathlib.Path, description: str, ignoreWhatIf: bool = False):
		if not FileHelpers._enableWhatIf or ignoreWhatIf:
			shutil.copyfile(sourceFile, targetFile)
		else:
			LogHelper.WhatIf(description)

	@staticmethod
	def MoveFile(sourceFile: pathlib.Path, targetFile: pathlib.Path, whatifDescription: str):
		LogHelper.Verbose(f'moving file "{sourceFile}" to "{targetFile}"')
		if not FileHelpers._enableWhatIf:
			#shutil.move(sourceFile, targetFile)	# will throw on Windows if target exists
			#sourceFile.rename(targetFile)			# will throw on Windows if target exists
			#os.replace(sourceFile, targetFile)
			if targetFile.exists():
				targetFile.unlink()
			shutil.move(sourceFile, targetFile)
		else:
			LogHelper.WhatIf(whatifDescription)

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
