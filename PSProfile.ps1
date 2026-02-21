#Requires -Version 5.1
[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $install,
	[switch] $showTimes
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

# using $script: doesn't work here, all the vars still get leaked,
# so keep track and explicitly remove them at the end
# ffs...
$localVars = @( 'localVars', 'localFuncs', 'install', 'showTimes', 'startNow', 'currentNow', 'ackIsWindows',
				'properModulesDir', 'documentsModulesDI', 'scriptsDir',
				'maybeAckTheme', 'themePaths', 't', 'moduleName', 'theme',
				'psReadLineProfile', 'SystemProfile', 'winBuild', 'ackIsWsl', 'oldPath'
			)
$localFuncs = @('function:_getts', 'function:_showTime')

function _getts { if ($showTimes) { return [System.DateTime]::Now } else { return 0 } }
function _showTime { param([System.DateTime]$start, [string]$desc) if ($showTimes) { Write-Host "${desc} took $(([DateTime]::Now - $start).TotalMilliseconds) ms" } }

$startNow = _getts

# in case we're running < .net 4.6, make sure TLS 1.2 is enabled:
if ([System.Net.ServicePointManager]::SecurityProtocol -ne 0 <# SystemDefault (added in 4.7/Core) #> -and
	([System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12) -eq 0)
{
	Write-Verbose "changing default SecurityProtocol to enable TLS 1.2"
	[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
}

function Test-IsElevated {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([bool])]
	param()
	if (($PSEdition -ne 'Core' -or $IsWindows)) {	# can't use ackIsWindows here
		return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]'Administrator')
	} else {
		return ((id -u) -eq 0)
	}
}

function Add-PathValue {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
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
		if ($PSCmdlet.ShouldProcess($pathVarName, 'SetEnvironmentVariable')) {
			[System.Environment]::SetEnvironmentVariable($pathVarName, ($values -join [System.IO.Path]::PathSeparator), $target)
		}
	}
}

$currentNow = _getts

$ackIsWindows = ($PSEdition -ne 'Core' -or $IsWindows)
$ackIsWsl = [bool]$env:WSL_DISTRO_NAME
# trying to use a different path without any windows stuff for Get-Commands below;
# this is working (results do seem to change) but Get-Commands on WSL are still really slow for some reason
# it actually gets super slow when it CAN'T find what you asked for, which seems backwards; 😖
# (Get-Module is really bad too...)
$oldPath = ''
if ($ackIsWsl) {
	$oldPath = $env:PATH
	$env:PATH = ($env:PATH -split [System.IO.Path]::PathSeparator | Where-Object { $_ -notlike '/mnt/*' }) -join [System.IO.Path]::PathSeparator
	#Write-Host "updated path: |$env:PATH|"
}

