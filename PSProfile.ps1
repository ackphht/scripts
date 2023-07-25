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
	$properModulesDir = "$env:LocalAppData\PowerShell\Modules"
	#if (-not (Test-Path -LiteralPath $properModulesDir -PathType Container)) {
	#	New-Item -Path $properModulesDir -Type Directory | Out-Null
	#}
	AddPathValue -pathVarName 'Path' -value $PSScriptRoot -prepend
	if (Test-Path -Path $properModulesDir -PathType Container) {
		AddPathValue -pathVarName 'PSModulePath' -value $properModulesDir -prepend
	}
	Remove-Variable -Name 'properModulesDir'
}
$scriptsDir = "$HOME\scripts"
if (Test-Path -Path $scriptsDir -PathType Container) {
	AddPathValue -pathVarName 'Path' -value $scriptsDir -prepend
	AddPathValue -pathVarName 'PSModulePath' -value $scriptsDir -prepend
}
Remove-Variable -Name 'scriptsDir'

#
# add oh-my-posh:
#
if ((Get-Command -Name 'oh-my-posh' -ErrorAction Ignore)) {
	foreach ($maybeAckTheme in @("$env:OneDrive/Documents/omp/ack.omp.json",
									"$PSScriptRoot/Themes/ack.omp.json",
									"$HOME/scripts/ack.omp.linux.json")) {
		if (Test-Path -Path $maybeAckTheme -PathType Leaf) {
			Write-Verbose "$($MyInvocation.InvocationName): using oh-my-posh profile `"$maybeAckTheme`""
			oh-my-posh --init --shell pwsh --config $maybeAckTheme | Invoke-Expression
			break
		}
	}
	Remove-Variable -Name 'maybeAckTheme'
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
$SystemProfile = "$HOME\.system_profile.ps1"
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