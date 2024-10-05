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
		*BSD|DragonFly) currShell=$(ps -p $$ -o comm=) ;;
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

if hasCmd sudo; then	# termux doesn't have it
	sudoCmd='sudo '
else
	sudoCmd=''
fi

alias cls='clear'
hasCmd screenfetch && alias sf='screenfetch' || true
hasCmd neofetch && alias nf='neofetch' || true
hasCmd fastfetch && alias ff='fastfetch' || true
hasCmd cpufetch && alias cf='cpufetch' || true
(hasCmd python3 || hasCmd pwsh) && test -f ~/scripts/ackfetch.sh && alias af='bash ~/scripts/ackfetch.sh' || true
#hasCmd git && test -d ~/scripts && test -z "$WSL_DISTRO_NAME" && alias scup='pushd ~/scripts && git pull && popd' || true
if hasCmd git; then
	alias git-count='git count-objects -v'
	alias git-compact='git reflog expire --expire=now --all && git gc --prune=now --aggressive'
	if test -d ~/scripts && test -z "$WSL_DISTRO_NAME"; then
		if hasCmd pushd ; then	# it's a builtin for bash/zsh/others, but not all
			alias scup='pushd ~/scripts && git pull && popd' || true
		elif hasCmd bash ; then
			alias scup="bash -c 'pushd ~/scripts && git pull && popd'" || true
		fi
	fi
fi
hasCmd man && [[ "$COLUMNS" -gt 120 ]] && export MANWIDTH=120 || true
test -n $currShell && test -f ~/scripts/showAppVersions.sh && alias sav="$currShell ~/scripts/showAppVersions.sh" || true
case $platform in
	Linux|MINGW*|MSYS*|CYGWIN*)
		alias ll='ls -AlFhv --group-directories-first'
		alias l='ls -AFv --group-directories-first'
		hasCmd journalctl && alias cj="${sudoCmd}journalctl --vacuum-time=1d" || true
		# ???
		#alias reboot="${sudoCmd}reboot --reboot"
		#alias shutdown="${sudoCmd}halt --poweroff --force --no-wall"
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
	OpenBSD|NetBSD|DragonFly)
		# OpenBSD/NetBSD don't support colors ??
		if [[ "$platform" == "DragonFly" ]]; then
			alias ls='ls -G'
		fi
		alias ll='ls -AlFh'
		alias l='ls -AF'
		;;
esac

if [[ "$platform" != "Darwin" ]] && hasCmd apt; then	# macOs (at least version i have) has some java app called apt; don't know what it is
	alias aptr="${sudoCmd}apt update"
	alias aptul='apt list --upgradable'
	alias aptu="${sudoCmd}apt upgrade --yes"
	alias aptuu="${sudoCmd}apt dist-upgrade"
	alias aptc="${sudoCmd}apt-get autoremove --yes && ${sudoCmd}apt-get autoclean --yes && ${sudoCmd}apt-get clean --yes"
	alias apts='apt-cache search'
	alias aptn='apt show'
	alias apti="${sudoCmd}apt install"
	alias aptx="${sudoCmd}apt remove"	# leaves settings	(leaving off --yes)
	alias aptxx="${sudoCmd}apt purge"	# removes settings too
	alias aptl='apt list --installed'
elif hasCmd dnf; then
	alias aptr="dnf updateinfo --refresh"
	alias aptul="dnf check-update"	# ???
	alias aptu="${sudoCmd}dnf upgrade --assumeyes"
	#alias aptc="${sudoCmd}dnf autoremove --assumeyes --cacheonly && ${sudoCmd}dnf clean all --assumeyes --cacheonly"
	alias aptc="${sudoCmd}dnf autoremove --assumeyes && ${sudoCmd}dnf clean packages --assumeyes --cacheonly"
	#alias aptc="${sudoCmd}dnf autoremove --assumeyes --cacheonly && pkcon refresh force --cache-age -1 && ${sudoCmd}dnf clean all --assumeyes --cacheonly"
	alias apts='dnf search'
	alias aptn='dnf info'
	alias apti="${sudoCmd}dnf install"
	alias aptx="${sudoCmd}dnf remove"	# these both do the same thing
	alias aptxx="${sudoCmd}dnf remove"	# but to keep the same aliases available...
	alias aptl='dnf list --installed'