# it's the 2020's: change default windows terminal/console encodings to utf8:
if ($ackIsWindows) {
	$currentNow = _getts
	chcp.com 65001 | Out-Null
	if ($OutputEncoding.CodePage -ne [System.Text.Encoding]::UTF8.CodePage) {
		Write-Verbose "changing default console encodings to UTF-8"
		$OutputEncoding = [System.Text.Encoding]::UTF8
	}
	if ([Console]::InputEncoding.CodePage -ne [System.Text.Encoding]::UTF8.CodePage) {
		Write-Verbose "changing System.Console.InputEncoding to UTF-8"
		[Console]::InputEncoding = [System.Text.Encoding]::UTF8
	}
	if ([Console]::OutputEncoding.CodePage -ne [System.Text.Encoding]::UTF8.CodePage) {
		Write-Verbose "changing System.Console.OutputEncoding to UTF-8"
		[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	}
	_showTime $currentNow 'ensuring console encodings are UTF-8'
}

#
# fix up some paths:
#
if ($ackIsWindows) {
	$currentNow = _getts
	Add-PathValue -pathVarName 'Path' -value $PSScriptRoot -prepend
	$properModulesDir = "$env:LocalAppData\PowerShell\Modules"
	$documentsModulesDI = Get-Item -Path (Join-Path (Split-Path -Path $PROFILE -Parent) 'Modules') -ErrorAction SilentlyContinue
	# add $properModulesDir to PSModulePath:
	if ((Test-Path -Path $properModulesDir -PathType Container) -and
			# but only if the Modules folder in the Documents folder (sigh) isn't a junction/symlink pointing to it:
			-not ($documentsModulesDI -and $documentsModulesDI.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) -and $properModulesDir -in @($documentsModulesDI.Target))) {
		Add-PathValue -pathVarName 'PSModulePath' -value $properModulesDir -prepend
	}
	_showTime $currentNow 'tweaking Path #1'
}
$scriptsDir = (Join-Path -Path $HOME -ChildPath 'scripts')
if (Test-Path -Path $scriptsDir -PathType Container) {
	$currentNow = _getts
	Add-PathValue -pathVarName 'Path' -value $scriptsDir -prepend
	Add-PathValue -pathVarName 'PSModulePath' -value $scriptsDir -prepend
	# don't remove this one at the end:
	function _updateScriptsFldr { Push-Location -Path (Join-Path -Path $HOME -ChildPath 'scripts')<#can't use var#>; git pull; Pop-Location; }
	if (-not [bool](Get-Alias -Name 'scup' -ErrorAction Ignore)) {
		New-Alias -Name 'scup' -Value '_updateScriptsFldr'
	}
	_showTime $currentNow 'tweaking Path #2'
}

#
# add oh-my-posh:
#
if ((Get-Command -Name 'oh-my-posh' -CommandType Application -ErrorAction Ignore)) {
	$currentNow = _getts
	$themePaths = @()
	if (Test-Path -Path env:OneDrive) {
		$themePaths += [System.IO.Path]::Combine($env:OneDrive, 'Documents', 'omp', 'ack.omp.{0}')	# Join-Path has different signature on desktop posh, so can't use that
	}
	$themePaths += [System.IO.Path]::Combine($PSScriptRoot, 'Themes', 'ack.omp.{0}')
	$themePaths += [System.IO.Path]::Combine($HOME, 'scripts', 'ack.omp.linux.{0}')
	foreach ($maybeAckTheme in @($themePaths | ForEach-Object { $t = $_; @('toml', 'jsonc', 'json') | ForEach-Object { $t -f $_ } })) {
		Write-Verbose "$($MyInvocation.InvocationName): checking for oh-my-posh profile `"$maybeAckTheme`""
		if (Test-Path -Path $maybeAckTheme -PathType Leaf) {
			_showTime $currentNow '    finding OhMyPosh profile'
			Write-Verbose "$($MyInvocation.InvocationName): using oh-my-posh profile `"$maybeAckTheme`""
			oh-my-posh init pwsh --config $maybeAckTheme | Invoke-Expression
			_showTime $currentNow '    initing OhMyPosh'
			break
		}
	}
	if (-not [bool](Get-Alias -Name 'omp' -ErrorAction Ignore)) {
		if ($ackIsWindows) { Set-Alias -Name 'omp' -Value 'oh-my-posh.exe' }
		else { Set-Alias -Name 'omp' -Value 'oh-my-posh' }
	}
	_showTime $currentNow 'total time adding OhMyPosh stuff'
}
#
# import some modules:
#
if (-not $ackIsWsl) {	# would probably be nice to have on WSL too, but Get-Module is excruciatingly slow there for some reason
	#$moduleName = 'Pscx'
	#if ((Get-Module -Name $moduleName -ListAvailable)) {
	#	Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
	#	Import-Module -Name $moduleName -NoClobber
	#}

	# Teminal-Icons has gotten *really* slow to load, and project seems to be dead
	# found way to load in the background, prompt comes up quicker, but still sits
	# there not accepting input until Terminal-Icons is loaded, so that's not gonna work
	# the icons and the colors are nice, but not that nice
	<#
	$moduleName = 'Terminal-Icons'
	#$currentNow = _getts
	if ((Get-Module -Name $moduleName -ListAvailable)) {
		#Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
		#Import-Module -Name $moduleName
		#$theme = Get-TerminalIconsTheme
		#if (-not $theme.Icon.Types.Files.ContainsKey('.epub')) { $theme.Icon.Types.Files.Add('.epub', 'nf-fa-book') }
		#if (-not $theme.Color.Types.Files.ContainsKey('.epub')) { $theme.Color.Types.Files.Add('.epub', '9e7a41') }
		#if (-not $theme.Icon.Types.Files.ContainsKey('.mobi')) { $theme.Icon.Types.Files.Add('.mobi', 'nf-fa-book') }
		#if (-not $theme.Color.Types.Files.ContainsKey('.mobi')) { $theme.Color.Types.Files.Add('.mobi', '9e7a41') }

		Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`" with PowerShell.OnIdle"
		# load in OnIdle: from https://github.com/devblackops/Terminal-Icons/issues/150
		Register-EngineEvent -SourceIdentifier 'PowerShell.OnIdle' -MaxTriggerCount 1 -Action {
			Import-Module -Name 'Terminal-Icons' -Global
			$theme = Get-TerminalIconsTheme
			#if (-not $theme.Icon.Types.Files.ContainsKey('.epub')) { $theme.Icon.Types.Files.Add('.epub', 'nf-fa-book') }
			if (-not $theme.Icon.Types.Files.ContainsKey('.epub')) { $theme.Icon.Types.Files.Add('.epub', 'nf-oct-book') }
			if (-not $theme.Color.Types.Files.ContainsKey('.epub')) { $theme.Color.Types.Files.Add('.epub', '9E7A41') }
			#if (-not $theme.Icon.Types.Files.ContainsKey('.mobi')) { $theme.Icon.Types.Files.Add('.mobi', 'nf-fa-book') }
			if (-not $theme.Icon.Types.Files.ContainsKey('.mobi')) { $theme.Icon.Types.Files.Add('.mobi', 'nf-oct-book') }
			if (-not $theme.Color.Types.Files.ContainsKey('.mobi')) { $theme.Color.Types.Files.Add('.mobi', '9E7A41') }
		} | Out-Null
	}
	_showTime $currentNow 'checking/adding Terminal-Icons module'
	#>

	$moduleName = 'AckWare.AckLib'
	$currentNow = _getts
	if ((Get-Module -Name $moduleName -ListAvailable)) {
		Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
		Import-Module -Name $moduleName
	}
	_showTime $currentNow 'checking/adding AckWare.AckLib module'

	#$moduleName = 'gsudoModule'
	#$currentNow = _getts
	#if ((Get-Module -Name $moduleName -ListAvailable)) {
	#	Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
	#	Import-Module -Name $moduleName
	##	Set-Alias -Name 'sudo' -Value 'Invoke-Gsudo'	# their usage is different but really should use explicit calls anyway
	##} else {
	##	Set-Alias -Name 'sudo' -Value 'Invoke-Elevated'
	#}
	#_showTime $currentNow 'checking/adding gsudo module'
}

$currentNow = _getts
if ([bool](Get-Command -Name 'sudo' -CommandType Application -ErrorAction Ignore)) {
	function Invoke-Sudo {
		[CmdletBinding(SupportsShouldProcess=$false)]
		[OutputType([void])]
		param(
			[Parameter(Mandatory = $true, ParameterSetName = 'ByCommand', Position = 0, ValueFromPipeline)] [string] $command,
			[Parameter(Mandatory = $false, ParameterSetName = 'ByCommand', Position = 1, ValueFromRemainingArguments)] [string[]] $commandArgs,
			[Parameter(Mandatory = $true, ParameterSetName = 'ByScriptBlock', Position = 0, ValueFromPipeline)] [scriptblock] $commandScriptBlock
		)
		begin {
			# if we just specify a simple name, like 'sudo' (which we'd need on linux), we get an infinite loop, so get full path:
			$sudoCmd = (Get-Command -Name 'sudo' -CommandType Application | Select-Object -First 1).Path
			$currPoshCmd = (Get-Process -id $PID).MainModule.FileName
			Write-Verbose "$($MyInvocation.InvocationName): `$sudoCmd = |$sudoCmd|, `$currPoshCmd = |$currPoshCmd|"
		}
		process {}
		end {
			if ($commandScriptBlock) {
				Write-Verbose "$($MyInvocation.InvocationName): single arg is a scriptblock; running that"
				$encCmd = Get-EncodedCommand -c $commandScriptBlock.ToString()
				& $sudoCmd $currPoshCmd -Nologo -EncodedCommand $encCmd
			} else {
				$cmdToRun = (Get-Command -Name $command -CommandType Application,Cmdlet,ExternalScript,Function,Alias -ErrorAction Ignore | Select-Object -First 1)
				Write-Verbose "$($MyInvocation.InvocationName): command to run type = |$($cmdToRun.CommandType)|, path = |$($cmdToRun.Path)|"
				if (-not $cmdToRun) {
					throw "Could not find command `"$command`""
				} elseif ($cmdToRun.CommandType -eq 'Application') {
					Write-Verbose "$($MyInvocation.InvocationName): running application $command"
					if ($commandArgs -ne $null -and $commandArgs.Count -gt 0) {
						& $sudoCmd $command @commandArgs
					} else {
						& $sudoCmd $command
					}
				} else {	# it's a Cmdlet or ExternalScript or Function or Alias
					Write-Verbose "$($MyInvocation.InvocationName): running cmdlet/script/function/alias $command"
					$theCmd = $command
					if ($cmdToRun.CommandType -eq 'Alias') { $theCmd = $cmdToRun.ResolvedCommandName }
					# TODO?: should we make sure command and commandArgs are quoted? maybe only if they actually need it? will that break anything?
					if ($commandArgs -ne $null -and $commandArgs.Count -gt 0) {
						$encCmd = Get-EncodedCommand -c ($theCmd + ' ' + ($commandArgs -join ' '))
					} else {
						$encCmd = Get-EncodedCommand -c $theCmd
					}
					& $sudoCmd $currPoshCmd -Nologo -EncodedCommand $encCmd
				}
			}
		}
	}
	if (-not [bool](Get-Alias -Name 'sudo' -ErrorAction Ignore)) {
		Set-Alias -Name 'sudo' -Value 'Invoke-Sudo'
	}
}
_showTime $currentNow 'checking/adding Invoke-Sudo function and alias'

