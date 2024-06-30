#Requires -Version 5.1

#[CmdletBinding(SupportsShouldProcess=$false)]
#param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# use full path in case we're not PSModulePath:
Import-Module -Name "$PSScriptRoot/../ackPoshHelpers" -ErrorAction Stop

class OSDetails {
	[string] $Platform			# 'Windows' or 'Linux' or 'MacOS'
	[string] $Id				# e.g. 'win.10', 'win.8.1', 'mac.13', 'mac.10.15'
	[string] $Description		# e.g. 'Microsoft Windows 10 Pro'
	[string] $Release			# e.g. 'Vista SP2', '7 SP1', '8.1', '10 1709', '11', '11 22H2'	# <- for bagOS, just the os version (13.2.1), for Linux, the distro version
	[System.Version] $ReleaseVersion # e.g. 10.0.16299.723; Linux, MacOS have different versions for the OS itself and for the kernel
	[string] <# [System.Version] #> $KernelVersion	 # e.g. 10.0.16299.723; Linux has stupid looking versions so this can't be [System.Version]
	[string] $BuildNumber
	[UInt32] $UpdateRevision	# non-core posh doesn't recognize [uint]; Windows' UBR (UpdateBuildRevision)
	[string] $Distributor		# e.g. 'Microsoft Corporation', 'Apple', 'Ubuntu', 'Fedora', etc
	[string] $Codename
	[string] $Type				# e.g. 'WorkStation', 'Server'
	[string] $Edition			# e.g. 'Professional', 'Home', etc
	[string] $OSArchitecture	# e.g. 'x86_64', 'Arm64'
	[bool] $Is64BitOS
	#[DateTime] $OSInstallTime
	#[DateTime] $OSStartTime

	OSDetails() {
		$this.Platform = $this.Id = $this.Description = $this.Release = $this.Distributor = $this.Codename = $this.Type = $this.Edition = [System.String]::Empty
		$this.BuildNumber = '0'
		$this.KernelVersion = '0.0.0' #[System.Version]::new(0, 0)
		$this.UpdateRevision = [UInt32]0
		#$this.OSInstallTime = $this.OSStartTime = [System.DateTime]::MinValue

		$this.OSArchitecture = _getOSArchitecture
		$this.Is64BitOS = [System.Environment]::Is64BitOperatingSystem
	}
}

$script:cachedOsDetails = $null		# it's not going to change, so...
function Get-OSDetails {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([OSDetails])]
	param()

	if ($script:cachedOsDetails) {
		WriteVerboseMessage 'returning cached OSDetails'
		return $script:cachedOsDetails
	}

	WriteVerboseMessage 'populating OS details'

	$result = [OSDetails]::new()
	$result.Platform = _getPlatform
	switch ($result.Platform) {
		'Windows' { _populateWindowsInfo -osDetails $result; break; }
		'Linux' { _populateLinuxInfo -osDetails $result; break; }
		'MacOS' { _populateMacOSInfo -osDetails $result; break; }
	}

	$script:cachedOsDetails = $result
	return $result
}

function _populateWindowsInfo {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([void])]
	param([Parameter(Mandatory=$true)] [OSDetails] $osDetails)

	if (Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue) {
		$osinfo = Get-CimInstance -ClassName 'CIM_OperatingSystem'
	} else {
		# (much) older versions
		$osinfo = Get-WmiObject -Class 'Win32_OperatingSystem'
	}

	$osInfoLookups = (_loadOsInfoLookups).windows

	$osDetails.Description = $osinfo.Caption
	$osDetails.Distributor = $osinfo.Manufacturer
	$osDetails.BuildNumber = $osinfo.BuildNumber.ToString()
	#$osDetails.OSInstallTime = $osinfo.InstallDate
	#$osDetails.OSStartTime = $osinfo.LastBootUpTime
	$osDetails.Type = if ($osinfo.ProductType -eq 3) { 'Server' } else { 'WorkStation' }
	$kernelVersion = _getWindowsKernelVersion
	$osDetails.KernelVersion = $kernelVersion.ToString()
	$osDetails.UpdateRevision = $kernelVersion.Revision
	$release = _getWindowsRelease -wmios $osinfo -ubr $kernelVersion.Revision -lookups $osInfoLookups
	# TODO: right now, we're setting $osDetails.Release like '11.22H2', '11', '10.2009', '8.1', '7.SP1', etc;
	# is that really how we want it? other OSes are just the release version, maybe for Win, should be simpler
	# or maybe other OSes should include more?
	$osDetails.Release = $release
	$osDetails.Id = _getWindowsId -wmios $osinfo -release $release
	$osDetails.Edition = _getWindowsEdition -cimOsSku $osinfo.OperatingSystemSKU -cimOsCaption $osinfo.Caption -lookups $osInfoLookups
	$osDetails.ReleaseVersion = _getWindowsVersion -kernelVersion $kernelVersion -lookups $osInfoLookups
	#$osDetails.MajorMinor = $osDetails.KernelVersion.ToString(2)
	$osDetails.Codename = _getWindowsCodename -wmios $osinfo -lookups $osInfoLookups
}

