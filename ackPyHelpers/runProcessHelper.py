#!python3
# -*- coding: utf-8 -*-

import os, subprocess

class RunProcessHelper:
	"""
	helper class to run a command with optional arguments, and return the result with exit code, stdout and stderr

	example:
	result = RunProcessHelper.runProcess(["uname", "-v"])
	print(f"exit code = {result.exitCode}")
	print(f"stdout = {result.stdout}")
	"""

	class RunProcessResults:
		def __init__(self) -> None:
			self._exitCode = 0
			self._stdout = ''
			self._stderr = ''

		@staticmethod
		def _parseResult(processResult: subprocess.CompletedProcess) -> "RunProcessHelper.RunProcessResults":	# -> Self:
			result = RunProcessHelper.RunProcessResults()
			result._exitCode = processResult.returncode
			result._stdout = processResult.stdout
			result._stderr = processResult.stderr
			return result

		@property
		def exitCode(self) -> int:
			return self._exitCode

		@property
		def stdout(self) -> str:
			return self._stdout

		@property
		def stderr(self) -> str:
			return self._stderr

		def getCombinedStdoutStderr(self) -> str:
			result = ''
			if self._stdout and self._stderr:
				result = f"{self._stdout}{os.linesep}{self._stderr}"
			elif self._stdout:
				result = self._stdout
			elif self._stderr:
				result = self._stderr
			return result

	@staticmethod
	def runProcess(args: list[str]) -> "RunProcessHelper.RunProcessResults":
		proc = subprocess.run(["oh-my-posh", "--version"], capture_output=True, text=True)
		return RunProcessHelper.RunProcessResults._parseResult(proc)
