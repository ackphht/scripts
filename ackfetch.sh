#!/bin/bash

# TODO: how do we pass in a flag for the '-a' or '--showAllProps' option?

doItPosh() {
	pwsh -file ~/scripts/ackfetch.ps1
}

doItPython() {
	python3 ~/scripts/ackfetch.py
}

which python3 >/dev/null 2>&1 && doItPython || which pwsh >/dev/null 2>&1 && doItPosh || echo "WARNING: neither powershell nor python were found"