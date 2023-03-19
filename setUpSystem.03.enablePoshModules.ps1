#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	#$osDetails = Get-OSDetails
	#Write-Verbose "$($MyInvocation.InvocationName): osDetails = |$(ConvertTo-Json -InputObject $osdetails -Depth 100)|"

	Write-Verbose "$($MyInvocation.InvocationName): enabling powershell packages and the gallery"
	$g = Get-PSRepository -Name 'PSGallery' -ErrorAction 'SilentlyContinue'
	if ($g) {
		if (-not (Get-PackageProvider -Name 'NuGet')) {
			Install-PackageProvider -Name 'NuGet' -Force
		}
		if ($g.InstallationPolicy -ne 'Trusted') {
			Write-Verbose "$($MyInvocation.InvocationName): trusting repo 'PSGallery'"
			Set-PSRepository -Name 'PSGallery' -InstallationPolicy 'Trusted'
		}
		# see if we already have newer PowerShellGet (looks like latest PowerShellCore's come with it) and install it if we do not:
		$mod = (Get-Module -Name 'PowerShellGet' -ListAvailable | Sort-Object -Property 'Version' -Descending | Select-Object -First 1)
		if (-not $mod -or $mod.Version -lt ([Version]'2.0')) {
			Write-Verbose "$($MyInvocation.InvocationName): installing latest version of PowerShellGet"
			Install-Module -Name 'PowerShellGet' -Scope 'CurrentUser' -AllowClobber -Force
		}
	}

	#Install-Module -Name Pscx -Scope CurrentUser -AllowClobber

	$wallach9Repo = Get-PSRepository -Name 'wallach9' -ErrorAction 'SilentlyContinue'
	if (-not $wallach9Repo) {
		Write-Host
		Write-Host
		$yn = Read-Host 'do you want to add a package repository for wallach9? y/N'
		if ($yn -eq 'y') {
			Register-PSRepository -Name 'wallach9' -SourceLocation '\\wallach9\packages\powershell\' -PublishLocation '\\wallach9\packages\powershell\' -InstallationPolicy 'Trusted'
		}
	}
}

#==============================
Main
#==============================