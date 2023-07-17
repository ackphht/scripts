#!/bin/bash

_has() { which "$1" >/dev/null 2>/dev/null && [[ ! $(which "$1") =~ ^/mnt/[[:alpha:]]/.+ ]]; }	# filter out WSL paths

_has bash    && echo "bash    = |$(bash --version | head --lines 1 | awk '{print $4}')|" ||	echo 'bash    = |<n/a>|'
_has zsh     && echo "zsh     = |$(zsh --version | awk '{print $2}')|" ||					echo 'zsh     = |<n/a>|'
_has python3 && echo "python3 = |$(python3 --version | awk '{print $2}')|" ||				echo 'python3 = |<n/a>|'
_has git     && echo "git     = |$(git --version | awk '{print $3}')|" ||					echo 'git     = |<n/a>|'
_has snap    && echo "snap    = |$(snap --version | head --lines 1 | awk '{print $2}')|" ||	echo "snap    = |<n/a>|"
_has flatpak && echo "flatpak = |$(flatpak --version | awk '{print $2}')|" ||				echo "flatpak = |<n/a>|"
_has java    && echo "java    = |$(java --version 2>/dev/null | head --lines 1)|" ||		echo 'java    = |<n/a>|'	# show whole version line for this one
_has perl    && echo "perl    = |$(perl --version | head --lines 2 | tail --lines 1 | sed -E 's/^(.+)\((v[\.0-9]+)\)(.+)$/\2/')|" || echo 'perl    = |<n/a>|'
_has ruby    && echo "ruby    = |$(ruby --version | awk '{print $2}')|" ||					echo "ruby    = |<n/a>|"
_has go      && echo "go      = |$(go version | awk '{print $3}')|" ||						echo "go      = |<n/a>|"
_has pwsh    && echo "pwsh    = |$(pwsh --version | awk '{print $2}')|" ||					echo "pwsh    = |<n/a>|"
_has code    && echo "code    = |$(code --version | head --lines 1)|" ||					echo "code    = |<n/a>|"