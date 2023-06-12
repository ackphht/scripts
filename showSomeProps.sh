##!/bin/bash

has() { type -p "$1" >/dev/null; }

echo
echo \$0 = \|$0\|
echo \$SHELL = \|$SHELL\|
echo \$TERM = \|$TERM\|
echo \$BASH = \|$BASH\|
echo \$BASH_VERSION = \|$BASH_VERSION\|
echo \$ZSH = \|$ZSH\|
echo \$ZSH_NAME = \|$ZSH_NAME\|
echo \$ZSH_VERSION = \|$ZSH_VERSION\|
echo \$HOSTNAME = \|$HOSTNAME\|
echo \$HOSTTYPE = \|$HOSTTYPE\|
echo \$MACHTYPE = \|$MACHTYPE\|
echo \$OSTYPE = \|$OSTYPE\|
if has readlink; then
	echo \"readlink /proc/\$\$/exe\" = \|$(readlink -f /proc/$$/exe)\|
else
	echo \"readlink /proc/\$\$/exe\" = \<n/a\>
fi
if has uname; then
	echo uname: kernel-name = \|$(uname -s)\|
	echo uname: kernel-release = \|$(uname -r)\|
	echo uname: kernel-version = \|$(uname -v)\|
	echo uname: operating system = \|$(uname -o)\|
	echo uname: machine = \|$(uname -m)\|
	echo uname: processor = \|$(uname -p 2>/dev/null)\|
	echo uname: hardware-platform = \|$(uname -i 2>/dev/null)\|
else
	echo uname = \<n/a\>
fi
if has lsb_release; then
	echo 'lsb_release = |'
	lsb_release -a 2>/dev/null
	echo '|'
else
	echo lsb_release = \<n/a\>
fi
