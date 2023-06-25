#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$True)]
param()

Set-StrictMode -Version Latest

. $PSScriptRoot/setUpSystem.00.common.ps1

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()
	$windowsName = GetWindowsVersionName
	if (@("Windows10", "Windows8", "Windows7") -notcontains $windowsName) {
		WriteErrorishMessage "This version of Windows, |$windowsName|, is not supported by this script."
		return
	}

	$scriptPath = $PSScriptRoot
	#$packagesConfigPath = Join-Path $scriptPath "setUpSystem.packages.test.config"
	$packagesConfigPath = Join-Path $scriptPath "setUpSystem.packages.config"
	Write-Verbose "$($MyInvocation.InvocationName): using package.config file |$packagesConfigPath|"

	$packagesToInstall = ReadListOfPackagesToInstall -packagesConfigPath $packagesConfigPath -type 'PSModule'

	# install all the things:
	InstallAllThePackages -packageList $packagesToInstall -windowsName $windowsName
}

#==============================
Main
#==============================
