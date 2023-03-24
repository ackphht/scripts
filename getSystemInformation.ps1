#Requires -Version 5.1

using namespace System.Collections.Generic

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $asJson,
	[switch] $asCsv,
	[switch] $asText,
	[string] $outputFolder
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue
#Set-StrictMode -Version Latest

. $PSScriptRoot/helpers.ps1
. $PSScriptRoot/populateSystemData.ps1

$script:NA = 'N/A'

function Main {
	[CmdletBinding(SupportsShouldProcess=$false)]
	param(
		[switch] $saveJson,
		[switch] $saveCsv,
		[switch] $saveText,
		[string] $saveToFldr
	)
	$allResults = @{}
	WriteVerboseMessage 'dumping environment vars'
	$allResults.EnvVars = Get-ChildItem -Path env: | Select-Object -Property Name,Value | Sort-Object -Property Name

	# dump out special folder paths (??)
	WriteVerboseMessage 'getting special folders'
	$allResults.SpecFldrs = [System.Enum]::GetValues([System.Environment+SpecialFolder]) |
					ForEach-Object { [PSCustomObject]@{ Folder = $_.ToString(); Path = [System.Environment]::GetFolderPath($_); } } |
					Sort-Object -Property Folder

	$unameAvail = [bool](Get-Command -Name 'uname' -ErrorAction Ignore)
	$cimInstanceAvail = [bool](Get-Command -Name 'Get-CimInstance' -ErrorAction Ignore)

	if ($unameAvail) {
		WriteVerboseMessage 'getting uname info'
		$allResults.UnameVals =  @(@{ nm = 'kernel-name'; op = 's'; }, @{ nm = 'kernel-release'; op = 'r'; }, @{ nm = 'kernel-version'; op = 'v'; },
					@{ nm = 'machine'; op = 'm'; }, @{ nm = 'processor'; op = 'p'; }, @{ nm = 'hardware-platform'; op = 'i'; },
					@{ nm = 'operating-system'; op = 'o'; }) |
				ForEach-Object {
					$v = uname -$($_.op) 2>/dev/null
					if ($LASTEXITCODE -eq 0) {
						[PSCustomObject]@{ Name = $_.nm; Value = $v; }
					}
				}
	}

	# get system properties/data/etc:
	WriteVerboseMessage 'getting system properties'

	$results = [List[PSObject]]::new(16) #[PSObject]::new()
	_addProperty -obj $results -propName 'PSVersion_PowerShell' -propValue $PSVersionTable.PSVersion
	_addProperty -obj $results -propName 'PSVersion_Edition' -propValue $PSVersionTable.PSEdition
	_addProperty -obj $results -propName 'PSVersion_Platform' -propValue $PSVersionTable.Platform
	_addProperty -obj $results -propName 'PSVersion_OS' -propValue $PSVersionTable.OS

	_addProperty -obj $results -propName 'Var_PSEdition' -propValue (_getVariableValue -varName 'PSEdition')
	_addProperty -obj $results -propName 'Var_IsCoreCLR' -propValue (_getVariableValue -varName 'IsCoreCLR')
	_addProperty -obj $results -propName 'Var_IsWindows' -propValue (_getVariableValue -varName 'IsWindows')
	_addProperty -obj $results -propName 'Var_IsLinux' -propValue (_getVariableValue -varName 'IsLinux')
	_addProperty -obj $results -propName 'Var_IsMacOS' -propValue (_getVariableValue -varName 'IsMacOS')

	_addProperty -obj $results -propName 'SysEnv_DotNetVersion' -propValue ([System.Environment]::Version.ToString())
	_addProperty -obj $results -propName 'SysEnv_OSPlatform' -propValue ([System.Environment]::OSVersion.Platform)
	_addProperty -obj $results -propName 'SysEnv_OSVersion' -propValue ([System.Environment]::OSVersion.Version.ToString())
	_addProperty -obj $results -propName 'SysEnv_OSVersionString' -propValue ([System.Environment]::OSVersion.VersionString)
	_addProperty -obj $results -propName 'SysEnv_Is64BitOperatingSystem' -propValue ([System.Environment]::Is64BitOperatingSystem)
	_addProperty -obj $results -propName 'SysEnv_Is64BitProcess' -propValue ([System.Environment]::Is64BitProcess)
	_addProperty -obj $results -propName 'SysEnv_ProcessorCount' -propValue ([System.Environment]::ProcessorCount)
	_addProperty -obj $results -propName 'SysEnv_Newline' -propValue (_charsToString -chars ([System.Environment]::NewLine))

	_addProperty -obj $results -propName 'Path_DirectorySeparatorChar' -propValue ([System.IO.Path]::DirectorySeparatorChar)
	_addProperty -obj $results -propName 'Path_AltDirectorySeparatorChar' -propValue ([System.IO.Path]::AltDirectorySeparatorChar)
	_addProperty -obj $results -propName 'Path_PathSeparator' -propValue ([System.IO.Path]::PathSeparator)
	_addProperty -obj $results -propName 'Path_VolumeSeparatorChar' -propValue ([System.IO.Path]::VolumeSeparatorChar)
	_addProperty -obj $results -propName 'Path_InvalidPathChars' -propValue (_charsToString -chars ([System.IO.Path]::InvalidPathChars))
	_addProperty -obj $results -propName 'Path_InvalidFileNameChars' -propValue (_charsToString -chars ([System.IO.Path]::GetInvalidFileNameChars()))

	WriteVerboseMessage 'getting runtime info'
	if ($IsMacOS) {
		# cache this, avoid a couple redundant calls below:
		$macOsData = (system_profiler -json SPHardwareDataType SPSoftwareDataType) | ConvertFrom-Json
	} else {
		$macOsData = [PSCustomObject]@{}
	}
	@('OSArchitecture', 'ProcessArchitecture', 'OSDescription', 'FrameworkDescription', 'RuntimeIdentifier') |
		ForEach-Object { _addProperty -obj $results -propName "RuntimeInfo_$_" -propValue '' }
	if ([bool]('System.Runtime.InteropServices.RuntimeInformation' -as [type])) {
		_setProperty -obj $results -propName 'RuntimeInfo_OSArchitecture' -propValue ([System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture)
		_setProperty -obj $results -propName 'RuntimeInfo_ProcessArchitecture' -propValue ([System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture)
		_setProperty -obj $results -propName 'RuntimeInfo_OSDescription' -propValue ([System.Runtime.InteropServices.RuntimeInformation]::OSDescription)
		_setProperty -obj $results -propName 'RuntimeInfo_FrameworkDescription' -propValue ([System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription)
		_setProperty -obj $results -propName 'RuntimeInfo_RuntimeIdentifier' -propValue ([System.Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier)
	}

	WriteVerboseMessage 'getting Computer info'
	@('Manufacturer', 'Model', 'SystemType', 'BIOSVersion', 'SerialNumber') |
		ForEach-Object { _addProperty -obj $results -propName "Computer_$_" -propValue '' }
	if ($cimInstanceAvail) {
		$cs = Get-CimInstance -ClassName 'CIM_ComputerSystem'
		if ($cs) {
			_setProperty -obj $results -propName 'Computer_Manufacturer' -propValue $cs.Manufacturer
			_setProperty -obj $results -propName 'Computer_Model' -propValue $cs.Model
			_setProperty -obj $results -propName 'Computer_SystemType' -propValue $cs.SystemType
		}
		$be = Get-CimInstance -ClassName 'CIM_BIOSElement'
		if ($be) {
			_setProperty -obj $results -propName 'Computer_BIOSVersion' -propValue $be.Description
			_setProperty -obj $results -propName 'Computer_SerialNumber' -propValue $be.SerialNumber
		}
	} elseif ($IsMacOS) {
		_setProperty -obj $results -propName 'Computer_Manufacturer' -propValue 'Apple'
		_setProperty -obj $results -propName 'Computer_Model' -propValue ('{0} ({1}) [model#: {2}]' -f $macOsData.SPHardwareDataType.machine_name, $macOsData.SPHardwareDataType.machine_model, $macOsData.SPHardwareDataType.model_number)
		_setProperty -obj $results -propName 'Computer_BIOSVersion' -propValue $macOsData.SPHardwareDataType.boot_rom_version
		_setProperty -obj $results -propName 'Computer_SerialNumber' -propValue $macOsData.SPHardwareDataType.serial_number
		_setProperty -obj $results -propName 'Computer_SystemType' -propValue (uname -m <# --machine; macOS doesn't support the '--' options ??? #>)
	}

	WriteVerboseMessage 'getting OS info'
	@('Platform', 'Distributor', 'Name', 'Id', 'Release', 'Version', 'OSArchitecture', 'Kernel', 'SKU', 'OSType', 'Codename') |
		ForEach-Object { _addProperty -obj $results -propName "OS_$_" -propValue '' }
	$osDetails = Get-OSDetails
	_setProperty -obj $results -propName 'OS_Platform' -propValue $osDetails.Platform
	_setProperty -obj $results -propName 'OS_Distributor' -propValue $osDetails.Distributor
	_setProperty -obj $results -propName 'OS_Name' -propValue $osDetails.Description
	_setProperty -obj $results -propName 'OS_Id' -propValue $osDetails.Id
	_setProperty -obj $results -propName 'OS_Release' -propValue $osDetails.Release
	_setProperty -obj $results -propName 'OS_Version' -propValue $osDetails.ReleaseVersion.ToString()
	_setProperty -obj $results -propName 'OS_OSArchitecture' -propValue $osDetails.OSArchitecture
	_setProperty -obj $results -propName 'OS_Kernel' -propValue $osDetails.KernelVersion
	_setProperty -obj $results -propName 'OS_Codename' -propValue $osDetails.Codename
	if ($cimInstanceAvail) {
		$os = Get-CimInstance -ClassName 'CIM_OperatingSystem'
		if ($os) {
			_setProperty -obj $results -propName 'OS_SKU' -propValue $os.OperatingSystemSKU
			_setProperty -obj $results -propName 'OS_OSType' -propValue $os.OSType
		}
	}

	WriteVerboseMessage 'getting processor info'
	_addProperty -obj $results -propName 'Processor_IsLittleEndian' -propValue ([System.BitConverter]::IsLittleEndian)
	@('Name', 'Description', 'Architecture', 'AddressWidth', 'DataWidth', 'L2CacheSize', 'L3CacheSize', 'NumberOfCores', 'LogicalProcessors', 'ProcessorId') |
		ForEach-Object { _addProperty -obj $results -propName "Processor_$_" -propValue '' }
	if ($cimInstanceAvail) {
		$proc = Get-CimInstance -ClassName 'CIM_Processor'
		if ($proc) {
			_setProperty -obj $results -propName 'Processor_Name' -propValue $proc.Name
			_setProperty -obj $results -propName 'Processor_Description' -propValue $proc.Description
			_setProperty -obj $results -propName 'Processor_Architecture' -propValue (_mapCimProcArch -arch $proc.Architecture)
			_setProperty -obj $results -propName 'Processor_AddressWidth' -propValue $proc.AddressWidth
			_setProperty -obj $results -propName 'Processor_DataWidth' -propValue $proc.DataWidth
			_setProperty -obj $results -propName 'Processor_L2CacheSize' -propValue $proc.L2CacheSize
			_setProperty -obj $results -propName 'Processor_L3CacheSize' -propValue $proc.L3CacheSize
			_setProperty -obj $results -propName 'Processor_NumberOfCores' -propValue $proc.NumberOfCores
			_setProperty -obj $results -propName 'Processor_LogicalProcessors' -propValue $proc.NumberOfLogicalProcessors
			_setProperty -obj $results -propName 'Processor_ProcessorId' -propValue $proc.ProcessorId
		}
	} elseif ($IsMacOS) {
		_setProperty -obj $results -propName 'Processor_Name' -propValue $macOsData.SPHardwareDataType.chip_type
		_setProperty -obj $results -propName 'Processor_Architecture' -propValue (uname -m <# --machine #>)
		_setProperty -obj $results -propName 'Processor_L2CacheSize' -propValue (sysctl -hin hw.l2cachesize)
		_setProperty -obj $results -propName 'Processor_L3CacheSize' -propValue (sysctl -hin hw.l3cachesize)	# doesn't exist but maybe will get added
		_setProperty -obj $results -propName 'Processor_NumberOfCores' -propValue (sysctl -hin hw.physicalcpu)
		_setProperty -obj $results -propName 'Processor_LogicalProcessors' -propValue (sysctl -hin hw.logicalcpu)
		# don't see anything better for these next two:
		_setProperty -obj $results -propName 'Processor_AddressWidth' -propValue $(if ([System.Environment]::Is64BitOperatingSystem) { '64' } else { '32' })
		_setProperty -obj $results -propName 'Processor_DataWidth' -propValue $(if ([System.Environment]::Is64BitOperatingSystem) { '64' } else { '32' })
	} elseif ((Get-Command -Name 'lscpu' -ErrorAction Ignore)) {
		$lscpu = lscpu | ParseLinesToLookup
		_setProperty -obj $results -propName 'Processor_Name' -propValue $lscpu['Model name']
		_setProperty -obj $results -propName 'Processor_Architecture' -propValue $lscpu['Architecture']
		_setProperty -obj $results -propName 'Processor_AddressWidth' -propValue $lscpu['Address sizes']
		$coresPerSocket = $lscpu['Core(s) per socket']
		$socketCnt = $lscpu['Socket(s)']
		if ($coresPerSocket -and $socketCnt) {
			_setProperty -obj $results -propName 'Processor_NumberOfCores' -propValue ([int]$coresPerSocket * [int]$socketCnt)
		}
		_setProperty -obj $results -propName 'Processor_LogicalProcessors' -propValue $lscpu['CPU(s)']
		_setProperty -obj $results -propName 'Processor_L2CacheSize' -propValue $lscpu['L2 cache']
		_setProperty -obj $results -propName 'Processor_L3CacheSize' -propValue $lscpu['L3 cache']
	} elseif ((Test-Path -Path '/proc/cpuinfo' -ErrorAction Ignore)) {
		$cpuinfo = Get-Content -Path '/proc/cpuinfo' | ParseLinesToLookup -saveFirstValue
		_setProperty -obj $results -propName 'Processor_Name' -propValue $cpuinfo['model name']
		_setProperty -obj $results -propName 'Processor_AddressWidth' -propValue $cpuinfo['address sizes']
		_setProperty -obj $results -propName 'Processor_NumberOfCores' -propValue $cpuinfo['cpu cores']
		# ???:
		_setProperty -obj $results -propName 'Processor_LogicalProcessors' -propValue $cpuinfo['siblings']
		_setProperty -obj $results -propName 'Processor_L3CacheSize' -propValue $cpuinfo['cache size']
	}
	$procArch = $results | Where-Object { $_.Name -eq 'Processor_Architecture' }
	if ((-not $procArch -or $procArch.Value -eq $script:NA) -and $unameAvail) {
		$procarch = (uname --processor <# right ?? #>)
		if (-not $procarch -or $procarch -eq 'unknown') {
			$procarch = (uname --machine)	<# fall back; or should we just leave it blank ?? #>
		}
		_setProperty -obj $results -propName 'Processor_Architecture' -propValue $procarch
	}
	$procDesc = $results | Where-Object { $_.Name -eq 'Processor_Description' }
	$procName = $results | Where-Object { $_.Name -eq 'Processor_Name' }
	if ($procName -and (-not $procDesc -or $procDesc.Value -eq $script:NA)) {
		_setProperty -obj $results -propName 'Processor_Description' -propValue $procName.Value
	}
	_addProperty -obj $results -propName 'Processor_IsVectorHardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVectorHardwareAccelerated)
	_addProperty -obj $results -propName 'Processor_IsVector64HardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVector64HardwareAccelerated)
	_addProperty -obj $results -propName 'Processor_IsVector128HardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVector128HardwareAccelerated)
	_addProperty -obj $results -propName 'Processor_IsVector256HardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVector256HardwareAccelerated)

	WriteVerboseMessage 'getting env var info'
	_addProperty -obj $results -propName 'EnvVar_ProcessorArchitecture' -propValue (_getEnvVarValue -envVarName 'Processor_Architecture')
	_addProperty -obj $results -propName 'EnvVar_ProcessorIdentifier' -propValue (_getEnvVarValue -envVarName 'Processor_Identifier')
	_addProperty -obj $results -propName 'EnvVar_CPU' -propValue (_getEnvVarValue -envVarName 'CPU')
	_addProperty -obj $results -propName 'EnvVar_HostType' -propValue (_getEnvVarValue -envVarName 'HostType')
	_addProperty -obj $results -propName 'EnvVar_OsType' -propValue (_getEnvVarValue -envVarName 'OsType')

	$allResults.SysProps = $results

	if ($saveJson -or $saveCsv -or $saveText) {
		$scriptname = Split-Path -Path $PSCommandPath -LeafBase
		$outputBaseName = if ($saveToFldr) { Join-Path $saveToFldr $scriptname } else { $scriptname }
		if ($saveJson) {
			$encoding = if ($PSEdition -ne 'Core') { 'UTF8' } else { 'UTF8NoBOM' }
			ConvertTo-ProperFormattedJson -InputObject $allResults.EnvVars | Set-Content -LiteralPath "$outputBaseName.EnvVars.json" -Encoding $encoding -NoNewline
			ConvertTo-ProperFormattedJson -InputObject $allResults.SpecFldrs | Set-Content -LiteralPath "$outputBaseName.SpecFldrs.json" -Encoding $encoding -NoNewline
			if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
				ConvertTo-ProperFormattedJson -InputObject $allResults.UnameVals | Set-Content -LiteralPath "$outputBaseName.Uname.json" -Encoding $encoding -NoNewline
			}
			ConvertTo-ProperFormattedJson -InputObject $allResults.SysProps | Set-Content -LiteralPath "$outputBaseName.SysProps.json" -Encoding $encoding -NoNewline
		}
		if ($saveCsv) {
			$parms = @{ NoTypeInformation = $true; }
			if ($PSEdition -eq 'Core') { $parms.Add('UseQuotes', 'AsNeeded') }
			$allResults.EnvVars | Export-Csv -LiteralPath "$outputBaseName.EnvVars.csv" @parms
			$allResults.SpecFldrs | Export-Csv -LiteralPath "$outputBaseName.SpecFldrs.csv" @parms
			if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
				$allResults.UnameVals | Export-Csv -LiteralPath "$outputBaseName.Uname.csv" @parms
			}
			$allResults.SysProps | Export-Csv -LiteralPath "$outputBaseName.SysProps.csv" @parms
		}
		if ($saveText) {
			$allResults.EnvVars | Format-Table -AutoSize | Out-File -LiteralPath "$outputBaseName.EnvVars.txt" -Width 4096
			$allResults.SpecFldrs | Format-Table -AutoSize -Property Folder,Path | Out-File -LiteralPath "$outputBaseName.SpecFldrs.txt" -Width 4096
			if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
				$allResults.UnameVals | Format-Table -AutoSize | Out-File -LiteralPath "$outputBaseName.Uname.txt" -Width 4096
			}
			$allResults.SysProps | Format-Table -AutoSize | Out-File -LiteralPath "$outputBaseName.SysProps.txt" -Width 4096
		}
	} else {
		WriteHeader -text 'Environment Variables' -includeExtraSpace $false
		$allResults.EnvVars | Format-Table -AutoSize
		WriteHeader -text 'System Special Folders'
		$allResults.SpecFldrs | Format-Table -Property Folder,Path -AutoSize
		if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
			WriteHeader -text 'uname'
			$allResults.UnameVals | Format-Table -AutoSize
		}
		WriteHeader -text 'System Properties'
		$allResults.SysProps | Format-Table -AutoSize
	}
}

function _addProperty {
	[OutputType([void])]
	param(
		<# [Parameter(Mandatory=$true)] #> [ValidateNotNull()] [List[PSObject]] $obj,
		[Parameter(Mandatory=$true)] [string] $propName,
		[object] $propValue,
		[switch] $allowNull
	)
	if (-not $allowNull -and ($propValue -eq $null -or ($propValue -is [string] -and $propValue -eq ''))) { $propValue = $script:NA }
	$obj.Add([PSCustomObject]@{ Name = $propName; Value = $propValue; })
}

function _setProperty {
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [List[PSObject]] $obj,
		[Parameter(Mandatory=$true)] [string] $propName,
		[object] $propValue,
		[switch] $allowNull
	)
	if (-not $allowNull -and -not $propValue) { $propValue = $script:NA }
	$nv = $obj | Where-Object { $_.Name -eq $propName }
	if ($nv) {
		$nv.Value = $propValue
	} else {
		Write-Error "supposed to set a property named '$propName' but no property found with that name"
	}
}

function _getVariableValue {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)] [string] $varName
	)
	$value = $script:NA
	$v = Get-Variable -Name $varName -ErrorAction SilentlyContinue
	if ($v) {
		$value = $v.Value
	}
	WriteVerboseMessage 'value for variable |{0}| = |{1}|' @($varName, $value)
	return $value
}

