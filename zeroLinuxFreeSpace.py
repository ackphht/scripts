#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, shutil, argparse, re, io, uuid
from collections import namedtuple
from ackPyHelpers import LogHelper, RunProcessHelper

PyScript = pathlib.Path(os.path.abspath(__file__))
PyScriptRoot = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))

def main():
	args = initArgParser().parse_args()
	LogHelper.Init(args.verbose)

	if '_pydevd_bundle' not in sys.modules:		# if we're on windows and/or working in VSCode (or some other editor?), skip checks so rest of file won't be grayed out; there's also 'debugpy' that's MS specific ??
		if sys.platform != "linux":
			LogHelper.Error("this script is only intended for Linux")
			return 1
		if os.geteuid() != 0:
			LogHelper.Error("this script requires root; please run it with sudo or something")
			return 1

	fsRoot:str = pathlib.Path("/")
	bufferSize: int = 64 * 1024
	oneMB: int = 1048576
	tenMB: int = 10 * oneMB
	twentyMB: int = 20 * oneMB
	hundredMB: int = 100 * oneMB
	oneTenMB: int = 110 * oneMB
	oneGB: int = 1024 * 1048576
	onePointOneGB: int = oneGB + hundredMB
	passesFor1MB: int = (oneMB // bufferSize)
	passesFor10MB: int = (tenMB // bufferSize)
	passesFor100MB: int = (hundredMB // bufferSize)
	passesFor1GB: int = (oneGB // bufferSize)
	zeroesBuffer: bytearray = bytearray(bufferSize)
	zeroFile = fsRoot / (uuid.uuid4().hex)

	fsInfo = getFsInfo(fsRoot)

	# some distro's seem to be ignoring it if we set specific files to not use compressions, so maybe remount drive without compression ???
	remountedRoot = remountBtrfsFilesystemNoCompression(fsRoot, fsInfo, args.forceRemountCompressibleFS)

	LogHelper.MessageCyan('writing zeroes to file "{0}"', zeroFile)
	try:
		progress = ProgressBar("Zero'ing free space", args.verbose)
		with open(zeroFile, "wb", buffering=0) as zf:
			# try to disable compression on the file (in case we don't remount above...):
			disableFileBtrfsCompression(zeroFile, fsInfo)
			# start loop:
			usage = shutil.disk_usage(fsRoot)
			startFreeSpace = freeSpace = usage.free
			while freeSpace > 0:
				percentDone: int = (startFreeSpace - freeSpace) * 100.0 // startFreeSpace
				progress.update(percentDone)
				if freeSpace >= onePointOneGB:
					writeData(zf, zeroesBuffer, passesFor1GB, freeSpace, "1GB")
				elif freeSpace >= oneTenMB:
					writeData(zf, zeroesBuffer, passesFor100MB, freeSpace, "100MB")
				elif freeSpace >= twentyMB:
					writeData(zf, zeroesBuffer, passesFor10MB, freeSpace, "10MB")
				elif freeSpace >= tenMB:
					writeData(zf, zeroesBuffer, passesFor1MB, freeSpace, "1MB")
				else:
					LogHelper.Verbose("freespace = {0}, breaking out of loop", freeSpace)
					RunProcessHelper.runProcess(["sync"])
					break
				RunProcessHelper.runProcess(["sync"])
				freeSpace = shutil.disk_usage(fsRoot).free
	finally:
		progress.finish()
		if args.pauseBeforeCleanup:
			input("press Enter to continue and clean up space...")
		if zeroFile.exists(): zeroFile.unlink()
		if remountedRoot:
			remountBtrfsFilesystemWithDefaults(fsRoot)

	LogHelper.MessageMagenta("done; you can shut down the system")

def writeData(file: io.FileIO, bytes: bytearray, passes: int, freespace: int, totalData: str):
	LogHelper.Verbose("freespace = {0}, writing {1} data", freespace, totalData)
	for i in range(passes):
		file.write(bytes)

FsInfo = namedtuple("FsInfo", ["drive", "mountPoint", "fileSystem", "compression"])
def getFsInfo(mountPoint: pathlib.Path) -> FsInfo:
	drv = mnt = fs = opts = cmp = ''

	m = RunProcessHelper.runProcess(["mount"])
	if m.exitCode or not m.stdout:
		raise Exception(f"failed getting filesystem info: return code = {m.exitCode}:{os.linesep}{m.getCombinedStdoutStderr()}")

	mntRe = re.compile(rf"^(?P<drv>/dev/\w+) on (?P<mnt>{str(mountPoint)}) type (?P<fs>\w+) \((?P<opts>.*)\)")
	for line in m.stdout.splitlines():
		match = mntRe.match(line)
		if match:
			drv = match.group('drv')
			mnt = match.group('mnt')
			fs = match.group('fs')
			opts = match.group('opts')
			break

	# couldn't figure out a regex to get this all in one go above, so second step:
	if opts and fs == "btrfs":
		cmpRe = re.compile(r"^.*compress=(?P<cmp>[^,]+).*$")
		match = cmpRe.match(opts)
		if match:
			cmp = match.group("cmp")

	LogHelper.Verbose("getFsInfo(): filesystem info: drive = '{0}', mountPoint = '{3}', filesystem = '{1}', compression = '{2}'", drv, fs, cmp, mnt)
	return FsInfo(drv, mnt, fs, cmp)

def remountBtrfsFilesystemNoCompression(fsPath: pathlib.Path, fsInfo: FsInfo, forceRemount: bool) -> bool:
	remounted = False
	if forceRemount and fsInfo.fileSystem == "btrfs" and fsInfo.compression and fsInfo.compression != "none":
		LogHelper.MessageYellow("remounting root filesystem with no compression")
		p = RunProcessHelper.runProcess(["mount", "-o", "remount,compress=none", str(fsPath)])
		if p.exitCode:
			LogHelper.Warning("remounting root filesystem failed (will try to continue): exit code = {0}{1}{2}", p.exitCode, os.linesep, p.getCombinedStdoutStderr())
		else:
			remounted = True
	return remounted

def remountBtrfsFilesystemWithDefaults(fsPath: pathlib.Path) -> bool:
	remounted = False
	LogHelper.MessageYellow("remounting root filesystem with defaults")
	p = RunProcessHelper.runProcess(["mount", "-o", "remount", str(fsPath)])
	if p.exitCode:
		LogHelper.Warning("remounting root filesystem failed: exit code = {0}{1}{2}", p.exitCode, os.linesep, p.getCombinedStdoutStderr())
	else:
		remounted = True
	return remounted

def disableFileBtrfsCompression(path: pathlib.Path, fsInfo: FsInfo) -> bool:
	disabled = False
	if fsInfo.fileSystem == "btrfs" and fsInfo.compression and fsInfo.compression != "none":
		LogHelper.Verbose('disabling btrfs compression for file "{0}"', path)
		p = RunProcessHelper.runProcess(["btrfs", "property", "set", str(path), "compression", "none"])
		if p.exitCode:
			LogHelper.Warning("disabling btrfs compression for file failed (will try to continue): exit code = {0}{1}{2}", p.exitCode, os.linesep, p.getCombinedStdoutStderr())
		else:
			disabled = True
	return disabled

class ProgressBar:
	def __init__(self, title: str, verboseEnabled: bool, width: int = 40):
		self._title: str = (title + " ") if title else ""
		self._barWidth: int = width
		self._enabled: bool = not verboseEnabled
		self._file = sys.stdout
		self._barStart: str = "["
		self._barEnd: str = "]"
		self._fillChar: str = "■" #"◯"
		self._emptyChar: str = " " #"◉"
		self._color: str = LogHelper.AnsiFore.Yellow
		self._reset: str = LogHelper.AnsiStyle.ResetAll
		self._hideCursor: str = "\x1b[?25l"
		self._showCursor: str = "\x1b[?25h"
		self._cursorHidden: bool = False
		self._lastFillWidth: int = -1

	def update(self, percent: int):
		if not self._enabled: return
		fillWidth = int(percent / 100.0 * self._barWidth)
		if fillWidth == self._lastFillWidth: return		# only update if something's actually changing
		self._lastFillWidth = fillWidth
		emptyWidth = self._barWidth - fillWidth
		fill = self._fillChar * fillWidth
		empty = self._emptyChar * emptyWidth
		line = "".join(["\r", self._color, self._title, self._barStart, fill, empty, self._barEnd, self._reset])
		if not self._cursorHidden:
			print(self._hideCursor, end="", file=self._file)
			self._cursorHidden = True
		print(line, end="", file=self._file, flush=True)

	def finish(self):
		if not self._enabled: return
		self.update(100)
		if self._cursorHidden:
			print(self._showCursor, end="", file=self._file)
			self._cursorHidden = False
		print("", file=self._file, flush=True)

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	parser.add_argument("-r", "--forceRemountCompressibleFS", action="store_true", help="force remounting if filesystem has compression to turn off compression (will try to create data without compresion but doesn't always work)")
	parser.add_argument("-p", "--pauseBeforeCleanup", action="store_true", help="pause before cleaning up data file (e.g. for troubleshooting)")
	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	return parser

if __name__ == "__main__":
	sys.exit(main())
