#Requires -Version 5.1

#[CmdletBinding(SupportsShouldProcess=$false)]
#param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

class OSDetails {
	[string] $Id				# e.g. 'win.10', 'win.8.1'
	[string] $Caption			# e.g. 'Microsoft Windows 10 Pro'
	[string] $Release			# e.g. 'SP1' for < Win10, or '1903', '21H2' for >= Win10
	[System.Version] $Version	# e.g. 10.0.16299.0
	[string] $MajorMinor		# e.g. '6.3', '10.0'
	[int] $BuildNumber			# should be '[uint]' but old desktop posh doesn't recognize that
	[int] $UpdateBuildRevision
	[string] $Codename
	[string] $Type				# e.g. 'WorkStation', 'Server'
	[string] $Edition			# e.g. 'Professional', 'Home', etc
	[string] $OSArchitecture	# e.g. 'x86_64', 'Arm64'
	[bool] $Is64BitOS
	[string] $Manufacturer		# e.g. 'Microsoft Corporation'
	[DateTime] $InstallDateTime
	[DateTime] $LastBootDateTime
}

$script:cachedOsDetails = $null		# it's not going to change, so...
function Get-OSDetails {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([OSDetails])]
	param()

	if ($script:cachedOsDetails) {
		Write-Verbose "$($MyInvocation.InvocationName): returning cached OSDetails"
		return $script:cachedOsDetails
	}

	Write-Verbose "$($MyInvocation.InvocationName): populating OS details"

	if (Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue) {
		$osinfo = Get-CimInstance -ClassName 'CIM_OperatingSystem'
	} else {
		# (much) older versions
		$osinfo = Get-WmiObject -Class 'Win32_OperatingSystem'
	}

	$result = [OSDetails]::new()
	$result.Caption = $osinfo.Caption
	$result.Manufacturer = $osinfo.Manufacturer
	$result.BuildNumber = [int]$osinfo.BuildNumber
	$result.OSArchitecture = _getWindowsArchitecture
	$result.Is64BitOS = [System.Environment]::Is64BitOperatingSystem
	$result.InstallDateTime = $osinfo.InstallDate
	$result.LastBootDateTime = $osinfo.LastBootUpTime
	$result.Type = if ($osinfo.ProductType -eq 3) { 'Server' } else { 'WorkStation' }
	$result.Id = _getWindowsId -wmios $osinfo
	$result.Release = _getWindowsRelease -wmios $osinfo
	$result.Edition = _getWindowsEdition -wmios $osinfo
	$result.UpdateBuildRevision = _getWindowsUBR
	$result.Version = _getWindowsVersion -ubr $result.UpdateBuildRevision
	$result.MajorMinor = $result.Version.ToString(2)
	$result.Codename = _getWindowsCodename -wmios $osinfo

	$script:cachedOsDetails = $result
	return $result
}

