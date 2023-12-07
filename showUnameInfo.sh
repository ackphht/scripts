#!env bash
scriptRoot=$(dirname $(realpath ${ZSH_SCRIPT[0]:-${ZSH_SCRIPT:-${BASH_SOURCE[0]:-${0}}}}))		# ffs
source $scriptRoot/ackShellHelpers.sh

if hasCmd uname >/dev/null 2>/dev/null; then
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