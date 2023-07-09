#! /usr/bin/sh
if [[ -n "${theScript:=${ZSH_SCRIPT:-$BASH_SOURCE[0]}}" ]]; then
	scriptRoot=$(dirname $(realpath $theScript))
	unset theScript
fi

has() { which "$1" >/dev/null 2>/dev/null && [[ ! $(which "$1") =~ ^/mnt/[[:alpha:]]/.+ ]]; }	# filter out WSL paths

echo
echo "\$0 = |$0|"
echo "\$SHELL = |$SHELL|"
has readlink && echo "\"readlink /proc/\$\$/exe\" = |$(readlink -f /proc/$$/exe)|" || echo '"readlink /proc/$$/exe" = |<n/a>|'
has realpath && test -f /usr/bin/sh && echo "/usr/bin/sh = |$(realpath /usr/bin/sh)|" || echo '/usr/bin/sh = |<n/a>|'

echo
echo "\$TERM = |$TERM|"
echo "\$COLORTERM = |$COLORTERM|"
echo "\$BASH = |$BASH|"
echo "\$BASH_VERSION = |$BASH_VERSION|"
echo "\$BASH_SOURCE = |$BASH_SOURCE|"
echo "\$ZSH_NAME = |$ZSH_NAME|"
echo "\$ZSH_VERSION = |$ZSH_VERSION|"
echo "\$ZSH_SCRIPT = |$ZSH_SCRIPT|"
echo "\$VENDOR = |$VENDOR|"
echo "\$HOSTNAME = |$HOSTNAME|"
echo "\$HOSTTYPE = |$HOSTTYPE|"
echo "\$CPU = |$CPU|"
echo "\$CPUTYPE = |$CPUTYPE|"
echo "\$MACHTYPE = |$MACHTYPE|"
echo "\$OSTYPE = |$OSTYPE|"
echo "\$LANG = |$LANG|"
echo "\$WSL_DISTRO_NAME = |$WSL_DISTRO_NAME|"

echo
# for future me: can do multiple sed subs by separating with a ';' or can specify multiples with '-e' (-e <expr1> -e <expr2>):
has lsb_release && echo "lsb_release = |$(lsb_release -a 2>/dev/null | tr '\t' ' ' | tr '\n' '|' | sed -E 's/\|$//;s/\|/ ¦ /g')|" || echo 'lsb_release = |<n/a>|'
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

if [[ -f "$scriptRoot/showAppVersions.sh" ]]; then
	echo
	source $scriptRoot/showAppVersions.sh
fi