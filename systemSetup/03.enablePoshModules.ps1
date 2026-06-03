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
		# make sure newest Microsoft.PowerShell.PSResourceGet is installed (looks like latest PowerShellCore's come with it)
		# if it's already installed, this will just overwrite it, meh:
		Write-Verbose "$($MyInvocation.InvocationName): (re)installing latest version of Microsoft.PowerShell.PSResourceGet"
		Install-Module -Name 'Microsoft.PowerShell.PSResourceGet' -Scope 'CurrentUser' -AllowClobber -Force
		# make sure PSGallery is Trusted in this one, too:
		$g2 = Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue
		if (-not $g2) {		# just in case:
			Register-PSResourceRepository -PSGallery
			$g2 = Get-PSResourceRepository -Name PSGallery -ErrorAction SilentlyContinue
		}
		if ($g2 -and -not $g2.Trusted) {
			Set-PSResourceRepository -Name PSGallery -Trusted
		}
	}

	#Install-Module -Name Pscx -Scope CurrentUser -AllowClobber

	$yn = $Host.UI.PromptForChoice('Add repository', 'do you want to add a package repositories for wallach9?', $('&Yes', '&No'), 1)
	if ($yn -eq 0) {
		Read-Host -Prompt "`nmake sure system is connected to wallach9 and logged in...`n`npress Enter to continue..."

		$wallach9Repo = Get-PSRepository -Name 'wallach9' -ErrorAction 'SilentlyContinue'
		if (-not $wallach9Repo) {
			Write-Host
			Write-Host
			Write-Host 'adding repository registration for wallach9 for old package management' -ForegroundColor DarkCyan
			Register-PSRepository -Name 'wallach9' -SourceLocation '\\wallach9\packages\powershell\' -PublishLocation '\\wallach9\packages\powershell\' -InstallationPolicy 'Trusted'
		}

		$wallach9Repo = Get-PSResourceRepository -Name 'wallach9' -ErrorAction 'SilentlyContinue'
		if (-not $wallach9Repo) {
			Write-Host
			Write-Host
			Write-Host 'adding repository registration for wallach9 for PSResourceGet package management' -ForegroundColor DarkCyan
			Register-PSResourceRepository -Name 'wallach9' -Uri 'file://wallach9/packages/powershell/' -Trusted
		}
	}
}

#==============================
Main
#==============================