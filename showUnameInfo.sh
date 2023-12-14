#!env bash

scriptRoot=$(dirname $(realpath ${BASH_SOURCE[0]:-${0}}))
source $scriptRoot/ackShellHelpers.sh

if hasCmd uname; then
	# macOS doesn't like the '--xxx' arguments for uname, so have to use short ones:
	echo "kernel-name [-s]       = |$(uname -s)|"
	echo "kernel-release [-r]    = |$(uname -r)|"
	echo "kernel-version [-v]    = |$(uname -v)|"
	echo "operating system [-o]  = |$(uname -o)|"
	echo "machine [-m]           = |$(uname -m)|"
	echo "processor [-p]         = |$(uname -p 2>/dev/null || echo '<n/a>')|"
	echo "hardware-platform [-i] = |$(uname -i 2>/dev/null || echo '<n/a>')|"
else
	echo '|<n/a>|'
fi