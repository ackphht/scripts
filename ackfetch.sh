#!/bin/bash

showAll=''
noColors=''
while [ $# -ne 0 ]; do
	name="$1"
	case "$name" in
		-a|--show[Aa]ll)
			showAll="-a"
			;;
		-n|--no[Cc]olors)
			noColors="-n"
			;;
		-?|--?|-h|--help|-[Hh]elp)
			script_name="$(basename "$0")"
			echo "show system info"
			echo "Usage: $script_name [-a|--showAll] [-n|--noFormatting]"
			echo "       $script_name -h|-?|--help"
			echo ""
			echo "$script_name dumps out some system details, kind of like neofetch or screenfetch"
			echo ""
			echo "Options:"
			echo "  -a,--showAll              show all properties; default is a short list"
			echo "  -n,--noColors             no colors"
			echo "  -?,--?,-h,--help,-Help    shows this help message"
			echo ""
			exit 0
			;;
		*)
			echo ""
			echo "Unknown argument \"$name\""
			exit 1
			;;
	esac
	shift
done

doItPosh() {
	pwsh -file ~/scripts/ackfetch.ps1 $showAll
}

doItPython() {
	python3 ~/scripts/ackfetch.py $showAll $noColors
}

(which python3 >/dev/null 2>&1 && doItPython) || (which pwsh >/dev/null 2>&1 && doItPosh) || echo "WARNING: neither powershell nor python were found"