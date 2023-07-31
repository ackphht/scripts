#[CmdletBinding(SupportsShouldProcess=$true)]
#param()

#region safety checks
if (-not ($PSEdition -ne 'Core' -or $IsWindows)) {
	Write-Warning "this module is only for Windows"
	return
}
if (-not ([bool](Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue))) {
	Write-Warning "winget.exe not found"
	return
}
#endregion

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

#region check if Microsoft.WinGet.Client is available and usable
function _checkWinGetClientModule {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([bool])]
	param([psmoduleinfo] $module)
	$versionOkay = $false
	if ($module) {
		# test that it actually works (still alpha/beta, getting errors on some systems):
		try {
			Write-Verbose "testing Get-WinGetSource to see if WinGet.Client module is usable"
			[void] (Get-WinGetSource -Name 'winget' -ErrorAction Stop)
			Write-Verbose "Get-WinGetSource looks okay, enabling module"
			$versionOkay = $true
		} catch [System.Reflection.TargetInvocationException],[System.TypeLoadException] {
			Write-Verbose "got exception trying to call Get-WinGetSource; disabling module"
		} catch {
			Write-Error "unexpected exception trying to call Get-WinGetSource:`n$($_.Exception)"
		}
		if ($versionOkay) {
			# make sure our updated formatting info is read before theirs:
			Update-FormatData -PrependPath (Join-Path -Path $PSScriptRoot -ChildPath 'Format.ps1xml')
		} else {
			# this doesn't actually seem to be removing it, but we'll try:
			Remove-Module -ModuleInfo $module -Force
		}
	}
	return ($versionOkay)
}
$wgClientModuleName = 'Microsoft.WinGet.Client'
$wgClientModule = Import-Module -Name $wgClientModuleName -PassThru -ErrorAction SilentlyContinue
$wgModuleAvailable = _checkWinGetClientModule -module $wgClientModule
Write-Verbose "`$wgModuleAvailable = |$wgModuleAvailable|"
Remove-Variable -Name 'wgClientModuleName','wgClientModule'
#endregion

<#
NOTE: WhatIfPreference and other preference vars don't propagate into module cmdlets/functions, so have to do a hacky check to read
	them from caller in each cmdlet/function that needs it (can't use a helper function for it because that's a new scope); ugh:
		if it's specified explicitly in the call to the cmdlet/function, use that; otherwise look up the caller's pref
	see https://devblogs.microsoft.com/scripting/weekend-scripter-access-powershell-preference-variables/
#>

