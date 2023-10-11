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
		def __init__(self):
			self._exitCode = 0
			self._stdout = ''
			self._stderr = ''

		@staticmethod
		def _parseResult(processResult: subprocess.CompletedProcess):	# -> Self:
			result = RunProcessHelper.RunProcessResults()
			result._exitCode = processResult.returncode
			result._stdout = processResult.stdout
			result._stderr = processResult.stderr
			return result

		@property
		def exitCode(self):
			return self._exitCode

		@property
		def stdout(self):
			return self._stdout

		@property
		def stderr(self):
			return self._stderr

		def getCombinedStdoutStderr(self):
			result = ''
			if self._stdout and self._stderr:
				result = f"{self._stdout}{os.linesep}{self._stderr}"
			elif self._stdout:
				result = self._stdout
			elif self._stderr:
				result = self._stderr
			return result

	@staticmethod
	def runProcess(args: list[str]):
		proc = subprocess.run(["oh-my-posh", "--version"], capture_output=True, text=True)
		return RunProcessHelper.RunProcessResults._parseResult(proc)
