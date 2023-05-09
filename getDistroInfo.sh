#!/bin/bash
scriptRoot=$(realpath $(dirname ${BASH_SOURCE[0]}))
targetFolder="$HOME/distInfo"

if [ ! -d $targetFolder ]; then
	mkdir -p $targetFolder
else
	rm -frd $targetFolder/*
fi

cd $targetFolder

cp -Lr /etc/*-release .		# os-release, lsb-release, manjaro-release, redhat-release, etc
test -f /etc/mime.types && cp /etc/mime.types .
test -d /etc/lsb-release.d && mkdir ./lsb-release.d && cp /etc/lsb-release.d/* ./lsb-release.d/
test -f /etc/debian_version && cp /etc/debian_version .
test -f /etc/SUSE-brand && cp /etc/SUSE-brand .
test -f /etc/linuxmint/info && cp /etc/linuxmint/info linuxmint_info
test -f /etc/mx-version && cp /etc/mx-version .

# sysctl needs sudo to access everything it wants, but also on some OSes (e.g. opensuse) need sudo just to see it:
sudo which sysctl >/dev/null 2>&1 && sudo sysctl -a | sort --ignore-case > sysctl.log || echo "WARNING: sysctl not found"
which lsb_release >/dev/null 2>&1 && lsb_release -a > lsb_release.log 2>/dev/null || echo "WARNING: lsb_release not found"
which screenfetch >/dev/null 2>&1 && screenfetch -N > screenfetch.log 2>/dev/null || echo "WARNING: screenfetch not found"
which neofetch >/dev/null 2>&1 && neofetch --stdout > neofetch.log 2>/dev/null || echo "WARNING: neofetch not found"

test -f $scriptRoot/showSomeProps.py && python3 $scriptRoot/showSomeProps.py > pythonProperties.log

which pwsh >/dev/null 2>&1 && test -f $scriptRoot/getSystemInformation.ps1 && \
	pwsh -command "& { $scriptRoot/getSystemInformation.ps1 | Out-File getSystemInformation.log -Width 4096 }" && \
	pwsh -command "& { $scriptRoot/getSystemInformation.ps1 -asCsv }"

# for macOS:
which system_profiler >/dev/null 2>&1 && system_profiler -json SPHardwareDataType SPSoftwareDataType SPMemoryDataType SPStorageDataType SPNVMeDataType > system_profiler.json && \
	system_profiler SPHardwareDataType SPSoftwareDataType SPMemoryDataType SPStorageDataType SPNVMeDataType > system_profiler.log
which sw_vers >/dev/null 2>&1 && sw_vers > sw_vers.log || true

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

env | sort --ignore-case > envVars_env.log
#set > envVars_set.txt	# TODO?: is there a way to run this from lower shell level ??
echo
echo "you'll need to get 'set' output outside the script to get proper value; run the following:"
echo "    set > $targetFolder/envVars_set.log"
echo
