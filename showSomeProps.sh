#!env bash

scriptRoot=$(dirname $(realpath ${BASH_SOURCE[0]:-${0}}))
source $scriptRoot/ackShellHelpers.sh

echo
echo "\$0 = |$0|"
echo "\$SHELL = |$SHELL|"
hasCmd readlink && echo "\"readlink /proc/\$\$/exe\" = |$(readlink -f /proc/$$/exe)|" || echo '"readlink /proc/$$/exe" = |<n/a>|'
hasCmd sh && hasCmd realpath && echo "$(which sh) = |$(realpath $(which sh))|" || echo 'sh = |<n/a>|'

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
hasCmd lsb_release && echo "lsb_release = |$(lsb_release -a 2>/dev/null | tr '\t' ' ' | tr '\n' '|' | sed -E 's/\|$//;s/\|/ ¦ /g')|" || echo 'lsb_release = |<n/a>|'

if [[ -f "$scriptRoot/showAppVersions.sh" ]]; then
	echo
	source $scriptRoot/showAppVersions.sh
fi