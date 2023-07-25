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

#
# fix up some paths:
#
if ($PSEdition -ne 'Core' -or $IsWindows) {
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
}
Remove-Variable -Name 'scriptsDir'

#
# add oh-my-posh:
#
if ((Get-Command -Name 'oh-my-posh' -ErrorAction Ignore)) {
	$themePaths = [System.Collections.Generic.List[string]]::new(4)
	if (Test-Path -Path env:OneDrive) {
		$themePaths.Add([System.IO.Path]::Combine($env:OneDrive, 'Documents', 'omp', 'ack.omp.json'))	# Join-Path has different signature on desktop posh, so can't use that
	}
	$themePaths.Add([System.IO.Path]::Combine($PSScriptRoot, 'Themes', 'ack.omp.json'))
	$themePaths.Add([System.IO.Path]::Combine($HOME, 'scripts', 'ack.omp.linux.json'))
	foreach ($maybeAckTheme in $themePaths) {
		if (Test-Path -Path $maybeAckTheme -PathType Leaf) {
			Write-Verbose "$($MyInvocation.InvocationName): using oh-my-posh profile `"$maybeAckTheme`""
			oh-my-posh --init --shell pwsh --config $maybeAckTheme | Invoke-Expression
			break
		}
	}
	Remove-Variable -Name 'maybeAckTheme'
	Remove-Variable -Name 'themePaths'
	Set-Alias -Name 'omp' -Value 'oh-my-posh.exe'
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