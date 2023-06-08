#!python3
# -*- coding: utf-8 -*-

import sys, os, re, pathlib, shutil, subprocess, urllib.request, json, argparse, tarfile, zipfile
from typing import Iterator, Self#, List, Dict#, Any, Pattern, Tuple
from io import BytesIO
from loghelper import LogHelper

def main() -> int:
	parser = initArgParser()
	args = parser.parse_args()
	verboseLogging = args.verbose
	testMode = args.test
	forceInstall = args.force

	LogHelper.Init(verboseLogging)

	userFontsFldr = userFontsFldrV2 = ""
	if testMode:
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/tmp/fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/tmp/fonts/NerdFonts"))
	elif sys.platform == "linux":
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts/NerdFonts"))
	elif sys.platform == "darwin":
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts/NerdFonts"))
	elif '_pydevd_bundle' not in sys.modules:	# so if we're on windows and working in VSCode (or other editor?), rest of file won't be grayed out; there's also 'debugpy' that's MS specific ??
		raise RuntimeError(f"invalid/unrecognized OS: '{sys.platform}'")

	LogHelper.Verbose(f"using userFontsFolder = |{userFontsFldr}|")

	if not checkPrereqs(userFontsFldr): return 1

	# get latest release info for NerdFonts on GitHub:
	ghRelease : GithubRelease = GithubRelease.CreateReleaseInfo("https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest")

	# get version string, and compare that to version file in the NerdFonts folders:
	currVerStr = getNerdFontsVerStr(ghRelease)
	if not forceInstall:
		for f in userFontsFldr.glob("@version_*"):
			if f.name >= currVerStr:
				LogHelper.Message("latest version of NerdFonts already installed")
				return 0

	print("")
	LogHelper.Message2("################################################")
	LogHelper.Message2(f"installing version {ghRelease.tag} of NerdFonts")
	LogHelper.Message2("################################################")

	fontsToInstall = initFontsToInstall(ghRelease)

	removeOldFonts(userFontsFldr, userFontsFldrV2)

	for nfd in fontsToInstall.fonts:
		installFont(nfd, userFontsFldr)

	# create version file:
	(userFontsFldr / currVerStr).touch()

	if not testMode:
		rebuildFontCache()

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	parser.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	parser.add_argument("-t", "--test", action="store_true", help="enable test mode (won't actually install fonts)")
	parser.add_argument("-f", "--force", action="store_true", help="force download and install, even if we already have latest version")
	return parser

def checkPrereqs(fontDir : pathlib.Path) -> bool:
	if not shutil.which("wget"):
		LogHelper.Error("could not find command 'wget'")
		return False

	# make sure font directory userFontsFldr exists
	if not fontDir.exists():
		fontDir.mkdir(parents=True)

	return True

class GithubReleaseAsset:
	def __init__(self, assetDict : dict):
		self._id : int = assetDict['id']
		self._name : str = assetDict['name']
		self._label : str = assetDict['label']
		self._contentType : str = assetDict['content_type']
		self._size : int = assetDict['size']
		self._downloadUrl : str = assetDict['browser_download_url']

	@property
	def id(self) -> int:
		return self._id

	@property
	def name(self) -> str:
		return self._name

	@property
	def label(self) -> str:
		return self._labbel

	@property
	def contentType(self) -> str:
		return self._contentType

	@property
	def size(self) -> int:
		return self._size

	@property
	def downloadUrl(self) -> str:
		return self._downloadUrl

class GithubRelease:
	def __init__(self, releaseJson : str):
		j = json.loads(releaseJson)
		self._id : int = j['id']
		self._releaseUrl : str = j['html_url']
		self._tag : str = j['tag_name']
		self._name : str = j['name']
		self._publishedAt : str = j['published_at']
		self._assets = []
		for a in j['assets']:
			self._assets.append(GithubReleaseAsset(a))

	@staticmethod
	def CreateReleaseInfo(url : str) -> Self:
		with urllib.request.urlopen(url) as resp:
			return GithubRelease(resp.read())

	@property
	def id(self) -> int:
		return self._id

	@property
	def releaseUrl(self) -> str:
		return self._releaseUrl

	@property
	def tag(self) -> str:
		return self._tag

	@property
	def name(self) -> str:
		return self._name

	@property
	def publishedAt(self) -> str:
		return self._publishedAt

	@property
	def assets(self) -> list[GithubReleaseAsset]:
		return self._assets

