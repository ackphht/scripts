#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, argparse, time, io, csv
import logging
from collections.abc import Iterable
import fontTools
from fontTools import ttLib, unicodedata		# https://fonttools.readthedocs.io/en/latest/index.html
from tabulate import tabulate	# https://pypi.org/project/tabulate/

PyScript = os.path.abspath(__file__)
PyScriptRoot = os.path.dirname(os.path.abspath(__file__))

def main():
	args = initArgParser().parse_args()
	initLogging(args.verbose)

	def fontPathsIter(args) -> Iterable[str]:
		if args.fontPath:
			for fp in args.fontPath:
				yield fp
		else:
			pth = pathlib.Path(args.fontListPath)
			if not pth.exists():
				raise FileNotFoundError(f'the specified input file does not exist: "{pth}"')
			with open(pth) as f:
				for fp in f:
					fp = fp.strip()
					if fp and not fp.startswith("#"):
						yield fp

	fontsList = FontsList()
	for fp in fontPathsIter(args):
		fontpath = pathlib.Path(fp)
		if not fontpath.exists():
			raise FileNotFoundError(f'the font file does not exist: "{fontpath}"')
		fontsList.addFont(fontpath)

	if args.csv:
		with open(args.csv, "w", newline="") as csvfile:
			writer = csv.writer(csvfile)
			writer.writerow(fontsList.getFontNames(title=""))
			writer.writerow(fontsList.getFontVersions(title="Version"))
			writer.writerows(fontsList.getBlockCodepointCountRows())
	else:
		print()
		tableFormat = "rst"#"simple" #"presto"
		hdrs = list(fontsList.getFontNameAndVersions(title="Block / Font", sep="\n"))
		print(tabulate(fontsList.getBlockCodepointCountRows(), hdrs, tablefmt=tableFormat, numalign="left"))

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	pathGroup = parser.add_mutually_exclusive_group(required=True)
	pathGroup.add_argument("-f", "--fontPath", action="append", help="path to the font file to show info for")
	pathGroup.add_argument("-l", "--fontListPath", help="path to a file containing a list of fonts to get info for, one font path per line")
	# exGroup = parser.add_mutually_exclusive_group()
	# exGroup.add_argument("-b", "--allBlocks", action="store_true", help="print all blocks, not just ones with codepoints")
	# exGroup.add_argument("-c", "--csv", help="write output as CSV to specified file path", metavar="CSVFILE")
	parser.add_argument("-c", "--csv", help="write output as CSV to specified file path", metavar="CSVFILE")
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

