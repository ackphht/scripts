#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, argparse, time
import logging
from populateSystemData import OSDetails

PyScript = pathlib.Path(os.path.abspath(__file__))
PyScriptRoot = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))

def main():
	args = _initArgParser().parse_args()
	_initLogging(args.verbose)

	deets = OSDetails.GetDetails()
	noColors = args.noColors
	print("")
	if args.showAllProps:
		hdrWidth = 14
		_printDetail("Platform", deets.platform, hdrWidth, noColors)
		_printDetail("Id", deets.id, hdrWidth, noColors)
		_printDetail("Description", deets.description, hdrWidth, noColors)
		_printDetail("Release", deets.release, hdrWidth, noColors)
		_printDetail("ReleaseVersion", deets.releaseVersion, hdrWidth, noColors)
		_printDetail("KernelVersion", deets.kernelVersion, hdrWidth, noColors)
		if deets.buildNumber:
			_printDetail("BuildNumber", deets.buildNumber, hdrWidth, noColors)
		if deets.updateRevision:
			_printDetail("UpdateRevision", deets.updateRevision, hdrWidth, noColors)
		_printDetail("Distributor", deets.distributor, hdrWidth, noColors)
		_printDetail("Codename", deets.codename, hdrWidth, noColors)
		if deets.osType:
			_printDetail("Type", deets.osType, hdrWidth, noColors)
		if deets.edition:
			_printDetail("Edition", deets.edition, hdrWidth, noColors)
		_printDetail("OSArchitecture", deets.osArchitecture, hdrWidth, noColors)
		_printDetail("Is64BitOS", deets.is64BitOS, hdrWidth, noColors)
	else:
		hdrWidth = 13
		_printDetail("Description", deets.description, hdrWidth, noColors)
		_printDetail("Id", deets.id, hdrWidth, noColors)
		_printDetail("Distributor", deets.distributor, hdrWidth, noColors)
		_printDetail("Codename", deets.codename, hdrWidth, noColors)
		_printDetail("Release", deets.release, hdrWidth, noColors)
		_printDetail("KernelVersion", deets.kernelVersion, hdrWidth, noColors)

def _printDetail(name: str, value: str, nameMinWidth: int, noColors: bool) -> None:
	if noColors:
		print(f"{name:<{nameMinWidth}} : {value}")
	else:
		print(f"\033[22m\033[32m\033[1m{name:<{nameMinWidth}} :\033[0m {value}")

def _initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	parser.add_argument("-a", "--showAllProps", action="store_true", help="show all properties rather than short list")
	parser.add_argument("-n", "--noColors", action="store_true", help="no colors or ANSI formating")
	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	return parser

def _initLogging(verbose : bool = False, useLocalTime : bool = False):
	loglevel = logging.DEBUG if verbose else logging.INFO
	if (useLocalTime):
		logTimeFormat = "{asctime}.{msecs:0<3.0f}" + time.strftime('%z')
	else:
		logging.Formatter.converter = time.gmtime
		logTimeFormat = "{asctime}.{msecs:0<3.0f}Z"
	# see https://docs.python.org/3/library/logging.html#logrecord-attributes for things can include in format:
	logging.basicConfig(level=loglevel, format=f"{logTimeFormat}|{{levelname:8}}|{{module}}|{{funcName}}|{{message}}", style='{', datefmt='%Y-%m-%d %H:%M:%S')

if __name__ == "__main__":
	sys.exit(main())