function Get-AckWingetInstalledPackages {
	<#
		.SYNOPSIS
		Calls winget to list the currently installed packages on the system

		.DESCRIPTION
		Calls winget to list the currently installed packages on the system. This can list all packages,
		or can be limited to a given package search term

		.PARAMETER query
		optional value to search for

		.PARAMETER source
		limits the results to the specified source, either 'winget' or 'msstore'.
		(This doesn't really seem to do anything, but included just in case i'm missing something...)

		.PARAMETER maxCount
		limits the results to the specified count

		Note: winget's results are unsorted and if this is specified, it just returns the first X number of results,
		whatever those are. Any apparent sorting of the results is done by this script on whatever results winget returned.

		.PARAMETER byId
		if a query param is specified, this switch parameter will limit the search to winget IDs

		.PARAMETER byName
		if a query param is specified, this switch parameter will limit the search to winget names

		.OUTPUTS
		a list of winget results
	#>
	[CmdletBinding(DefaultParameterSetName='searchByAny')]
	[OutputType([void])]
	param(
		[Parameter(Position=0)]
		[Alias('qry')] [string] $query,

		[ValidateSet('', 'winget', 'msstore')]
		[Alias('src')] [string] $source = '',		# this doesn't seem to actually do anything...

		[Alias('c', 'cnt')] [int] $maxCount = 0,

		[Parameter(ParameterSetName='searchById')]
		[Alias('i', 'id')] [switch] $byId,

		[Parameter(ParameterSetName='searchByName')]
		[Alias('n', 'nm', 'name')] [switch] $byName
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	if ($wgModuleAvailable) {
		Write-Verbose '$wgModuleAvailable is true, using WinGet.Client cmdlets'
		$parms = @{}
		if ($query) {
			if ($byId) { $parms.Add('Id', $query) } elseif ($byName) { $parms.Add('Name', $query) } else { $parms.Add('Query', $query) }
		}
		#$parms.Add('MatchOption', 'EqualsCaseInsensitive')		???
		if ($source) { $parms.Add('Source', $source) }
		if ($maxCount -gt 0) { $parms.Add('Count', $maxCount) }
		$parms.Add('ErrorAction', $ErrorActionPreference)
		$parms.Add('Verbose', $VerbosePreference)

		Write-Verbose "$($MyInvocation.InvocationName): Get-WinGetPackage parameters: |$($parms.GetEnumerator())|"
		Get-WinGetPackage @parms | Sort-Object -Property 'Name'
	} else {
		Write-Verbose '$wgModuleAvailable is false, using winget.exe'
		$cmd = 'winget.exe list'
		if ($query) {
			if ($byId) { $cmd += ' --id ' } elseif ($byName) { $cmd += ' --name ' } else { $cmd += ' --query ' }
			$cmd += $query
		}
		if ($source) { $cmd += " --source $source" }
		if ($maxCount -gt 0) { $cmd += " --count $maxCount" }

		Write-Verbose "$($MyInvocation.InvocationName): command = |$cmd|"
		$list = _invokeWingetCommand -command $cmd
		_sortAndWriteOutput -list $list
	}
}

function Get-AckWingetPackageDetails {
	<#
		.SYNOPSIS
		Gets the details of the specified winget package

		.DESCRIPTION
		Gets the details of the specified winget package by ID (the default), or by name

		.PARAMETER query
		the ID of the package to show (or the name, if -byName param is used)

		.PARAMETER source
		limits the results to the specified source, either 'winget' or 'msstore'

		.PARAMETER byName
		switch parameter to search by winget name

		.OUTPUTS
		the details of the winget package
	#>
	[CmdletBinding(DefaultParameterSetName='searchByAny')]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('qry')] [string] $query,

		[ValidateSet('', 'winget', 'msstore')]
		[Alias('src')] [string] $source = '',

		[Parameter(ParameterSetName='searchByName')]
		[Alias('n', 'nm', 'name')] [switch] $byName
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	# no Microsoft.WinGet.Client cmdlet for this one (yet?):
	Write-Verbose 'no WinGet.Client cmdlet for this, using winget.exe'
	$cmd = 'winget.exe show '
	if ($byName) { $cmd += '--name ' } else { $cmd += '--id ' }
	$cmd += $query
	if ($source) { $cmd += " --source $source" }

	Write-Verbose "$($MyInvocation.InvocationName): command = |$cmd|"
	_invokeWingetCommand -command $cmd
}

