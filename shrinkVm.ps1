#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules 'Hyper-V'

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)] [string] $vhd
)

$ErrorActionPreference = 'Stop'	#'Continue'
Set-StrictMode -Version Latest

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [string] $vhd
	)

	Optimize-VHD -Mode Full -Path $vhd
}

#==============================
Main -vhd $vhd
#==============================
