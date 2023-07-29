#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$false)]
param(
	[Parameter(Mandatory=$false)] [string] $moduleName,
	[Parameter(Mandatory=$false)] [ValidateSet('Basic', 'Detailed', 'Full')] [string] $helpLevel = 'Detailed'
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

if (-not (Get-Module -Name $moduleName -ListAvailable -ErrorAction SilentlyContinue)) {
	Write-Error "module `"$moduleName`" not found"
	return
}

$divider = [string]::new('#', 80)
function _writeDivider {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param([string] $msg)
	Write-Output $divider
	if ($msg) {
		Write-Output $msg
		Write-Output $divider
	}
}

_writeDivider -msg 'Module Details'
Get-Module -Name $moduleName -ListAvailable |
	Select-Object -First 1 <# should we sort by version or something? Get-Command below only shows one, how does it decide which one? #> |
	Format-List -Property Name,Version,Author,CompanyName,Copyright,ModuleBase,Path,Description,ProjectUri,ModuleType

_writeDivider -msg 'Module Exports'
Get-Command -Module $moduleName | Format-Table -Property @{Label='CommandType';Expression={$_.CommandType};Alignment='Left'},@{Label='Name';Expression={$_.Name};Alignment='Left'}

foreach ($cmd in (Get-Command -Module $moduleName)) {
	_writeDivider -msg $cmd.Name
	switch ($helpLevel) {
		'Basic' {
			Get-Help -Name (Join-Path $cmd.ModuleName $cmd.Name) | Out-String
			break
		}
		'Detailed' {
			Get-Help -Name (Join-Path $cmd.ModuleName $cmd.Name) -Detailed | Out-String
			break
		}
		'Full' {
			Get-Help -Name (Join-Path $cmd.ModuleName $cmd.Name) -Full | Out-String
			break
		}
	}
}