elif hasCmd zypper; then
	alias aptr="${sudoCmd}zypper refresh" # --force'	# if output is piped into, e.g. grep, it displays a warning about not having a 'stable CLI interface', 'use with caution'; ???
	alias aptul="${sudoCmd}zypper list-updates"		# no idea why this requires sudo now...
	alias aptu="${sudoCmd}zypper update --no-confirm --no-recommends"
	alias aptuu="${sudoCmd}zypper dist-upgrade --no-recommends"	# --no-confirm
	#alias aptc="${sudoCmd}zypper remove --clean-deps && ${sudoCmd}zypper clean --all"
	alias aptc="${sudoCmd}zypper clean" # --all'
	alias apts='zypper search'
	alias aptn='zypper info'
	alias apti="${sudoCmd}zypper install --no-recommends"
	alias aptx="${sudoCmd}zypper remove --clean-deps"
	alias aptxx="${sudoCmd}zypper remove --clean-deps"
	alias aptl='zypper search --installed-only'
	alias zp='zypper'
elif hasCmd pacman; then
	alias aptr="${sudoCmd}pacman -Syy"	# --sync --refresh x 2 to force updae
	alias aptul='pacman --query --upgrades'
	alias aptu="${sudoCmd}pacman --sync --sysupgrade --noconfirm"
	alias aptc="${sudoCmd}pacman --sync --clean --noconfirm"
	alias apts='pacman --sync --search'
	alias aptn='pacman --query --info'
	alias apti="${sudoCmd}pacman --sync"
	alias aptx="${sudoCmd}pacman --remove --recursive"
	alias aptxx="${sudoCmd}pacman --remove --recursive --nosave"
	alias aptl='pacman --query'
	# just to store this somewhere: to list all explicitly installed packages that aren't required by something else:
	#	pacman --query --explicit --unrequired (or pacman -Qet if wanna be lazy)
elif hasCmd apk; then
	alias aptr="${sudoCmd}apk update"
	alias aptul='apk list --upgradable'
	alias aptu="${sudoCmd}apk upgrade --available"
	alias aptc="${sudoCmd}apk cache --purge"	# ???
	alias apts='apk search'
	alias aptn='apk info'		# can add '--all' to dump out all info, but this gets most likely relevant
	alias apti="${sudoCmd}apk add"
	alias aptx="${sudoCmd}apk del"
	alias aptxx="${sudoCmd}apk del"
	alias aptl='apk list --installed'
elif hasCmd eopkg; then
	alias aptr="${sudoCmd}eopkg update-repo"
	alias aptul='eopkg list-upgrades --install-info'
	alias aptu="${sudoCmd}eopkg upgrade --yes-all"
	alias aptc="${sudoCmd}eopkg remove-orphans && ${sudoCmd}eopkg delete-cache"
	alias apts='eopkg search'
	alias aptn='eopkg info'
	alias apti="${sudoCmd}eopkg install"
	alias aptx="${sudoCmd}eopkg remove"
	alias aptxx="${sudoCmd}eopkg remove"
	alias aptl='eopkg list-installed --install-info'
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
	alias aptr="${sudoCmd}pkg update --force"
	alias aptul='pkg upgrade --dry-run'
	alias aptu="${sudoCmd}pkg upgrade --yes"
	alias aptc="${sudoCmd}pkg autoremove --yes && ${sudoCmd}pkg clean --all --yes"
	alias apts='pkg search'
	alias aptn='pkg info --case-insensitive'
	alias apti="${sudoCmd}pkg install"
	alias aptx="${sudoCmd}pkg delete"
	alias aptxx="${sudoCmd}pkg delete"
	alias aptl='pkg info --all'
