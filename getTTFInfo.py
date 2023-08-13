#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, argparse, time, io, csv
import logging
from collections.abc import Iterable
import fontTools
from fontTools import ttLib
from fontTools import unicodedata
from tabulate import tabulate	# https://pypi.org/project/tabulate/

PyScript = os.path.abspath(__file__)
PyScriptRoot = os.path.dirname(os.path.abspath(__file__))

def main():
	args = initArgParser().parse_args()
	initLogging(args.verbose)

	fontpath = pathlib.Path(args.fontpath)
	if not fontpath.exists():
		raise FileNotFoundError(f'the specified file does not exist: "{args.fontpath}"')
	f = FontInfo(fontpath)
	print()
	print(tabulate(f.GetFontNameInfo(), tablefmt="plain"))
	print()
	tableFormat = "rst"#"simple" #"presto"
	print(tabulate([(blk.BlockName, blk.CodepointCount) for blk in f.GetCodepointsInfo(args.allBlocks)], headers=["Block", "Codepoints"], tablefmt=tableFormat, numalign="left"))

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	parser.add_argument("-f", "--fontpath", required=True, help="path to the font file to show info for")
	parser.add_argument("-b", "--allBlocks", action="store_true", help="print all blocks, not just ones with codepoints")
	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	return parser

def initLogging(verbose : bool = False, useLocalTime : bool = False):
	loglevel = logging.DEBUG if verbose else logging.INFO
	if (useLocalTime):
		logTimeFormat = "{asctime}.{msecs:0<3.0f}" + time.strftime('%z')
	else:
		logging.Formatter.converter = time.gmtime
		logTimeFormat = "{asctime}.{msecs:0<3.0f}Z"
	# see https://docs.python.org/3/library/logging.html#logrecord-attributes for things can include in format:
	logging.basicConfig(level=loglevel, format=f"{logTimeFormat}|{{levelname:8}}|{{module}}|{{funcName}}|{{message}}", style='{', datefmt='%Y-%m-%d %H:%M:%S')

class FontInfo:
	class BlockCodepoints:
		def __init__(self, blockName : str, initialCount : int = 0):
			self._name = blockName
			self._count = initialCount

		def _incrementCodepoint(self):
			self._count += 1

		@property
		def BlockName(self):
			return self._name

		@property
		def CodepointCount(self):
			return self._count

	class CodepointsInfo:
		def __init__(self):
			self._total : int = 0
			self._blocks : dict[str, FontInfo.BlockCodepoints] = { blk: FontInfo.BlockCodepoints(blk) for blk in unicodedata.Blocks.VALUES }

		def _incrementBlockCodepoint(self, blockName : str):
			self._total += 1
			self._blocks[blockName]._incrementCodepoint()

		#@property
		#def TotalCodepoints(self):
		#	return self._total

		def _getBlockCodepointCounts(self, includeAllBlocks : bool = False) :#-> Iterable[FontInfo.BlockCodepoints]:
			yield FontInfo.BlockCodepoints("<Total Codepoints>", self._total)
			for blk in self._blocks.values():
				if blk.CodepointCount > 0 or includeAllBlocks:
					yield blk

	def __init__(self, fontFilepath : pathlib.Path):
		self._fontpath : pathlib.Path = pathlib.Path(fontFilepath).resolve()
		self._ttfFile : ttLib.TTFont = ttLib.TTFont(self._fontpath)
		self._nameTbl : fontTools.ttLib.tables._n_a_m_e.table__n_a_m_e = self._ttfFile["name"]

	def _getNameTableRecord(self, nameId : int):
		val = self._nameTbl.getFirstDebugName((nameId,))
		return val if val is not None else ""

	def GetFontNameInfo(self) -> Iterable[(str, str)]:
		yield ("FontName", self.FontName)
		yield ("FontFamily", self.FontFamily)
		yield ("Version", self.Version)
		# yield ("Copyright", self.Copyright)
		# yield ("Trademark", self.Trademark)
		# yield ("Vendor", self.Vendor)
		# yield ("Designer", self.Designer)
		# yield ("LicenseURL", self.LicenseURL)

	def GetCodepointsInfo(self, includeAllBlocks : bool = False) :#-> Iterable[FontInfo.BlockCodepoints]: :#-> FontInfo.CodepointsInfo:
		cpInfo = FontInfo.CodepointsInfo()
		cmap = self._ttfFile.getBestCmap()#['cmap']
		for cp in cmap:
			cpInfo._incrementBlockCodepoint(unicodedata.block(chr(cp)))
		return cpInfo._getBlockCodepointCounts(includeAllBlocks)

	@property
	def FontName(self):
		return self._nameTbl.getBestFullName()

	@property
	def FontFamily(self):
		return self._nameTbl.getBestFamilyName()

	@property
	def Version(self):
		ver : str = self._getNameTableRecord(5)
		return ver[8:] if ver.startswith("Version ") else ver

	@property
	def Copyright(self):
		return self._getNameTableRecord(0)

	@property
	def Trademark(self):
		return self._getNameTableRecord(7)

	@property
	def Vendor(self):
		return self._getNameTableRecord(8)

	@property
	def Designer(self):
		return self._getNameTableRecord(9)

	@property
	def Description(self):
		return self._getNameTableRecord(10)

	@property
	def VendorURL(self):
		self._getNameTableRecord(11)

	@property
	def DesignerURL(self):
		self._getNameTableRecord(12)

	@property
	def License(self):
		return self._getNameTableRecord(13)

	@property
	def LicenseURL(self):
		return self._getNameTableRecord(14)

# region don't actually need this, dang it:
# class UnicodeBlockLookups:
# 	DbFile = pathlib.Path(PyScriptRoot) / f"{os.path.splitext(PyScript)[0]}.blocks.csv"	# <script's folder>/<script's basename>.blocks.csv

# 	class Block:
# 		def __init__(self, csvrow):
# 			self.Begin = int(csvrow['BlockBegin'], 16)
# 			self.End = int(csvrow['BlockEnd'], 16)
# 			self.Name = csvrow['BlockName']

# 	def __init__(self):
# 		self._db : list[UnicodeBlockLookups.Block] = UnicodeBlockLookups._initDb(UnicodeBlockLookups.DbFile)

# 	def GetCharacterBlock(self, codepoint : int) -> str:
# 		for b in self._db:
# 			if b.Begin <= codepoint <= b.End: # codepoint >= b.Begin and codepoint <= b.End:
# 				return b.Name
# 		raise ValueError(f"codepoint {codepoint} is not contained within any defined blocks")

# 	def GetBlocks(self) -> Iterable[str]:
# 		for b in self._db:
# 			yield b.Name

# 	@staticmethod
# 	def _filterCommentLines(inputFile : io.TextIOBase):
# 		for line in inputFile:
# 			if not line.startswith("#") and not line.isspace():
# 				yield line

# 	@staticmethod
# 	def _initDb(dbFilename : pathlib.Path) :#-> list(UnicodeBlockLookups.Block):
# 		db = []
# 		with open(dbFilename, newline="") as csvFile:
# 			csvRdr = csv.DictReader(UnicodeBlockLookups._filterCommentLines(csvFile))
# 			for entry in csvRdr:
# 				db.append(UnicodeBlockLookups.Block(entry))
# 		return db
# endregion

if __name__ == "__main__":
	sys.exit(main())