function _populateLinuxInfo {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([void])]
	param([Parameter(Mandatory=$true)] [OSDetails] $osDetails)

	$distId,$description,$release,$codename = _getLinuxReleaseProps
	$releaseLooksLikeVersion = _looksLikeVersion -version $release
	# special case(s):
	if ($distId -eq 'debian' -and $release -match '^\d+$' -and (Test-Path -Path '/etc/debian_version' -PathType Leaf)) {
		# Debian's os-release VERSION_ID is too simple, so let's try to get debian_version:
		$release = Get-Content -Path '/etc/debian_version' -Raw
		$release = $release.Trim()
	}

	if ($distId) { $osDetails.Distributor = [System.Globalization.CultureInfo]::CurrentCulture.TextInfo.ToTitleCase($distId) }
	if ($releaseLooksLikeVersion -and -not $description.Contains($release)) { $osDetails.Description = '{0} {1}' -f $description,$release } else { $osDetails.Description = $description }
	$osDetails.Release = $release
	$osDetails.Codename = $codename
	if ($releaseLooksLikeVersion) {
		$osDetails.Id = 'linux.{0}.{1}' -f $distId.ToLower(),$release
		$osDetails.ReleaseVersion = _convertVersion -version $release
	} else {
		$osDetails.Id = 'linux.{0}' -f $distId.ToLower()
	}
	$osDetails.KernelVersion = _getLinuxKernelVersion #(uname --kernel-release)
	<#
	$osDetails.OSInstallTime = _getLinuxInstallDatetime
	# try to get last boot time:
	$uptime = uptime -s 2>/dev/null		# opensuse doesn't support -s; and no idea how to parse the basic command's crap; they all do that different of course
	if ($LASTEXITCODE -ne 0) {
		$tmp = who -b 2>/dev/null
		if ($LASTEXITCODE -eq 0) {
			$m = [regex]::Match($tmp, '^\s*system boot\s+(?<ts>\d\d\d\d-\d\d-\d\d \d\d:\d\d).*$')
			if ($m.Success) { $uptime = $m.Groups['ts'].Value + ':00' }
		}
	}
	if ($uptime) {
		$osDetails.OSStartTime = [System.DateTime]::ParseExact($uptime, 'yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::CurrentCulture)
	}
	#>
	#$osDetails.BuildNumber = ???
	#$osDetails.UpdateRevision = ???
}

function _populateMacOSInfo {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([void])]
	param([Parameter(Mandatory=$true)] [OSDetails] $osDetails)

	$sysProfData = (system_profiler -json SPHardwareDataType SPSoftwareDataType) | ConvertFrom-Json

	$osInfoLookups = (_loadOsInfoLookups).macos

	$osDetails.Distributor = 'Apple'
	$osDetails.Description = $sysProfData.SPSoftwareDataType.os_version
	$osDetails.Release = _getMacReleaseVersion
	$osDetails.ReleaseVersion = _convertVersion -version $osDetails.Release
	$kern = _getMacKernelVersion
	if ($kern) { $osDetails.KernelVersion = $kern }
	$osDetails.Id = _getMacId -osVersion $osDetails.ReleaseVersion
	$osDetails.Codename = _getMacCodename -osVersion $osDetails.ReleaseVersion -lookups $osInfoLookups
	$osDetails.BuildNumber = _getMacBuildNumber
	$osDetails.UpdateRevision = _getMacRevision
	#$osDetails.OSInstallTime = _getMacInstallTime
	#$osDetails.OSStartTime = _getMacStartupTime
	#$osDetails.Type =
	#$osDetails.Edition =
}