class FontDetails:
	class _fontNames:
		def __init__(self, font : ttLib.TTFont):
			nameTbl = font["name"]	# : fontTools.ttLib.tables._n_a_m_e.table__n_a_m_e
			self.fontName : str = nameTbl.getBestFullName()
			self.fontFamily : str = nameTbl.getBestFamilyName()
			ver : str = self._getNameTableRecord(nameTbl, 5)
			self.version = ver[8:] if ver.startswith("Version ") else ver
			self.copyright : str = self._getNameTableRecord(nameTbl, 0)
			self.trademark : str =  self._getNameTableRecord(nameTbl, 7)
			self.vendor : str = self._getNameTableRecord(nameTbl, 8)
			self.designer : str = self._getNameTableRecord(nameTbl, 9)
			self.description : str = self._getNameTableRecord(nameTbl, 10)
			self.vendorUrl : str = self._getNameTableRecord(nameTbl, 11)
			self.designerUrl : str = self._getNameTableRecord(nameTbl, 12)
			self.license : str = self._getNameTableRecord(nameTbl, 13)
			self.licenseUrl : str = self._getNameTableRecord(nameTbl, 14)

		def _getNameTableRecord(self, nameTbl, nameId : int):
			val = nameTbl.getFirstDebugName((nameId,))
			return val if val is not None else ""

	#def __init__(self, filepath : pathlib.Path, blockNames : list[str]):
	def __init__(self, filepath : pathlib.Path):
		self._filepath : pathlib.Path = filepath
		self._total = 0
		#self._blockCounts : dict[str, int] = { blk: 0 for blk in blockNames }
		self._blockCounts : dict[str, int] = dict()
		self._fontNames : FontDetails.FontNames = None

	def _incrementBlockCodepoint(self, blockName : str):
		self._total += 1
		if blockName in self._blockCounts:
			self._blockCounts[blockName] += 1
		else:
			self._blockCounts[blockName] = 1

	def populateDetails(self):
		ttfFile : ttLib.TTFont = ttLib.TTFont(self._filepath)
		self._fontNames : FontDetails._fontNames = FontDetails._fontNames(ttfFile)
		cmap = ttfFile.getBestCmap()#['cmap']
		for cp in cmap:
			self._incrementBlockCodepoint(unicodedata.block(chr(cp)))

	def getBlockCodepointCount(self, blockName : str):
		return self._blockCounts[blockName] if blockName in self._blockCounts else 0

	#region properties
	@property
	def TotalCodepoints(self) -> int:
		return self._total

	@property
	def BlockCodepointCounts(self) -> Iterable[tuple[str, int]]:
		for blk in self._blockCounts:
			if blk.CodepointCount > 0:
				yield (blk, self._blockCounts[blk])

	@property
	def FontName(self) -> str:
		return self._fontNames.fontName if self._fontNames else ''

	@property
	def FontFamily(self) -> str:
		return self._fontNames.fontFamily if self._fontNames else ''

	@property
	def Version(self) -> str:
		return self._fontNames.version if self._fontNames else ''

	@property
	def Copyright(self) -> str:
		return self._fontNames.copyright if self._fontNames else ''

	@property
	def Trademark(self) -> str:
		return self._fontNames.trademark if self._fontNames else ''

	@property
	def Vendor(self) -> str:
		return self._fontNames.vendor if self._fontNames else ''

	@property
	def Designer(self) -> str:
		return self._fontNames.designer if self._fontNames else ''

	@property
	def Description(self) -> str:
		return self._fontNames.description if self._fontNames else ''

	@property
	def VendorURL(self) -> str:
		return self._fontNames.vendorUrl if self._fontNames else ''

	@property
	def DesignerURL(self) -> str:
		return self._fontNames.designerUrl if self._fontNames else ''

	@property
	def License(self) -> str:
		return self._fontNames.license if self._fontNames else ''

	@property
	def LicenseURL(self) -> str:
		return self._fontNames.licenseUrl if self._fontNames else ''
	#endregion

class FontsList:
	def __init__(self):
		self._fonts : dict[pathlib.Path, FontDetails] = dict()

	def addFont(self, filepath : pathlib.Path):
		deets = FontDetails(filepath)
		deets.populateDetails()
		self._fonts[filepath] = deets

	def getFontNames(self, title : str = None) -> Iterable[str]:
		if title is not None:
			yield title
		for f in self._fonts.values():
			yield f.FontName

	def getFontVersions(self, title : str = None) -> Iterable[str]:
		if title is not None:
			yield title
		for f in self._fonts.values():
			yield f.Version

	def getFontNameAndVersions(self, title : str = None, sep : str = " ") -> Iterable[str]:
		if title is not None:
			yield title
		for f in self._fonts.values():
			yield f"{f.FontName}{sep}v{f.Version}"

	def getBlockCodepointCountRows(self) -> Iterable[list]:
		row : list = ["<Total Codepoints>",]
		for f in self._fonts.values():
			row.append(f.TotalCodepoints)
		yield row
		for blk in unicodedata.Blocks.VALUES:
			row : list = [blk,]
			yieldBlock = False
			for f in self._fonts.values():
				cnt = f.getBlockCodepointCount(blk)
				row.append(cnt)
				if cnt > 0:
					yieldBlock = True
			if yieldBlock:
				yield row

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
