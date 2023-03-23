#!/bin/bash

if ! $(which wget > /dev/null 2>&1) ; then
	echo "'wget' command not found"
	exit 1
fi

userFontsFldr=$HOME/.local/share/fonts
if [[ ! -d $userFontsFldr ]]; then
	echo "creating folder '$userFontsFldr'"
	mkdir -p $userFontsFldr
fi

#
# download fonts:
#
# FantasqueSansMono:
wget --output-document "$userFontsFldr/Fantasque Sans Mono Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FantasqueSansMono/Regular/complete/Fantasque%20Sans%20Mono%20Regular%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fantasque Sans Mono Bold Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FantasqueSansMono/Bold/complete/Fantasque%20Sans%20Mono%20Bold%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fantasque Sans Mono Italic Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FantasqueSansMono/Italic/complete/Fantasque%20Sans%20Mono%20Italic%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fantasque Sans Mono Bold Italic Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FantasqueSansMono/Bold-Italic/complete/Fantasque%20Sans%20Mono%20Bold%20Italic%20Nerd%20Font%20Complete.ttf
# FiraCode:
wget --output-document "$userFontsFldr/Fira Code Bold Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Bold/complete/Fira%20Code%20Bold%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fira Code Light Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Light/complete/Fira%20Code%20Light%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fira Code Medium Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Medium/complete/Fira%20Code%20Medium%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fira Code Regular Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Regular/complete/Fira%20Code%20Regular%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fira Code Retina Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/Retina/complete/Fira%20Code%20Retina%20Nerd%20Font%20Complete.ttf
wget --output-document "$userFontsFldr/Fira Code SemiBold Nerd Font Complete.ttf" https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/FiraCode/SemiBold/complete/Fira%20Code%20SemiBold%20Nerd%20Font%20Complete.ttf

# update font cache:
fc-cache -vf
