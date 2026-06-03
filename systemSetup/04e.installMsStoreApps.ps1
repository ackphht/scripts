<# #Requires -RunAsAdministrator #>	# ??
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$True)]
param()

Set-StrictMode -Version Latest

. $PSScriptRoot/00.common.ps1

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()

	$windowsName = GetWindowsVersionName
	if (@('Windows10', 'Windows11') -notcontains $windowsName) {
		WriteErrorishMessage "This version of Windows, |$windowsName|, is not supported by this script."
		return
	}

	$scriptPath = $PSScriptRoot
	$packagesConfigPath = Join-Path $scriptPath 'packages.config'
	Write-Verbose "$($MyInvocation.InvocationName): using package.config file |$packagesConfigPath|"

	if (-not (Test-UsableVersionOfWinget)) {
		WriteErrorishMessage -message "Windows Package Manager (winget) is not installed or is too old. Please run the 00.installWinget.ps1 script first to install/update it, then re-run this script."
		return
	}

	# create list of apps to install with chocolatey, and list of apps that we can't install that way (so we can show it at the end as a reminder)
	$packagesToInstall = ReadListOfPackagesToInstall -packagesConfigPath $packagesConfigPath -type 'MSStore'

	# install all the things:
	InstallAllThePackages -packageList $packagesToInstall -windowsName $windowsName
}

#==============================
Main
#==============================
