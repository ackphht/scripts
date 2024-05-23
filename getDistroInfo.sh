#!/bin/bash
scriptRoot=$(dirname $(realpath ${BASH_SOURCE[0]:-${0}}))
source $scriptRoot/ackShellHelpers.sh

targetFolder="$HOME/distInfo"

if [ ! -d $targetFolder ]; then
	mkdir -p $targetFolder
else
	rm -frd $targetFolder/*
fi

cd $targetFolder

ls /etc/*-release 1>/dev/null 2>&1 && cp -Lr /etc/*-release . || true		# os-release, lsb-release, manjaro-release, redhat-release, etc
ls /etc/*-version 1>/dev/null 2>&1 && cp -Lr /etc/*-version . || true		# some use this instead of *-release (e.g. MX, Slackware)
test -f /etc/mime.types && cp /etc/mime.types .
test -d /etc/lsb-release.d && mkdir ./lsb-release.d && cp /etc/lsb-release.d/* ./lsb-release.d/
test -f /etc/debian_version && cp /etc/debian_version .
test -f /etc/SUSE-brand && cp /etc/SUSE-brand .
test -f /etc/linuxmint/info && cp /etc/linuxmint/info linuxmint_info
test -f /etc/issue && cp /etc/issue .

# sysctl needs sudo to access everything it wants, but also on some OSes (e.g. opensuse) need sudo just to see it:
sudo which sysctl >/dev/null 2>&1 && sudo sysctl -a | sort -f > sysctl.log || echo "WARNING: sysctl not found"
if [[ $(uname -s) == "Linux" ]]; then
	hasCmd lsb_release && lsb_release -a > lsb_release.log 2>/dev/null || echo "WARNING: lsb_release not found"
fi
hasCmd screenfetch && screenfetch -N > screenfetch.log 2>/dev/null || echo "WARNING: screenfetch not found"
hasCmd neofetch && neofetch --stdout > neofetch.log 2>/dev/null || echo "WARNING: neofetch not found"
hasCmd fastfetch && fastfetch > fastfetch.log 2>/dev/null || true
hasCmd python3 && test -f $scriptRoot/ackfetch.py && python3 $scriptRoot/ackfetch.py -an > ackfetch.log 2>/dev/null || true
if hasCmd hostnamectl ; then
	# two formats, slightly different info, only supported if systemd used, and json format not always supported:
	if hostnamectl > hostnamectl.log 2>&1; then
		if ! hostnamectl --json=pretty > hostnamectl.json 2>&1 ; then
			rm --force hostnamectl.json
		fi
	else
		rm --force hostnamectl.log
	fi
else
	echo "WARNING: hostnamectl not found"
fi
hasCmd inxi && inxi -Fr > inxi.log 2>/dev/null || true

hasCmd bash && test -f $scriptRoot/showAppVersions.sh && bash $scriptRoot/showAppVersions.sh > showAppVersions.log
hasCmd python3 && test -f $scriptRoot/showSomeProps.py && python3 $scriptRoot/showSomeProps.py > pythonProperties.log

hasCmd pwsh && test -f $scriptRoot/getSystemInformation.ps1 && pwsh -command "& { $scriptRoot/getSystemInformation.ps1 -asText }"

# for macOS:
hasCmd system_profiler && system_profiler -json SPHardwareDataType SPSoftwareDataType SPMemoryDataType SPStorageDataType SPNVMeDataType > system_profiler.json && \
	system_profiler SPHardwareDataType SPSoftwareDataType SPMemoryDataType SPStorageDataType SPNVMeDataType > system_profiler.log
hasCmd sw_vers && sw_vers > sw_vers.log || true
#uname -a > uname.txt
echo -n '' > uname.log
if hasCmd uname; then
	source $scriptRoot/showUnameInfo.sh > uname.log
fi

env | sort -f > envVars_env.log
#set > envVars_set.txt	# TODO?: is there a way to run this from lower shell level ??
echo
echo "you'll need to get 'set' output outside the script to get proper value; run the following:"
echo "    set > $targetFolder/envVars_set.log"
echo
