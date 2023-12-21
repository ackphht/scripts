#
# add this to .bashrc (or .zshrc [will it work ??] or whatever) (and might need to go at the bottom of file [e.g. Ubuntu]):
#	test -r ~/scripts/ackShellStuff.sh && source ~/scripts/ackShellStuff.sh || true
#

scriptRoot=$(dirname $(realpath ${ZSH_SCRIPT[0]:-${ZSH_SCRIPT:-${BASH_SOURCE[0]:-${0}}}}))		# ffs
source $scriptRoot/ackShellHelpers.sh

platform=$(uname -s)

currShell=$(readlink -f /proc/$$/exe 2>/dev/null)
if [[ -z "$currShell" ]]; then
	case $platform in
		Linux) currShell=$(ps -p $$ -o exe=) ;;		# things i found said to use 'cmd=' but that sometimes include all the args, too; think this one's more what i need
		Darwin) currShell=$(ps -p $$ -o command=) ;;
		MINGW*) currShell=$(ps -p $$ | tail -n 1 | awk '{print $NF}') ;;		# for git's bash; doesn't support ps -o
		FreeBSD) currShell=$(ps -p $$ -o comm=) ;;
	esac
elif [[ "$currShell" =~ "busybox" ]]; then
	currShell=$SHELL	# nothing else is working
fi
if [[ "${currShell:0:1}" == "/" ]]; then currShell=$(basename $currShell); fi	# in case got a full path
if [[ "${currShell:0:1}" == "-" ]]; then currShell=${currShell:1}; fi	# sometimes has a '-' on the front which means it's the login shell

# make sure these paths are added:
if [[ -d /snap/bin && ! "$PATH" =~ "/snap/bin" ]]; then
	export PATH="/snap/bin:$PATH"
fi
if [[ -d ~/scripts && ! "$PATH" =~ "$HOME/scripts" ]]; then
	export PATH="$HOME/scripts:$PATH"
fi
if [[ -d ~/.local/bin && ! "$PATH" =~ "$HOME/.local/bin" ]]; then
	export PATH="$HOME/.local/bin:$PATH"
fi

alias cls='clear'
hasCmd screenfetch && alias sf='screenfetch' || true
hasCmd neofetch && alias nf='neofetch' || true
(hasCmd python3 || hasCmd pwsh) && test -f ~/scripts/ackfetch.sh && alias af='bash ~/scripts/ackfetch.sh' || true
#hasCmd git && test -d ~/scripts && test -z "$WSL_DISTRO_NAME" && alias scup='pushd ~/scripts && git pull && popd' || true
if hasCmd git && test -d ~/scripts && test -z "$WSL_DISTRO_NAME" ; then
	if hasCmd pushd ; then	# it's a builtin for bash/zsh/others, but not all
		alias scup='pushd ~/scripts && git pull && popd' || true
	elif hasCmd bash ; then
		alias scup="bash -c 'pushd ~/scripts && git pull && popd'" || true
	fi
fi
hasCmd man && [[ "$COLUMNS" -gt 120 ]] && export MANWIDTH=120 || true
test -n $currShell && test -f ~/scripts/showAppVersions.sh && alias sav="$currShell ~/scripts/showAppVersions.sh" || true
case $platform in
	Linux|MINGW*|MSYS*|CYGWIN*)
		alias ll='ls -AlFhv --group-directories-first'
		alias l='ls -AFv --group-directories-first'
		hasCmd journalctl && alias cj='sudo journalctl --vacuum-time=1d' || true
		# ???
		#alias reboot='sudo reboot --reboot'
		#alias shutdown='sudo halt --poweroff --force --no-wall'
		;;
	Darwin|FreeBSD)
		alias ls='ls -G'	# -G sorta equivalent to --color=auto except it will work in ssh, too
		alias ll='ls -AlFhv'
		alias l='ls -AFv'
		alias grep='grep --color=auto'
		alias fgrep='fgrep --color=auto'
		alias egrep='egrep --color=auto'
		alias diff='diff --color=auto'
		;;
esac

