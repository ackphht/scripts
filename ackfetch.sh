#!/bin/bash

doIt() {
	#pwsh -c "& { . ~/scripts/populateSystemData.ps1; \
	#				Get-OSDetails | \
	#					Select-Object Id,Distributor,Description,Codename,Release,KernelVersion | \
	#					Format-List }"
	pwsh -file ~/scripts/ackfetch.ps1
}

which pwsh >/dev/null 2>&1 && doIt || echo "WARNING: powershell not found"