#!env bash
if [[ -n "${theScript:=${ZSH_SCRIPT:-$BASH_SOURCE[0]}}" ]]; then
	if [[ "${theScript: -3}" == "[0]" ]]; then theScript=${theScript:0:-3}; fi	# freaking macpOS
	scriptRoot=$(dirname $(realpath $theScript))
	unset theScript
fi

has() { which "$1" >/dev/null 2>/dev/null && [[ ! $(which "$1") =~ ^/mnt/[[:alpha:]]/.+ ]]; }	# filter out WSL paths

echo
echo "\$0 = |$0|"
echo "\$SHELL = |$SHELL|"
has readlink && echo "\"readlink /proc/\$\$/exe\" = |$(readlink -f /proc/$$/exe)|" || echo '"readlink /proc/$$/exe" = |<n/a>|'
has sh && has realpath && echo "$(which sh) = |$(realpath $(which sh))|" || echo 'sh = |<n/a>|'

echo
echo "\$TERM            = |$TERM|"
echo "\$COLORTERM       = |$COLORTERM|"
echo "\$BASH            = |$BASH|"
echo "\$BASH_VERSION    = |$BASH_VERSION|"
echo "\$BASH_SOURCE     = |$BASH_SOURCE|"
echo "\$ZSH_NAME        = |$ZSH_NAME|"
echo "\$ZSH_VERSION     = |$ZSH_VERSION|"
echo "\$ZSH_SCRIPT      = |$ZSH_SCRIPT|"
echo "\$VENDOR          = |$VENDOR|"
echo "\$HOSTNAME        = |$HOSTNAME|"
echo "\$HOSTTYPE        = |$HOSTTYPE|"
echo "\$CPU             = |$CPU|"
echo "\$CPUTYPE         = |$CPUTYPE|"
echo "\$MACHTYPE        = |$MACHTYPE|"
echo "\$OSTYPE          = |$OSTYPE|"
echo "\$LANG            = |$LANG|"
echo "\$WSL_DISTRO_NAME = |$WSL_DISTRO_NAME|"

if [[ -f "$scriptRoot/showUnameInfo.sh" ]]; then
	echo
	echo 'uname:'
	source $scriptRoot/showUnameInfo.sh
fi
echo
# for future me: can do multiple sed subs by separating with a ';' or can specify multiples with '-e' (-e <expr1> -e <expr2>):
has lsb_release && echo "lsb_release = |$(lsb_release -a 2>/dev/null | tr '\t' ' ' | tr '\n' '|' | sed -E 's/\|$//;s/\|/ ¦ /g')|" || echo 'lsb_release = |<n/a>|'

if [[ -f "$scriptRoot/showAppVersions.sh" ]]; then
	echo
	source $scriptRoot/showAppVersions.sh
fi