#
# add this to .bashrc (or whatever for zsh or whatever):
#	if [[ -r ~/scripts/bashAliases.sh ]]; then
#		. ~/scripts/bashAliases.sh
#	fi
#

alias ll='ls -AlFhv --group-directories-first'
alias l='ls -AFv --group-directories-first'

alias cls='clear'

if [ -f /usr/bin/apt ]; then
	alias aptr='sudo apt update'
	alias aptl='apt list --upgradable'
	alias aptu='sudo apt upgrade --yes'
	alias aptc='sudo apt-get autoremove --yes && sudo apt-get autoclean --yes && sudo apt-get clean --yes'
elif [ -f /usr/bin/dnf ]; then
	alias aptr='sudo dnf check-update --refresh'
	alias aptl='sudo dnf check-update'	# ???
	alias aptu='sudo dnf upgrade --assumeyes'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && sudo dnf clean all --assumeyes --cacheonly'
	alias aptc='sudo dnf autoremove --assumeyes && sudo dnf clean all --assumeyes --cacheonly'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && pkcon refresh force --cache-age -1 && sudo dnf clean all --assumeyes --cacheonly'
elif [ -f /usr/bin/zypper ]; then
	alias aptr='sudo zypper refresh --force'
	alias aptl='zypper list-updates'
	alias aptu='sudo zypper update --no-confirm'
	#alias aptc='sudo zypper remove --clean-deps && sudo zypper clean --all'
	alias aptc='sudo zypper clean --all'
elif [ -f /usr/bin/pacman ]; then
	alias aptr='sudo pacman --sync --refresh'
	alias aptl='pacman --query --upgrades'
	alias aptu='sudo pacman --sync --sysupgrade --noconfirm'
	alias aptc='sudo pacman --sync --clean'
fi

if [ -f /usr/sbin/btrfs ] || [ -f /usr/bin/btrfs ]; then
	alias defrag='sudo btrfs filesystem defrag -czstd -rv /'
fi

alias sf='screenfetch'
alias nf='neofetch'
alias cj='sudo journalctl --vacuum-time=1d'
alias omp='oh-my-posh'
