#!python3
# -*- coding: utf-8 -*-

import os, pathlib, shutil, hashlib, stat
from typing import Any, Iterable, Callable
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
			return fromFile.relative_to(toFolder)
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

	@staticmethod	# this name is horrible, but i can't think of anything else…
	def SaveFileWrapper(saveAction: Callable[[], Any], filePath: pathlib.Path, keepSourceTimestamp: bool = False, copyTimestampFrom: pathlib.Path|None = None,
					 tweakTimestampBySecs: int = 0, force: bool = False, whatIf: bool = False) -> None:
		"""
		wraps an action to save a file, with options to:
		* preserve the file's timestamp or copy the timestamp from another file (if both are specified, copying from another file takes precedence)
		* tweak the timestamp (if it's being preserved),
		* save the file even if it's readonly
		"""
		if whatIf:
			LogHelper.WhatIf(f'saving file "{filePath}"')
		else:
			filestat = filePath.stat()
			fileMode = filestat.st_mode
			lastModTime = copyTimestampFrom.stat().st_mtime if copyTimestampFrom is not None else (filestat.st_mtime if keepSourceTimestamp else 0)
			lastAccessTime = copyTimestampFrom.stat().st_atime if copyTimestampFrom is not None else (filestat.st_atime if keepSourceTimestamp else 0)
			wasReadOnly = False
			if not (fileMode & stat.S_IWRITE):
				if not force:
					# 13 == errno.EACCES (this is what python throws); guess we could just the
					# saveAction be the one to throw an error, but that might be harder to troubleshoot??
					raise OSError(13, 'The file specified is read-only', str(filePath))
				wasReadOnly = True
				filePath.chmod(fileMode | stat.S_IWRITE)		# make sure it's NOT readonly

			saveAction()

			if lastModTime > 0:
				os.utime(filePath, (lastAccessTime, lastModTime + tweakTimestampBySecs))
			if wasReadOnly:
				filePath.chmod(fileMode)		# put it back

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
