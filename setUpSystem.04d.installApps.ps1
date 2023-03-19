#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$True)]
param()

Set-StrictMode -Version Latest

. ./setUpSystem.00.common.ps1

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()

	$windowsName = GetWindowsVersionName
	if (@("Windows10", "Windows8", "Windows7") -notcontains $windowsName) {
		WriteErrorishMessage "This version of Windows, |$windowsName|, is not supported by this script."
		return
	}

	$scriptPath = $PSScriptRoot
	#$packagesConfigPath = Join-Path $scriptPath "setUpSystem.packages.test.config"
	$packagesConfigPath = Join-Path $scriptPath "setUpSystem.packages.config"
	Write-Verbose "$($MyInvocation.InvocationName): using package.config file |$packagesConfigPath|"

	MakeSureAckAptModuleIsLoaded

	# create list of apps to install with chocolatey, and list of apps that we can't install that way (so we can show it at the end as a reminder)
	$packagesToInstall = ReadListOfPackagesToInstall -packagesConfigPath $packagesConfigPath -type 'AckApt'

	# install all the things:
	InstallAllThePackages -packageList $packagesToInstall -windowsName $windowsName
}

function MakeSureAckAptModuleIsLoaded {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()

	if ((Get-Module AckApt) -eq $null) {
		Write-Verbose "$($MyInvocation.InvocationName): loading AckApt module"
		Import-Module AckApt -ErrorAction Stop
	} else {
		Write-Verbose "$($MyInvocation.InvocationName): AckApt module already loaded"
	}
}

#==============================
Main
#==============================