function _getEnvVarValue {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)] [string] $envVarName
	)
	$value = $script:NA
	$v = Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue
	if ($v) {
		$value = $v.Value
	}
	WriteVerboseMessage 'value for envVar |{0}| = |{1}|' @($envVarName, $value)
	return $value
}

function _mapCimProcArch {
	[OutputType([string])]
	param(
		[int] $arch
	)
	switch ($arch) {
		0 { return '0 [x86]' }
		1 { return '1 [MIPS]' }
		2 { return '2 [Alpha]' }
		3 { return '3 [PowerPC]' }
		5 { return '5 [ARM32]' }
		6 { return '6 [ia64]' }
		9 { return '9 [x64]' }
		12 { return '12 [ARM64]' }
		default { return "$arch [Other]" }
	}
}

$script:nonDisplayCharsMap = @{
	[char]0 = '\x00'; [char]1 = '\x01'; [char]2 = '\x02'; [char]3 = '\x03'; [char]4 = '\x04'; [char]5 = '\x05'; [char]6 = '\x05'; [char]7 = '\x07';
	[char]8 = '\b'; [char]9 = '\t'; [char]0x0a = '\n'; [char]0x0b = '\x0b'; [char]0x0c = '\f'; [char]0x0d = '\r'; [char]0x0e = '\x0e'; [char]0x0f = '\x0f';
	[char]0x10 = '\x10'; [char]0x11 = '\x11'; [char]0x12 = '\x12'; [char]0x13 = '\x13'; [char]0x14 = '\x14'; [char]0x15 = '\x15'; [char]0x16 = '\x16'; [char]0x17 = '\x17';
	[char]0x18 = '\x18'; [char]0x19 = '\x19'; [char]0x1a = '\x1a'; [char]0x1b = '\x1b'; [char]0x1c = '\x1c'; [char]0x1d = '\x1d'; [char]0x1e = '\x1e'; [char]0x1f = '\x1f';
	[char]0x20 = '␠'; [char]0x7f = '\x7f'; [char]0xa0<#NBSP#> = '\xa0'; [char]0x85<#NEL#> = '\x85'; [char]0x2028<#LS#> = '\u2028'; [char]0x2029<#PS#> = '\u2029';
}