#region helpers
function _getPlatform {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	# $PSEdition, $IsCoreCLR, $IsWindows, etc were added for PowerShellCore 6/PowerShell Desktop 5.1, so if they don't exist, then it has to be old powershell, which means Windows
	if (-not [bool](Get-Variable -Name 'PSEdition' -ErrorAction Ignore) -or $PSEdition -eq 'Desktop' -or
			-not [bool](Get-Variable -Name 'IsWindows' -ErrorAction Ignore) -or $IsWindows) {
		return 'Windows'
	} elseif ($IsLinux) {
		return 'Linux'
	} elseif ($IsMacOS) {
		return 'MacOS'
	} else {
		Write-Error 'could not determine OS platform' -ErrorAction Stop
	}
}

function _getPSEdition {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	# $PSEdition was added for PowerShellCore 6/PowerShell Desktop 5.1,
	# so if it doesn't exist, then it has to be old powershell, which means 'Desktop'
	if (-not [bool](Get-Variable -Name 'PSEdition' -ErrorAction Ignore)) {
		return 'Desktop'
	}
	return $PSEdition
}

function _getOSArchitecture {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	$result = ''
	# RuntimeInformation.OSArchitecture should always exist for Linux and MacOS, but not necessarily for older version of PowerShell on Windows
	# in which case, we'll fall back to the PROCESSOR_ARCHITECTURE env vars
	#   (as far as i can tell, the PROCESSOR_ARCHITECTURE/PROCESSOR_ARCHITEW6432 env var is sorta misnamed; it's really OS_ARCHITECTURE)
	if ('System.Runtime.InteropServices.Architecture' -as [type] -and
			[bool]([System.Runtime.InteropServices.RuntimeInformation].GetProperty('OSArchitecture', @([System.Reflection.BindingFlags]::Static, [System.Reflection.BindingFlags]::Public)))) {
		$result = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
	} elseif (Test-Path -Path env:PROCESSOR_ARCHITEW6432 -PathType Leaf) {
		# if you're running a 32-bit app on a 64-bit OS, then the PROCESSOR_ARCHITEW6432 env var will exist and contain the correct OS architecture
		$result = $env:PROCESSOR_ARCHITEW6432
	} elseif (Test-Path -Path env:PROCESSOR_ARCHITECTURE -PathType Leaf) {
		# else you're running a 64-bit app on a 64-bit os or a 32-bit app on a 32-bit OS, and only PROCESSOR_ARCHITECTURE will exist and contain the correct OS architecture
		$result = $env:PROCESSOR_ARCHITECTURE
	} else {
		<# ??? if linux, can try uname --hardware-platform; or just fall back to uname --machine and assume the OS type is same as cpu type ??? #>
	}
	switch ($result) {
		{$_ -eq 'X64' -or $_ -eq 'AMD64' -or $_ -eq 'EM64T'} { $result = 'x86_64'; break; }
		'X86' { $result = 'x86_32'; break; }
		# ARM ones just use as-is
	}
	return $result.ToLowerInvariant()
}

function _looksLikeVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([bool])]
	param([string] $version)
	return ($version -and $version -match '^[\d\.]+$')
}

function _convertVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([System.Version])]
	param([string] $version)
	if ($version -match '^\d{8}$') {	# opensuse tumbleweed
		$result = [System.Version]::Parse(($version -replace '(\d\d\d\d)(\d\d)(\d\d)','$1.$2.$3'))	# meh
	} elseif ($version -match '^\d+$') {
		$result = [System.Version]::new([int]$version, 0)
	} elseif ($version -match '^[\d\.]+$') {
		$result = [System.Version]::Parse($version)
	} else {
		$result = [System.Version]::new(0, 0)
	}
	return $result
}

