#!/bin/bash

binFldr=$HOME/.local/bin
if [[ ! -d $binFldr ]]; then
	#echo "    creating folder '$binFldr'"
	mkdir -p $binFldr
fi
outfile=$binFldr/oh-my-posh

#sudo wget https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64 -O $outfile
#sudo chmod +x $outfile
wget --output-document $outfile https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-amd64
chmod +x $outfile

# use installNerdFonts.sh to install the NerdFonts i like
# probably have to restart console for it to see new fonts
# set console to use one of them

# then update .bashrc (or whatever distro is using) (see https://ohmyposh.dev/docs/installation/prompt):
# at bottom or somewhere, add
#	xxx eval "$(oh-my-posh init bash --config https://gist.githubusercontent.com/ackphht/be15af198d20420f4fa51782936036f8/raw/587d5c90a26b867f7355d2f82c26e185e4d566fb/ack.omp.json)"
#	eval "$(oh-my-posh init bash --config https://ackphht.github.io/ack.omp.linux.json)"
# save, then restart bash prompt or can do
#	. ~/.bashrc