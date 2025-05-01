#!/bin/bash

scriptRoot=$(dirname $(realpath ${BASH_SOURCE[0]:-${0}}))
source $scriptRoot/ackShellHelpers.sh

platform=$(uname -s)

hasCmd apt-get && echo "apt-get = |$(apt-get --version | head -n 1 | awk '{print $2}')|" || true
hasCmd zypper  && echo "zypper  = |$(zypper --version | awk '{print $2}')|" || true
if hasCmd dnf5; then
	echo "dnf     = |$(dnf5 --version | head -n 1 | awk '{print $3}')|"
elif hasCmd dnf; then
	echo "dnf     = |$(dnf --version | head -n 1 | awk '{print $1}')|"
fi
hasCmd pacman  && echo "pacman  = |$(pacman --version | head -n 2 | tail -n 1 | awk '{print $3}' | sed -E 's/^v//')|" || true
hasCmd eopkg   && echo "eopkg   = |$(eopkg --version | awk '{print $2}')|" || true
hasCmd brew    && echo "brew    = |$(brew --version | awk '{print $2}')|" || true
hasCmd apk     && echo "apk     = |$(apk --version | awk '{print $2}' | sed -E 's/,$//')|" || true
hasCmd dpkg    && echo "dpkg    = |$(dpkg --version | head -n 1 | awk '{print $7}')|" || true
hasCmd rpm     && echo "rpm     = |$(rpm --version | awk '{print $3}')|" || true
hasCmd pkcon   && echo "pkcon   = |$(pkcon --version | awk '{print $1}')|" || true
hasCmd busybox && echo "busybox = |$(busybox | head -n 1 | awk '{print $2}')|" || true
hasCmd bash    && echo "bash    = |$(bash --version | head -n 1 | awk '{print $4}')|" ||	echo 'bash    = |<n/a>|'
hasCmd zsh     && echo "zsh     = |$(zsh --version | awk '{print $2}')|" ||					echo 'zsh     = |<n/a>|'
hasCmd python3 && echo "python3 = |$(python3 --version | awk '{print $2}')|" ||				echo 'python3 = |<n/a>|'
hasCmd git     && echo "git     = |$(git --version | awk '{print $3}')|" ||					echo 'git     = |<n/a>|'
hasCmd snap    && echo "snap    = |$(snap --version | head -n 1 | awk '{print $2}')|" ||	echo "snap    = |<n/a>|"
hasCmd flatpak && echo "flatpak = |$(flatpak --version | awk '{print $2}')|" ||				echo "flatpak = |<n/a>|"
hasCmd java    && echo "java    = |$(java --version 2>/dev/null | head -n 1)|" ||			echo 'java    = |<n/a>|'	# show whole version line for this one
hasCmd perl    && echo "perl    = |$(perl --version 2>/dev/null | head -n 2 | tail -n 1 | sed -E 's/^(.+)\(v([\.0-9]+)\)(.+)$/\2/')|" || echo 'perl    = |<n/a>|'
hasCmd ruby    && echo "ruby    = |$(ruby --version | awk '{print $2}')|" ||				echo "ruby    = |<n/a>|"
hasCmd go      && echo "go      = |$(go version | awk '{print $3}' | sed -E 's/^go//')|" ||	echo "go      = |<n/a>|"
hasCmd rustc   && echo "rustc   = |$(rustc --version | awk '{print $2}')|" ||					echo "rustc   = |<n/a>|"
hasCmd pwsh    && echo "pwsh    = |$(pwsh --version | awk '{print $2}')|" ||				echo "pwsh    = |<n/a>|"
hasCmd code    && echo "code    = |$(code --version | head -n 1)|" ||						echo "code    = |<n/a>|"