function _loadOsInfoLookups {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([PSObject])]
	param()
	$json = Get-Content -Path $PSScriptRoot/osInfoLookups.jsonc -Raw
	if ((_getPSEdition) -eq 'Desktop') {
		# old posh's ConvertFrom-Json can't handle comments 😖 so strip them out
		# (these regexes will break things if there's '//' or '/*' inside a string in the json but that's okay for this file because i didn't do that):
		$json = $json -replace '//.*[\r\n]+', ''		# line comments
		$json = $json -replace '/\*[\s\S]+?\*/', ''		# block comments
	}
	return ($json | ConvertFrom-Json)
}
#endregion

#region windows parsing helpers
function _getWindowsId {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param([PSObject] $wmios, [string] $release)
	$build = [int]$wmios.BuildNumber
	$type = [int]$wmios.ProductType
	$caption = [string]$wmios.Caption
	$release = $release.ToLowerInvariant()
	WriteVerboseMessage 'mapping windows OS id: build = "{0}", type = "{1}", caption = "{2}"' $build,$type,$caption
	switch ($type) {
		1 {
			switch ($build) {
				{ $_ -ge 6000 } { $result = 'win.{0}' -f $release; break; }
				default { $result = "win.$build"; break; }
			}
		}
		3 {
			switch ($build) {
				#
				#TODO: this needs to be updated; have not kept up with Server versions
				#
				{ $_ -ge 17763 } {
						if ($caption -like '*2019*') {		# can't find any other way to distinguish these...
							$result = 'srvr.2019'
						} else {
							$result = 'srvr'
						}
						break
					}
				{ $_ -ge 16299 } { $result = 'srvr.'; break; }
				{ $_ -ge 10240 } { $result = 'srvr.2016'; break; }
				{ $_ -ge 9600 } { $result = 'srvr.2012R2'; break; }
				{ $_ -ge 9200 } { $result = 'srvr.2012'; break; }
				{ $_ -ge 7600 } { $result = 'srvr.2008R2'; break; }
				{ $_ -ge 6000 } { $result = 'srvr.2008'; break; }
				default { $result = "srvr.$build"; break; }
			}
		}
		default { $result = "unknown.type${type}.${build}"; break; }
	}
	WriteVerboseMessage 'map OS id result == "{0}"' $result
	return $result
}

function _getWindowsRelease {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param($wmios, $ubr, [PSObject] $lookups)
	$build = [int]$wmios.BuildNumber
	$type = [int]$wmios.ProductType
	WriteVerboseMessage 'mapping OS release: build = "{0}", type = "{1}"' $build,$type
	$result = '<unknown>'
	switch ($type) {
		1 {
			foreach ($info in ($lookups.names.client | Sort-Object -Property build -Descending)) {
				if ($build -ge $info.build) {
					$result = $info.name
					if ($info.addRegRelease) { $result += '.{0}' -f (_getWinReleaseFromReg) }
					if ($info.addBuildNumber) { $result += '.{0}' -f $build }
					if ($info.addUbr) { $result += '.{0}' -f $ubr }
					if ($info.addBuildLab) { $result += '.{0}' -f (_getWindowsBuildLab) }
					break
				}
			}
		}
		3 {
			#
			# TODO: convert to using $lookups (once we get that populated)
			#
			switch ($build) {
				#
				#TODO: this needs to be updated; have not kept up with Server versions
				#
				{ $_ -ge 17763 } {
					if ($wmios.Caption -like '*2019*') {		# can't find any other way to distinguish these...
						$result = 'RTM'
					} else {
						$result = _getWinReleaseFromReg
					}
					break
				}
				{ $_ -ge 16299 } { $result = _getWinReleaseFromReg; break; }
				{ $_ -ge 14393 } { $result = 'RTM'; break; }
				{ $_ -ge 10240 } { $result = 'RTM'; break; }
				{ $_ -ge 9600 } { $result = 'RTM'; break; }
				{ $_ -ge 9200 } { $result = 'RTM'; break; }
				{ $_ -ge 7600 } {
					if ($build -gt 7601) { $result = 'SP1' }
					else { $result = 'RTM' }
					break
				}
				{ $_ -ge 6001 } {
					if ($build -gt 6002) { $result = 'SP1' }
					else { $result = 'RTM' }
					break
				}
			}
		}
	}
	WriteVerboseMessage 'map OS release result == "{0}"' $result
	return $result
}