function _charsToString {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param(
		[char[]] $chars
	)
	if ($chars) {
		$sb = [System.Text.StringBuilder]::new(512)
		foreach ($c in ($chars | Sort-Object)) {
			if ($sb.Length -gt 0) { [void]$sb.Append(' ') }
			if ($script:nonDisplayCharsMap.ContainsKey($c)) {
				[void]$sb.Append($script:nonDisplayCharsMap[$c])
			} else {
				[void]$sb.Append($c)
			}
		}
		return $sb.ToString()
	}
	return ''
}

$script:divider = [string]::new('=', 80)
function WriteHeader {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $text,
		[bool] $includeExtraSpace = $true
	)
	if ($includeExtraSpace) {
		Write-Output ''
		Write-Output ''
	}
	Write-Output $script:divider
	Write-Output $text
	Write-Output $script:divider
}

if ($PSVersionTable.PSVersion -ge '7.3.0') {
	# doing this with a compiled code because if just call the properties directly,
	# they always return false because they need RyuJit and PowerShell turns that off ??
	# but doing it this way they seem to work...
	Add-Type -TypeDefinition @"
namespace AckWare {
	public static class Intrinsics {
		public static bool IsVectorHardwareAccelerated => System.Numerics.Vector.IsHardwareAccelerated;
		public static bool IsVector64HardwareAccelerated => System.Runtime.Intrinsics.Vector64.IsHardwareAccelerated;
		public static bool IsVector128HardwareAccelerated => System.Runtime.Intrinsics.Vector128.IsHardwareAccelerated;
		public static bool IsVector256HardwareAccelerated => System.Runtime.Intrinsics.Vector256.IsHardwareAccelerated;
	}
}
"@
} else {
	# processor might support these, but this version of .NET and/or PowerShell can't tell:
	Add-Type -TypeDefinition @"
namespace AckWare {
	public static class Intrinsics {
		public static bool IsVectorHardwareAccelerated => false;
		public static bool IsVector64HardwareAccelerated => false;
		public static bool IsVector128HardwareAccelerated => false;
		public static bool IsVector256HardwareAccelerated => false;
	}
}
"@
}

#==============================
Main -saveJson:$asJson -saveCsv:$asCsv -saveText:$asText -saveToFldr $outputFolder
#==============================
