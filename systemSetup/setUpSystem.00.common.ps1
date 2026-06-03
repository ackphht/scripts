Set-StrictMode -Version Latest

function Is64BitOs {
	[System.Environment]::Is64BitOperatingSystem
}

function InstallAllThePackages {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [PSObject[]] $packageList,
		[Parameter(Mandatory=$true)] [string] $windowsName
	)
	$needRestart = $false
	foreach ($pkg in $packageList) {
		Write-Verbose ''
		Write-Verbose ''
		Write-Verbose "$($MyInvocation.InvocationName): package=|$($pkg.packageName)|, packageType=|$($pkg.packageType)|, windowsVersions=|$($pkg.windowsVersions -join ',')|, skipSystems=|$($pkg.skipSystems -join ',')|"
		if ((-not $pkg.windowsVersions -or $pkg.windowsVersions -contains $windowsName) -and ($pkg.skipSystems -notcontains $env:ComputerName)) {
			switch ($pkg.packageType) {
				'AckApt' {
					_installAckAptPackage -packageToInstall $pkg
					break
				}
				'WindowsFeature' {
					$needRestart = (_installWindowsFeature -packageToInstall $pkg) -or $needRestart
					break
				}
				'PSModule' {
					_installPoshModule -packageToInstall $pkg
					break
				}
				'MSStore' {
					_installMsStorePackage -packageToInstall $pkg
					break
				}
				default {
					WriteErrorishMessage "Package name '$($pkg.packageName)' has an unrecognized package type: '$($pkg.packageType)'"
				}
			}
		} else {
			Write-Verbose "    the windowsVersion specifed |$($pkg.windowsVersions -join ',')| excludes installing on this os |$windowsName|, or the skipSystems specified, |$($pkg.skipSystems -join ',')|, includes this system |$env:ComputerName|"
		}
	}

	if ($needRestart) {
		Write-Host ''
		Write-Host ''
		WriteWarningishMessage 'one or more features have indicated that a system restart is needed. So, you know, do that.'
	}
}

function _installAckAptPackage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [PSObject] $packageToInstall
	)
	WriteStatusHeader
	Install-AckAptApplication $packageToInstall.packageName
}

function _installWindowsFeature {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory=$true)] [PSObject] $packageToInstall
	)
	$restartNeeded = $false
	WriteStatusHeader
	WriteStatusMessage "Installing Windows Feature '$($packageToInstall.packageName)'"
	if ($PSCmdlet.ShouldProcess($packageToInstall.packageName, 'Enable-WindowsOptionalFeature')) {
		$s = Enable-WindowsOptionalFeature -Online -All -NoRestart -FeatureName $packageToInstall.packageName
		if ($s.RestartNeeded) {
			WriteWarningishMessage "WindowsFeature '$($packageToInstall.packageName)' has indicated that a restart is needed after installation."
			$restartNeeded = $true
		}
	}
	return $restartNeeded
}

function _installPoshModule {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [PSObject] $packageToInstall
	)
	WriteStatusHeader
	WriteStatusMessage "Installing PowerShell Module '$($packageToInstall.packageName)'"
	Install-Module -Name $packageToInstall.packageName -Repository $packageToInstall.repository -Scope CurrentUser
}

function _installMsStorePackage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [PSObject] $packageToInstall
	)
	WriteStatusHeader
	WriteStatusMessage "Installing Microsoft Store App '$($packageToInstall.displayName)'"
	if ($PSCmdlet.ShouldProcess("$($packageToInstall.packageName) ($($packageToInstall.displayName))", 'winget.exe')) {
		winget.exe install --query $packageToInstall.packageName --id --exact --source msstore --accept-package-agreements
	}
}

function VerifyUsableVersionOfWinget {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([bool])]
	param ()
	$wingetCmd = Get-Command -Name 'winget.exe' -ErrorAction SilentlyContinue
	if ($wingetCmd) {
		# check that version is > 1.2; the exe apparently doesn't have version info, so have to run '--verison' to get it, ffs
		$ver = winget.exe --version
		if ($ver) {
			$ver = $ver.Trim('v')
			if (([Version]$ver) -ge ([Version]'1.3')) {
				Write-Verbose "$($MyInvocation.InvocationName): winget.exe version ($ver) looks usable"
				return $true
			}
			Write-Verbose "$($MyInvocation.InvocationName): winget.exe version not usable ($ver)"
		} else{
			Write-Verbose "$($MyInvocation.InvocationName): winget.exe version not found"
		}
	} else {
		Write-Verbose "$($MyInvocation.InvocationName): winget.exe not found"
	}
	return $false
}

