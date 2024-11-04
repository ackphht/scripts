#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, platform, stat, argparse, shutil, urllib.request
from collections import namedtuple
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

	ompInfo = initOmpInfo(osPlatform, osArch, forceInstall, testMode)
	if ompInfo.isUpToDate:
		return	# function logs everything, so just return

	downloadOmp(ompInfo, testMode)
	disableUpdateCheck(ompInfo, testMode)

OmpInfo = namedtuple("OmpInfo", ["ompBinPath", "isUpToDate", "installedVersion", "latestVersion", "downloadUrl"])
def initOmpInfo(osPlatform: str, osArch: str, forceInstall: bool, whatIf: bool) -> OmpInfo:
	ompFilename = f"posh-{osPlatform}-{osArch}"
	downloadUrl = f"https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/{ompFilename}"
	ompInfo = OmpInfo(getBinPath(osPlatform, whatIf), False, getCurrentOhMyPoshVer(), Version.zeroVersion(), downloadUrl)
	LogHelper.Verbose(f"current installed version: |{ompInfo.installedVersion}|")
	if not ompInfo.installedVersion.isZeroVersion:
		if not forceInstall:
			gh = GithubRelease.GetLatestRelease("JanDeDobbeleer", "oh-my-posh")
			LogHelper.Verbose(f"latest release info: tag = |{gh.tag}|, published at |{gh.published}|")
			ompInfo = ompInfo._replace(latestVersion=Version.parseVersionString(cleanUpVersion(gh.tag)))
			if ompInfo.latestVersion > ompInfo.installedVersion:
				LogHelper.Message(f"installing newer version of OhMyPosh: v{ompInfo.latestVersion} (current version = v{ompInfo.installedVersion})")
				for a in gh.assets:	# see if we can save them a redirect
					if a.name == ompFilename:
						ompInfo = ompInfo._replace(downloadUrl=a.downloadUrl)
						break
			else:
				LogHelper.Message(f"currently installed OhMyPosh is already the latest version: v{ompInfo.installedVersion}")
				ompInfo = ompInfo._replace(isUpToDate=True)
		else:
			LogHelper.Message(f"force mode enabled, ignoring checks and installing latest OhMyPosh (current version = v{ompInfo.installedVersion})")
	else:
		LogHelper.Message("no current Oh-My-Posh found, installing latest version")
	return ompInfo

def downloadOmp(ompInfo: OmpInfo, whatIf: bool) -> None:
	LogHelper.Verbose(f"writing file |{ompInfo.ompBinPath}| from url |{ompInfo.downloadUrl}|")
	with urllib.request.urlopen(ompInfo.downloadUrl) as resp:
		if not whatIf:
			with open(ompInfo.ompBinPath, "wb") as f:
				f.write(resp.read())
		else:
			LogHelper.WhatIf(f"writing download to file |{ompInfo.ompBinPath}|")
	# set execute permission:
	if not whatIf:
		os.chmod(ompInfo.ompBinPath, stat.S_IRUSR | stat.S_IWUSR | stat.S_IXUSR | stat.S_IRGRP | stat.S_IROTH)
	else:
		LogHelper.WhatIf(f'setting execute permission on file "{ompInfo.ompBinPath}"')

def disableUpdateCheck(ompInfo: OmpInfo, whatIf: bool) -> None:
	currentVer = getCurrentOhMyPoshVer()
	# make sure the notify thing is off:
	if not whatIf:
		result = RunProcessHelper.runProcess([ompInfo.ompBinPath, "disable", "notice"])
		if result.exitCode != 0:
			LogHelper.Error(f"error running oh-my-posh disable notice: exit code = {result.exitCode}{os.linesep}{result.getCombinedStdoutStderr()}")
	else:
		LogHelper.WhatIf(f'running command "{ompInfo.ompBinPath} disable notice"')

	if currentVer.major >= 24:
		if not whatIf:
			result = RunProcessHelper.runProcess([ompInfo.ompBinPath, "disable", "upgrade"])
			if result.exitCode != 0:
				LogHelper.Error(f"error running oh-my-posh disable upgrade: exit code = {result.exitCode}{os.linesep}{result.getCombinedStdoutStderr()}")
		else:
			LogHelper.WhatIf(f'running command "{ompInfo.ompBinPath} disable upgrade"')

def getBinPath(osPlatform: str, whatIf: bool):
	binFldr = ".local/bin" if osPlatform == "linux" else "bin"
	binFldr = pathlib.Path(os.path.expanduser(f"~/{binFldr}"))
	if not binFldr.exists():
		LogHelper.Verbose(f"creating bin folder |{binFldr}|")
		if not whatIf:
			binFldr.mkdir(parents=True)
		else:
			LogHelper.WhatIf(f"creating bin folder |{binFldr}|")
	return binFldr / "oh-my-posh"

def cleanUpVersion(ver : str) -> str:
	if ver:
		ver = ver.strip()
		if ver.lower().startswith("v"):
			ver = ver[1:]
	return ver

def getCurrentOhMyPoshVer() -> Version:
	if shutil.which("oh-my-posh"):
		result = RunProcessHelper.runProcess(["oh-my-posh", "version"])
		if result.exitCode == 0:
			ver = cleanUpVersion(result.stdout)
			return Version.parseVersionString(ver)
		else:
			LogHelper.Error(f"error running oh-my-posh version: exit code = {result.exitCode}{os.linesep}{result.getCombinedStdoutStderr()}")
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
