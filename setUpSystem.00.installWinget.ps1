#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param()

#
# based on https://learn.microsoft.com/en-us/windows/package-manager/winget/#install-winget-on-windows-sandbox
#

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

$minVersion = [System.Version]'10.0.16299'	# Win10 1709, lowest supported version for winget
if ([System.Environment]::OSVersion.Version -lt $minVersion) {
	Write-Warning "unsupported OS: Windows Package Manager requires Windows 10 1709 (build 16299) or higher"
	return
}

# TODO?: check if it's already installed with a suitable version ??

$windowsPkgMngrFilename = 'Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle'
# should be able to use System.Runtime.InteropServices.RuntimeInformation.OSArchitecture back to .NET 4.7.1 per docs,
# but for some reason it doesn't always work on old powershell, so we'll use env var:
if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
	$vclibsFilename = 'Microsoft.VCLibs.x64.14.00.Desktop.appx'
} elseif ($env:PROCESSOR_ARCHITECTURE -eq 'X86') {
	$vclibsFilename = 'Microsoft.VCLibs.x86.14.00.Desktop.appx'
} elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
	$vclibsFilename = 'Microsoft.VCLibs.arm64.14.00.Desktop.appx'
} else {
	Write-Error "unrecognized OS architecture: ${env:PROCESSOR_ARCHITECTURE}: cannot continue" -ErrorAction 'Stop'
}

if (-not (Test-Path -Path $env:TEMP -PathType Container)) { [void](New-Item -Path $env:TEMP -ItemType Directory -Force) }
$vclibsTempFile = Join-Path $env:TEMP $vclibsFilename
$windowsPkgMngrTempFile = Join-Path $env:TEMP $windowsPkgMngrFilename
$oldProgressPref = $ProgressPreference

try {
	$ProgressPreference = 'SilentlyContinue'

	$url = "https://aka.ms/${vclibsFilename}"
	Write-Host 'downloading VCLibs dependency' -ForegroundColor DarkCyan
	Write-Verbose "downloading VCLibs dependency: url = |$url|`n    output filename = |$vclibsTempFile|"
	Invoke-WebRequest -Method GET -Uri $url -OutFile $vclibsTempFile

	$url = "https://github.com/microsoft/winget-cli/releases/latest/download/${windowsPkgMngrFilename}"
	Write-Host 'downloading windows package manager' -ForegroundColor DarkCyan
	Write-Verbose "downloading windows package manager: url = |$url|`n    output filename = |$windowsPkgMngrTempFile|"
	Invoke-WebRequest -Method GET -Uri $url -OutFile $windowsPkgMngrTempFile

	Write-Host 'installing VCLibs dependency' -ForegroundColor DarkCyan
	Write-Verbose "installing package |$vclibsFilename|"
	Add-AppxPackage -Path $vclibsTempFile
	Write-Host 'installing windows package manager' -ForegroundColor DarkCyan
	Write-Verbose "installing package |$windowsPkgMngrFilename|"
	Add-AppxPackage -Path $windowsPkgMngrTempFile
} finally {
	if (Test-Path -Path $vclibsTempFile -PathType Leaf) { Remove-Item -Path $vclibsTempFile -Force }
	if (Test-Path -Path $windowsPkgMngrTempFile -PathType Leaf) { Remove-Item -Path $windowsPkgMngrTempFile -Force }
	if ($ProgressPreference -ne $oldProgressPref) { $ProgressPreference = $oldProgressPref }
}