function _getWindowsVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([System.Version])]
	param([System.Version] $kernelVersion, [PSObject] $lookups)
	$result = $kernelVersion
	foreach ($info in ($lookups.versions | Sort-Object -Property build -Descending)) {
		if ($kernelVersion.Build -ge $info.build) {
			$result = if ($info.includeUbr) {
				$val = '{0}.{1}.{2}.{3}' -f $info.major, $info.minor, $kernelVersion.Build, $kernelVersion.Revision
			} else {
				$val = '{0}.{1}.{2}.0' -f $info.major, $info.minor, $kernelVersion.Build
			}
			$result = [System.Version]::new($val)
			break
		}
	}
	return $result
}

function _getWindowsKernelVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([System.Version])]
	param()
	$result = [System.Environment]::OSVersion.Version
	$ubr = _getWindowsUBR
	if ($ubr -gt 0) {
		$result = [System.Version]::new($result.Major, $result.Minor, $result.Build, $ubr)
	}
	return $result
}

function _getWindowsCodename {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param($wmios, [PSObject] $lookups)
	$result = ''
	$bld = [int]$wmios.BuildNumber
	if ($osinfo.ProductType -eq '1') {	# client
		foreach ($info in ($lookups.codenames | Sort-Object -Property build -Descending)) {
			if ($bld -ge $info.build) {
				$result = $info.codename
				break
			}
		}
	} elseif ($osinfo.ProductType -eq '3') {	# server
		# ???
	}
	return $result
}
function _getWindowsEdition {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param([System.UInt32] $cimOsSku, [string] $cimOsCaption, [PSObject] $lookups)
	$result = '<unknown>'
	# skus is a psobject rather than a dictionary, so have to look for value by 'reflection':
	$prop = $lookups.skus.PSObject.Properties | Where-Object { $_.Name -eq $cimOsSku }
	if ($prop) {
		$result = $prop.Value
		# special case: Pro Education originally had same SKU as Pro; a real SKU for it was added later...
		if (($result -eq 'Professional' -or $result -eq 'ProfessionalN') -and $cimOsCaption -like '*Education*') {
			$result = if ($result -eq 'Professional') { 'ProfessionalEducation' } else { 'ProfessionalEducationN' }
		}
	}
	return $result
}

function _getWindowsUBR {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([UInt32])]
	$result = [UInt32]0
	$prop = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR' -ErrorAction SilentlyContinue
	if ($prop) {
		$result = [UInt32]$prop.UBR
	}
	return $result
}

function _getWinReleaseFromReg {
	# DisplayVersion added when they switched names from '2009' to '20H2'
	$result = (Get-ItemProperty -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion').DisplayVersion	# new with 20H2 (2009)
	if (-not $result) {
		# fall back to older one (e.g. '2004', '1903')
		$result = (Get-ItemProperty -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion').ReleaseId
	}
	return $result
}

function _getWindowsBuildLab {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	$result = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'BuildLab' -ErrorAction SilentlyContinue
	if (-not $result) { return '<unknown>' }
	return $result.BuildLab
}
#endregion

#region linux parsing helpers
function _getLinuxReleaseProps {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string[]])]
	$distId = $description = $release = $codename = [string]::Empty
	# try getting data from reading files before shelling out to lsb_release:
	$lsbReleasePath = '/etc/lsb-release'
	if (Test-Path -Path $lsbReleasePath -PathType Leaf) {
		WriteVerboseMessage -message 'reading lsb-release file from "{0}"' -formatParams $lsbReleasePath
		$lsbrelease = Get-Content -Path $lsbReleasePath | ParseLinesToLookup
		if ($lsbrelease.ContainsKey('DISTRIB_ID')) { $distId = $lsbrelease['DISTRIB_ID'] }
		if ($lsbrelease.ContainsKey('DISTRIB_DESCRIPTION')) { $description = $lsbrelease['DISTRIB_DESCRIPTION'] }
		if ($lsbrelease.ContainsKey('DISTRIB_RELEASE')) { $release = $lsbrelease['DISTRIB_RELEASE'] }
		if ($lsbrelease.ContainsKey('DISTRIB_CODENAME')) { $codename = $lsbrelease['DISTRIB_CODENAME'] }
	} else {
		WriteVerboseMessage -message 'no lsb-release file found'
	}
