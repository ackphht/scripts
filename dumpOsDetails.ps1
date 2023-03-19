[CmdletBinding(SupportsShouldProcess=$True)]
param()

#Set-Location ~\Desktop

function Main {
	$netver = GetDotNetVersions

	if (Get-Command -Name Get-CimInstance -ErrorAction SilentlyContinue) {
		$osinfo = Get-CimInstance -ClassName 'Win32_OperatingSystem'
	} else {
		$osinfo = Get-WmiObject -Class 'Win32_OperatingSystem'
	}
	#$osver = $osinfo.Version
	$osbuild = [int]$osinfo.BuildNumber
	$osname = GetWindowsName $osinfo
	$osver = GetVersion $osname $osinfo
	$edition = GetEdition $osinfo

	if ($PSScriptRoot) {
		#$baseFilename = "$PSScriptRoot\${osname}.${osbuild}.${edition}"
		$baseFilename = "$PSScriptRoot\${osname}.${osver}.${edition}"
	} else {
		#$baseFilename = "$(Split-Path -Parent $script:MyInvocation.MyCommand.Path)\${osname}.${osbuild}.${edition}"
		$baseFilename = "$(Split-Path -Parent $script:MyInvocation.MyCommand.Path)\${osname}.${osver}.${edition}"
	}
	Set-Content -Path "${baseFilename}.dotnetVersion.txt" -Value $netver
	$osinfo | Format-List ([string[]]($osinfo | Get-Member -MemberType Property | ForEach-Object { $_.Name } | Sort-Object)) > "${baseFilename}.osInfo.txt"
	Set-Content -Path "${baseFilename}.poshVersion.txt" -Value (GetPowerShellVersion)

	$cv = Get-ItemProperty -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion'
	$cv | Format-List ([string[]]($cv | Get-Member -MemberType NoteProperty | ForEach-Object { $_.Name } | Where-Object { $_ -notlike 'PS*' } | Sort-Object)) > "${baseFilename}.WinNTCurrVer.txt"

	if ($osbuild -ge 9200) {
		$featuresByName = Get-WindowsOptionalFeature -Online | Sort-Object FeatureName
		$featuresByName | Format-Table FeatureName,State > "${baseFilename}.windowsOptionalFeatures.txt"
		$featuresByName | Select-Object FeatureName,State | ConvertTo-Csv -NoTypeInformation > "${baseFilename}.windowsOptionalFeatures.csv"
		#$featuresByState = Get-WindowsOptionalFeature -Online | Sort-Object State,FeatureName
		#$featuresByState | Format-Table FeatureName,State > "${baseFilename}.windowsOptionalFeatures.byState.txt"
		#$featuresByState | Select-Object FeatureName,State | ConvertTo-Csv -NoTypeInformation > "${baseFilename}.windowsOptionalFeatures.byState.csv"

		Get-AppxPackage | Sort-Object Name | Format-Table Name,Version > "${baseFilename}.installedUserAppxPackages.txt"
		Get-AppxPackage | Sort-Object Name | Select-Object Name,Version | ConvertTo-Csv -NoTypeInformation > "${baseFilename}.installedUserAppxPackages.csv"

		# these throw "The specified module could not be found" on Server Core; haven't figured out how to handle that yet...
		Get-AppxProvisionedPackage -Online | Sort-Object DisplayName | Format-Table DisplayName,Version,PackageName > "${baseFilename}.installedSystemAppxPackages.txt"
		Get-AppxProvisionedPackage -Online | Sort-Object DisplayName | Select-Object DisplayName,Version,PackageName | ConvertTo-Csv -NoTypeInformation  > "${baseFilename}.installedSystemAppxPackages.csv"
	} elseif ($osbuild -ge 7600) {
		Dism.exe -Online -Get-Features -Format:Table > "${baseFilename}.windowsOptionalFeatures.byName.txt"
	} elseif ($osbuild -ge 6000 -and $osinfo.ProductType -eq 3) {
		Write-Host ""
		Write-Warning "cannot get list of features from dism.exe or powershell; try running ServerManagerCmd.exe (for Gui) or OcList.exe (for Core)"
	} else {
		Write-Host ""
		Write-Warning "cannot get list of features"
	}
}