function ReadListOfPackagesToInstall {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject[]])]
	param (
		[Parameter(Mandatory=$true)] [string] $packagesConfigPath,
		[ValidateSet('', 'AckApt', 'WindowsFeature', 'PSModule', 'MSStore')] [string] $type
	)

	$splitOn = @(',', '|', ':', ';')
	$packagesConfig = [xml] (Get-Content $packagesConfigPath)
	$packagesConfig.packages.package |
		Where-Object { -not [String]::IsNullOrWhiteSpace($_.name) } |
		Where-Object { -not $type -or $_.type -eq $type } |
		#select -first 10 |
		ForEach-Object {
			$props = @{ packageName = $_.name; packageType = $_.type; windowsVersions = @(); skipSystems = @(); repository = $null; displayName = $null; }
			if ($_.HasAttribute('windowsVersions') -and -not [String]::IsNullOrWhiteSpace($_.windowsVersions)) {
				#$props.windowsVersions = $_.windowsVersions -split { $_ -eq ',' -or $_ -eq '|' -or $_ -eq ':' -or $_ -eq ';' }
				$props.windowsVersions = $_.windowsVersions -split { $_ -in $splitOn }
			}
			if ($_.HasAttribute('skipSystems') -and -not [String]::IsNullOrWhiteSpace($_.skipSystems)) {
				#$props.skipSystems = $_.skipSystems -split { $_ -eq ',' -or $_ -eq '|' -or $_ -eq ':' -or $_ -eq ';' }
				$props.skipSystems = $_.skipSystems -split { $_ -in $splitOn }
			}
			if ($_.HasAttribute('repository') -and -not [String]::IsNullOrWhiteSpace($_.repository)) {
				$props.repository = $_.repository
			}
			if ($_.HasAttribute('displayName') -and -not [String]::IsNullOrWhiteSpace($_.displayName)) {
				$props.displayName = $_.displayName
			}
			Write-Verbose "$($MyInvocation.InvocationName): creating package: packageName=|$($props.packageName)|, packageType=|$($props.packageType)|, windowsVersions=|$($props.windowsVersions)|, skipSystems=|$($props.skipSystems)|"
			[PSCustomObject]$props
		}
}

