#
# add this to .bashrc (or .zshrc [will it work ??] or whatever) (and might need to go at the bottom of file [e.g. Ubuntu]):
#	test -r ~/scripts/ackShellStuff.sh && source ~/scripts/ackShellStuff.sh || true
#

# default prompt in case oh-my-posh (below) isn't installed
PS1='\n\e[36m\s \e[95m\u @ \h \e[33m\t \e[92m\w\n\e[32mWHAT?!? \$\e[0m '

alias ll='ls -AlFhv --group-directories-first'
alias l='ls -AFv --group-directories-first'

alias cls='clear'

type -p screenfetch >/dev/null && alias sf='screenfetch' || true
type -p neofetch >/dev/null && alias nf='neofetch' || true
alias cj='sudo journalctl --vacuum-time=1d'

# ???
#alias reboot='sudo reboot --reboot'
#alias shutdown='sudo halt --poweroff --force --no-wall'

if type -p apt >/dev/null; then
	alias aptr='sudo apt update'
	alias aptl='apt list --upgradable'
	alias aptu='sudo apt upgrade --yes'
	alias aptc='sudo apt-get autoremove --yes && sudo apt-get autoclean --yes && sudo apt-get clean --yes'
elif type -p dnf >/dev/null; then
	alias aptr='sudo dnf check-update --refresh'
	alias aptl='sudo dnf check-update'	# ???
	alias aptu='sudo dnf upgrade --assumeyes'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && sudo dnf clean all --assumeyes --cacheonly'
	alias aptc='sudo dnf autoremove --assumeyes && sudo dnf clean all --assumeyes --cacheonly'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && pkcon refresh force --cache-age -1 && sudo dnf clean all --assumeyes --cacheonly'
elif type -p zypper >/dev/null; then
	alias aptr='sudo zypper refresh --force'
	alias aptl='zypper list-updates'
	alias aptu='sudo zypper update --no-confirm'
	#alias aptc='sudo zypper remove --clean-deps && sudo zypper clean --all'
	alias aptc='sudo zypper clean --all'
elif type -p pacman >/dev/null; then
	alias aptr='sudo pacman --sync --refresh'
	alias aptl='pacman --query --upgrades'
	alias aptu='sudo pacman --sync --sysupgrade --noconfirm'
	alias aptc='sudo pacman --sync --clean --noconfirm'
fi

type -p btrfs >/dev/null && alias defrag='sudo btrfs filesystem defrag -czstd -rv /' || true

if type -p oh-my-posh >/dev/null; then
	eval "$(oh-my-posh init bash --config ~/scripts/ack.omp.linux.json)"
	alias omp='oh-my-posh'
fi