if ($ackIsWindows) {
	$currentNow = _getts
	$moduleName = 'AckWingetHelpers'
	if ((Get-Module -Name $moduleName -ListAvailable)) {
		Write-Verbose "$($MyInvocation.InvocationName): importing module `"$moduleName`""
		Import-Module -Name $moduleName
	}
	_showTime $currentNow 'checking/adding AckWingetHelpers module'
}

#
# misc:
#
$currentNow = _getts
$psReadLineProfile = Get-Command -Name 'PSReadLineProfile.ps1' -CommandType ExternalScript -ErrorAction SilentlyContinue
if ($psReadLineProfile) {
	Write-Verbose "$($MyInvocation.InvocationName): adding PSReadlineProfile `"$($psReadLineProfile.Path)`""
	. $psReadLineProfile.Path
}
_showTime $currentNow 'checking/adding PSReadLine profile'

# support having a profile that's system specific, not shared and not in git:
$currentNow = _getts
$SystemProfile = Join-Path -Path $HOME -ChildPath '.system_profile.ps1'
if (Test-Path -Path $SystemProfile -PathType Leaf) {
	Write-Verbose "$($MyInvocation.InvocationName): importing local profile `"$SystemProfile`""
	. $SystemProfile
}
_showTime $currentNow 'checking/adding system_profile.ps1'

$currentNow = _getts
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
_showTime $currentNow 'checking/tweaking PSStyle'

if ($ackIsWindows) {
	$currentNow = _getts
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
		function Search-AppxPackages {
			[CmdletBinding(SupportsShouldProcess=$false)]
			[OutputType([PSObject[]])]
			param(
				[string] $name
			)
			$isElevated = Test-IsElevated
			if (-not $isElevated) { Write-Warning "not elevated: only user AppX packages will be shown" }
			Get-AppxPackage -AllUsers:$isElevated |
				Where-Object { -not $name -or ($_.Name -like "*${name}*" -or $_.PackageFullName -like "*${name}*") } |
				Sort-Object -Property Name |
				Select-Object -Property Name,Version,PackageFullName
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
		if (-not [bool](Get-Alias -Name 'forceStoreAppsUpdate' -ErrorAction Ignore)) {
			New-Alias -Name 'forceStoreAppsUpdate' -Value 'Update-StoreAppsAvailableUpgrades'	# old name
		}
	}
	_showTime $currentNow 'checking/adding AppX functions'
}

function Get-EncodedCommand { param([Parameter(Mandatory=$true)][string]$c) return ([System.Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($c))) }
function Get-DecodedCommand { param([Parameter(Mandatory=$true)][string]$c) return ([System.Text.Encoding]::Unicode.GetString([System.Convert]::FromBase64String($c))) }
function Get-EnumValues { param([Parameter(Mandatory=$true)][type]$enumType) [System.Enum]::GetValues($enumType) | ForEach-Object { [PSCustomObject]@{ Value = [int]$_; Name = $_.ToString(); } } }

# ackfetch.ps1
$currentNow = _getts
if ((Test-Path -Path ~/scripts/ackfetch.ps1 -PathType Leaf) -and (-not [bool](Get-Alias -Name 'af' -ErrorAction Ignore))) {
	Set-Alias -Name 'af' -Value ~/scripts/ackfetch.ps1
}
_showTime $currentNow 'checking/adding ackfetch alias'
# fastfetch
$currentNow = _getts
if ([bool](Get-Command -Name fastfetch -CommandType Application -ErrorAction Ignore) -and (-not [bool](Get-Alias -Name 'ff' -ErrorAction Ignore))) {
	Set-Alias -Name 'ff' -Value @(Get-Command -Name fastfetch -CommandType Application)[0].Source
}
_showTime $currentNow 'checking/adding fastfetch alias'
# pip
$currentNow = _getts
if ($ackIsWindows-and [bool](Get-Command -Name python.exe -CommandType Application -ErrorAction Ignore) -and (-not [bool](Get-Alias -Name 'pipi' -ErrorAction Ignore))) {
	function Invoke-PipList { python.exe -m pip list }
	Set-Alias -Name 'pipl' -Value 'Invoke-PipList'
	function Invoke-PipListUpdates { python.exe -m pip list --outdated }
	Set-Alias -Name 'pipul' -Value 'Invoke-PipListUpdates'
	function Invoke-PipUpgrade { python.exe -m pip install --upgrade $args }
	Set-Alias -Name 'pipu' -Value 'Invoke-PipUpgrade'
	function Invoke-PipInstall { python.exe -m pip install --user $args }
	Set-Alias -Name 'pipi' -Value 'Invoke-PipInstall'
	function Invoke-PipUninstall { python.exe -m pip uninstall $args }
	Set-Alias -Name 'pipx' -Value 'Invoke-PipUninstall'
	function Invoke-PipShowInfo { python.exe -m pip show $args }
	Set-Alias -Name 'pipn' -Value 'Invoke-PipShowInfo'
	#Set-Alias -Name 'pips' -Value 'python.exe -m pip search'	# search throws an error, no longer supported, even though it's still in the --help
}
_showTime $currentNow 'checking/adding pip aliases'

#
# some tab completions:
#

if (-not $ackIsWsl) {
	# dotnet CLI (https://learn.microsoft.com/en-us/dotnet/core/tools/enable-tab-autocomplete#powershell)
	$currentNow = _getts
	if ((Get-Command -Name 'dotnet' -CommandType Application -ErrorAction Ignore)) {	# this takes forever on linux ??? or at least on WSL...
		Register-ArgumentCompleter -Native -CommandName 'dotnet' -ScriptBlock {
			param($wordToComplete, $commandAst, $cursorPosition)
			dotnet complete --position $cursorPosition "$commandAst" |
				ForEach-Object {
					[System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
				}
		}
	}
	_showTime $currentNow 'checking/adding dotnet autocompletes'
}

if ($ackIsWindows) {
	# winget (https://github.com/microsoft/winget-cli/blob/master/doc/Completion.md#powershell)
	$currentNow = _getts
	if ((Get-Command -Name 'winget' -CommandType Application -ErrorAction Ignore)) {
		Register-ArgumentCompleter -Native -CommandName winget -ScriptBlock {
			param($wordToComplete, $commandAst, $cursorPosition)
			# don't think we need to tweak encodings for this:
			#[Console]::InputEncoding = [Console]::OutputEncoding = $OutputEncoding = [System.Text.Utf8Encoding]::new()
			$local:word = $wordToComplete.Replace('"', '""')
			$local:ast = $commandAst.ToString().Replace('"', '""')
			winget complete --word="$local:word" --commandline "$local:ast" --position $cursorPosition |
				ForEach-Object {
					[System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
				}
		}
	}
	_showTime $currentNow 'checking/adding winget autocompletes'

	$currentNow = _getts
	if ((Get-Command -Name 'dsc.exe' -CommandType Application -ErrorAction Ignore)) {
		dsc.exe completer powershell | Out-String | Invoke-Expression
	}
	_showTime $currentNow 'checking/adding dsc autocompletes'
}

# some more aliases:
if (-not [bool](Get-Alias -Name 'll' -ErrorAction Ignore)) {
	New-Alias -Name 'll' -Value 'Get-ChildItem'
}

if ($oldPath) {
	$env:PATH = $oldPath
	#Write-Host "restored path: |$env:PATH|"
}

_showTime $startNow 'total time loading Profile'
Remove-Item -Path $localFuncs -ErrorAction Ignore
Remove-Variable -Name $localVars -ErrorAction Ignore