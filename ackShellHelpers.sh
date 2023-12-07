#!/bin/bash

getPath() {
	# want this to work for builtins, too, and which and type are inconsistent across shells,
	# but command -v seems to work across bash, zsh and ash, at least, maybe others, too:
	echo "$(command -v "$1" 2>/dev/null)"
}

hasCmd() {
	p=$(getPath "$1")
	if [[ -n "$p" ]]; then
		# fail if looks like WSL or MinGW path:
		if [[ $p =~ ^/mnt/[[:alpha:]]/.+ || $p =~ ^/[[:alpha:]]/.+ ]]; then
			return 2
		fi
		return 0
	else
		return 1
	fi
}

ackVerifyFolder() {
	if [[ ! -d $1 ]]; then
		#echo "    creating folder '$1'"
		mkdir -p $1
	fi
}