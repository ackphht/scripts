#!/bin/sh

has() { which "$1" >/dev/null 2>/dev/null && [[ ! $(which "$1") =~ ^/mnt/[[:alpha:]]/.+ ]] }	# filter out WSL paths

echo
echo "\$0 = |$0|"
echo "\$SHELL = |$SHELL|"
echo "\$TERM = |$TERM|"
echo "\$COLORTERM = |$COLORTERM|"
echo "\$BASH = |$BASH|"
echo "\$BASH_VERSION = |$BASH_VERSION|"
echo "\$ZSH = |$ZSH|"
echo "\$ZSH_NAME = |$ZSH_NAME|"
echo "\$ZSH_VERSION = |$ZSH_VERSION|"
echo "\$VENDOR = |$VENDOR|"
echo "\$HOSTNAME = |$HOSTNAME|"
echo "\$HOSTTYPE = |$HOSTTYPE|"
echo "\$CPUTYPE = |$CPUTYPE|"
echo "\$MACHTYPE = |$MACHTYPE|"
echo "\$OSTYPE = |$OSTYPE|"
echo "\$LANG = |$LANG|"
if has readlink; then
	echo "\"readlink /proc/\$\$/exe\" = |$(readlink -f /proc/$$/exe)|"
else
	echo '"readlink /proc/$$/exe" = |<n/a>|'
fi
if has uname; then
	echo "uname: kernel-name [-s] = |$(uname -s)|"
	echo "uname: kernel-release [-r] = |$(uname -r)|"
	echo "uname: kernel-version [-v] = |$(uname -v)|"
	echo "uname: operating system [-o] = |$(uname -o)|"
	echo "uname: machine [-m] = |$(uname -m)|"
	echo "uname: processor [-p] = |$(uname -p 2>/dev/null || echo '<n/a>')|"
	echo "uname: hardware-platform [-i] = |$(uname -i 2>/dev/null || echo '<n/a>')|"
else
	echo 'uname = |<n/a>|'
fi
has lsb_release && echo "lsb_release = |$(lsb_release -a 2>/dev/null | tr '\t' ' ' | tr '\n' '|' | sed -E 's/\|$//' | sed -E 's/\|/ ¦ /g')|" || echo 'lsb_release = |<n/a>|'
echo
has python3 && echo "python3 = |$(python3 --version | awk '{print $2}')|" || echo 'python3 = |<n/a>|'
has git     && echo "git     = |$(git --version | awk '{print $3}')|" || echo 'git     = |<n/a>|'
has snap    && echo "snap    = |$(snap --version | head --lines 1 | awk '{print $2}')|" || echo "snap    = |<n/a>|"
has flatpak && echo "flatpak = |$(flatpak --version | awk '{print $2}')|" || echo "flatpak = |<n/a>|"
has java    && echo "java    = |$(java --version | head --lines 1)|" || echo 'java    = |<n/a>|'	# show whole version line for this one
has perl    && echo "perl    = |$(perl --version | head --lines 2 | tail --lines 1 | sed -E 's/^(.+)\((v[\.0-9]+)\)(.+)$/\2/')|" || echo 'perl    = |<n/a>|'
has ruby    && echo "ruby    = |$(ruby --version | awk '{print $2}')|" || echo "ruby    = |<n/a>|"
has go      && echo "go      = |$(go version | awk '{print $3}')|" || echo "go      = |<n/a>|"
has pwsh    && echo "pwsh    = |$(pwsh --version | awk '{print $2}')|" || echo "pwsh    = |<n/a>|"
has code    && echo "code    = |$(code --version | head --lines 1)|" || echo "code    = |<n/a>|"