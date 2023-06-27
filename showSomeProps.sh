##!/bin/bash

has() { type -p "$1" >/dev/null; }

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
if has lsb_release; then
	echo "lsb_release = |$(lsb_release -a | tr '\t' ' ' | tr '\n' '|' | sed -E 's/\|$//' | sed -E 's/\|/ ¦ /g')|"
else
	echo 'lsb_release = |<n/a>|'
fi
if has python3; then
	echo "python3 = |$(python3 --version)|"
else
	echo 'python3 = |<n/a>|'
fi
if has git; then
	echo "git = |$(git --version)|"
else
	echo 'git = |<n/a>|'
fi