function _getWindowsId {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param($wmios)
	$build = [int]$wmios.BuildNumber
	$type = [int]$wmios.ProductType
	$caption = [string]$wmios.Caption
	Write-Verbose "$($MyInvocation.InvocationName): mapping OS name: build = '$build', type = '$type', caption = '$caption'"
	switch ($type) {
		1 {
			switch ($build) {
				{ $_ -ge 22000 } { $result = 'win.11'; break; }
				{ $_ -ge 10240 } { $result = 'win.10'; break; }
				{ $_ -ge 9600 } { $result = 'win.8.1'; break; }
				{ $_ -ge 9200 } { $result = 'win.8'; break; }
				{ $_ -ge 7600 } { $result = 'win.7'; break; }
				{ $_ -ge 6000 } { $result = 'win.vista'; break; }
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
	Write-Verbose "$($MyInvocation.InvocationName): map OS name result == '$result'"
	return $result
}

function _getWindowsRelease {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param($wmios)
	$build = [int]$wmios.BuildNumber
	$type = [int]$wmios.ProductType
	Write-Verbose "$($MyInvocation.InvocationName): mapping OS release: build = '$build', type = '$type'"
	$result = '<unknown>'
	switch ($type) {
		1 {
			switch ($build) {
				{ $_ -ge 22000 } {
					if ($build -ge 22621) { $result = _getWinReleaseFromReg }
					else { $result = 'RTM' }
					break
				}
				{ $_ -ge 10240 } {
					if ($build -ge 14393) { $result = _getWinReleaseFromReg }
					elseif ($build -ge 10586) { $result = '1511' }	# think it's in the registry for this one, too, but...
					elseif ($build -ge 10240) { $result = 'RTM' }
					break
				}
				{ $_ -ge 9600 } { $result = 'RTM'; break; }
				{ $_ -ge 9200 } { $result = 'RTM'; break; }
				{ $_ -ge 7600 } {
					if ($build -gt 7600) { $result = 'SP1' }
					else { $result = 'RTM' }
					break
				}
				{ $_ -ge 6000 } {
					if ($build -gt 6001) { $result = 'SP2' }
					if ($build -eq 6001) { $result = 'SP1' }
					else { $result = 'RTM' }
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
					if ($build -gt 7600) { $result = 'SP1' }
					else { $result = 'RTM' }
					break
				}
				{ $_ -ge 6000 } {
					if ($build -gt 6001) { $result = 'SP1' }
					else { $result = 'RTM' }
					break
				}
			}
		}
	}
	Write-Verbose "$($MyInvocation.InvocationName): map OS release result == '$result'"
	return $result
}

function _getWindowsEdition {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param($wmios)
	#
	# can also kinda get this from registry (HKLM:\Software\Microsoft\Windows NT\CurrentVersion\@EditionId) but
	# 1) for non-server, have to switch 'Core' to 'Home'
	# 2) for servers, no way to tell between regular and core installs
	#
	$ossku = $wmios.OperatingSystemSKU
	$result = '<unknown>'
	# https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem, search for 'OperatingSystemSKU':
	switch ($ossku) {
		# PRODUCT_UNDEFINED (0): Undefined
		0 { $result = 'Undefined' }
		# PRODUCT_ULTIMATE (1): Ultimate Edition, e.g. Windows Vista Ultimate.
		1 { $result = 'Ultimate' }
		# PRODUCT_HOME_BASIC (2): Home Basic Edition
		2 { $result = 'HomeBasic' }
		# PRODUCT_HOME_PREMIUM (3): Home Premium Edition
		3 { $result = 'HomePremium' }
		# PRODUCT_ENTERPRISE (4): Enterprise Edition
		4 { $result = 'Enterprise' }
		5 { $result = 'HomeBasicN' }
		# PRODUCT_BUSINESS (6): Business Edition
		6 { $result = 'Business' }
		# PRODUCT_STANDARD_SERVER (7): Windows Server Standard Edition (Desktop Experience installation)
		7 { $result = 'ServerStandard' }
		# PRODUCT_DATACENTER_SERVER (8): Windows Server Datacenter Edition (Desktop Experience installation)
		8 { $result = 'ServerDatacenter' }
		# PRODUCT_SMALLBUSINESS_SERVER (9): Small Business Server Edition
		9 { $result = 'ServerSmallBusiness' }
		# PRODUCT_ENTERPRISE_SERVER (10): Enterprise Server Edition
		10 { $result = 'ServerEnterprise' }
		# PRODUCT_STARTER (11): Starter Edition
		11 { $result = 'Starter' }
		# PRODUCT_DATACENTER_SERVER_CORE (12): Datacenter Server Core Edition
		12 { $result = 'ServerDatacenterCore' }			# only < Srvr2012
		# PRODUCT_STANDARD_SERVER_CORE (13): Standard Server Core Edition
		13 { $result = 'ServerStandardCore' }			# only < Srvr2012
		# PRODUCT_ENTERPRISE_SERVER_CORE (14): Enterprise Server Core Edition
		14 { $result = 'ServerEnterpriseCore' }			# only < Srvr2012
		# PRODUCT_WEB_SERVER (17): Web Server Edition
		17 { $result = 'ServerWeb' }
		# PRODUCT_HOME_SERVER (19): Home Server Edition
		19 { $result = 'HomeServer' }
		# PRODUCT_STORAGE_EXPRESS_SERVER (20): Storage Express Server Edition
		20 { $result = 'StorageServerExpress' }
		# PRODUCT_STORAGE_STANDARD_SERVER (21): Windows Storage Server Standard Edition (Desktop Experience installation)
		21 { $result = 'StorageServerStandard' }
		# PRODUCT_STORAGE_WORKGROUP_SERVER (22): Windows Storage Server Workgroup Edition (Desktop Experience installation)
		22 { $result = 'StorageServerWorkgroup' }
		# PRODUCT_STORAGE_ENTERPRISE_SERVER (23): Storage Enterprise Server Edition
		23 { $result = 'StorageServerEnterprise' }
		# PRODUCT_SERVER_FOR_SMALLBUSINESS (24): Server For Small Business Edition
		24 { $result = 'ServerSmallBusiness' }
		# PRODUCT_SMALLBUSINESS_SERVER_PREMIUM (25): Small Business Server Premium Edition
		25 { $result = 'ServerSmallBusinessPremium' }
		26 { $result = 'HomePremiumN' }
		# PRODUCT_ENTERPRISE_N (27): Windows Enterprise Edition
		27 { $result = 'EnterpriseN' }
		# PRODUCT_ULTIMATE_N (28): Windows Ultimate Edition
		28 { $result = 'UltimateN' }
		# PRODUCT_WEB_SERVER_CORE (29): Windows Server Web Server Edition (Server Core installation)
		29 { $result = 'ServerWebCore' }			# only < Srvr2012
		# PRODUCT_STANDARD_SERVER_V (36): Windows Server Standard Edition without Hyper-V
		# PRODUCT_DATACENTER_SERVER_V (37): Windows Server Datacenter Edition without Hyper-V (full installation)
		# PRODUCT_ENTERPRISE_SERVER_V (38): Windows Server Enterprise Edition without Hyper-V (full installation)
		# PRODUCT_DATACENTER_SERVER_CORE_V (39): Windows Server Datacenter Edition without Hyper-V (Server Core installation)
		# PRODUCT_STANDARD_SERVER_CORE_V (40): Windows Server Standard Edition without Hyper-V (Server Core installation)
		# PRODUCT_ENTERPRISE_SERVER_CORE_V (41): Windows Server Enterprise Edition without Hyper-V (Server Core installation)
		# PRODUCT_HYPERV (42): Microsoft Hyper-V Server
		42 { $result = 'ServerHyperV' }
		# PRODUCT_STORAGE_EXPRESS_SERVER_CORE (43): Storage Server Express Edition (Server Core installation)
		43 { $result = 'StorageServerExpressCore' }
		# PRODUCT_STORAGE_STANDARD_SERVER_CORE (44): Storage Server Standard Edition (Server Core installation)
		44 { $result = 'StorageServerStandardCore' }
		# PRODUCT_STORAGE_WORKGROUP_SERVER_CORE (45): Storage Server Workgroup Edition (Server Core installation)
		45 { $result = 'StorageServerWorkgroupCore' }
		# PRODUCT_STORAGE_ENTERPRISE_SERVER_CORE (46): Storage Server Enterprise Edition (Server Core installation)
		46 { $result = 'StorageServerEnterpriseCore' }
		47 { $result = 'StarterN' }
		# PRODUCT_PROFESSIONAL (48): Windows Professional
		48 {
			# Pro Education originally had same SKU as Pro; real SKU below added later...
			if ($wmios.Caption -notlike '*Education*') {
				$result = 'Professional'
			} else {
				$result = 'ProfessionalEducation'
			}
		}
		49 {
			if ($wmios.Caption -notlike '*Education*') {
				$result = 'ProfessionalN'
			} else {
				$result = 'ProfessionalEducationN'
			}
		}
		# PRODUCT_SB_SOLUTION_SERVER (50): Windows Server Essentials (Desktop Experience installation)
		50 { $result = 'ServerEssentials' }
		# PRODUCT_SMALLBUSINESS_SERVER_PREMIUM_CORE (63); Small Business Server Premium (Server Core installation)
		63 { $result = 'ServerSmallBusinessPremiumCore' }
		# PRODUCT_CLUSTER_SERVER_V (64): Windows Compute Cluster Server without Hyper-V
		# PRODUCT_CORE_ARM (97): Windows RT
		97 { $result = 'WindowsRT' }	# the original Windows ARM version (??)
		98 { $result = 'HomeN' }
		100 { $result = 'HomeSingleLanguage' }
		# PRODUCT_CORE (101): Windows Home
		101 { $result = 'Home' }
		# PRODUCT_PROFESSIONAL_WMC (103): Windows Professional with Media Center
		103 { $result = 'ProfessionalWithMediaCenter' }
		# PRODUCT_MOBILE_CORE (104): Windows Mobile
		104 { $result = 'WindowsMobile' }
		121 { $result = 'Education' }
		122 { $result = 'EducationN' }
		# PRODUCT_IOTUAP (123): Windows IoT (Internet of Things) Core
		123 { $result = 'WindowsIoTCore' }
		# PRODUCT_DATACENTER_NANO_SERVER (143): Windows Server Datacenter Edition (Nano Server installation)
		143 { $result = 'ServerDataCenterNano' }
		# PRODUCT_STANDARD_NANO_SERVER (144): Windows Server Standard Edition (Nano Server installation)
		144 { $result = 'ServerStandardNano' }
		#145 { $result = 'dcCore' }			# ?????
		#146 { $result = 'stdCore' }			# ?????
		# PRODUCT_DATACENTER_WS_SERVER_CORE (147): Windows Server Datacenter Edition (Server Core installation)
		147 { $result = 'ServerDatacenterCoreWS' }
		# PRODUCT_STANDARD_WS_SERVER_CORE (148): Windows Server Standard Edition (Server Core installation)
		148 { $result = 'ServerStandrdCoreWS' }
		161 { $result = 'ProfessionalWorkstation' }
		162 { $result = 'ProfessionalWorkstationN' }
		164 { $result = 'ProfessionalEducation' }
		165 { $result = 'ProfessionalEducationN' }
		# PRODUCT_ENTERPRISE_FOR_VIRTUAL_DESKTOPS (175): Windows Enterprise for Virtual Desktops (Azure Virtual Desktop)
		175 { $result = 'EnterpriseForVirtualDesktop' }
	}
	Write-Verbose "trying to map OS edition: ossku = '$ossku' ==> '$result'"
	return $result
}

function _getWindowsArchitecture {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param()
	if ('System.Runtime.InteropServices.Architecture'-as [type]) {	# property 'System.Runtime.InteropServices.RuntimeInformation.OSArchitecture' and this enum were added at same time...
		switch ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture) {
			# posh switch can't compare the enum value directly ???
			'X64' { $result = 'x86-64'; break; }
			'X86' { $result = 'x86-32'; break; }
			default { $result = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString(); break; }
		}
	} else {
		$result = $env:PROCESSOR_ARCHITECTURE
	}
	return $result
}

function _getWindowsVersion {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([System.Version])]
	param([int] $ubr)
	$result = [System.Environment]::OSVersion.Version
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
		if ($bld -ge 22621) {
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
	[OutputType([int])]
	$result = 0
	$prop = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -Name 'UBR' -ErrorAction SilentlyContinue
	if ($prop) {
		$result = $prop.UBR
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