<# Get-Help about_Requires or https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_requires #>
<# #Requires -RunAsAdministrator #>
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $outputFolder = ''
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'
#[System.Environment]::CurrentDirectory = (Get-Location).Path

#
# figure out where we're putting stuff:
#
#if (-not $outputFolder) { $outputFolder = Join-Path ([System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::DesktopDirectory)) 'sysInfo' }
if (-not $outputFolder) { $outputFolder = Join-Path ([System.IO.Path]::GetTempPath()) 'sysInfo' }
if (-not (Test-Path -Path $outputFolder -PathType Container)) { New-Item -ItemType Directory -Path $outputFolder -Force | Out-Null }
Invoke-Item -Path $outputFolder

#
# start gathering
#
& $PSScriptRoot/getSystemInformation.ps1 -asText -outputFolder $outputFolder
& $PSScriptRoot/getComputerInfo.ps1 -outputTable | Out-File -Path $outputFolder/getComputerInfo.log -Width 4096
& $PSScriptRoot/ackfetch.ps1 -showAllProps > $outputFolder/ackfetch.log
& $PSScriptRoot/dumpSomeOsProps.ps1 > $outputFolder/dumpSomeOsProps.log
systeminfo.exe > $outputFolder/systeminfo.log
Start-Process -FilePath msinfo32.exe -ArgumentList @('/report', "${outputFolder}\msinfo.log") -Wait		# is still a gui app, so only way to get posh to wait for it to complete

Compress-Archive -Path $outputFolder/*.log -DestinationPath $outputFolder/sysInfo.zip -CompressionLevel Optimal