function Get-AckWingetOutdatedPackages {
	<#
		.SYNOPSIS
		Lists packages which have an upgrade available

		.DESCRIPTION
		Lists packages which have an upgrade available

		.PARAMETER source
		limits the results to the specified source, either 'winget' or 'msstore'

		.OUTPUTS
		the list of packages for which an upgrade is available
	#>
	[CmdletBinding(DefaultParameterSetName='searchByAny')]
	[OutputType([void])]
	param(
		[ValidateSet('', 'winget', 'msstore')]
		[Alias('src')] [string] $source = ''
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	# no Microsoft.WinGet.Client cmdlet for this one (yet?):
	Write-Verbose 'no WinGet.Client cmdlet for this, using winget.exe'
	$cmd = 'winget.exe list --upgrade-available'
	if ($source) { $cmd += " --source $source" }

	Write-Verbose "$($MyInvocation.InvocationName): command = |$cmd|"
	$list = _invokeWingetCommand -command $cmd
	_sortAndWriteOutput -list $list
}

function Install-AckWingetPackage {
	<#
		.SYNOPSIS
		Calls winget to install a package using its specified ID

		.DESCRIPTION
		Calls winget to install a package using its specified ID

		.PARAMETER packageId
		the Winget ID of the package to install

		.PARAMETER exactIdMatch
		by default, the packageId param is searched for case-insensitively and partially, and if only one result is found that will be installed.
		Specifying this param will turn on exact matching for the ID.

		.PARAMETER version
		optional version to be installed; if not specified, winget will install the latest version available

		.PARAMETER scope
		If a package has both a machine and a user install available, this can be used to specify which one to install.

		.PARAMETER source
		limits finding the package to the specified source, either 'winget' or 'msstore' (this is passed to the winget '--source' param).
		If nothing is specified, then any winget source can be used.

		.PARAMETER installerArguments
		if anything is specified, it will be passed to the winget '--override' parameter to pass on to the installer.
		NOTE: Passing anything here appears to also imply '--interactive', so if you really want a completely silent install,
		you'll need to pass that argument to the installer also

		.PARAMETER forceSilent
		by default, this script wlll pass '--interactive' to winget because i hate completely silent invisible installs.
		If that's what you want, though, specify this switch (see Note for installerArguments, though)

		.OUTPUTS
		whatever winget.exe outputs
	#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('id')] [string] $packageId,

		[Alias('exact')] [switch] $exactIdMatch,

		[string] $version = $null,

		[ValidateSet('', 'machine', 'user')]
		[string] $scope = '',

		[ValidateSet('', 'winget', 'msstore')]
		[string] $source = '',

		[Alias('args')] [string] $installerArguments = $null,

		[switch] $forceSilent
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	if (-not $PSBoundParameters.ContainsKey('WhatIf')) { $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference') }
	if ($wgModuleAvailable) {
		Write-Verbose '$wgModuleAvailable is true, using WinGet.Client cmdlets'
		$parms = @{}
		$parms.Add('Id', $packageId)
		if ($exactIdMatch) { $parms.Add('MatchOption', 'Equals') }
		if ($version) { $parms.Add('Version', $version) }
		if ($scope) { $parms.Add('Scope', $scope) }
		if ($source) { $parms.Add('Source', $source) }
		if ($forceSilent -and -not $installerArguments) {	# using --override with installer arguments apparently also implicitly implies --interactive
			$parms.Add('Mode', 'Silent')
		} else {
			$parms.Add('Mode', 'Interactive')
		}
		if ($installerArguments) {
			#$escArgs = $installerArguments -replace '"','""""'	# escape one double quote to four
			$parms.Add('Override', $installerArguments)		# shouldn't need to escape anything, right?
		}
		$parms.Add('ErrorAction', $ErrorActionPreference)
		$parms.Add('Verbose', $VerbosePreference)
		if ($WhatIfPreference) { $parms.Add('WhatIf', $null) }

		Write-Verbose "$($MyInvocation.InvocationName): Install-WinGetPackage parameters: |$($parms.GetEnumerator())|"
		Install-WinGetPackage @parms
	} else {
		Write-Verbose '$wgModuleAvailable is false, using winget.exe'
		_installWingetPackage @PSBoundParameters
	}
}

function Search-AckWingetPackages {
	<#
		.SYNOPSIS
		Searches winget for the specified package

		.DESCRIPTION
		Searches winget for the specified package, by id, by name, or by anything (the default).

		.PARAMETER query
		the value to search for

		.PARAMETER source
		limits the results to the specified source, either 'winget' or 'msstore'

		.PARAMETER maxCount
		limits the results to the specified count

		Note: winget's results are unsorted and if this is specified, it just returns the first X number of results,
		whatever those are. Any apparent sorting of the results is done by this script on whatever results winget returned.

		.PARAMETER byId
		switch parameter to limit the search to winget IDs

		.PARAMETER byName
		switch parameter to limit the search to winget names

		.OUTPUTS
		a list of winget results
	#>
	[CmdletBinding(DefaultParameterSetName='searchByAny')]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('qry')] [string] $query,

		[ValidateSet('', 'winget', 'msstore')]
		[Alias('src')] [string] $source = '',

		[Alias('c', 'cnt')] [int] $maxCount = 0,

		[Parameter(ParameterSetName='searchById')]
		[Alias('i', 'id')] [switch] $byId,

		[Parameter(ParameterSetName='searchByName')]
		[Alias('n', 'nm', 'name')] [switch] $byName
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	if ($wgModuleAvailable) {
		Write-Verbose '$wgModuleAvailable is true, using WinGet.Client cmdlets'
		$parms = @{}
		if ($byId) { $parms.Add('Id', $query) } elseif ($byName) { $parms.Add('Name', $query) } else { $parms.Add('Query', $query) }
		#$parms.Add('MatchOption', 'EqualsCaseInsensitive')		???
		if ($source) { $parms.Add('Source', $source) }
		if ($maxCount -gt 0) { $parms.Add('Count', $maxCount) }
		$parms.Add('ErrorAction', $ErrorActionPreference)
		$parms.Add('Verbose', $VerbosePreference)

		Write-Verbose "$($MyInvocation.InvocationName): Find-WinGetPackage parameters: |$($parms.GetEnumerator())|"
		Find-WinGetPackage @parms | Sort-Object -Property 'Name'
	} else {
		Write-Verbose '$wgModuleAvailable is false, using winget.exe'
		$cmd = 'winget.exe search '
		if ($byId) { $cmd += '--id ' } elseif ($byName) { $cmd += '--name ' } else { $cmd += '--query ' }
		$cmd += $query
		if ($source) { $cmd += " --source $source" }
		if ($maxCount -gt 0) { $cmd += " --count $maxCount" }

		Write-Verbose "$($MyInvocation.InvocationName): command = |$cmd|"
		$list = _invokeWingetCommand -command $cmd
		_sortAndWriteOutput -list $list
	}
}

function Show-AckWingetPackageRepository {
	<#
		.SYNOPSIS
		Opens the GitHub repository for the winget package

		.DESCRIPTION
		Opens the GitHub repository for the winget package

		.PARAMETER packageId
		the Winget ID of the package to show
	#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('id')] [string] $packageId
	)
	$prefix = $packageId.Substring(0, 1).ToLowerInvariant()
	$path = $packageId.Replace('.', '/')
	Start-Process -FilePath "https://github.com/microsoft/winget-pkgs/tree/master/manifests/${prefix}/${path}"
}

