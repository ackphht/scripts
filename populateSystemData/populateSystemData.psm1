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

	$osDetails.Description = $osinfo.Caption
	$osDetails.Distributor = $osinfo.Manufacturer
	$osDetails.BuildNumber = $osinfo.BuildNumber.ToString()
	#$osDetails.OSInstallTime = $osinfo.InstallDate
	#$osDetails.OSStartTime = $osinfo.LastBootUpTime
	$osDetails.Type = if ($osinfo.ProductType -eq 3) { 'Server' } else { 'WorkStation' }
	$release = _getWindowsRelease -wmios $osinfo
	$osDetails.Id = _getWindowsId -wmios $osinfo -release $release
	# TODO: right now, we're setting $osDetails.Release like '11.22H2', '11', '10.2009', '8.1', '7.SP1', etc;
	# is that really how we want it? other OSes are just the release version, maybe for Win, should be simpler
	# or maybe other OSes should include more?
	$osDetails.Release = $release
	$osDetails.Edition = MapCimOsSku -cimOsSku $osinfo.OperatingSystemSKU -cimOsCaption $osinfo.Caption
	$kernelVersion = _getWindowsKernelVersion
	$osDetails.KernelVersion = $kernelVersion.ToString()
	$osDetails.UpdateRevision = $kernelVersion.Revision
	$osDetails.ReleaseVersion = _getWindowsVersion -kernelVersion $kernelVersion
	#$osDetails.MajorMinor = $osDetails.KernelVersion.ToString(2)
	$osDetails.Codename = _getWindowsCodename -wmios $osinfo
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

	$osDetails.Distributor = 'Apple'
	$osDetails.Description = $sysProfData.SPSoftwareDataType.os_version
	$osDetails.Release = _getMacReleaseVersion
	$osDetails.ReleaseVersion = _convertVersion -version $osDetails.Release
	$kern = _getMacKernelVersion
	if ($kern) { $osDetails.KernelVersion = $kern }
	$osDetails.Id = _getMacId -osVersion $osDetails.ReleaseVersion
	$osDetails.Codename = _getMacCodename -osVersion $osDetails.ReleaseVersion
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

function _getOSArchitecture {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	$result = ''
	if ('System.Runtime.InteropServices.Architecture' -as [type] -and
			[bool]([System.Runtime.InteropServices.RuntimeInformation].GetProperty('OSArchitecture', @([System.Reflection.BindingFlags]::Static, [System.Reflection.BindingFlags]::Public)))) {
		$result = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString()
	} elseif (Test-Path -Path env:PROCESSOR_ARCHITECTURE -PathType Leaf) {
		$result = $env:PROCESSOR_ARCHITECTURE
	} else {
		<# ??? if linux, can try uname --hardware-platform; or just fall back to uname --machine and assume the OS type is same as cpu type ??? #>
	}
	switch ($result) {
		{$_ -eq 'X64' -or $_ -eq 'AMD64' -or $_ -eq 'EM64T'} { $result = 'x86-64'; break; }
		'X86' { $result = 'x86-32'; break; }
		# ARM ones just use as-is
	}
	return $result
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
	WriteVerboseMessage 'mapping windows OS name: build = "{0}", type = "{1}", caption = "{2}"' $build,$type,$caption
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
	WriteVerboseMessage 'map OS name result == "{0}"' $result
	return $result
}

