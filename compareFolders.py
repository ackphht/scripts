#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, argparse, time, concurrent.futures
from tracemalloc import start
from ackPyHelpers import LogHelper, FileHelpers, DateTimeHelpers
try:
	import xxhash
	hashFactory = lambda: xxhash.xxh3_128()
except ModuleNotFoundError:
	import hashlib
	hashFactory = lambda: hashlib.sha256()
_hashBufferSize = 128 * 1024

PyScript = pathlib.Path(os.path.abspath(__file__))
PyScriptRoot = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))

def main():
	args = initArgParser().parse_args()
	LogHelper.Init(verbose=(args.verbose if 'verbose' in args else False))
	args.func(args)	# will call the handler that was added

def validateCommandHandler(args : argparse.Namespace):
	sourceBase = checkBaseFolder(args.sourceFolder)
	targetBase = checkBaseFolder(args.targetFolder)
	exclusions = getExclusions(args.noDefaultExcludes, args.exclude)

	if args.verbose:
		LogHelper.Verbose("exclusions:")
		for x in exclusions:
			LogHelper.Verbose(x)

	totalStartTs = time.perf_counter()
	totalHashSecs = 0
	with concurrent.futures.ThreadPoolExecutor(max_workers=8) as executor:
		for sourceFile in sourceBase.glob("**/*"):
			if sourceFile.is_dir(): continue
			if isExcluded(sourceFile, exclusions):
				LogHelper.Verbose('skipping excluded source file "{0}"', sourceFile)
				continue
			filebase = sourceFile.relative_to(sourceBase)
			targetFile = targetBase / filebase
			LogHelper.Verbose('checking source "{0}" to target "{1}"', sourceFile, targetFile)
			if targetFile.is_file():
				startTs = time.perf_counter()
				if args.noParallel:
					sourceHash = getHash(sourceFile)
					targetHash = getHash(targetFile)
				else:
					sourceFuture = executor.submit(getHash, sourceFile)
					targetFuture = executor.submit(getHash, targetFile)
					concurrent.futures.wait([sourceFuture, targetFuture])	# do i need this? the result() calls will block anyway...
					sourceHash = sourceFuture.result()
					targetHash = targetFuture.result()
				secsTaken = time.perf_counter() - startTs
				totalHashSecs += secsTaken
				LogHelper.Verbose('calculating hashes took {0} secs', secsTaken)
				if sourceHash != targetHash:
					LogHelper.Warning('hash mismatch for files{0}  source: [{3}] {1}{0}  target: [{4}] {2}',
						os.linesep, sourceFile.as_posix(), targetFile.as_posix(),
						DateTimeHelpers.FromTimestamp(sourceFile.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S'),
						DateTimeHelpers.FromTimestamp(targetFile.stat().st_mtime).strftime('%Y-%m-%d %H:%M:%S'))
				else:
					LogHelper.Verbose('hashes of source file "{0}" and target file "{1}" match', sourceFile, targetFile)
			else:
				if args.warnNoTarget:
					LogHelper.Warning('target file "{0}" does not exist', targetFile)
				else:
					LogHelper.Verbose('target file "{0}" does not exist', targetFile)
	LogHelper.Verbose('finished; total hash time taken = {0} secs, total overall time taken = {1} secs', totalHashSecs, (time.perf_counter() - totalStartTs))

def findDupesCommandHandler(args : argparse.Namespace):
	sourceBase = checkBaseFolder(args.sourceFolder)
	targetBase = checkBaseFolder(args.targetFolder)
	raise NotImplementedError()

def checkBaseFolder(fldr: str) -> pathlib.Path:
	f = pathlib.Path(fldr)
	if not f.is_dir():
		raise NotADirectoryError(f'"{fldr}" is not a directory, or cannot be accessed')
	return f

def getExclusions(ignoreDefaults: bool, addList: list[str] | None) -> list[pathlib.Path]:
	result = []
	if not ignoreDefaults:
		result = [
			pathlib.Path("desktop.ini"),
			pathlib.Path("thumbs.db"),
			pathlib.Path("*.bak"),
			pathlib.Path("*.tmp"),
			pathlib.Path("*.cache"),
			pathlib.Path("~$*.docx"),
			pathlib.Path("~$*.xlsx"),
			pathlib.Path("**/*cache*/*"),	# don't think this will work; don't think it's actually doing very fancy matching
		]
	if addList:
		for x in addList:
			result.append(pathlib.Path(x))
	return result

def isExcluded(file: pathlib.Path, exclusions: list[pathlib.Path]) -> bool:
	for x in exclusions:
		if file.match(x):
			return True
	return False

def getHash(file: pathlib.Path):
	hasher = hashFactory()
	with open(file, 'rb', buffering=0) as f:
		for chunk in iter(lambda: f.read(_hashBufferSize), b''):
			hasher.update(chunk)
	return hasher.hexdigest()

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	subparsers = parser.add_subparsers(dest="commandName", title="subcommands")		# 'commandName' will be set to values passed to add_parser

	cmd1 = subparsers.add_parser("validate", aliases=["v", "val"], help="validate hashes of files in sourceFolder against those in targetFolder")
	cmd1.add_argument("sourceFolder", help="the base source folder")
	cmd1.add_argument("targetFolder", help="the base target folder")
	cmd1.add_argument("-n", "--noDefaultExcludes", action="store_true", help="do not use the default list of file paterrns to exclude")
	cmd1.add_argument("-x", "--exclude", action="append", help="there is a default list of file paterrns to exclude; use this to specify additional exclusions")
	cmd1.add_argument("-t", "--warnNoTarget", action="store_true", help="warn if the target file does not exist; by default, these are just logged as verbose messages")
	cmd1.add_argument("-p", "--noParallel", action="store_true", help="disable parallel hashing")
	cmd1.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	cmd1.set_defaults(func=validateCommandHandler)

	cmd2 = subparsers.add_parser("findDuplicates", aliases=["d", "f", "dupes"], help="find files in targetFolder that are duplicates of files in sourceFolder")
	cmd2.add_argument("sourceFolder", help="the base source folder")
	cmd2.add_argument("targetFolder", help="the base target folder")
	cmd2.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	cmd2.set_defaults(func=findDupesCommandHandler)

	return parser

if __name__ == "__main__":
	try:
		sys.exit(main())
	except KeyboardInterrupt:
		LogHelper.MessageYellow("")
		LogHelper.MessageYellow("cancelled...")
