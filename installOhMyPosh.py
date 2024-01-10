#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, platform, stat, argparse, shutil, subprocess, urllib.request
from ackPyHelpers import LogHelper, GithubRelease, Version, RunProcessHelper

PyScript = os.path.abspath(__file__)
PyScriptRoot = os.path.dirname(os.path.abspath(__file__))

def main():
	args = initArgParser().parse_args()
	verboseLogging = args.verbose
	testMode = args.test
	forceInstall = args.force

	LogHelper.Init(verboseLogging)

	osPlatform = platform.system().lower()
	osArch = normalizeArchForOhMyPosh(platform.machine())
	if osPlatform != "linux" and osPlatform != "freebsd" and \
			'_pydevd_bundle' not in sys.modules:	# so if we're on windows and working in VSCode (or other editor?), rest of file won't be grayed out; there's also 'debugpy' that's MS specific ??:
		raise RuntimeError("this script is only for Linux and FreeBSD")

	binFldr = ".local/bin" if osPlatform == "linux" else "bin"
	binFldr = pathlib.Path(os.path.expanduser(f"~/{binFldr}"))
	if not binFldr.exists():
		LogHelper.Verbose(f"creating bin folder |{binFldr}|")
		if not testMode:
			binFldr.mkdir(parents=True)
		else:
			LogHelper.WhatIf(f"creating bin folder |{binFldr}|")
	outfile = binFldr / "oh-my-posh"

	ompFilename = f"posh-{osPlatform}-{osArch}"
	downloadUrl = f"https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/{ompFilename}"
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
					if a.name == ompFilename:
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

	# set execute permission:
	if not testMode:
		os.chmod(outfile, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR | stat.S_IRGRP | stat.S_IROTH)
	else:
		LogHelper.WhatIf(f'setting execute permission on file "{outfile}"')

	# make sure the notify thing is off:
	if not testMode:
		result = RunProcessHelper.runProcess([outfile, "disable", "notice"])
		if result.exitCode != 0:
			LogHelper.Error(f"error running oh-my-posh disable notice: exit code = {result.exitCode}{os.linesep}{result.getCombinedStdoutStderr()}")
	else:
		LogHelper.WhatIf(f'running command "{outfile} disable notice"')

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

def normalizeArchForOhMyPosh(arch: str) -> str:
	arch = arch.lower()
	LogHelper.Verbose(f"normalizing os architecture |{arch}|")
	if arch in ["x86_64", "x64", "em64t", "x86_64h"]:
		arch = "amd64"
	elif arch in ["x86", "i386", "i686"]:
		arch = "386"
	elif arch in ["aarch64", "arm64e"]:
		arch = "arm64"
	elif arch.startswith("armv"):
		arch = "arm"
	# any others just use name as-is
	LogHelper.Verbose(f"normalized os architecture |{arch}|")
	return arch

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()

	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	parser.add_argument("-t", "--test", action="store_true", help="enable test mode (won't actually install fonts)")
	parser.add_argument("-f", "--force", action="store_true", help="force download and install, even if we already have latest version")

	return parser

if __name__ == "__main__":
	sys.exit(main())
