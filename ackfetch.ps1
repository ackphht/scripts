#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

. $PSScriptRoot/populateSystemData.ps1
Get-OSDetails |
	Select-Object Id,Distributor,Description,Codename,Release,KernelVersion |
	Format-List
