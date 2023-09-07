#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, argparse, time, io, csv
import logging
from collections.abc import Iterable
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
		ttfFile : ttLib.TTFont = None
		if self._filepath.suffix == ".ttc":
			ttc : ttLib.TTCollection = ttLib.TTCollection(self._filepath)
			if len(ttc.fonts) > 0:
				# just use first one, assume they all have same codepoint counts (???)
				ttfFile : ttLib.TTFont = ttc.fonts[0]
		else:
			ttfFile : ttLib.TTFont = ttLib.TTFont(self._filepath)
		if ttfFile is None:
			return
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

if __name__ == "__main__":
	sys.exit(main())
