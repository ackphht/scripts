#!env bash

scriptRoot=$(dirname $(realpath ${BASH_SOURCE[0]:-${0}}))
source $scriptRoot/ackShellHelpers.sh

if hasCmd uname; then
	# macOS doesn't like the '--xxx' arguments for uname, so have to use short ones:
	echo "kernel-name [-s]       = |$(uname -s)|"
	echo "kernel-release [-r]    = |$(uname -r)|"
	echo "kernel-version [-v]    = |$(uname -v)|"
	echo "operating system [-o]  = |$(uname -o 2>/dev/null || echo '<n/a>')|"
	echo "machine [-m]           = |$(uname -m)|"	# this one is actually the OS's bitness (e.g. on 32 bit OS on 64 bit processor, this will say 'i686', while 64 bit OS says 'x86_64')
	echo "processor [-p]         = |$(uname -p 2>/dev/null || echo '<n/a>')|"
	echo "hardware-platform [-i] = |$(uname -i 2>/dev/null || echo '<n/a>')|"
else
	echo '|<n/a>|'
fi