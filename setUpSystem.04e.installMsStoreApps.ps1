<# #Requires -RunAsAdministrator #>	# ??
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$True)]
param()

Set-StrictMode -Version Latest

. $PSScriptRoot/setUpSystem.00.common.ps1

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()

	$windowsName = GetWindowsVersionName
	if (@('Windows10', 'Windows11') -notcontains $windowsName) {
		WriteErrorishMessage "This version of Windows, |$windowsName|, is not supported by this script."
		return
	}

	$scriptPath = $PSScriptRoot
	$packagesConfigPath = Join-Path $scriptPath 'setUpSystem.packages.config'
	Write-Verbose "$($MyInvocation.InvocationName): using package.config file |$packagesConfigPath|"

	if (-not (MakeSureWinGetIsInstalled)) {
		return	# it will write an error message
	}

	# create list of apps to install with chocolatey, and list of apps that we can't install that way (so we can show it at the end as a reminder)
	$packagesToInstall = ReadListOfPackagesToInstall -packagesConfigPath $packagesConfigPath -type 'MSStore'

	# install all the things:
	InstallAllThePackages -packageList $packagesToInstall -windowsName $windowsName
}

function MakeSureWinGetIsInstalled {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()

	$required = [Version]'1.1.12663'
	$gcm = @(Get-Command -Name 'winget.exe')
	if ($gcm -and $gcm.Count -gt 0) {
		$ver = & $gcm[0].Source --version
		$thisVer = [Version]($ver.Trim('v'))
		if ($thisVer -ge $required) {
			Write-Verbose "$($MyInvocation.InvocationName): valid version of winget.exe found: v$thisVer"
			return $true
		}
	}
	Write-Error "winget.exe version $required or later is required for this script. Make sure you have the latest 'App Installer' application installed in the MS Store."
	return $false
}

#==============================
Main
#==============================
