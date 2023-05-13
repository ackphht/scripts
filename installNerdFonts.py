#!python3
# -*- coding: utf-8 -*-

import sys
import os
import pathlib
import shutil
import subprocess
from typing import Any, List#, Pattern, Tuple, Iterator, Dict

def main() -> int:
	if sys.platform == "linux":
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/.local/share/fonts/NerdFonts"))
	elif sys.platform == "darwin":
		userFontsFldrV2 = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts"))
		userFontsFldr = pathlib.Path(os.path.expandvars("$HOME/Library/Fonts/NerdFonts"))
	else:
		raise f"invalid/unrecognized OS: '{sys.platform}'"

	#LogHelper.Verbose(f"VERBOSE: using userFontsFolder = |{userFontsFldr}|")

	fantasqueFontName = "FantasqueSansMono"
	fantasqueFilenameBase = "FantasqueSansMNerdFont"
	fantasqueBaseNameV2 = "Fantasque Sans Mono"
	firaCodeFontName = "FiraCode"
	firaCodeFilenameBase = "FiraCodeNerdFont"
	firaCodeBaseNameV2 = "Fira Code"
	mesloFontName = "Meslo"
	mesloFilenameBase = "MesloLGSNerdFont"

	if not checkPrereqs(userFontsFldr): return 1

	# remove old fonts (like for <= v2 which had different names):
	fontFolders = [userFontsFldrV2, userFontsFldr]
	cleanUpOldFont(f"{fantasqueBaseNameV2} Regular Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{fantasqueBaseNameV2} Bold Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{fantasqueBaseNameV2} Italic Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{fantasqueBaseNameV2} Bold Italic Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeBaseNameV2} Regular Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeBaseNameV2} Bold Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeBaseNameV2} Light Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeBaseNameV2} Medium Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeBaseNameV2} SemiBold Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeBaseNameV2} Retina Nerd Font Complete.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeFilenameBase}-Regular.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeFilenameBase}-Bold.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeFilenameBase}-Light.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeFilenameBase}-Medium.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeFilenameBase}-SemiBold.ttf", fontFolders)
	cleanUpOldFont(f"{firaCodeFilenameBase}-Retina.ttf", fontFolders)

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

def cleanUpOldFont(fontFilename : str, fontFldrs : List[pathlib.Path]):
	for f in fontFldrs:
		filepath = f / fontFilename
		if filepath.exists():
			writeMessage3(f'removing old font file "{filepath}"')
			filepath.unlink()

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