#	if ((-not $distId -or -not $description -or -not $release -or -not $codename) -and (Test-Path -Path '/etc/os-release' -PathType Leaf)) {
	if ((-not $distId -or -not $description -or -not $release -or -not $codename)) {
		$osReleasePath = '/etc/os-release'
		if (-not (Test-Path -Path $osReleasePath -PathType Leaf)) { $osReleasePath = '/usr/lib/os-release' }
		if ((Test-Path -Path $osReleasePath -PathType Leaf)) {
			WriteVerboseMessage -message 'reading os-release file from "{0}"' -formatParams $osReleasePath
			$osrelease = Get-Content -Path $osReleasePath | ParseLinesToLookup
			if (-not $distId -and $osrelease.ContainsKey('ID')) { $distId = $osrelease['ID'] }
			if (-not $description -and $osrelease.ContainsKey('NAME')) { $description = $osrelease['NAME'] }
			if (-not $release -and $osrelease.ContainsKey('VERSION_ID')) { $release = $osrelease['VERSION_ID'] }
			if (-not $codename -and $osrelease.ContainsKey('VERSION_CODENAME')) { $codename = $osrelease['VERSION_CODENAME'] }
		} else {
			WriteVerboseMessage -message 'no os-release file found'
		}
	}
	# some distros (e.g. fedora and opensuse tumbleweed) still don't have everything but it is returned by lsb_release (??), so let's try that:
	if ((-not $distId -or -not $description -or -not $release -or -not $codename)) {
		if ((Get-Command -Name 'lsb_release' -ErrorAction Ignore)) {
			WriteVerboseMessage -message 'calling lsb_release for info'
			$lsb = lsb_release --all 2>/dev/null | ParseLinesToLookup
			if (-not $distId -and $lsb.ContainsKey('Distributor ID')) { $distId = $lsb['Distributor ID'] }
			if (-not $description -and $lsb.ContainsKey('Description')) { $description = $lsb['Description'] }
			if (-not $release -and $lsb.ContainsKey('Release')) { $release = $lsb['Release'] }
			if (-not $codename -and $lsb.ContainsKey('Codename')) { $codename = $lsb['Codename'] }
		} else {
			WriteVerboseMessage -message 'lsb_release command not found'
		}
	}
	if ($codename -eq 'n/a') { $codename = [string]::Empty }	# opensuse tumbleweed

	return $distId,$description,$release,$codename
}

function _getLinuxInstallDatetime {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string[]])]
	param()
	# try to figure out os install datetime; doesn't look lik linux has a command for it, but can check for when basic os files folders were created; we'll try these:
	# and .NET/PowerShell's DirectoryInfo is not returning this for its CreationTime; looks like it's returning ctime rather than birth time (??)
	# and 'birth' time might not be supported on all filesystems, so be ready for that...
	$result = [System.DateTime]::MinValue
	$createSecs = 0
	if (Test-Path -Path '/root' -PathType Container) {
		$tmpSecs = stat /root --format=%W 2>/dev/null
		if ($LASTEXITCODE -eq 0) { $createSecs = $tmpSecs }
	}
	if ($createSecs -eq 0 -and (Test-Path -Path '/etc' -PathType Container)) {
		$tmpSecs = stat /etc --format=%W 2>/dev/null
		if ($LASTEXITCODE -eq 0) { $createSecs = $tmpSecs }
	}
	if ($createSecs -ne 0) {
		$result = [System.DateTimeOffset]::FromUnixTimeSeconds($createSecs).LocalDateTime
	}
	return $result
}

