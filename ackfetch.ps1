#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] [Alias('all')] $showAllProps
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

if ($showAllProps) {
	$propList = @('*')
} else {
	$propList = @('Description','Id','Distributor','Codename','Release','KernelVersion')
}

Import-Module -Name $PSScriptRoot/populateSystemData
Get-OSDetails |
	Select-Object -Property $propList |
	Format-List