function _getWindowsRelease {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param($wmios)
	$build = [int]$wmios.BuildNumber
	$type = [int]$wmios.ProductType
	WriteVerboseMessage 'mapping OS release: build = "{0}", type = "{1}"' $build,$type
	$result = '<unknown>'
	switch ($type) {
		1 {
			switch ($build) {
				# ??? haven't really found anything better than build number for canary/dev/beta flights:
				#		in registry under HKLM\WindowsNT\CurrentVersion, there's a BuildBranch that's different
				#		from release for cancary and dev, but not for beta, so not sure that's helpful ???
				{ $_ -ge 25000 } { $result = '11.canary.{0}' -f (_getWindowsBuildLab); break; }
				{ $_ -ge 23000 } { $result = '11.dev.{0}' -f (_getWindowsBuildLab); break; }
				{ $_ -gt 22631 } { $result = '11.beta.{0}' -f $build; break; }	# ???
				{ $_ -ge 22000 } {
					if ($build -ge 22621) { $result = '11.{0}' -f (_getWinReleaseFromReg) }
					elseif ($build -ge 22449) { $result = '11.dev.{0}' -f $build }	# Win11 22H2 dev builds
					else { $result = '11' }
					break
				}
				{ $_ -ge 19500 } { $result = '11.dev.{0}' -f $build; break; }	# Win 11 dev builds (or beta ??)
				{ $_ -ge 10240 } {
					if ($build -ge 10586) { $result = '10.{0}' -f (_getWinReleaseFromReg) }
					elseif ($build -ge 10240) { $result = '10' }
					break
				}
				{ $_ -ge 9600 } { $result = '8.1'; break; }
				{ $_ -ge 9200 } { $result = '8'; break; }
				{ $_ -ge 7600 } {
					if ($build -gt 7601) { $result = '7.SP1' }
					else { $result = '7' }
					break
				}
				{ $_ -ge 6000 } {
					if ($build -gt 6002) { $result = 'Vista.SP2' }
					if ($build -eq 6001) { $result = 'Vista.SP1' }
					else { $result = 'Vista' }
					break
				}
			}
		}
		3 {
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
	param([System.Version] $kernelVersion)
	$result = $kernelVersion
	switch ($kernelVersion.Build) {
		{ $_ -ge 22000 } {
			$result = [System.Version]::new(11, 0, $kernelVersion.Build, $kernelVersion.Revision)
			break
		}
		{ $_ -ge 10240 } {
			if ($kernelVersion.Build -ge 10586) { $rev = $kernelVersion.Revision }
			else { $rev = 0 }
			$result = [System.Version]::new(10, 0, $kernelVersion.Build, $rev)
			break
		}
		{ $_ -ge 9600 } { $result = [System.Version]::new(8, 1, $kernelVersion.Build, 0); break; }
		{ $_ -ge 9200 } { $result = [System.Version]::new(8, 0, $kernelVersion.Build, 0); break; }
		{ $_ -ge 7600 } {
			if ($kernelVersion.Build -gt 7601) { $min = 1 }
			else { $result = $min = 0 }
			$result = [System.Version]::new(7, $min, $kernelVersion.Build, 0)
			break
		}
		{ $_ -ge 6000 } {
			if ($kernelVersion.Build -gt 6002) { $min = 2 }
			if ($kernelVersion.Build -eq 6001) { $min = 1 }
			else { $result = $min = 0 }
			$result = [System.Version]::new(6, $min, $kernelVersion.Build, 0)
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
	param($wmios)
	$result = ''
	$bld = [int]$wmios.BuildNumber
	if ($osinfo.ProductType -eq '1') {	# client
		if ($bld -ge 22631) {
			$result = 'Sun Valley 3'
		} elseif ($bld -ge 22621) {
			$result = 'Sun Valley 2'
		} elseif ($bld -ge 22000) {
			$result = 'Sun Valley'
		} elseif ($bld -ge 19041) {	# codename includes Win10 2004, 20H2, 21H1, 21H2, 22H2
			$result = 'Vibranium'
		} elseif ($bld -ge 18363) {	# 1909
			$result = 'Vanadium'
		} elseif ($bld -ge 18362) {	# 1903
			$result = '19H1'
		} elseif ($bld -ge 17763) {	# 1809
			$result = 'Redstone 5'
		} elseif ($bld -ge 17134) {	# 1803
			$result = 'Redstone 4'
		} elseif ($bld -ge 16299) {	# 1709
			$result = 'Redstone 3'
		} elseif ($bld -ge 15063) {	# 1703
			$result = 'Redstone 2'
		} elseif ($bld -ge 14393) {	# 1607
			$result = 'Redstone 1'
		} elseif ($bld -ge 10586) { # 1511
			$result = 'Threshold 2'
		} elseif ($bld -ge 10240) { # RTM
			$result = 'Threshold'
		} elseif ($bld -ge 9600) {	# Win 8.1
			$result = 'Blue'
		} elseif ($bld -ge 7600) {	# Win 7 and 8 didn't have codenames ?
			$result = ''
		} elseif ($bld -ge 6000) {	# Vista
			$result = 'Longhorn'
		} elseif ($bld -ge 2600) {	# WinXP
			$result = 'Whistler'
		#} elseif ($bld -ge XXXX) {	#
		#	$result = 'XXXXXXXX'
		}
	} elseif ($osinfo.ProductType -eq '3') {	# server
		# ???
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
	if (Test-Path -Path '/etc/lsb-release' -PathType Leaf) {
		$lsbrelease = Get-Content -Path '/etc/lsb-release' | ParseLinesToLookup
		if ($lsbrelease.ContainsKey('DISTRIB_ID')) { $distId = $lsbrelease['DISTRIB_ID'] }
		if ($lsbrelease.ContainsKey('DISTRIB_DESCRIPTION')) { $description = $lsbrelease['DISTRIB_DESCRIPTION'] }
		if ($lsbrelease.ContainsKey('DISTRIB_RELEASE')) { $release = $lsbrelease['DISTRIB_RELEASE'] }
		if ($lsbrelease.ContainsKey('DISTRIB_CODENAME')) { $codename = $lsbrelease['DISTRIB_CODENAME'] }
	}
	if ((-not $distId -or -not $description -or -not $release -or -not $codename) -and (Test-Path -Path '/etc/os-release' -PathType Leaf)) {
		$osrelease = Get-Content -Path '/etc/os-release' | ParseLinesToLookup
		if (-not $distId -and $osrelease.ContainsKey('ID')) { $distId = $osrelease['ID'] }
		if (-not $description -and $osrelease.ContainsKey('NAME')) { $description = $osrelease['NAME'] }
		if (-not $release -and $osrelease.ContainsKey('VERSION_ID')) { $release = $osrelease['VERSION_ID'] }
		if (-not $codename -and $osrelease.ContainsKey('VERSION_CODENAME')) { $codename = $osrelease['VERSION_CODENAME'] }
	}
	# some distros (e.g. fedora and opensuse tumbleweed) still don't have everything but it is returned by lsb_release (??), so let's try that:
	if ((-not $distId -or -not $description -or -not $release -or -not $codename) -and (Get-Command -Name 'lsb_release' -ErrorAction Ignore)) {
		$lsb = lsb_release --all 2>/dev/null | ParseLinesToLookup
		if (-not $distId -and $lsb.ContainsKey('Distributor ID')) { $distId = $lsb['Distributor ID'] }
		if (-not $description -and $lsb.ContainsKey('Description')) { $description = $lsb['Description'] }
		if (-not $release -and $lsb.ContainsKey('Release')) { $release = $lsb['Release'] }
		if (-not $codename -and $lsb.ContainsKey('Codename')) { $codename = $lsb['Codename'] }
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
	param([System.Version] $osVersion)
	$result = ''
	switch ($osVersion.Major) {
		14 { $result = 'Sonoma'; break; }
		13 { $result = 'Ventura'; break; }
		12 { $result = 'Monterey'; break; }
		11 { $result = 'Big Sur'; break; }
		10 {
			switch ($osVersion.Minor) {
				15 { $result = 'Catalina'; break; }
				14 { $result = 'Mojave'; break; }
				13 { $result = 'High Sierra'; break; }
				12 { $result = 'Sierra'; break; }
				11 { $result = 'El Capitan'; break; }
				10 { $result = 'Yosemite'; break; }
				9 { $result = 'Mavericks'; break; }
				8 { $result = 'Mountain Lion'; break; }
				7 { $result = 'Lion'; break; }
				6 { $result = 'Snow Leopard'; break; }
				5 { $result = 'Leopard'; break; }
				4 { $result = 'Tiger'; break; }
				3 { $result = 'Panther'; break; }
				2 { $result = 'Jaguar'; break; }
				1 { $result = 'Puma'; break; }
				0 { $result = 'Cheetah'; break; }
			}
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