function GetDotNetVersions {
	$netfx45RegKeyName = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full'
	$netfx45RegValueName = 'Release'
	$netfxStdRegValueName = 'Install'
	$netfxStdVersionRegValueName = 'Version'
	$netfx4SPxRegValueName = 'Servicing'

	$dotnet45ver = [int](GetRegPropertyValue $netfx45RegKeyName $netfx45RegValueName)
	$dotnet45sp = [int](GetRegPropertyValue $netfx45RegKeyName $netfx4SPxRegValueName)
	if ($dotnet45ver -ge 378389) {
		if ($dotnet45ver -ge 528040) { $ver = '4.8' }
		elseif ($dotnet45ver -ge 461808) { $ver = '4.7.2' }
		elseif ($dotnet45ver -ge 461308) {	$ver = '4.7.1' }
		elseif ($dotnet45ver -ge 460798) { $ver = '4.7' }
		elseif ($dotnet45ver -ge 394802) { $ver = '4.6.2' }
		elseif ($dotnet45ver -ge 394254) { $ver = '4.6.1' }
		elseif ($dotnet45ver -ge 393295) { $ver = '4.6' }
		elseif ($dotnet45ver -ge 379893) { $ver = '4.5.2' }
		elseif ($dotnet45ver -ge 378675) { $ver = '4.5.1' }
		else { $ver = '4.5' }
		if ($dotnet45sp -gt 0) { $sp = " w/ service pack $dotnet45sp" } else { $sp = '' }
		Write-Output ".NET Framework $ver$sp is installed."
	} else {
		$netfx40FullRegKeyName = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Full'
		$netfx40ClientRegKeyName = 'HKLM:\Software\Microsoft\NET Framework Setup\NDP\v4\Client'
		$dotnet4Version = [Version]"4.0.30319.0"

		$dotnet4fullinstall = [int](GetRegPropertyValue $netfx40FullRegKeyName $netfxStdRegValueName)
		$dotnet4fullver = [string](GetRegPropertyValue $netfx40FullRegKeyName $netfxStdVersionRegValueName)
		$dotnet4fullsp = [int](GetRegPropertyValue $netfx40FullRegKeyName $netfx4SPxRegValueName)
		$dotnet4clientinstall = [int](GetRegPropertyValue $netfx40ClientRegKeyName $netfxStdRegValueName)
		$dotnet4clientver = [string](GetRegPropertyValue $netfx40ClientRegKeyName $netfxStdVersionRegValueName)
		$dotnet4clientsp = [int](GetRegPropertyValue $netfx40FullRegKeyName $netfx4SPxRegValueName)
		if ($dotnet4fullinstall -gt 0 -and $dotnet4fullver) {
			$v = [Version]$dotnet4fullver
			if ($v -ge $dotnet4Version) {
				if ($dotnet4fullsp -gt 0) {
					Write-Output ".NET Framework 4 Full service pack $dotnet4fullsp is installed."
				} else {
					Write-Output ".NET Framework 4 Full is installed."
				}
			}
		}
		if ($dotnet4clientinstall -gt 0 -and $dotnet4clientver) {
			$v = [Version]$dotnet4clientver
			if ($v -ge $dotnet4Version) {
				if ($dotnet4clientsp -gt 0) {
					Write-Output ".NET Framework 4 Full service pack $dotnet4fullsp is installed."
				} else {
					Write-Output ".NET Framework 4 Full is installed."
				}
			}
		}
	}

	$netfx10RegKeyName = "HKLM:\Software\Microsoft\.NETFramework\Policy\v1.0"
	$netfx11RegKeyName = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v1.1.4322"
	$netfx20RegKeyName = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v2.0.50727"
	$netfx30RegKeyName = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.0\Setup"
	$netfx35RegKeyName = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.5"
	$netfx30SpRegKeyName = "HKLM:\Software\Microsoft\NET Framework Setup\NDP\v3.0"
	$netfx10RegValueName = "3705"
	$netfx30RegValueName = "InstallSuccess"
	$netfxStdSpRegValueName = "SP"

	$dotnet20install = [int](GetRegPropertyValue $netfx20RegKeyName $netfxStdRegValueName)
	if ($dotnet20install -gt 0) {
		# check for .NET 3.0
		$dotnet30install = [int](GetRegPropertyValue $netfx30RegKeyName $netfx30RegValueName)
		if ($dotnet30install -gt 0) {
			$dotnet30ver = [string](GetRegPropertyValue $netfx30RegKeyName $netfxStdVersionRegValueName)
			if ($dotnet30ver) {
				$dotnet30Version = [Version]"3.0.4506.26"
				$v30 = [Version]$dotnet30ver
				if ($v30 -ge $dotnet30Version) {
					# check for .NET 3.5
					$dotnet35install = [int](GetRegPropertyValue $netfx35RegKeyName $netfxStdRegValueName)
					if ($dotnet35install -gt 0) {
						$dotnet35ver = [string](GetRegPropertyValue $netfx35RegKeyName $netfxStdVersionRegValueName)
						if ($dotnet35ver) {
							$dotnet35Version = [Version]"3.5.21022.8"
							$v35 = [Version]$dotnet35ver
							if ($v35 -ge $dotnet35Version) {
								$dotnet35sp = [int](GetRegPropertyValue $netfx35RegKeyName $netfxStdSpRegValueName)
								if ($dotnet35sp -gt 0) {
									Write-Output ".NET Framework 3.5 w/ SP$dotnet35sp is installed."
								} else {
									Write-Output ".NET Framework 3.5 is installed."
								}
							}
						}
					}
				}
				$dotnet30sp = [int](GetRegPropertyValue $netfx30SpRegKeyName $netfxStdSpRegValueName)
				if ($dotnet30sp -gt 0) {
					Write-Output ".NET Framework 3.0 w/ SP$dotnet30sp is installed."
				} else {
					Write-Output ".NET Framework 3.0 is installed."
				}
			}
		}
		$dotnet20sp = [int](GetRegPropertyValue $netfx20RegKeyName $netfxStdSpRegValueName)
		if ($dotnet20sp -gt 0) {
			Write-Output ".NET Framework 2.0 w/ SP$dotnet20sp is installed."
		} else {
			Write-Output ".NET Framework 2.0 is installed."
		}
	}
	# look for .NET 1.1
	$dotnet11install = [int](GetRegPropertyValue $netfx11RegKeyName $netfxStdRegValueName)
	if ($dotnet11install -gt 0) {
		$dotnet11sp = [int](GetRegPropertyValue $netfx11RegKeyName $netfxStdSpRegValueName)
		if ($dotnet11sp -gt 0) {
			Write-Output ".NET Framework 1.1 w/ SP$dotnet20sp is installed."
		} else {
			Write-Output ".NET Framework 1.1 is installed."
		}
	}
	# TODO: check for .NET 1.0 (skipping for now, because, i kinda doubt we'll ever see it again anyway...)
	#$dotnet10install = [int](GetRegPropertyValue $netfx10RegKeyName $netfx10RegValueName)
}

