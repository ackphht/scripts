#!/bin/sh

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
has python3 && echo "python3 = |$(python3 --version)|" || echo 'python3 = |<n/a>|'
has git     && echo "git     = |$(git --version)|" || echo 'git     = |<n/a>|'
has snap    && echo "snap    = |$(snap --version | head --lines 1 | awk '{print $2}')|" || echo "snap    = |<n/a>|"
has java    && echo "java    = |$(java --version | head --lines 1)|" || echo 'java    = |<n/a>|'
has perl    && echo "perl    = |$(perl --version | head --lines 2 | tail --lines 1)|" || echo 'perl    = |<n/a>|'
has ruby    && echo "ruby    = |$(ruby --version)|" || echo "ruby    = |<n/a>|"
has go      && echo "go      = |$(go version)|" || echo "go      = |<n/a>|"