#
# OBSOLETE: include setUpSystem.00.SystemData.ps1 and use Get-OSDetails
#
function GetWindowsVersionName {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([string])]
	param()

	$major = [Environment]::OsVersion.Version.Major; $minor = [Environment]::OsVersion.Version.Minor;
	Write-Verbose "G$($MyInvocation.InvocationName): `$major=$major, `$minor=$minor"
	# one other possibility here: just get the ProductName value from the above reg location: it will be "Windows 7 Professional" or "Windows 8.1 Pro" or "Windows Server 2012 R2 Standard"
	$windowsName = $null
	if ($major -lt 6) {
		Write-Verbose "    setting `$windowsName = Unsupported"
		$windowsName = 'Unsupported'
	} else {
		$edition = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'EditionID').EditionID
		Write-Verbose "    setting `$edition = |$edition|"
		if ($major -eq 6 -and $minor -eq 0) {
			$productType = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\ProductOptions' -Name 'ProductType').ProductType
			Write-Verbose "    setting `$productType = |$productType|"
			if ($productType -eq 'ServerNT') {
				# $edition can be: 'ServerStandard', '', '', ''
				Write-Verbose "    setting `$windowsName = Windows2008"
				$windowsName = 'Windows2008'
			} elseif ($productType -eq 'WinNT') {
				# $edition can be: 'HomeBasic', 'HomePremium', 'Business??', 'Ultimate'
				Write-Verbose "    setting `$windowsName = WindowsVista"
				$windowsName = 'WindowsVista'
			}
		} else {
			$installType = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'InstallationType').InstallationType
			Write-Verbose "    setting `$installType = |$installType|"
			if ($major -eq 6 -and $minor -eq 1) {
				if ('Server','Server Core' -contains $installType) {
					# $edition can be: 'ServerWeb', 'ServerStandard', 'ServerEnterprise', 'ServerDataCenter'
					Write-Verbose "    setting `$windowsName = Windows2008R2"
					$windowsName = 'Windows2008R2'
				} elseif ($installType -eq 'Client') {
					# $edition can be: 'Professional', 'HomeBasic', 'HomePremium', 'Starter', 'Ultimate', 'Enterprise??'
					Write-Verbose "    setting `$windowsName = Windows7"
					$windowsName = 'Windows7'
				}
			} elseif ($major -eq 6 -and $minor -gt 1 -and $minor -le 3) {
				if ('Server','Server Core' -contains $installType) {
					# $edition can be: 'ServerStandard', 'ServerDataCenter', ...
					Write-Verbose "    setting `$windowsName = Windows2012"
					$windowsName = 'Windows2012'   # includes R2; shouldn't need to distinguish them, right? if so, 6.2 is 2012, 6.3 is 2012R2
				} elseif ($installType -eq 'Client') {
					# $edition can be: 'Professional', 'ProfessionalWMC', 'Core' (for non-Pro), 'Enterprise??'
					Write-Verbose "    setting `$windowsName = Windows8"
					$windowsName = 'Windows8'      # includes 8.1; shouldn't need to distinguish them, right? if so, 6.2 is Win8, 6.3 is Win8.1
				}
			#} elseif ($major -eq 6 -and $minor -eq 4) {
			} elseif ($major -gt 6 -or ($major -eq 6 -and $minor -gt 3)) {
				Write-Verbose "    setting `$windowsName = Windows10"
				$windowsName = 'Windows10'
			} else {
				Write-Verbose "    setting `$windowsName = Unsupported (#2)"
				$windowsName = 'Unsupported'
			}
		}
	}
	$windowsName
}

$script:cachedAckSetupTempFolder = $null
function GetAckTempFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([string])]
	param()
	if ($script:cachedAckSetupTempFolder) { return $script:cachedAckSetupTempFolder }
	$tmpFolder = Join-Path ([System.IO.Path]::GetTempPath()) 'ackSetup'
	if (-not (Test-Path -Path $tmpFolder -PathType Container)) {
		Write-Verbose "$($MyInvocation.InvocationName): creating setup temp folder = |$tmpFolder|"
		[void](New-Item -Path $tmpFolder -ItemType Directory -Force)
	}
	$script:cachedAckSetupTempFolder = $tmpFolder
	return $tmpFolder
}