class NerdFontDefn:
	DownloadTypeTarXz = "tarxz"
	DownloadTypeZip = "zip"

	def __init__(self, assetName : str, patternsToExtract : list[str]):
		self._assetName : str = assetName
		self._patterns : list[re.Pattern] = []
		for p in patternsToExtract:
			self._patterns.append(re.compile(p))
		self._downloadUrl : str = ""
		self._downloadType : str = ""

	@property
	def assetName(self) -> str:
		return self._assetName

	@property
	def downloadUrl(self) -> str:
		return self._downloadUrl

	@property
	def downloadType(self) -> str:
		return self._downloadType

	def updateDownloadUrl(self, url : str, type : str) -> None:
		# prefer .tar.xz:
		if type == NerdFontDefn.DownloadTypeTarXz:
			self._downloadUrl = url
			self._downloadType = type
		elif type == NerdFontDefn.DownloadTypeZip and not self._downloadUrl:
			self._downloadUrl = url
			self._downloadType = type

	def shouldExtract(self, filename : str) -> bool:
		for r in self._patterns:
			if r.search(filename):
				return True
		return False

class NerdFontCollection:
	def __init__(self):
		self._fonts : dict[str, NerdFontDefn] = dict()

	@property
	def fonts(self) -> Iterator[NerdFontDefn]:
		return [self._fonts[k] for k in self._fonts]

	def addFontDefn(self, fontName : str, patternsToExtract : list[str]):
		if fontName not in self._fonts:
			self._fonts[fontName] = NerdFontDefn(fontName, patternsToExtract)

	def processAsset(self, asset : GithubReleaseAsset):
		# currently, at least, none of the font names have dots, so split at first dot into font name and extension
		dotPos = asset.name.find(".")
		if (dotPos >= 0):
			fontname = asset.name[:dotPos]
			if fontname in self._fonts:
				extension = asset.name[dotPos:].lower()
				if extension == ".tar.xz":
					self._fonts[fontname].updateDownloadUrl(asset.downloadUrl, NerdFontDefn.DownloadTypeTarXz)
				elif extension == ".zip":
					self._fonts[fontname].updateDownloadUrl(asset.downloadUrl, NerdFontDefn.DownloadTypeZip)

def getNerdFontsVerStr(releaseInfo : GithubRelease) -> str:
#	with urllib.request.urlopen("https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest") as resp:
#		# should throw if there's an error, so if we get here, assume it worked:
#		jsonData = json.loads(resp.read())
		# tag name/version not reliably comparable, so use id first, since that should
		# be always incrementing (right?), then include tag name/version for my readability:
#		return f"@version_{jsonData['id']:>012}_{jsonData['tag_name']}"
	return f"@version_{releaseInfo.id:>012}_{releaseInfo.tag}"

def initFontsToInstall(ghRelease : GithubRelease) -> NerdFontCollection:
	fontsToInstall : NerdFontCollection = NerdFontCollection()
	fontsToInstall.addFontDefn("FantasqueSansMono", ["FantasqueSansMNerdFont-.+\.ttf"])#, "FantasqueSansMNerdFontMono-.+\.ttf"])
	fontsToInstall.addFontDefn("CascadiaCode", ["CaskaydiaCoveNerdFont-.+\.ttf"])#, "CaskaydiaCoveNerdFontMono-.+\.ttf"])
	fontsToInstall.addFontDefn("Meslo", ["MesloLGSNerdFont-.+\.ttf"])#, "MesloLGSNerdFontMono-.+\.ttf"])
	for a in ghRelease.assets:
		fontsToInstall.processAsset(a)
	return fontsToInstall

