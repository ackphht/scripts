#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, argparse, shutil, subprocess, urllib.request
from loghelper import LogHelper
from githubHelper import GithubRelease

PyScript = os.path.abspath(__file__)
PyScriptRoot = os.path.dirname(os.path.abspath(__file__))

def main():
	if sys.platform != "linux" and \
			'_pydevd_bundle' not in sys.modules:	# so if we're on windows and working in VSCode (or other editor?), rest of file won't be grayed out; there's also 'debugpy' that's MS specific ??
		raise RuntimeError("this script is only for Linux")
	args = initArgParser().parse_args()
	verboseLogging = args.verbose
	testMode = args.test
	forceInstall = args.force

	LogHelper.Init(verboseLogging)

	binFldr = pathlib.Path(os.path.expandvars(f"$HOME/.local/bin"))
	if not binFldr.exists():
		LogHelper.Verbose(f"creating bin folder |{binFldr}|")
		if not testMode:
			binFldr.mkdir(parents=True)
		else:
			LogHelper.WhatIf(f"creating bin folder |{binFldr}|")
	outfile = binFldr / "oh-my-posh"

	downloadUrl = "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64"
	print("")
	if not forceInstall:
		currVer = getCurrentOhMyPoshVer()
		LogHelper.Verbose(f"current installed version: |{currVer}|")
		if not currVer.isZeroVersion:
			gh = GithubRelease.GetLatestRelease("JanDeDobbeleer", "oh-my-posh")
			LogHelper.Verbose(f"latest release info: tag = |{gh.tag}|, published at |{gh.published}|")
			latestVer = Version.parseVersionString(cleanUpVersion(gh.tag))
			if latestVer > currVer:
				LogHelper.Message(f"installing newer version of OhMyPosh: v{latestVer} (current version = v{currVer})")
				for a in gh.assets:	# see if we can save them a redirect
					if a.name == "posh-linux-amd64":
						downloadUrl = a.downloadUrl
						break
			else:
				LogHelper.Message(f"currently installed OhMyPosh is already the latest version: v{currVer}")
				return 0	# nothing else to do
		else:
			LogHelper.Message("no current Oh-My-Posh found, installing latest version")
	else:
		LogHelper.Message("force mode enabled, ignoring checks and installing latest OhMyPosh")

	LogHelper.Verbose(f"writing file |{outfile}| from url |{downloadUrl}|")
	with urllib.request.urlopen(downloadUrl) as resp:
		if not testMode:
			with open(outfile, "wb") as f:
				f.write(resp.read())
		else:
			LogHelper.WhatIf(f"writing download to file |{outfile}|")

	# make sure the notify thing is off:
	if not testMode:
		result = RunProcessHelper.runProcess([outfile, "disable", "notice"])
		if result.exitCode != 0:
			LogHelper.Error(f"error running oh-my-posh disable notice: exit code = {result.exitCode}{os.linesep}{result.getCombinedStdoutStderr()}")
	else:
		LogHelper.WhatIf(f'running command "{outfile} disable notice"')

class Version:
	def __init__(self, major : int, minor: int, revision : int):
		self._major : int = major
		self._minor : int = minor
		self._rev : int = revision

	def __repr__(self):
		return f"<Version: major={self.major}, minor={self.minor}, revision={self.revision}>"

	def __str__(self):
		return f"{self.major}.{self.minor}.{self.revision}"

	def __hash__(self):
		return hash(self.major, self.minor, self.revision)

	# docs (Library Reference > Built-in Types > Comparisons) say that __eq__ and __lt__ are enough
	def __eq__(self, other):
		return self.major == other.major and self.minor == other.minor and self.revision == other.revision if isinstance(other, Version) else NotImplemented

	def __lt__(self, other):
		return self.major < other.major or self.minor < other.minor or self.revision < other.revision if isinstance(other, Version) else NotImplemented

	@staticmethod
	def parseVersionString(ver : str):	# -> Self:
		if ver:
			major = minor = rev = 0
			sp = ver.split(".")
			# TODO: error handling for non-ints ??
			major = int(sp[0])
			if len(sp) >= 2:
				minor = int(sp[1])
			if len(sp) >= 3:
				rev = int(sp[2])
			return Version(major, minor, rev)
		else:
			return Version(0, 0, 0)

	@property
	def isZeroVersion(self):
		return self.major == 0 and self.minor == 0 and self.revision == 0

	@property
	def major(self):
		return self._major if self._major else 0

	@property
	def minor(self):
		return self._minor if self._minor else 0

	@property
	def revision(self):
		return self._rev if self._rev else 0

class RunProcessHelper:
	class RunProcessResults:
		def __init__(self):
			self._exitCode = 0
			self._stdout = ''
			self._stderr = ''

		@staticmethod
		def parseResult(processResult : subprocess.CompletedProcess):	# -> Self:
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
	def runProcess(args : list[str]):
		proc = subprocess.run(["oh-my-posh", "--version"], capture_output=True, text=True)
		return RunProcessHelper.RunProcessResults.parseResult(proc)

def cleanUpVersion(ver : str) -> str:
	if ver:
		ver = ver.strip()
		if ver.lower().startswith("v"):
			ver = ver[1:]
	return ver

def getCurrentOhMyPoshVer() -> Version:
	if shutil.which("oh-my-posh"):
		result = RunProcessHelper.runProcess(["oh-my-posh", "--version"])
		if result.exitCode == 0:
			ver = cleanUpVersion(result.stdout)
			return Version.parseVersionString(ver)
		else:
			LogHelper.Error(f"error running oh-my-posh --version: exit code = {result.exitCode}{os.linesep}{result.getCombinedStdoutStderr()}")
	return Version(0, 0, 0)

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()

	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	parser.add_argument("-t", "--test", action="store_true", help="enable test mode (won't actually install fonts)")
	parser.add_argument("-f", "--force", action="store_true", help="force download and install, even if we already have latest version")

	return parser

if __name__ == "__main__":
	sys.exit(main())
