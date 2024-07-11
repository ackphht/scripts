#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $install
)
if ($install) {
	Write-Verbose "`$PROFILE = |$PROFILE|; this file = |$PSCommandPath|"
	if (Test-Path -Path $PROFILE -PathType Leaf) {
		Write-Warning "powershell profile `"$PROFILE`" already exists; exiting"
	} else {
		# create a symlink at $PROFILE pointing to this file:
		$profileFldr = Split-Path -Path $PROFILE -Parent
		if (-not (Test-Path -Path $profileFldr -PathType Container)) {
			[void] (New-Item -ItemType Directory -Path $profileFldr -Force)
		}
		Write-Host "creating symlink from |$PROFILE| to |$PSCommandPath|" -ForegroundColor Cyan
		[void](New-Item -ItemType SymbolicLink -Path $PROFILE -Value $PSCommandPath)
	}
	return
}
# in case we're running < .net 4.6, make sure TLS 1.2 is enabled:
if ([System.Net.ServicePointManager]::SecurityProtocol -ne 0 <# SystemDefault (added in 4.7/Core) #> -and
	([System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12) -eq 0)
{
	Write-Verbose "changing default SecurityProtocol to enable TLS 1.2"
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
}

function AddPathValue {
	param(
		[Parameter(Mandatory=$true)] [string] $pathVarName,
		[Parameter(Mandatory=$true)] [string] $value,
		[System.EnvironmentVariableTarget] $target = [System.EnvironmentVariableTarget]::Process,
		[switch] $prepend
	)
	$values = [System.Collections.Generic.List[string]]::new(8)
	$current = [System.Environment]::GetEnvironmentVariable($pathVarName, $target)
	if ($current) {
		$values.AddRange(($current -split [System.IO.Path]::PathSeparator))
	}
	$changed = $false
	if ($values -notcontains $value) {
		if ($prepend) {
			$values.Insert(0, $value)
		} else {
			$values.Add($value)
		}
		$changed = $true
	}
	if ($changed) {
		[System.Environment]::SetEnvironmentVariable($pathVarName, ($values -join [System.IO.Path]::PathSeparator), $target)
	}
}

$ackIsWindows = ($PSEdition -ne 'Core' -or $IsWindows)
#
# fix up some paths:
#
if ($ackIsWindows) {
	AddPathValue -pathVarName 'Path' -value $PSScriptRoot -prepend
	$properModulesDir = "$env:LocalAppData\PowerShell\Modules"
	$documentsModulesDI = Get-Item -Path (Join-Path (Split-Path -Path $PROFILE -Parent) 'Modules') -ErrorAction SilentlyContinue
	# add $properModulesDir to PSModulePath:
	if ((Test-Path -Path $properModulesDir -PathType Container) -and
			# but only if the Modules folder in the Documents folder (sigh) isn't a junction/symlink pointing to it:
			-not ($documentsModulesDI -and $documentsModulesDI.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) -and $properModulesDir -in @($documentsModulesDI.Target))) {
		AddPathValue -pathVarName 'PSModulePath' -value $properModulesDir -prepend
	}
	Remove-Variable -Name 'properModulesDir'
	Remove-Variable -Name 'documentsModulesDI'
}
$scriptsDir = (Join-Path -Path $HOME -ChildPath 'scripts')
if (Test-Path -Path $scriptsDir -PathType Container) {
	AddPathValue -pathVarName 'Path' -value $scriptsDir -prepend
	AddPathValue -pathVarName 'PSModulePath' -value $scriptsDir -prepend
	function _updateScriptsFldr { Push-Location -Path (Join-Path -Path $HOME -ChildPath 'scripts')<#can't use var#>; git pull; Pop-Location; }
	New-Alias -Name 'scup' -Value '_updateScriptsFldr'
}
Remove-Variable -Name 'scriptsDir'

#
# add oh-my-posh:
#
if ((Get-Command -Name 'oh-my-posh' -ErrorAction Ignore)) {
	$themePaths = @()
	if (Test-Path -Path env:OneDrive) {
		$themePaths += [System.IO.Path]::Combine($env:OneDrive, 'Documents', 'omp', 'ack.omp.{0}')	# Join-Path has different signature on desktop posh, so can't use that
	}
	$themePaths += [System.IO.Path]::Combine($PSScriptRoot, 'Themes', 'ack.omp.{0}')
	$themePaths += [System.IO.Path]::Combine($HOME, 'scripts', 'ack.omp.linux.{0}')
	foreach ($maybeAckTheme in @($themePaths | ForEach-Object { $t = $_; @('toml', 'jsonc', 'json') | ForEach-Object { $t -f $_ } })) {
		Write-Verbose "$($MyInvocation.InvocationName): checking for oh-my-posh profile `"$maybeAckTheme`""
		if (Test-Path -Path $maybeAckTheme -PathType Leaf) {
			Write-Verbose "$($MyInvocation.InvocationName): using oh-my-posh profile `"$maybeAckTheme`""
			oh-my-posh --init --shell pwsh --config $maybeAckTheme | Invoke-Expression
			break
		}
	}
	Remove-Variable -Name 'maybeAckTheme'
	Remove-Variable -Name 'themePaths'
	if ($ackIsWindows) { Set-Alias -Name 'omp' -Value 'oh-my-posh.exe'}
	else { Set-Alias -Name 'omp' -Value 'oh-my-posh' }
}
#
# import some modules:
#
#$moduleName = 'Pscx'
#if ((Get-Module -Name $moduleName -ListAvailable)) {
#	Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
#	Import-Module -Name $moduleName -NoClobber
#}
$moduleName = 'Terminal-Icons'
if ((Get-Module -Name $moduleName -ListAvailable)) {
	Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
	Import-Module -Name $moduleName
	$theme = Get-TerminalIconsTheme
	if (-not $theme.Icon.Types.Files.ContainsKey('.epub')) { $theme.Icon.Types.Files.Add('.epub', 'nf-fa-book') }
	if (-not $theme.Color.Types.Files.ContainsKey('.epub')) { $theme.Color.Types.Files.Add('.epub', '9e7a41') }
	if (-not $theme.Icon.Types.Files.ContainsKey('.mobi')) { $theme.Icon.Types.Files.Add('.mobi', 'nf-fa-book') }
	if (-not $theme.Color.Types.Files.ContainsKey('.mobi')) { $theme.Color.Types.Files.Add('.mobi', '9e7a41') }
	Remove-Variable -Name 'theme'
}

$moduleName = 'AckWare.AckLib'
if ((Get-Module -Name $moduleName -ListAvailable)) {
	Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
	Import-Module -Name $moduleName
}

$moduleName = 'gsudoModule'
if ((Get-Module -Name $moduleName -ListAvailable)) {
	Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
	Import-Module -Name $moduleName
#	Set-Alias -Name 'sudo' -Value 'Invoke-Gsudo'	# their usage is different but really should use explicit calls anyway
#} else {
#	Set-Alias -Name 'sudo' -Value 'Invoke-Elevated'
}

if ($ackIsWindows) {
	$moduleName = 'AckWingetHelpers'
	if ((Get-Module -Name $moduleName -ListAvailable)) {
		Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
		Import-Module -Name $moduleName
	}
}

Remove-Variable -Name 'moduleName'
#
# misc:
#
$psReadLineProfile = Get-Command -Name 'PSReadLineProfile.ps1' -ErrorAction SilentlyContinue
if ($psReadLineProfile) {
	Write-Verbose "$($MyInvocation.InvocationName): adding PSReadlineProfile `"$($psReadLineProfile.Path)`""
	. $psReadLineProfile.Path
}
Remove-Variable -Name 'psReadLineProfile'

# support having a profile that's system specific, not shared and not in git:
$SystemProfile = Join-Path -Path $HOME -ChildPath '.system_profile.ps1'
if (Test-Path -Path $SystemProfile -PathType Leaf) {
	Write-Verbose "$($MyInvocation.InvocationName): importing local profile `"$SystemProfile`""
	. $SystemProfile
}
Remove-Variable -Name 'SystemProfile'

if ((Get-Variable -Name 'PSStyle' -ErrorAction Ignore)) {
	Write-Verbose "$($MyInvocation.InvocationName): adjusting PSStyle to my liking"
	# at least with posh 7, they made Debug, Verbose, Warning all the same color; change them:
	if ($PSStyle.Formatting.Verbose -eq "`e[33;1m" <# yellow, bold #>) {
		if ($PSStyle.Formatting.Warning -eq $PSStyle.Formatting.Verbose) {
			$PSStyle.Formatting.Warning = "`e[93;1m" <# bright yellow, bold #>
		}
		if ($PSStyle.Formatting.Debug -eq $PSStyle.Formatting.Verbose) {
			$PSStyle.Formatting.Debug = "`e[90;1m" <# bright black, bold #>
		}
	}
}

function Test-IsElevated {
	[OutputType([bool])]
	param()
	if (($PSEdition -ne 'Core' -or $IsWindows)) {	# can't use ackIsWindows here
		return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
	} else {
		return ((id -u) -eq 0)
	}
}

if ($ackIsWindows) {
	$winBuild = [System.Environment]::OSVersion.Version.Build
	if ($winBuild -ge 10240 <# Win10 #> -and ($PSEdition -ne 'Core' -or $winBuild -ge 22000 <# Win11 (cmdlets are broken on Win10 in Core) #>)) {
		function Remove-AppxCompletely {
			[CmdletBinding(SupportsShouldProcess=$true)]
			[OutputType([void])]
			param([Parameter(Mandatory=$true)] [string] $name)
			if (-not (Test-IsElevated)) {
				Write-Error "Elevation is required to remove system AppX apps"
				return
			}
			foreach ($appx in (Get-AppXPackage -Name $name)) {
				Write-Host "removing user appx '$($appx.Name)" -ForegroundColor DarkYellow
				try {
					$appx | Remove-AppxPackage -ErrorAction Stop
				} catch {
					if ($_.Exception) { Write-Warning "error removing user appx '$($appx.Name)': $($_.Exception.Message)" } else { throw }
				}
			}
			foreach ($appx in (Get-AppxProvisionedPackage -Online | Where-Object { $_.DisplayName -like $name })) {
				# Remove-AppxProvisionedPackage doesn't support -Confirm for some reason, so have to check ourselves:
				if ($PSCmdLet.ShouldProcess($appx.DisplayName, 'Remove provisioned package')) {
					Write-Host "removing system appx '$($appx.DisplayName)" -ForegroundColor DarkYellow
					try {
						$appx | Remove-AppxProvisionedPackage -Online
					} catch {
						if ($_.Exception) { Write-Warning "error removing system appx '$($appx.DisplayName)': $($_.Exception.Message)" } else { throw }
					}
				}
			}
		}
	}
	if ($winBuild -ge 10240 <# Win10 #> <# should it be higher?? #>) {
		function Update-StoreAppsAvailableUpgrades {
			[CmdletBinding(SupportsShouldProcess=$false)]
			[OutputType([void])]
			param()
			if (-not (Test-IsElevated)) { Write-Error "This command requires elevation"; return; }
			Get-CimInstance -Namespace "Root\cimv2\mdm\dmmap" -ClassName "MDM_EnterpriseModernAppManagement_AppManagement01" |
				Invoke-CimMethod -MethodName UpdateScanMethod |
				Out-Null
		}
		New-Alias -Name 'forceStoreAppsUpdate' -Value 'Update-StoreAppsAvailableUpgrades'	# old name
	}
	Remove-Variable -Name 'winBuild'
}

Remove-Variable -Name 'ackIsWindows'

function Get-EncodedCommand { param([Parameter(Mandatory=$true)][string]$c) return ([System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($c))) }
function Get-DecodedCommand { param([Parameter(Mandatory=$true)][string]$c) return ([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($c))) }

# some more aliases:
New-Alias -Name 'll' -Value 'Get-ChildItem'