function Uninstall-AckWinGetPackage {
	<#
		.SYNOPSIS
		Calls winget to uninstall a package using its specified ID

		.DESCRIPTION
		Calls winget to uninstall a package using its specified ID

		.PARAMETER packageId
		the Winget ID of the package to uninstall. This Id must match exactly an installed package.

		.PARAMETER version
		optional version to be uninstalled; if not specified, winget will uninstall the latest version available ?? or everything ??

		.PARAMETER source
		limits finding the package to the specified source, either 'winget' or 'msstore' (this is passed to the winget '--source' param).
		If nothing is specified, then any winget source can be used.

		.PARAMETER forceSilent
		by default, this script wlll pass '--interactive' to winget because i hate completely silent invisible installs.
		If that's what you want, though, specify this switch

		.OUTPUTS
		whatever winget.exe outputs
	#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('id')] [string] $packageId,

		[string] $version = $null,

		[ValidateSet('', 'winget', 'msstore')]
		[string] $source = '',

		[switch] $forceSilent
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	if (-not $PSBoundParameters.ContainsKey('WhatIf')) { $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference') }
	if ($wgModuleAvailable) {
		Write-Verbose '$wgModuleAvailable is true, using WinGet.Client cmdlets'
		$parms = @{}
		$parms.Add('Id', $packageId)
		$parms.Add('MatchOption', 'Equals')		# for uninstall we'll always require exact match
		if ($version) { $parms.Add('Version', $version) }
		if ($source) { $parms.Add('Source', $source) }
		if ($forceSilent) { $parms.Add('Mode', 'Silent') } else { $parms.Add('Mode', 'Interactive') }
		$parms.Add('ErrorAction', $ErrorActionPreference)
		$parms.Add('Verbose', $VerbosePreference)
		if ($WhatIfPreference) { $parms.Add('WhatIf', $null) }

		Write-Verbose "$($MyInvocation.InvocationName): Uninstall-WinGetPackage parameters: |$($parms.GetEnumerator())|"
		Uninstall-WinGetPackage @parms
	} else {
		Write-Verbose '$wgModuleAvailable is false, using winget.exe'
		$cmd = "winget.exe uninstall --id $packageId --exact"
		if ($version) { $cmd += " --version $version" }
		if ($source) { $cmd += " --source $source" }
		if (-not $forceSilent) { $cmd += ' --interactive' }

		Write-Verbose "$($MyInvocation.InvocationName): command = |$cmd|"
		_invokeWingetCommand -command $cmd
	}
}

function Update-AckWingetPackage {
	<#
		.SYNOPSIS
		Calls winget to upgrade a package using its specified ID

		.DESCRIPTION
		Calls winget to upgrade a package using its specified ID

		.PARAMETER packageId
		the Winget ID of the package to upgrade

		.PARAMETER exactIdMatch
		by default, the packageId param is searched for case-insensitively and partially, and if only one result is found that will be installed.
		Specifying this param will turn on exact matching for the ID.

		.PARAMETER version
		optional version to be installed; if not specified, winget will install the latest version available

		.PARAMETER source
		limits finding the package to the specified source, either 'winget' or 'msstore' (this is passed to the winget '--source' param).
		If nothing is specified, then any winget source can be used.

		.PARAMETER installerArguments
		if anything is specified, it will be passed to the winget '--override' parameter to pass on to the installer.
		NOTE: Passing anything here appears to also imply '--interactive', so if you really want a completely silent install,
		you'll need to pass that argument to the installer also

		.PARAMETER forceSilent
		by default, this script wlll pass '--interactive' to winget because i hate completely silent invisible installs.
		If that's what you want, though, specify this switch (see Note for installerArguments, though)

		.OUTPUTS
		whatever winget.exe outputs
	#>
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$true)]
		[Alias('id')] [string] $packageId,

		[Alias('exact')] [switch] $exactIdMatch,

		[string] $version = $null,

		[ValidateSet('', 'winget', 'msstore')]
		[string] $source = '',

		[Alias('args')] [string] $installerArguments = $null,

		[switch] $forceSilent
	)
	if (-not $PSBoundParameters.ContainsKey('ErrorAction')) { $ErrorActionPreference = $PSCmdlet.GetVariableValue('ErrorActionPreference') }
	if (-not $PSBoundParameters.ContainsKey('Verbose')) { $VerbosePreference = $PSCmdlet.GetVariableValue('VerbosePreference') }
	if (-not $PSBoundParameters.ContainsKey('WhatIf')) { $WhatIfPreference = $PSCmdlet.GetVariableValue('WhatIfPreference') }
	if ($wgModuleAvailable) {
		Write-Verbose '$wgModuleAvailable is true, using WinGet.Client cmdlets'
		$parms = @{}
		$parms.Add('Id', $packageId)
		if ($exactIdMatch) { $parms.Add('MatchOption', 'Equals') }
		if ($version) { $parms.Add('Version', $version) }
		if ($source) { $parms.Add('Source', $source) }
		if ($forceSilent -and -not $installerArguments) {	# using --override with installer arguments apparently also implicitly implies --interactive
			$parms.Add('Mode', 'Silent')
		} else {
			$parms.Add('Mode', 'Interactive')
		}
		if ($installerArguments) {
			#$escArgs = $installerArguments -replace '"','""""'	# escape one double quote to four
			$parms.Add('Override', $installerArguments)		# shouldn't need to escape anything, right?
		}
		$parms.Add('ErrorAction', $ErrorActionPreference)
		$parms.Add('Verbose', $VerbosePreference)
		if ($WhatIfPreference) { $parms.Add('WhatIf', $null) }

		Write-Verbose "$($MyInvocation.InvocationName): Update-WinGetPackage parameters: |$($parms.GetEnumerator())|"
		Update-WinGetPackage @parms
	} else {
		Write-Verbose '$wgModuleAvailable is false, using winget.exe'
		_installWingetPackage -upgrade @PSBoundParameters
	}
}