function GetRegPropertyValue {
	param (
		[Parameter(Mandatory=$true)] [string]$registryPath,
		[string]$propertyName
	)
	if (-not $propertyName) { $propertyName = '(default)' }
	try {
		if (Test-Path -LiteralPath $registryPath) {
			return (Get-ItemProperty -Path $registryPath -Name $propertyName -ErrorAction Stop)."$propertyName"	# use quotes, because the '(default)' value will require it (others don't)
		}
		return $null
	} catch {
		if ($_.Exception -and $_.Exception.Message -like "Property $propertyName does not exist *") {
			Write-Verbose "$($MyInvocation.InvocationName): property |$propertyName| does not exist at path |$registryPath|"
			return $null
		} else {
			throw
		}
	}
}

function GetPowerShellVersion {
	if ($PSVersionTable.PSVersion) {
		return $PSVersionTable.PSVersion.ToString()
	} else {
		if (Test-Path 'HKLM:\Software\Microsoft\PowerShell\3') {
			$k = 'HKLM:\Software\Microsoft\PowerShell\3\PowerShellEngine'
		} else {
			$k = 'HKLM:\Software\Microsoft\PowerShell\1\PowerShellEngine'
		}
		return (GetRegPropertyValue $k 'PowerShellVersion')
	}
}

function GetWindowsName {
	param($wmios)

	$build = [int]$wmios.BuildNumber
	$type = [int]$wmios.ProductType
	$caption = [string]$wmios.Caption
	switch ($type) {
		1 {
			switch ($build) {
				{ $_ -ge 22000 } { $result = 'win11'; break; }
				{ $_ -ge 10240 } { $result = 'win10'; break; }
				{ $_ -ge 9600 } { $result = 'win8.1'; break; }
				{ $_ -ge 9200 } { $result = 'win8'; break; }
				{ $_ -ge 7600 } { $result = 'win7'; break; }
				{ $_ -ge 6000 } { $result = 'vista'; break; }
				default { $result = "desktop.$build"; break; }
			}
		}
		3 {
			switch ($build) {
				{ $_ -ge 17763 } {
						if ($caption -match '20\d\d') {		# can't find any other way to distinguish these...
							$result = 'srvr2019'
						} else {
							$result = 'srvr'
						}
						break
					}
				{ $_ -ge 16299 } { $result = 'srvr'; break; }
				{ $_ -ge 10240 } { $result = 'srvr2016'; break; }
				{ $_ -ge 9600 } { $result = 'srvr2012r2'; break; }
				{ $_ -ge 9200 } { $result = 'srvr2012'; break; }
				{ $_ -ge 7600 } { $result = 'srvr2008r2'; break; }
				{ $_ -ge 6000 } { $result = 'srvr2008'; break; }
				default { $result = "srvr.$build"; break; }
			}
		}
	}
	Write-Verbose "trying to map OS name: build = '$build', type = '$type' ==> '$result'"
	return $result
}

