#!/bin/bash
scriptRoot=$(realpath $(dirname ${BASH_SOURCE[0]}))
targetFolder="$HOME/distInfo"

if [ ! -d $targetFolder ]; then
	mkdir -p $targetFolder
else
	rm -f $targetFolder/*
fi

cd $targetFolder

test -f /etc/os-release && cp /etc/os-release .
test -f /etc/debian_version && cp /etc/debian_version .
test -f /etc/mime.types && cp /etc/mime.types .
test -f /etc/lsb-release && cp /etc/lsb-release .
test -f /etc/fedora-release && cp /etc/fedora-release .
test -f /etc/SUSE-brand && cp /etc/SUSE-brand .
test -f /etc/manjaro-release && cp /etc/manjaro-release .
test -f /etc/linuxmint/info && cp /etc/linuxmint/info .

# sysctl needs sudo to access everything it wants, but also on some OSes (e.g. opensuse) need sudo just to see it:
sudo which sysctl > /dev/null 2>&1 && sudo sysctl -a | sort --ignore-case > sysctl.txt || echo "WARNING: sysctl not found"
which lsb_release > /dev/null 2>&1 && lsb_release -a > lsb_release.txt 2>/dev/null || echo "WARNING: lsb_release not found"
which screenfetch > /dev/null 2>&1 && screenfetch -N > screenfetch.txt 2>/dev/null || echo "WARNING: screenfetch not found"
which neofetch > /dev/null 2>&1 && neofetch --stdout > neofetch.txt 2>/dev/null || echo "WARNING: neofetch not found"

test -f $scriptRoot/showSomeProps.py && python3 $scriptRoot/showSomeProps.py > showSomeProps.py.log

which pwsh > /dev/null 2>&1 && test -f $scriptRoot/getSystemInformation.ps1 && pwsh -command "& { $scriptRoot/getSystemInformation.ps1 | Out-File getSystemInformation.log }"

#uname -a > uname.txt
echo -n '' > uname.log
# macOS doesn't like the '--xxx' arguments for uname, but want those for the names, so parse out a name/value pair thingy:
while read -d , kv; do
	IFS=: read name opt <<< $kv
	val=$(uname -${opt} 2>&1)
	if [[ $? == 0 ]]; then
		echo "${name} = ${val}" >> uname.log
	fi
done <<< 'kernel-name:s,kernel-release:r,kernel-version:v,machine:m,processor:p,hardware-platform:i,operating-system:o,'

env | sort --ignore-case > envVars_env.txt
#set > envVars_set.txt	# TODO?: is there a way to run this from lower shell level ??
echo
echo "you'll need to get 'set' output outside the script to get proper value; run the following:"
echo "    set > $targetFolder/envVars_set.txt"
echo