function LocateLgpoExe {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([string])]
	param()

	function _looksLikeValidLgpoExe {
		[CmdletBinding(SupportsShouldProcess=$false)]
		[OutputType([bool])]
		param([string] $path)
		if ($path) {
			$fi = Get-Item -Path $path -ErrorAction SilentlyContinue
			if ($fi -and $fi.VersionInfo.FileDescription -like '*Local Group Policy*') {	# ??
				$sig = Get-AuthenticodeSignature -FilePath $fi.FullName
				if ($sig.Status -eq [System.Management.Automation.SignatureStatus]::Valid -and `
					$sig.SignatureType -eq [System.Management.Automation.SignatureType]::Authenticode -and `
					$sig.SignerCertificate.Subject -like '*CN=Microsoft Corporation*')
				{
					return $true
				}
			}
		}
		return $false
	}

	$lgpoCmd = Get-Command -Name 'lgpo.exe' -ErrorAction SilentlyContinue
	Write-Verbose "$($MyInvocation.InvocationName): looking for already-installed lgpo.exe: found |$(if ($lgpoCmd) { $lgpoCmd.Path } else { '' })|"
	if ($lgpoCmd -and (_looksLikeValidLgpoExe -path $lgpoCmd.Path)) {
		Write-Verbose "$($MyInvocation.InvocationName): returning already-installed lgpo.exe: |$($lgpoCmd.Path)|"
		return $lgpoCmd.Path
	}
	# see if there's one in same folder as script, in case i go that route:
	$scriptFldrLgpo = Join-Path $PSScriptRoot 'lgpo.exe'
	if ((_looksLikeValidLgpoExe -path $scriptFldrLgpo)) {
		Write-Verbose "$($MyInvocation.InvocationName): returning lgpo.exe from same folder as scripts: |$scriptFldrLgpo|"
		return $scriptFldrLgpo
	}
	# see if we already have a downloaded one:
	$tmpFolder = Join-Path (GetAckTempFolder) 'lgpo'
	$tmpExePath = Join-Path $tmpFolder 'lgpo.exe'
	Write-Verbose "$($MyInvocation.InvocationName): looking for already-downloaded lgpo.exe |$tmpExePath|"
	if (_looksLikeValidLgpoExe -path $tmpExePath) {
		Write-Verbose "$($MyInvocation.InvocationName): returning already-downloaded lgpo.exe |$tmpExePath|"
		return $tmpExePath
	}
	# reset our temp folder:
	if (Test-Path -Path $tmpFolder -PathType Container) {
		Write-Verbose "$($MyInvocation.InvocationName): removing existing lgpo temp folder |$tmpFolder|"
		Remove-Item -Path $tmpFolder -Recurse -Force
	}
	Write-Verbose "$($MyInvocation.InvocationName): creating lgpo temp folder |$tmpFolder|"
	[void](New-Item -Path $tmpFolder -ItemType Directory -Force)
	# download lgpo.zip:
	$lgpoDownloadUrl = 'https://download.microsoft.com/download/8/5/C/85C25433-A1B0-4FFA-9429-7E023E7DA8D8/LGPO.zip'
	$tmpZipPath = Join-Path $tmpFolder 'lgpo.zip'
	Write-Verbose "downloading |$lgpoDownloadUrl| to file |$tmpZipPath|"
	if ($PSCmdlet.ShouldProcess('download and extract LGPO.exe', $lgpoDownloadUrl, 'Invoke-WebRequest')) {
		Invoke-WebRequest -Method Get -Uri $lgpoDownloadUrl -OutFile $tmpZipPath
		Unblock-File -Path $tmpZipPath		# just in case
		# extract the exe:
		$lgpoArchive = [System.IO.Compression.ZipFile]::OpenRead($tmpZipPath)
		try {
			$lgpoExeEntry = $lgpoArchive.Entries | Where-Object { $_.Name -eq 'lgpo.exe' }
			if (-not $lgpoExeEntry) {
				Write-Warning "could not find lgpo.exe in downloaded zip file `"$tmpZipPath`""
				return ''
			}
			[System.IO.Compression.ZipFileExtensions]::ExtractToFile($lgpoExeEntry, $tmpExePath)
		} finally {
			if ($lgpoArchive) { $lgpoArchive.Dispose() }
		}
		# make sure it's okay:
		if (_looksLikeValidLgpoExe -path $tmpExePath) {
			return $tmpExePath
		} else {
			Write-Warning "downloaded lgpo.exe does not appear to be a valid one: `"$tmpExePath`""
			return ''
		}
	} else {
		return $tmpExePath
	}
}

function WriteStatusMessage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [string] $message
	)
	Write-Host
	WriteFullWidthMessage -message $message -ForegroundColor Green -BackgroundColor Black
}

function WriteStatusHeader {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param()
	WriteStatusMessage ''.PadLeft(80, '#')
}

function WriteErrorishMessage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [string] $message
	)
	Write-Host ''
	WriteFullWidthMessage -message $message -foregroundColor Red -backgroundColor Black
}

function WriteWarningishMessage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [string] $message
	)
	Write-Host ''
	WriteFullWidthMessage -message $message -foregroundColor Yellow -backgroundColor Black
}

function WriteFullWidthMessage {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		<#[Parameter(Mandatory=$true)]#> [string] $message,
		[Parameter(Mandatory=$true)] [System.ConsoleColor] $foregroundColor,
		[Parameter(Mandatory=$true)] [System.ConsoleColor] $backgroundColor
	)
	#
	# what was the point of this again?
	#
	if ($host -and $host.UI -and $host.UI.RawUI -and $host.UI.RawUI.WindowSize) {
		Write-Host $message.PadRight(($host.UI.RawUI.WindowSize.Width - 1)) -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
	} else {
		Write-Host ''	# ???
	}
}