function GetVersion {
	param([string] $os, $wmios)
	$bld = [int]$wmios.BuildNumber
	switch ($os) {
		'srvr2008' { if ($bld -eq 6001) {$result = 'rtm'} else {$result = 'sp2'} }
		'srvr2008r2' { if ($bld -eq 7600) {$result = 'rtm'} else {$result = 'sp1'} }
		'srvr2012' { $result = 'rtm' }
		'srvr2012r2' { $result = 'rtm' }
		'srvr2016' { $result = 'rtm' }
		'srvr' {
			switch ($bld) {
				16299 { $result = '1709' }
				17134 { $result = '1803' }
				17763 { $result = '1809' }
				18362 { $result = '1903' }
				18363 { $result = '1909' }
				19041 { $result = '2004' }
				19042 { $result = '20H2' }
				default { $result = 'qqqq' }
			}
		}
		'srvr2019' { $result = 'rtm' }
		'vista' { if ($bld -eq 6000) {$result = 'rtm'} elseif ($bld -eq 6001) {$result = 'sp1'} else {$result = 'sp2'} }
		'win7' { if ($bld -eq 7600) {$result = 'rtm'} else {$result = 'sp1'} }
		'win8' { $result = 'rtm' }
		'win8.1' { $result = 'rtm' }
		'win10' {
			$result = 'zzzz'
			if ($bld -eq 10240) { $result = 'rtm' }
			elseif ($bld -eq 10586) { $result = '1511' }
			elseif ($bld -eq 14393) { $result = '1607' }
			elseif ($bld -eq 15063) { $result = '1703' }
			elseif ($bld -eq 16299) { $result = '1709' }
			elseif ($bld -ge 17134) {
				# somewhere in here they started putting it in the registry, so look there:
				$result = GetWinVersionFromReg
			}
		}
		'win11' {
			if ($bld -eq 22000) { $result = 'rtm' }
			else { $result = GetWinVersionFromReg }
		}
		default { $result = 'xxxxxx' }
	}
	Write-Verbose "trying to map OS version: os = '$os', bld = '$bld' ==> '$result'"
	return $result
}

function GetEdition {
	param($wmios)
	$ossku = $wmios.OperatingSystemSKU
	switch ($ossku) {
		48 {
			# Pro Education originally had same SKU as Pro; real SKU below added later...
			if ($wmios.Caption -notlike '*Education*') {
				$result = 'pro'
			} else {
				$result = 'proEdu'
			}
		}
		49 {
			if ($wmios.Caption -notlike '*Education*') {
				$result = 'proN'
			} else {
				$result = 'proEduN'
			}
		}
		161 { $result = 'proWks' }
		162 { $result = 'proWksN' }
		164 { $result = 'proEdu' }
		165 { $result = 'proEduN' }
		2 { $result = 'homeBasic' }
		3 { $result = 'homePrem' }
		101 { $result = 'home' }
		5 { $result = 'homeBasicN' }
		26 { $result = 'homePremN' }
		98 { $result = 'homeN' }
		100 { $result = 'homeSingleLang' }	# or is it 'Core Single Language' ??
		4 { $result = 'ent' }
		27 { $result = 'entN' }
		1 { $result = 'ult' }
		28 { $result = 'ultN' }
		11 { $result = 'starter' }
		47 { $result = 'starterN' }
		121 { $result = 'edu' }
		122 { $result = 'eduN' }
		# servers:
		50 { $result = 'ess' }
		7 { $result = 'std' }
		13 { $result = 'stdCore' }			# only < Srvr2012
		8 { $result = 'dc' }
		12 { $result = 'dcCore' }			# only < Srvr2012
		10 { $result = 'ent' }
		14 { $result = 'entCore' }			# only < Srvr2012
		17 { $result = 'web' }
		29 { $result = 'webCore' }			# only < Srvr2012
		21 { $result = 'strgStd' }
		22 { $result = 'strgWg' }
		143 { $result = 'dcNano' }			# Windows Server Datacenter Edition (Nano Server installation)
		144 { $result = 'stdNano' }			# Windows Server Standard Edition (Nano Server installation)
		145 { $result = 'dcCore' }			# ?????
		146 { $result = 'stdCore' }			# ?????
		147 { $result = 'dcCore' }			# Windows Server Datacenter Edition (Server Core installation)
		148 { $result = 'stdCore' }			# Windows Server Standard Edition (Server Core installation)
		default { $result = 'xxxxxxxx' }
	}
	Write-Verbose "trying to map OS edition: ossku = '$ossku' ==> '$result'"
	$result
}

function GetWinVersionFromReg {
	# somewhere in here they started putting it in the registry, so look there:
	$result = (Get-ItemProperty -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion').DisplayVersion	# new with 20H2 (2009)
	if (-not $result) {
		$result = (Get-ItemProperty -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion').ReleaseId
	}
	return $result
}

#==============================
Main
#==============================