def removeOldFonts(fontFldr : pathlib.Path, fontfldrV2 : pathlib.Path) -> None:
	# remove old fonts:
	# for <= v2 those had different names and in plain folder, so remove explicitly:
	cleanUpOldFile("Fantasque Sans Mono*.ttf", fontfldrV2)
	cleanUpOldFile("Fira Code*.ttf", fontfldrV2)
	cleanUpOldFile("FiraCodeNerdFont*.ttf", fontfldrV2)
	# for v3+, started putting nerd fonts in their own folder, can just delete everything in there:
	cleanUpOldFile("*.ttf", fontFldr)
	cleanUpOldFile("*.otf", fontFldr)
	cleanUpOldFile("@version_*", fontFldr)

def cleanUpOldFile(fontNameGlob : str, fontFldr : pathlib.Path):
	for f in fontFldr.glob(fontNameGlob):
		LogHelper.Message3(f'removing old file "{f}"')
		f.unlink()

def installFont(fontDfn : NerdFontDefn, fontFldr : pathlib.Path) -> None:
	if not fontDfn.downloadUrl or not fontDfn.downloadType:
		LogHelper.Warning(f"font \"{fontDfn.assetName}\" is missing either url and/or type: url = |{fontDfn.downloadUrl}|, type = |{fontDfn.downloadType}|")
		return
	print("")
	LogHelper.Message("------------------------------------------------")
	LogHelper.Message(f"installing font \"{fontDfn.assetName}\"")
	LogHelper.Message("------------------------------------------------")
	if fontDfn.downloadType == NerdFontDefn.DownloadTypeTarXz:
		installFontFromTarXz(fontDfn, fontFldr)
	elif fontDfn.downloadType == NerdFontDefn.DownloadTypeZip:
		installFontFromZip(fontDfn, fontFldr)
	else:
		LogHelper.Warning(f"font \"{fontDfn.assetName}\" has unrecognized type: |{fontDfn.downloadType}|")

def installFontFromTarXz(fontDfn : NerdFontDefn, fontFldr : pathlib.Path) -> None:
	LogHelper.Verbose(f"installing .tar.xz: url = |{fontDfn.downloadUrl}|")
	with urllib.request.urlopen(fontDfn.downloadUrl) as resp:
		tf = tarfile.open(fileobj=BytesIO(resp.read()), mode='r:xz')
	for f in tf.getnames():
		if fontDfn.shouldExtract(f):
			LogHelper.Message(f"installing font |{f}|")
			tf.extract(f, path=fontFldr)
		else:
			LogHelper.Verbose(f"skipping font file |{f}|")

def installFontFromZip(fontDfn : NerdFontDefn, fontFldr : pathlib.Path) -> None:
	LogHelper.Verbose(f"installing .zip: url = |{fontDfn.downloadUrl}|")
	with urllib.request.urlopen(fontDfn.downloadUrl) as resp:
		zf = zipfile.ZipFile(BytesIO(resp.read()))
	for f in zf.namelist():
		if fontDfn.shouldExtract(f):
			LogHelper.Message(f"installing font |{f}|")
			zf.extract(f, path=fontFldr)
		else:
			LogHelper.Verbose(f"skipping font file |{f}|")

def runApp(appAndArgs : list[str]) -> int:
	process = subprocess.run(appAndArgs)
	if process.returncode != 0:
		LogHelper.Error(f'app {appAndArgs[0]} returned non-zero exit code: {process.returncode}')
	return process.returncode

def rebuildFontCache() -> None:
	if sys.platform == "linux":
		runApp(["fc-cache", "--force", "--verbose"])
	elif sys.platform == "darwin":
		# ???
		retCode = runApp(["atsutil", "databases", "-removeUser"])
		if retCode == 0:
			retCode = runApp(["atsutil", "server", "-shutdown"])
		if retCode == 0:
			retCode = runApp(["atsutil", "server", "-ping"])

if __name__ == "__main__":
	sys.exit(main())