if [[ "$platform" != "Darwin" ]] && hasCmd apt; then	# macOs (at least version i have) has some java app called apt; don't know what it is
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
elif hasCmd dnf; then
	alias aptr='sudo dnf check-update --refresh'
	alias aptul='sudo dnf check-update'	# ???
	alias aptu='sudo dnf upgrade --assumeyes'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && sudo dnf clean all --assumeyes --cacheonly'
	alias aptc='sudo dnf autoremove --assumeyes && sudo dnf clean packages --assumeyes --cacheonly'
	#alias aptc='sudo dnf autoremove --assumeyes --cacheonly && pkcon refresh force --cache-age -1 && sudo dnf clean all --assumeyes --cacheonly'
	alias apts='dnf search'
	alias aptn='dnf info'
	alias apti='sudo dnf install'
	alias aptx='sudo dnf remove'	# these both do the same thing
	alias aptxx='sudo dnf remove'	# but to keep the same aliases available...
	alias aptl='dnf list --installed'
elif hasCmd zypper; then
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
elif hasCmd pacman; then
	alias aptr='sudo pacman -Syy'	# --sync --refresh x 2 to force updae
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
elif hasCmd apk; then
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
elif hasCmd eopkg; then
	alias aptr='sudo eopkg update-repo'
	alias aptul='eopkg list-upgrades --install-info'
	alias aptu='sudo eopkg upgrade --yes-all'
	alias aptc='sudo eopkg remove-orphans && sudo eopkg delete-cache'
	alias apts='eopkg search'
	alias aptn='eopkg info'
	alias apti='sudo eopkg install'
	alias aptx='sudo eopkg remove'
	alias aptxx='sudo eopkg remove'
	alias aptl='eopkg list-installed'
elif hasCmd brew; then
	# https://docs.brew.sh/Manpage
	alias aptr='brew update'
	alias aptul='brew outdated'
	alias aptu='brew upgrade'
	alias aptc='brew autoremove && brew cleanup'
	alias apts='brew search'
	alias aptn='brew desc'		# ???
	alias apti='brew install'
	alias aptx='brew uninstall'
	alias aptxx='brew uninstall'
	alias aptl='brew list'
elif hasCmd pkg; then
	alias aptr='sudo pkg update --force'
	alias aptul='pkg upgrade --dry-run'
	alias aptu='sudo pkg upgrade --yes'
	alias aptc='sudo pkg autoremove --yes && sudo pkg clean --all --yes'
	alias apts='pkg search'
	alias aptn='pkg info --case-insensitive'
	alias apti='sudo pkg install'
	alias aptx='sudo pkg delete'
	alias aptxx='sudo pkg delete'
	alias aptl='pkg info --all'
fi

if hasCmd snap; then
	alias snaptul='snap refresh --list'
	alias snaptr='snap refresh --list'
	alias snaptu='sudo snap refresh'
	alias snapts='snap find'
	alias snaptn='snap info'
	alias snapti='sudo snap install'
	alias snaptx='sudo snap remove'
	alias snaptxx='sudo snap remove'
	alias snaptl='snap list'
fi

# can't use which or type for sbin stuff on openSuse:
if [[ -x /usr/bin/btrfs || -x /usr/sbin/btrfs ]]; then
	alias defrag='sudo btrfs filesystem defrag -czstd -rv /'
fi

# default prompt in case oh-my-posh (below) isn't installed
case $currShell in
	bash) PS1='\n\e[36m\s v\v \e[95m\u@\h \e[33m\t \e[92m\w\n\e[32mWHAT?!? \$\e[0m ' ;;
	zsh) PS1=$'\n\e[36mzsh \e[95m%n@%m \e[33m%* \e[92m%~\n\e[32mWHAT?!? %(!.#.$)\e[0m ' ;;	# can use named colors with %F but they're limited
	ash) PS1='\n\e[36mash \e[95m\u@\h \e[33m\t \e[92m\w\n\e[32mWHAT?!? \$\e[0m ' ;;
esac
if hasCmd oh-my-posh && test -n $currShell ; then
	eval "$(oh-my-posh init $currShell --config ~/scripts/ack.omp.linux.json)"
	alias omp='oh-my-posh'
	if hasCmd python3; then
		alias ompu='python3 ~/scripts/installOhMyPosh.py'
	else
		alias ompu='bash ~/scripts/installOhMyPosh.sh'
	fi
fi

#case $currShell in
#	bash) unset has ;;
#	zsh) unfunction has ;;
#esac
unset platform currShell