#region helper functions
function _invokeWingetCommand {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([string[]])]
	param(
		[Parameter(Position=0, Mandatory=$true)] [string] $command
	)
	# winget outputs in utf8, but if you capture the output, posh/console apparently treats
	# it as ansi, and mojibake ensues; so switch console to utf8 temporarily:
	$currEncoding = [System.Console]::OutputEncoding
	[System.Console]::OutputEncoding = [System.Text.Encoding]::UTF8
	try {
		return Invoke-Expression -Command $command
	} finally {
		[System.Console]::OutputEncoding = $currEncoding
	}
}

function _installWingetPackage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[switch] $upgrade,

		[Parameter(Position=0, Mandatory=$true)]
		[string] $packageId,

		[switch] $exactIdMatch,

		[string] $version = $null,

		[string] $scope = $null,

		[string] $source = $null,

		[string] $installerArguments = '',

		[switch] $forceSilent
	)

	Write-Verbose "$($MyInvocation.InvocationName): beginning processing for id '$packageId' (upgrade = |$upgrade|, version = |$version|, scope = |$scope|, source = |$source|, forceSilent = |$forceSilent|, installerArguments = |$installerArguments|)"

	$sb = [System.Text.StringBuilder]::new(512)
	[void] $sb.Append('winget.exe')
	if ($upgrade) { [void] $sb.Append(' upgrade') } else { [void] $sb.Append(' install') }
	[void] $sb.Append(' --id ').Append($packageId)
	if ($exactIdMatch) { [void] $sb.Append(' --exact') }
	if ($version) { [void] $sb.Append(' --version "').Append($version).Append('"') }
	if ($scope) { [void] $sb.Append(' --scope ').Append($scope) }
	if ($source) { [void] $sb.Append(' --source ').Append($source) }
	[void] $sb.Append(' --accept-package-agreements')
	[void] $sb.Append(' --accept-source-agreements')
	if (-not $forceSilent -or $installerArguments) {
		# using --override with installer arguments apparently also implicitly implies --interactive, but we'll add it anyway:
		[void] $sb.Append(' --interactive')
	}
	if ($installerArguments) {
		$escArgs = $installerArguments -replace '"','""""'	# escape one double quote to four
		[void] $sb.Append(' --override "').Append($escArgs).Append('"')
	}
	$commandLine = $sb.ToString()

	Write-Verbose "$($MyInvocation.InvocationName): winget command:`n$commandLine"
	if ($PSCmdlet.ShouldProcess($commandLine, 'Invoke-Expression')) {
		Invoke-Expression -Command $commandLine
		Write-Verbose "$($MyInvocation.InvocationName): exit code from winget: $LASTEXITCODE"
	}
}

