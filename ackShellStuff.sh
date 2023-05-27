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
test -f ~/scripts/ackfetch.sh >/dev/null && alias af='bash ~/scripts/ackfetch.sh' || true
alias cj='sudo journalctl --vacuum-time=1d'

# ???
#alias reboot='sudo reboot --reboot'
#alias shutdown='sudo halt --poweroff --force --no-wall'

if type -p apt >/dev/null; then
	alias aptr='sudo apt update'
	alias aptul='apt list --upgradable'
	alias aptu='sudo apt upgrade --yes'
	alias aptc='sudo apt-get autoremove --yes && sudo apt-get autoclean --yes && sudo apt-get clean --yes'
	alias apts='apt-cache search'
	alias aptn='apt show'
	alias apti='sudo apt install'
	alias aptx='sudo apt remove'	# leaves settings	(leaving off --yes)
	alias aptxx='sudo apt purge'	# removes settings too
	alias aptl='apt list --installed'
elif type -p dnf >/dev/null; then
	alias aptr='sudo dnf check-update --refresh'
	alias aptul='sudo dnf check-update'	# ???
	alias aptu='sudo dnf upgrade --assumeyes'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && sudo dnf clean all --assumeyes --cacheonly'
	alias aptc='sudo dnf autoremove --assumeyes && sudo dnf clean all --assumeyes --cacheonly'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && pkcon refresh force --cache-age -1 && sudo dnf clean all --assumeyes --cacheonly'
	alias apts='dnf search'
	alias aptn='dnf info'
	alias apti='sudo dnf install'
	alias aptx='sudo dnf remove'	# these both do the same thing
	alias aptxx='sudo dnf remove'	# but to keep the same aliases available...
	alias aptl='dnf list --installed'
elif type -p zypper >/dev/null; then
	alias aptr='sudo zypper refresh --force'	# if output is piped into, e.g. grep, it displays a warning about not having a 'stable CLI interface', 'use with caution'; ???
	alias aptul='zypper list-updates'
	alias aptu='sudo zypper update --no-confirm'
	#alias aptc='sudo zypper remove --clean-deps && sudo zypper clean --all'
	alias aptc='sudo zypper clean --all'
	alias apts='zypper search'
	alias aptn='zypper info'
	alias apti='sudo zypper install'
	alias aptx='sudo zypper remove --clean-deps'
	alias aptxx='sudo zypper remove --clean-deps'
	alias aptl='zypper packages --installed-only'
elif type -p pacman >/dev/null; then
	alias aptr='sudo pacman --sync --refresh'
	alias aptul='pacman --query --upgrades'
	alias aptu='sudo pacman --sync --sysupgrade --noconfirm'
	alias aptc='sudo pacman --sync --clean --noconfirm'
	alias apts='pacman --sync --search'
	alias aptn='pacman --query --info'
	alias apti='sudo pacman --sync'
	alias aptx='sudo pacman --remove --recursive'
	alias aptxx='sudo pacman --remove --recursive --nosave'
	alias aptl='pacman --query'
	# just to store this somewhere: to list all explicitly installed packages that aren't required by something else:
	#	pacman --query --explicit --unrequired (or pacman -Qet if wanna be lazy)
elif type -p apk >/dev/null; then
	alias aptr='sudo apk update'
	alias aptul='apk list --upgradable'
	alias aptu='sudo apk upgrade --available'
	alias aptc='sudo apk cache --purge'	# ???
	alias apts='apk search'
	alias aptn='apk info'		# can add '--all' to dump out all info, but this gets most likely relevant
	alias apti='sudo apk add'
	alias aptx='sudo apk del'
	alias aptxx='sudo apk del'
	alias aptl='apk list --installed'
	#alias apta='apk list --available'
fi

# can't use which or type for sbin stuff on openSuse:
if [[ -x /usr/bin/btrfs || -x /usr/sbin/btrfs ]]; then
	alias defrag='sudo btrfs filesystem defrag -czstd -rv /'
fi

if type -p oh-my-posh >/dev/null; then
	eval "$(oh-my-posh init bash --config ~/scripts/ack.omp.linux.json)"
	alias omp='oh-my-posh'
fi