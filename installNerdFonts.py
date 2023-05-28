#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib, shutil, subprocess, urllib.request, json
from typing import Any, List#, Pattern, Tuple, Iterator, Dict

def main() -> int:
	userFontsFldr = userFontsFldrV2 = ""
	if sys.platform == "linux":
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts/NerdFonts"))
	elif sys.platform == "darwin":
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts/NerdFonts"))
	else:
		raise f"invalid/unrecognized OS: '{sys.platform}'"

	#LogHelper.Verbose(f"VERBOSE: using userFontsFolder = |{userFontsFldr}|")

	if not checkPrereqs(userFontsFldr): return 1

	# need to get latest version of NerdFonts on GitHub, and compare that to version file in the NerdFonts folders:
	currVerStr = getNerdFontsVerStr()
	for f in userFontsFldr.glob("@version_*"):
		if f.name >= currVerStr:
			writeMessage("latest version of NerdFonts already installed")
			return 0

	fantasqueFontName = "FantasqueSansMono"
	fantasqueFilenameBase = "FantasqueSansMNerdFont"
	fantasqueBaseNameV2 = "Fantasque Sans Mono"
	firaCodeFontName = "FiraCode"
	firaCodeFilenameBase = "FiraCodeNerdFont"
	firaCodeBaseNameV2 = "Fira Code"
	mesloFontName = "Meslo"
	mesloFilenameBase = "MesloLGSNerdFont"
	cascadiaFontName = "CascadiaCode"
	cascadiaFilenameBase = "CaskaydiaCoveNerdFont"
	comicShannsFontName = "ComicShannsMono"
	comicShannsFilenameBase = "ComicShannsMonoNerdFont"

	# remove old fonts (like for <= v2 which had different names):
	cleanUpOldFile(f"{fantasqueBaseNameV2}*.ttf", userFontsFldrV2)
	cleanUpOldFile(f"{firaCodeBaseNameV2}*.ttf", userFontsFldrV2)
	cleanUpOldFile(f"{firaCodeFilenameBase}*.ttf", userFontsFldrV2)
	# since we started putting nerd fonts in their own folder, can just delete everything in there:
	cleanUpOldFile("*.ttf", userFontsFldr)
	cleanUpOldFile("*.otf", userFontsFldr)
	cleanUpOldFile("@version_*", userFontsFldr)

	#
	# download fonts:
	# FantasqueSansMono:
	installNerdFont(fantasqueFontName, "Regular", f"{fantasqueFilenameBase}-Regular.ttf", userFontsFldr)
	installNerdFont(fantasqueFontName, "Bold", f"{fantasqueFilenameBase}-Bold.ttf", userFontsFldr)
	installNerdFont(fantasqueFontName, "Italic", f"{fantasqueFilenameBase}-Italic.ttf", userFontsFldr)
	installNerdFont(fantasqueFontName, "Bold-Italic", f"{fantasqueFilenameBase}-BoldItalic.ttf", userFontsFldr)
	## FiraCode:
	#installNerdFont(firaCodeFontName, "Regular", f"{firaCodeFilenameBase}-Regular.ttf", userFontsFldr)
	#installNerdFont(firaCodeFontName, "Bold", f"{firaCodeFilenameBase}-Bold.ttf", userFontsFldr)
	#installNerdFont(firaCodeFontName, "Light", f"{firaCodeFilenameBase}-Light.ttf", userFontsFldr)
	#installNerdFont(firaCodeFontName, "Medium", f"{firaCodeFilenameBase}-Medium.ttf", userFontsFldr)
	#installNerdFont(firaCodeFontName, "SemiBold", f"{firaCodeFilenameBase}-SemiBold.ttf", userFontsFldr)
	#installNerdFont(firaCodeFontName, "Retina", f"{firaCodeFilenameBase}-Retina.ttf", userFontsFldr)
	# Meslo:
	installNerdFont(mesloFontName, "S/Regular", f"{mesloFilenameBase}-Regular.ttf", userFontsFldr)
	installNerdFont(mesloFontName, "S/Bold", f"{mesloFilenameBase}-Bold.ttf", userFontsFldr)
	installNerdFont(mesloFontName, "S/Italic", f"{mesloFilenameBase}-Italic.ttf", userFontsFldr)
	installNerdFont(mesloFontName, "S/Bold-Italic", f"{mesloFilenameBase}-BoldItalic.ttf", userFontsFldr)
	# CascadiaCode (there's other styles but these are enough for this):
	installNerdFont(cascadiaFontName, "Regular", f"{cascadiaFilenameBase}-Regular.ttf", userFontsFldr)
	installNerdFont(cascadiaFontName, "Bold", f"{cascadiaFilenameBase}-Bold.ttf", userFontsFldr)
	installNerdFont(cascadiaFontName, "Regular", f"{cascadiaFilenameBase}-Italic.ttf", userFontsFldr)
	installNerdFont(cascadiaFontName, "Bold", f"{cascadiaFilenameBase}-BoldItalic.ttf", userFontsFldr)
	## ComicShannsMono:
	#installNerdFont(comicShannsFontName, "", f"{comicShannsFilenameBase}-Regular.otf", userFontsFldr)
	#installNerdFont(comicShannsFontName, "", f"{comicShannsFilenameBase}-Bold.otf", userFontsFldr)

	# create version file:
	(userFontsFldr / currVerStr).touch()

	# update font cache:
	if sys.platform == "linux":
		args = ["fc-cache", "--force", "--verbose"]
		process = subprocess.run(args)
		if process.returncode:
			LogHelper.Error(f'fc-cache failed to refresh font cache; return code was {process.returncode}')

def checkPrereqs(fontDir : pathlib.Path) -> bool:
	if not shutil.which("wget"):
		writeError("could not find command 'wget'")
		return False

	# make sure font directory userFontsFldr exists
	if not fontDir.exists():
		fontDir.mkdir(parents=True)

	return True

def getNerdFontsVerStr() -> str:
	with urllib.request.urlopen("https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest") as resp:
		# should throw if there's an error, so if we get here, assume it worked:
		jsonData = json.loads(resp.read())
		# tag name/version not reliably comparable, so use id first, since that should
		# be always incrementing (right?), then include tag name/version for my readability:
		return f"@version_{jsonData['id']:>012}_{jsonData['tag_name']}"

def cleanUpOldFile(fontNameGlob : str, fontFldr : pathlib.Path):
	for f in fontFldr.glob(fontNameGlob):
		writeMessage3(f'removing old file "{f}"')
		f.unlink()

def installNerdFont(fontname : str, style : str, filename : str, fontFldr : pathlib.Path):
	outputName = fontFldr / filename
	# assuming no spaces in the file names anymore:
	url = f"https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/{fontname}/{style}/{filename}"

	print("")
	writeMessage("################################################")
	writeMessage(filename)
	writeMessage("################################################")
	args = ["wget", "--output-document", outputName, url]
	process = subprocess.run(args)
	if process.returncode:
		writeError(f'wget failed to get file "{filename}"; return code was {process.returncode}')

def writeError(msg : str):
	print(f"\033[1;31m{msg}\033[0;39m")

def writeMessage(msg : str):
	print(f"\033[22;36m{msg}\033[0;39m")

def writeMessage3(msg : str):
	print(f"\033[22;33m{msg}\033[0;39m")

if __name__ == "__main__":
	sys.exit(main())