function _sortAndWriteOutput {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Position=0, Mandatory=$false)] [string[]] $list
	)
	if (-not $list) { return }
	# capturing the output from winget also includes its little progress thingy in the
	# first couple(?) lines, so figure out where the list and headers actually starts:
	$skipJunk = 0
	for ($indx = 0; $indx -lt $list.Count; ++$indx) {
		$line = $list[$indx]
		if ($line.StartsWith('Name ')) {
			$skipJunk = $indx
			break
		}
	}
	$hasTruncatedMsg = $false; $hasAvailableMsg = $false;
	if ($list[($list.Length - 1)].StartsWith('<additional entries truncated')) { $hasTruncatedMsg = $true }
	elseif ($list[($list.Length - 1)] -match '\d+ upgrades available') { $hasAvailableMsg = $true }

	Write-Verbose "$($MyInvocation.InvocationName): returned $($list.Length) lines, `$skipJunk = $skipJunk, `$hasTruncatedMsg = $hasTruncatedMsg"

	$startIndex = $skipJunk + 2
	$actualListLength = $list.Length - $startIndex - $(if ($hasTruncatedMsg -or $hasAvailableMsg) { 1 } else { 0 })

	Write-Output $list[$skipJunk]
	Write-Output $list[$skipJunk + 1]
	$list | Select-Object -Skip $startIndex -First $actualListLength | Sort-Object
	if ($hasTruncatedMsg -or $hasAvailableMsg) {
		Write-Output $list[($list.Length - 1)]
	}
}
#endregion

#region add aliases:
Set-Alias -Name 'wgs' -Value 'Search-AckWingetPackages'
Set-Alias -Name 'wgl' -Value 'Get-AckWingetInstalledPackages'
Set-Alias -Name 'wgsh' -Value 'Get-AckWingetPackageDetails'
Set-Alias -Name 'wgi' -Value 'Install-AckWingetPackage'
Set-Alias -Name 'wgx' -Value 'Uninstall-AckWinGetPackage'
Set-Alias -Name 'wgul' -Value 'Get-AckWingetOutdatedPackages'
Set-Alias -Name 'wgu' -Value 'Update-AckWingetPackage'
Set-Alias -Name 'wgr' -Value 'Show-AckWingetPackageRepository'
#endregion