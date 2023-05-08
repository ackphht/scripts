#!/bin/bash

if ! $(which wget > /dev/null 2>&1) ; then
	echo "'wget' command not found"
	exit 1
fi

userFontsFldrV2=$HOME/.local/share/fonts
userFontsFldr=$HOME/.local/share/fonts/NerdFonts
if [[ ! -d $userFontsFldr ]]; then
	echo "creating folder '$userFontsFldr'"
	mkdir -p $userFontsFldr
fi

cleanUpOldFont() {
	local filenameV2="${userFontsFldrV2}/$1"
	local filename="${userFontsFldr}/$1"
	if [[ -f "$filenameV2" ]]; then
		echo "removing old font \"$filenameV2\""
		rm -f "$filenameV2"
	fi
	if [[ -f "$filename" ]]; then
		echo "removing old font \"$filename\""
		rm -f "$filename"
	fi
}

installNerdFont() {
	local fontname=$1
	local style=$2
	local filename=$3
	local outputName="${userFontsFldr}/$3"
	# assuming no spaces in the file names anymore:
	local url="https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/${fontname}/${style}/${filename}"

	echo
	echo '################################################'
	echo $filename
	echo '################################################'
	wget --output-document $outputName $url
}

fantasqueFontName='FantasqueSansMono'
fantasqueFilenameBase='FantasqueSansMNerdFont'
fantasqueBaseNameV2='Fantasque Sans Mono'
firaCodeFontName='FiraCode'
firaCodeFilenameBase='FiraCodeNerdFont'
firaCodeBaseNameV2='Fira Code'

# remove old fonts (like for <= v2 which had different names):
cleanUpOldFont "${fantasqueBaseNameV2} Regular Nerd Font Complete.ttf"
cleanUpOldFont "${fantasqueBaseNameV2} Bold Nerd Font Complete.ttf"
cleanUpOldFont "${fantasqueBaseNameV2} Italic Nerd Font Complete.ttf"
cleanUpOldFont "${fantasqueBaseNameV2} Bold Italic Nerd Font Complete.ttf"
cleanUpOldFont "${firaCodeBaseNameV2} Regular Nerd Font Complete.ttf"
cleanUpOldFont "${firaCodeBaseNameV2} Bold Nerd Font Complete.ttf"
cleanUpOldFont "${firaCodeBaseNameV2} Light Nerd Font Complete.ttf"
cleanUpOldFont "${firaCodeBaseNameV2} Medium Nerd Font Complete.ttf"
cleanUpOldFont "${firaCodeBaseNameV2} SemiBold Nerd Font Complete.ttf"
cleanUpOldFont "${firaCodeBaseNameV2} Retina Nerd Font Complete.ttf"

#
# download fonts:
# FantasqueSansMono:
installNerdFont $fantasqueFontName 'Regular' "${fantasqueFilenameBase}-Regular.ttf"
installNerdFont $fantasqueFontName 'Bold' "${fantasqueFilenameBase}-Bold.ttf"
installNerdFont $fantasqueFontName 'Italic' "${fantasqueFilenameBase}-Italic.ttf"
installNerdFont $fantasqueFontName 'Bold-Italic' "${fantasqueFilenameBase}-BoldItalic.ttf"
# FiraCode:
# now get latest fonts:
installNerdFont $firaCodeFontName 'Regular' "${firaCodeFilenameBase}-Regular.ttf"
installNerdFont $firaCodeFontName 'Bold' "${firaCodeFilenameBase}-Bold.ttf"
installNerdFont $firaCodeFontName 'Light' "${firaCodeFilenameBase}-Light.ttf"
installNerdFont $firaCodeFontName 'Medium' "${firaCodeFilenameBase}-Medium.ttf"
installNerdFont $firaCodeFontName 'SemiBold' "${firaCodeFilenameBase}-SemiBold.ttf"
installNerdFont $firaCodeFontName 'Retina' "${firaCodeFilenameBase}-Retina.ttf"

# update font cache:
fc-cache -vf