fi

if hasCmd snap; then
	alias snaptul='snap refresh --list'
	alias snaptr='snap refresh --list'
	alias snaptu="${sudoCmd}snap refresh"
	alias snapts='snap find'
	alias snaptn='snap info'
	alias snapti="${sudoCmd}snap install"
	alias snaptx="${sudoCmd}snap remove"
	alias snaptxx="${sudoCmd}snap remove"
	alias snaptl='snap list'
fi

case $platform in
	Linux|MINGW*|MSYS*|CYGWIN*)
		dfBase='df -TPh --sync'
		if [[ $(readlink $(which df)) =~ "busybox" ]]; then
			dfBase='df -TPh'
		fi
		alias sz="${dfBase} /"
		# can't use which or type for sbin stuff on openSuse:
		if [[ -x /usr/bin/btrfs || -x /usr/sbin/btrfs ]]; then
			alias defrag="${sudoCmd}btrfs filesystem defrag -czstd -rv /"
			if [[ -x /usr/bin/compsize || -x /usr/sbin/compsize ]]; then
				alias sz="${dfBase} /; echo; ${sudoCmd}compsize -x /"
			fi
		fi
		alias szz="${dfBase} --type=ext2 --type=ext3 --type=ext4 --type=btrfs --type=zfs --type=vfat --type=ntfs"
		alias sza=$dfBase
		unset dfBase
		;;
	Darwin)
		alias sz='df -hY /'
		alias szz='df -hY -T apfs,hfs,smbfs,ntfs,vfat'
		alias sza='df -hlY'
		;;
	FreeBSD|DragonFly)
		alias sz='df -TPh /'
		alias szz='df -TPh -t ext2,ext3,ext4,btrfs,zfs,ufs,hammer1,hammer2,vfat,msdosfs,ntfs,apfs,hfs,smbfs'
		alias sza='df -TPh'
		;;
	OpenBSD|NetBSD)
		alias sz='df -hl /'
		alias szz='df -h -t ext2,ext3,ext4,btrfs,zfs,ffs,vfat,msdosfs,ntfs,apfs,hfs,smbfs'
		alias sza='df -h'
		;;
esac

if [[ "$platform" == "Linux" || "$platform" =~ "BSD" || "$platform" == "DragonFly" ]]; then
	if hasCmd python3 && [[ -f ~/scripts/zeroLinuxFreeSpace.py ]]; then
		alias zx="${sudoCmd}python3 ~/scripts/zeroLinuxFreeSpace.py"
	elif hasCmd pwsh && [[ -f ~/scripts/zeroLinuxFreeSpace.ps1 ]]; then
		alias zx="${sudoCmd}$(which pwsh) -f ~/scripts/zeroLinuxFreeSpace.ps1"
	fi
fi

hasCmd nano && alias nano='nano -lLA -T 4' || true

# default prompt in case oh-my-posh (below) isn't installed
case $currShell in
	bash) PS1='\n\e[36m\s v\v \e[95m\u@\h \e[33m\t \e[92m\w\n\e[32mWHAT?!? \$\e[0m ' ;;
	zsh) PS1=$'\n\e[36mzsh \e[95m%n@%m \e[33m%* \e[92m%~\n\e[32mWHAT?!? %(!.#.$)\e[0m ' ;;	# can use named colors with %F but they're limited
	ash) PS1='\n\e[36mash \e[95m\u@\h \e[33m\t \e[92m\w\n\e[32mWHAT?!? \$\e[0m ' ;;
esac

if hasCmd oh-my-posh && test -n $currShell ; then
	eval "$(oh-my-posh init $currShell --config ~/scripts/ack.omp.linux.toml)"
	alias omp='oh-my-posh'
	if hasCmd python3; then
		alias ompu='python3 ~/scripts/installOhMyPosh.py'
	else
		alias ompu='bash ~/scripts/installOhMyPosh.sh'
	fi
fi

unset platform currShell sudoCmd