#Requires -RunAsAdministrator
#Requires -Version 5.1
<# Requires -PSEdition Desktop #>	# taking this out because it works now, will check below; this work in Win11 but not on 10

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Import-Module -Name $PSScriptRoot/populateSystemData -ErrorAction Stop

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	$osDetails = Get-OSDetails
	if ($osDetails.BuildNumber -lt 10240 <# Windows 10 #>) {
		Write-Error "This script is only for Windows 10 and up."
		return
	}
	if (($PSVersionTable.PSVersion -ge ([Version]'6.0')) -and $osDetails.BuildNumber -lt 22000 <# Windows 11 #>) {
		Write-Error "This script requires running with Desktop PowerShell (with administrator privs) on Windows 10 (some of the needed cmdlets are broken)."
		return
	}

	#
	# Get-AppxPackage | Sort-Object Name | Format-Table Name,Version,PackageFullName,PackageFamilyName
	# Get-AppxProvisionedPackage -online | Sort-Object DisplayName | Format-Table DisplayName,Version,PackageName
	#

	Write-Host ''

	RemoveAppx -name 'Microsoft.Xbox*'					# all the various Xbox apps (some can't be uninstalled, so might error)
	RemoveAppx -name 'Microsoft.ZuneMusic'				# Groove Music
	RemoveAppx -name 'Microsoft.MicrosoftOfficeHub'		# 'Get Office'
	RemoveAppx -name 'Microsoft.MicrosoftSolitaireCollection'
	RemoveAppx -name 'Microsoft.OneConnect'				# 'Paid WiFi and Cellular'
	RemoveAppx -name 'Microsoft.SkypeApp'
	RemoveAppx -name 'Microsoft.YourPhone' -Confirm
	RemoveAppx -name 'Microsoft.Microsoft3DViewer' -Confirm
	RemoveAppx -name 'Microsoft.MixedReality.Portal' -Confirm
	RemoveAppx -name 'AppUp.IntelOptaneMemoryandStorageManagement' -Confirm

	RemoveAppx -name 'Microsoft.Getstarted' -Confirm

	Write-Host ''
	Write-Host ''
}

function RemoveAppx {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $name
	)

	Write-Verbose "$($MyInvocation.InvocationName): looking for user appx(s) |$name|"
	$appxes = @(Get-AppxPackage -Name $name)
	if ($appxes) {
		foreach ($appx in $appxes) {
			Write-Host "removing user appx '$($appx.Name)" -ForegroundColor DarkYellow
			try {
				$appx | Remove-AppxPackage -ErrorAction Stop
			} catch {
				if ($_.Exception) {
					Write-Warning "error removing user appx '$($appx.Name)': $($_.Exception.Message)"
				} else {
					throw
				}
			}
		}
	}

	Write-Verbose "$($MyInvocation.InvocationName): looking for system appx(s) |$name|"
	$appxes = @(Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $name })
	if ($appxes) {
		foreach ($appx in $appxes) {
			# Remove-AppxProvisionedPackage doesn't support -Confirm for some reason, so have to check ourselves:
			if ($PSCmdLet.ShouldProcess($appx.DisplayName, 'Remove provisioned package')) {
				Write-Host "removing system appx '$($appx.DisplayName)" -ForegroundColor DarkYellow
				try {
					$appx | Remove-AppxProvisionedPackage -Online
				} catch {
					if ($_.Exception) {
						Write-Warning "error removing system appx '$($appx.DisplayName)': $($_.Exception.Message)"
					} else {
						throw
					}
				}
			}
		}
	}
}

#==============================
Main
#==============================
