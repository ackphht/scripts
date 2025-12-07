#!/bin/bash

hasCmd() {
	if (command -v "$1" >/dev/null 2>&1); then
		return 0
	else
		return 1
	fi
}
################################
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
################################
if [[ -f /etc/os-release ]]; then
	distro=$(awk -F'=' '/^ID=/ {print $2}' /etc/os-release | tr '[:upper:]' '[:lower:]' | tr -d '"')
elif [[ -f /etc/lsb-release ]]; then	# probably a decent fallback ???
	distro=$(awk -F'=' '/^DISTRIB_ID=/ {print $2}' /etc/lsb-release | tr '[:upper:]' '[:lower:]' | tr -d '"')
else
	distro="unknown"
fi
################################
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

echo "detected platform: $platform"
echo "detected current shell: $currShell"
################################
if hasCmd sudo; then
	sudoCmd='sudo '
else
	sudoCmd=''		# ???????
fi
################################
if [[ "$platform" != "darwin" ]] && hasCmd apt; then	# macOs (at least version i have) has some java app called apt; don't know what it is
	${sudoCmd}apt update
	apti="${sudoCmd}apt install --yes"
	pkgMgr="apt"
elif hasCmd dnf; then
	if hasCmd dnf5; then
		dnf5 advisory summary --refresh
	else
		dnf updateinfo --refresh
	fi
	apti="${sudoCmd}dnf install --assumeyes"
	pkgMgr="dnf"
elif hasCmd zypper; then
	${sudoCmd}zypper refresh
	apti="${sudoCmd}zypper install --no-recommends --no-confirm"
	pkgMgr="zypper"
elif hasCmd pacman; then		# arch-based
	${sudoCmd}pacman --sync --refresh
	apti="${sudoCmd}pacman --sync --noconfirm"
	pkgMgr="pacman"
elif hasCmd apk; then			# alpine
	${sudoCmd}apk update
	apti="${sudoCmd}apk add"
	pkgMgr="apk"
elif hasCmd eopkg; then			# solaris
	${sudoCmd}eopkg update-repo
	apti="${sudoCmd}eopkg install --yes-all"
	pkgMgr="eopkg"
elif hasCmd brew; then
	brew update
	apti='brew install'
	pkgMgr="brew"
elif hasCmd pkg; then			# FreeBSD
	${sudoCmd}pkg update --force
	apti="${sudoCmd}pkg install --yes"
	pkgMgr="pkg"
fi
echo "using '$pkgMgr' as package manager"
################################
mkdir --parents ~/.local/bin
################################
# set up scripts folder:
if [[ -z "$WSL_DISTRO_NAME" ]]; then
	if (! hasCmd git); then
		${apti} git
		if [[ $? -ne 0 ]]; then
			exit 1
		fi
	fi
	if [[ ! -d ~/scripts ]]; then
		git clone https://github.com/ackphht/scripts ~/scripts
	fi
else
	if [[ ! -d ~/scripts ]]; then
		ln -s /mnt/c/Users/$USER/scripts ~/scripts
	fi
fi
if [[ $? -ne 0 ]]; then
	exit 1
fi
################################
# add our stuff to .bashrc
if [[ -f ~/.bashrc ]]; then
	if (! grep -iq "ackShellStuff.sh" ~/.bashrc); then
		echo -e "\n\ntest -r ~/scripts/ackShellStuff.sh && source ~/scripts/ackShellStuff.sh || true" >> ~/.bashrc
	fi
else
	echo "test -r ~/scripts/ackShellStuff.sh && source ~/scripts/ackShellStuff.sh || true" > ~/.bashrc
fi
################################
# add zsh, if not already installed
if (! hasCmd zsh); then
	${apti} zsh
	if [[ $? -ne 0 ]]; then
		exit 1
	fi
fi
# add our .zshrc
if [[ -f ~/.zshrc ]]; then
	if (! grep -iq "ackShellStuff.sh" ~/.zshrc); then
		echo -e "\n\ntest -r ~/scripts/ackShellStuff.sh && source ~/scripts/ackShellStuff.sh || true" >> ~/.zshrc
	fi
else
	ln -s ~/scripts/ack.zshrc ~/.zshrc
fi
#
# should we make zsh the default shell? probably not; should just set it in terminal apps
# chsh -s $(getPath zsh) $USER
#
################################
# try adding some more utils we need/like:
${apti} lsb-release nano jc jq tree 7zip zstd fastfetch #joe
################################
if (! hasCmd python); then		# some already have this; debian based have a package that creates a sumlink; for the rest, make our own
	if [[ "$pkgMgr" = "apt" ]]; then
		${apti} python-is-python3
	else
		ln -s $(which python3) ~/.local/bin/python
	fi
fi
if (! hasCmd py); then		# what python guys say to use on Windows, and ... i kind of like it; easier
	ln -s $(which python3) ~/.local/bin/py
fi
################################
# clean up:
#unset platform currShell sudoCmd apti