function _getLinuxKernelVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string[]])]
	param()
	$result = (uname --kernel-release)
	# Debian, Kali, maybe others, are now apparently using a 'display' version that's above, but then the real version has to be parsed out of below (haven't found a better way yet...)
	$version = (uname --kernel-version | awk '{print $5}') | Select-String -Pattern '\d+\.\d+\.\d+[\S]*' -Raw
	if ($version -and $version -ne $result) {
		$result = "$result [$version]"
	}
	return $result
}
#endregion

#region macos parsing helpers
function _getMacReleaseVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	$result = (sysctl -hin kern.osproductversion)
	if (-not $result) { <# anywhere else to look ??? #> }
	return $result
}

function _getMacKernelVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	#[OutputType([System.Version])]
	[OutputType([string])]
	param()
	$result = (sysctl -hin kern.osrelease)
	if (-not $result) { <# anywhere else to look ??? #> }
	return $result
	#if ($result) { return [System.Version]::Parse($result) } else { return [System.Version]::(0, 0) }
}

function _getMacBuildNumber {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	$result = (sysctl -hin kern.osversion)
	if (-not $result) { <# anywhere else to look ??? #> }
	return $result
}

function _getMacRevision {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([UInt32])]
	param()
	$result = [UInt32]0
	$tmp = (sysctl -hin kern.osrevision)
	if (-not $tmp) { <# anywhere else to look ??? #> }
	if ($tmp) { $result = [UInt32]$tmp }
	return $result
}

function _getMacStartupTime {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([System.DateTime])]
	param()
	$result = [System.DateTime]::MinValue
	$raw = (sysctl -hin kern.boottime)
	if ($raw) {
		$match = [regex]::Match($raw, '^{\s*sec\s*=\s*(?<secs>\d+).+$')
		if ($match.Success) {
			$result = [System.DateTimeOffset]::FromUnixTimeSeconds(([long]($match.Groups['secs'].Value))).LocalDateTime
		}
	}
	if ($result -eq [System.DateTime]::MinValue) {
		<# ??? #>
	}
	return $result
}

function _getMacId {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param([System.Version] $osVersion)
	$result = ''
	#if ($osVersion.Major -gt 10) {
	#	$result = 'mac.{0}' -f $osVersion.Major
	#} elseif ($osVersion.Major -eq 10) {
		$result = 'mac.{0}.{1}' -f $osVersion.Major,$osVersion.Minor
	#}
	return $result
}

function _getMacCodename {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param([System.Version] $osVersion, [PSObject] $lookups)
	$result = ''
	foreach ($info in $lookups.codenames) {
		if ($info.major -eq $osVersion.Major -and ($info.minor -lt 0 -or $info.minor -eq $osVersion.Minor)) {
			$result = $info.codename
		}
	}
	return $result
}

function _getMacInstallTime {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string[]])]
	param()
	# try to figure out os install datetime; no direct command for it, but can check for when basic os files folders were created; we'll try these:
	# alternate: call system_profiler SPInstallHistoryDataType, look for earliest item "_name -like 'macOS *'""; but that timestamp is way earlier than what using here, so ??
	# => this doesn't really work either; the times here get updated with new os updates, so meh
	$result = [System.DateTime]::MinValue
	$createSecs = 0
	$tmpSecs = stat -f%B / 2>/dev/null
	if ($LASTEXITCODE -eq 0) { $createSecs = $tmpSecs }
	if ($createSecs -eq 0 -and (Test-Path -Path '/System' -PathType Container)) {
		$tmpSecs = stat -f%B /System 2>/dev/null
		if ($LASTEXITCODE -eq 0) { $createSecs = $tmpSecs }
	}
	if ($createSecs -eq 0 -and (Test-Path -Path '/Library/Apple' -PathType Container)) {
		$tmpSecs = stat -f%B /Library/Apple 2>/dev/null
		if ($LASTEXITCODE -eq 0) { $createSecs = $tmpSecs }
	}
	if ($createSecs -ne 0) {
		$result = [System.DateTimeOffset]::FromUnixTimeSeconds($createSecs).LocalDateTime
	}
	return $result
}
#endregion