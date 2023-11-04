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
Set-StrictMode -Version Latest

Import-Module -Name $PSScriptRoot/ackPoshHelpers
Import-Module -Name $PSScriptRoot/populateSystemData

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

	#region powershell vars
	WriteVerboseMessage 'dumping posh variables'
	$allResults.PoshVars = Get-Variable -Scope Global |
		Where-Object {
			# skip these:
			$_.Name -notin @('StackTrace','Error','null','args','false','true','foreach','input','PSBoundParameters','PSDefaultParameterValues','PWD','kh')
		} |
		ForEach-Object {
			# one or more of these is causing an infinite loop trying to serialize to json, but name is good enough:
			if ($_.Name -in @('ExecutionContext','Host','MyInvocation','OutputEncoding','PSSessionOption','mod')) {
				$value = $_.Value.GetType().FullName
			} else {
				$value = $_.Value
			}
			Write-Output ([PSCustomObject]@{ Name = $_.Name; Value = $value })
		}
		Sort-Object -Property Name
	#endregion

	#region dump out special folder paths (??)
	WriteVerboseMessage 'getting special folders'
	$allResults.SpecFldrs = [System.Enum]::GetValues([System.Environment+SpecialFolder]) |
					ForEach-Object { [PSCustomObject]@{ Folder = $_.ToString(); Path = [System.Environment]::GetFolderPath($_); } } |
					Sort-Object -Property Folder
	#endregion

	$unameAvail = [bool](Get-Command -Name 'uname' -ErrorAction Ignore)
	$cimInstanceAvail = [bool](Get-Command -Name 'Get-CimInstance' -ErrorAction Ignore)
	$onWindows = [bool](_getVariableValue -n 'IsWindows' -defaultIfNotExists $true)
	$onMacOs = [bool](_getVariableValue -n 'IsMacOS')

	#region uname
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
	#endregion

	#region WinNT\CurrVer
	if ($onWindows) {
		WriteVerboseMessage 'getting WindowsNT\CurrentVersion info'
		$cv = Get-ItemProperty -path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion'
		$allResults.WinNTCurrVer = GetSortedPropertyNames -object $cv |
										Where-Object { $_ -notlike 'PS*' -and $_ -notin @('BuildGUID','InstallDate','InstallTime','PendingInstall',
																							'RegisteredOwner','DigitalProductId','DigitalProductId4') } |
										ForEach-Object { [PSCustomObject]@{ Value=$_; Data=$cv.$_; } }
	}
	#endregion

	#region get system properties

	#region get posh, .net, path info
	WriteVerboseMessage 'getting system properties'

	$results = [List[PSObject]]::new(16) #[PSObject]::new()
	_addProperty -o $results -n 'PSVersion_PowerShell' -v $PSVersionTable.PSVersion
	_addProperty -o $results -n 'PSVersion_Edition' -v $PSVersionTable.PSEdition
	_addProperty -o $results -n 'PSVersion_Platform' -v (_getPropertyIfExists -o $PSVersionTable -n 'Platform')
	_addProperty -o $results -n 'PSVersion_OS' -v (_getPropertyIfExists -o $PSVersionTable -n 'OS')

	_addProperty -o $results -n 'Var_PSEdition' -v (_getVariableValue -n 'PSEdition')
	_addProperty -o $results -n 'Var_IsCoreCLR' -v (_getVariableValue -n 'IsCoreCLR')
	_addProperty -o $results -n 'Var_IsWindows' -v (_getVariableValue -n 'IsWindows')
	_addProperty -o $results -n 'Var_IsLinux' -v (_getVariableValue -n 'IsLinux')
	_addProperty -o $results -n 'Var_IsMacOS' -v (_getVariableValue -n 'IsMacOS')

	_addProperty -o $results -n 'SysEnv_DotNetVersion' -v ([System.Environment]::Version.ToString())
	_addProperty -o $results -n 'SysEnv_OSPlatform' -v ([System.Environment]::OSVersion.Platform)
	_addProperty -o $results -n 'SysEnv_OSVersion' -v ([System.Environment]::OSVersion.Version.ToString())
	_addProperty -o $results -n 'SysEnv_OSVersionString' -v ([System.Environment]::OSVersion.VersionString)
	_addProperty -o $results -n 'SysEnv_Is64BitOperatingSystem' -v ([System.Environment]::Is64BitOperatingSystem)
	_addProperty -o $results -n 'SysEnv_Is64BitProcess' -v ([System.Environment]::Is64BitProcess)
	_addProperty -o $results -n 'SysEnv_ProcessorCount' -v ([System.Environment]::ProcessorCount)
	_addProperty -o $results -n 'SysEnv_Newline' -v (_charsToString -chars ([System.Environment]::NewLine))

	_addProperty -o $results -n 'Path_DirectorySeparatorChar' -v ([System.IO.Path]::DirectorySeparatorChar)
	_addProperty -o $results -n 'Path_AltDirectorySeparatorChar' -v ([System.IO.Path]::AltDirectorySeparatorChar)
	_addProperty -o $results -n 'Path_PathSeparator' -v ([System.IO.Path]::PathSeparator)
	_addProperty -o $results -n 'Path_VolumeSeparatorChar' -v ([System.IO.Path]::VolumeSeparatorChar)
	_addProperty -o $results -n 'Path_InvalidPathChars' -v (_charsToString -chars ([System.IO.Path]::InvalidPathChars))
	_addProperty -o $results -n 'Path_InvalidFileNameChars' -v (_charsToString -chars ([System.IO.Path]::GetInvalidFileNameChars()))
	#endregion

	#region runtime info
	WriteVerboseMessage 'getting runtime info'
	@('OSArchitecture', 'ProcessArchitecture', 'OSDescription', 'FrameworkDescription', 'RuntimeIdentifier') |
		ForEach-Object { _addProperty -o $results -n "RuntimeInfo_$_" -v '' }
	if ([bool]('System.Runtime.InteropServices.RuntimeInformation' -as [type])) {
		_setProperty -o $results -n 'RuntimeInfo_OSArchitecture' -v (_getStaticPropertyIfExists -t 'System.Runtime.InteropServices.RuntimeInformation' -n 'OSArchitecture')
		_setProperty -o $results -n 'RuntimeInfo_ProcessArchitecture' -v (_getStaticPropertyIfExists -t 'System.Runtime.InteropServices.RuntimeInformation' -n 'ProcessArchitecture')
		_setProperty -o $results -n 'RuntimeInfo_OSDescription' -v (_getStaticPropertyIfExists -t 'System.Runtime.InteropServices.RuntimeInformation' -n 'OSDescription')
		_setProperty -o $results -n 'RuntimeInfo_FrameworkDescription' -v (_getStaticPropertyIfExists -t 'System.Runtime.InteropServices.RuntimeInformation' -n 'FrameworkDescription')
		_setProperty -o $results -n 'RuntimeInfo_RuntimeIdentifier' -v (_getStaticPropertyIfExists -t 'System.Runtime.InteropServices.RuntimeInformation' -n 'RuntimeIdentifier')
	}
	#endregion

	#region computer info
	WriteVerboseMessage 'getting Computer info'
	if ($onMacOs) {
		# cache this, avoid a couple redundant calls below:
		$macOsData = (system_profiler -json SPHardwareDataType SPSoftwareDataType) | ConvertFrom-Json
	} else {
		$macOsData = [PSCustomObject]@{}
	}
	@('Manufacturer', 'Model', 'SystemType', 'BIOSVersion', 'SerialNumber') |
		ForEach-Object { _addProperty -o $results -n "Computer_$_" -v '' }
	if ($cimInstanceAvail) {
		$cs = Get-CimInstance -ClassName 'CIM_ComputerSystem'
		if ($cs) {
			_setProperty -o $results -n 'Computer_Manufacturer' -v $cs.Manufacturer
			_setProperty -o $results -n 'Computer_Model' -v $cs.Model
			_setProperty -o $results -n 'Computer_SystemType' -v $cs.SystemType
		}
		$be = Get-CimInstance -ClassName 'CIM_BIOSElement'
		if ($be) {
			_setProperty -o $results -n 'Computer_BIOSVersion' -v $be.Description
			_setProperty -o $results -n 'Computer_SerialNumber' -v $be.SerialNumber
		}
	} elseif ($onMacOs) {
		_setProperty -o $results -n 'Computer_Manufacturer' -v 'Apple'
		_setProperty -o $results -n 'Computer_Model' -v ('{0} ({1}) [model#: {2}]' -f $macOsData.SPHardwareDataType.machine_name, $macOsData.SPHardwareDataType.machine_model, $macOsData.SPHardwareDataType.model_number)
		_setProperty -o $results -n 'Computer_BIOSVersion' -v $macOsData.SPHardwareDataType.boot_rom_version
		_setProperty -o $results -n 'Computer_SerialNumber' -v $macOsData.SPHardwareDataType.serial_number
		_setProperty -o $results -n 'Computer_SystemType' -v (uname -m <# --machine; macOS doesn't support the '--' options ??? #>)
	}
	#endregion

	#region os info
	WriteVerboseMessage 'getting OS info'
	@('Platform', 'Distributor', 'Name', 'Id', 'Release', 'Version', 'OSArchitecture', 'Kernel', 'SKU', 'OSType', 'Codename') |
		ForEach-Object { _addProperty -o $results -n "OS_$_" -v '' }
	$osDetails = Get-OSDetails
	_setProperty -o $results -n 'OS_Platform' -v $osDetails.Platform
	_setProperty -o $results -n 'OS_Distributor' -v $osDetails.Distributor
	_setProperty -o $results -n 'OS_Name' -v $osDetails.Description
	_setProperty -o $results -n 'OS_Id' -v $osDetails.Id
	_setProperty -o $results -n 'OS_Release' -v $osDetails.Release
	_setProperty -o $results -n 'OS_Version' -v $(if ($osDetails.ReleaseVersion) {$osDetails.ReleaseVersion.ToString()} else {''})
	_setProperty -o $results -n 'OS_OSArchitecture' -v $osDetails.OSArchitecture
	_setProperty -o $results -n 'OS_Kernel' -v $osDetails.KernelVersion
	_setProperty -o $results -n 'OS_Codename' -v $osDetails.Codename
	if ($cimInstanceAvail) {
		$os = Get-CimInstance -ClassName 'CIM_OperatingSystem'
		if ($os) {
			_setProperty -o $results -n 'OS_SKU' -v $os.OperatingSystemSKU
			_setProperty -o $results -n 'OS_OSType' -v $os.OSType
		}
	}
	#endregion

	#region processor info
	WriteVerboseMessage 'getting processor info'
	_addProperty -o $results -n 'Processor_IsLittleEndian' -v ([System.BitConverter]::IsLittleEndian)
	@('Name', 'Description', 'Architecture', 'AddressWidth', 'DataWidth', 'L2CacheSize', 'L3CacheSize', 'NumberOfCores', 'LogicalProcessors', 'ProcessorId') |
		ForEach-Object { _addProperty -o $results -n "Processor_$_" -v '' }
	if ($cimInstanceAvail) {
		$proc = Get-CimInstance -ClassName 'CIM_Processor'
		if ($proc) {
			_setProperty -o $results -n 'Processor_Name' -v $proc.Name
			_setProperty -o $results -n 'Processor_Description' -v $proc.Description
			_setProperty -o $results -n 'Processor_Architecture' -v (MapCimProcArch -arch $proc.Architecture)
			_setProperty -o $results -n 'Processor_AddressWidth' -v $proc.AddressWidth
			_setProperty -o $results -n 'Processor_DataWidth' -v $proc.DataWidth
			_setProperty -o $results -n 'Processor_L2CacheSize' -v $proc.L2CacheSize
			_setProperty -o $results -n 'Processor_L3CacheSize' -v $proc.L3CacheSize
			_setProperty -o $results -n 'Processor_NumberOfCores' -v $proc.NumberOfCores
			_setProperty -o $results -n 'Processor_LogicalProcessors' -v $proc.NumberOfLogicalProcessors
			_setProperty -o $results -n 'Processor_ProcessorId' -v $proc.ProcessorId
		}
	} elseif ($onMacOs) {
		_setProperty -o $results -n 'Processor_Name' -v $macOsData.SPHardwareDataType.chip_type
		_setProperty -o $results -n 'Processor_Architecture' -v (uname -m <# --machine #>)
		_setProperty -o $results -n 'Processor_L2CacheSize' -v (sysctl -hin hw.l2cachesize)
		_setProperty -o $results -n 'Processor_L3CacheSize' -v (sysctl -hin hw.l3cachesize)	# doesn't exist but maybe will get added
		_setProperty -o $results -n 'Processor_NumberOfCores' -v (sysctl -hin hw.physicalcpu)
		_setProperty -o $results -n 'Processor_LogicalProcessors' -v (sysctl -hin hw.logicalcpu)
		# don't see anything better for these next two:
		_setProperty -o $results -n 'Processor_AddressWidth' -v $(if ([System.Environment]::Is64BitOperatingSystem) { '64' } else { '32' })
		_setProperty -o $results -n 'Processor_DataWidth' -v $(if ([System.Environment]::Is64BitOperatingSystem) { '64' } else { '32' })
	} elseif ((Get-Command -Name 'lscpu' -ErrorAction Ignore)) {
		$lscpu = lscpu | ParseLinesToLookup
		_setProperty -o $results -n 'Processor_Name' -v $lscpu['Model name']
		_setProperty -o $results -n 'Processor_Architecture' -v $lscpu['Architecture']
		_setProperty -o $results -n 'Processor_AddressWidth' -v $lscpu['Address sizes']
		$coresPerSocket = $lscpu['Core(s) per socket']
		$socketCnt = $lscpu['Socket(s)']
		if ($coresPerSocket -and $socketCnt) {
			_setProperty -o $results -n 'Processor_NumberOfCores' -v ([int]$coresPerSocket * [int]$socketCnt)
		}
		_setProperty -o $results -n 'Processor_LogicalProcessors' -v $lscpu['CPU(s)']
		_setProperty -o $results -n 'Processor_L2CacheSize' -v $lscpu['L2 cache']
		_setProperty -o $results -n 'Processor_L3CacheSize' -v $lscpu['L3 cache']
	} elseif ((Test-Path -Path '/proc/cpuinfo' -ErrorAction Ignore)) {
		$cpuinfo = Get-Content -Path '/proc/cpuinfo' | ParseLinesToLookup -saveFirstValue
		_setProperty -o $results -n 'Processor_Name' -v $cpuinfo['model name']
		_setProperty -o $results -n 'Processor_AddressWidth' -v $cpuinfo['address sizes']
		_setProperty -o $results -n 'Processor_NumberOfCores' -v $cpuinfo['cpu cores']
		# ???:
		_setProperty -o $results -n 'Processor_LogicalProcessors' -v $cpuinfo['siblings']
		_setProperty -o $results -n 'Processor_L3CacheSize' -v $cpuinfo['cache size']
	}
	$procArch = $results | Where-Object { $_.Name -eq 'Processor_Architecture' }
	if ((-not $procArch -or $procArch.Value -eq $script:NA) -and $unameAvail) {
		$procarch = (uname --processor <# right ?? #>)
		if (-not $procarch -or $procarch -eq 'unknown') {
			$procarch = (uname --machine)	<# fall back; or should we just leave it blank ?? #>
		}
		_setProperty -o $results -n 'Processor_Architecture' -v $procarch
	}
	$procDesc = $results | Where-Object { $_.Name -eq 'Processor_Description' }
	$procName = $results | Where-Object { $_.Name -eq 'Processor_Name' }
	if ($procName -and (-not $procDesc -or $procDesc.Value -eq $script:NA)) {
		_setProperty -o $results -n 'Processor_Description' -v $procName.Value
	}
	_addProperty -o $results -n 'Processor_IsVectorHardwareAccelerated' -v ([GetSysInfo.Intrinsics]::IsVectorHardwareAccelerated)
	_addProperty -o $results -n 'Processor_IsVector64HardwareAccelerated' -v ([GetSysInfo.Intrinsics]::IsVector64HardwareAccelerated)
	_addProperty -o $results -n 'Processor_IsVector128HardwareAccelerated' -v ([GetSysInfo.Intrinsics]::IsVector128HardwareAccelerated)
	_addProperty -o $results -n 'Processor_IsVector256HardwareAccelerated' -v ([GetSysInfo.Intrinsics]::IsVector256HardwareAccelerated)
	#endregion

	#region env var info
	WriteVerboseMessage 'getting env var info'
	_addProperty -o $results -n 'EnvVar_ProcessorArchitecture' -v (_getEnvVarValue -n 'Processor_Architecture')
	_addProperty -o $results -n 'EnvVar_ProcessorIdentifier' -v (_getEnvVarValue -n 'Processor_Identifier')
	_addProperty -o $results -n 'EnvVar_CPU' -v (_getEnvVarValue -n 'CPU')
	_addProperty -o $results -n 'EnvVar_HostType' -v (_getEnvVarValue -n 'HostType')
	_addProperty -o $results -n 'EnvVar_OsType' -v (_getEnvVarValue -n 'OsType')
	#endregion

	#endregion

	$allResults.SysProps = $results

	#region output data
	if ($saveJson -or $saveCsv -or $saveText) {
		$scriptname = (Get-Item -LiteralPath $PSCommandPath).BaseName
		$outputBaseName = if ($saveToFldr) { Join-Path $saveToFldr $scriptname } else { $scriptname }
		if ($saveJson) {
			$encoding = if ($PSEdition -ne 'Core') { 'UTF8' } else { 'UTF8NoBOM' }
			ConvertTo-ProperFormattedJson -InputObject $allResults | Set-Content -LiteralPath "$outputBaseName.json" -Encoding $encoding -NoNewline
		}
		if ($saveCsv) {
			$parms = @{ NoTypeInformation = $true; }
			if ($PSEdition -eq 'Core') { $parms.Add('UseQuotes', 'AsNeeded') }
			$allResults.EnvVars | Export-Csv -LiteralPath "$outputBaseName.EnvVars.csv" @parms
			$allResults.PoshVars | Export-Csv -LiteralPath "$outputBaseName.PoshVars.csv" @parms
			$allResults.SpecFldrs | Export-Csv -LiteralPath "$outputBaseName.SpecFldrs.csv" @parms
			if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
				$allResults.UnameVals | Export-Csv -LiteralPath "$outputBaseName.Uname.csv" @parms
			}
			if ($allResults.ContainsKey('WinNTCurrVer') -and $allResults.WinNTCurrVer) {
				$allResults.WinNTCurrVer | Export-Csv -LiteralPath "$outputBaseName.WinNTCurrVer.csv" @parms
			}
			$allResults.SysProps | Export-Csv -LiteralPath "$outputBaseName.SysProps.csv" @parms
		}
		if ($saveText) {
			$encoding = if ($PSEdition -ne 'Core') { 'UTF8' } else { 'UTF8NoBOM' }
			$parms = @{ LiteralPath = "$outputBaseName.txt"; Encoding = $encoding; Width = 4096; }
			WriteHeader -text 'Environment Variables' -includeExtraSpace $false | Out-File @parms
			$allResults.EnvVars | Format-Table -AutoSize -Wrap | Out-File -Append @parms
			WriteHeader -text 'PowerShell Variables' -includeExtraSpace $false | Out-File -Append @parms
			$allResults.PoshVars | Format-Table -Property Name,@{Label='Value';Expression={$_.Value};Alignment='Left';} -AutoSize -Wrap | Out-File -Append @parms
			WriteHeader -text 'System Special Folders' -includeExtraSpace $false | Out-File -Append @parms
			$allResults.SpecFldrs | Format-Table -Property Folder,Path -AutoSize -Wrap | Out-File -Append @parms
			if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
				WriteHeader -text 'uname' -includeExtraSpace $false | Out-File -Append @parms
				$allResults.UnameVals | Format-Table -AutoSize -Wrap | Out-File -Append @parms
			}
			if ($allResults.ContainsKey('WinNTCurrVer') -and $allResults.WinNTCurrVer) {
				WriteHeader -text 'Windows NT\CurrentVersion' -includeExtraSpace $false | Out-File -Append @parms
				$allResults.WinNTCurrVer | Format-Table -Property Value,@{Label='Data';Expression={$_.Data};Alignment='Left';} -AutoSize -Wrap | Out-File -Append @parms
			}
			WriteHeader -text 'System Properties' -includeExtraSpace $false | Out-File -Append @parms
			$allResults.SysProps | Format-Table -AutoSize -Wrap | Out-File -Append @parms
		}
	} else {
		WriteHeader -text 'Environment Variables' -includeExtraSpace $false
		$allResults.EnvVars | Format-Table -AutoSize -Wrap
		WriteHeader -text 'PowerShell Variables' -includeExtraSpace $false
		$allResults.PoshVars | Format-Table -Property Name,@{Label='Value';Expression={$_.Value};Alignment='Left';} -AutoSize -Wrap
		WriteHeader -text 'System Special Folders' -includeExtraSpace $false
		$allResults.SpecFldrs | Format-Table -Property Folder,Path -AutoSize -Wrap
		if ($allResults.ContainsKey('UnameVals') -and $allResults.UnameVals) {
			WriteHeader -text 'uname' -includeExtraSpace $false
			$allResults.UnameVals | Format-Table -AutoSize -Wrap
		}
		if ($allResults.ContainsKey('WinNTCurrVer') -and $allResults.WinNTCurrVer) {
			WriteHeader -text 'Windows NT\CurrentVersion' -includeExtraSpace $false
			$allResults.WinNTCurrVer | Format-Table -Property Value,@{Label='Data';Expression={$_.Data};Alignment='Left';} -AutoSize -Wrap
		}
 		WriteHeader -text 'System Properties' -includeExtraSpace $false
		$allResults.SysProps | Format-Table -AutoSize -Wrap
	}
	#endregion
}

function _getPropertyIfExists {
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [Alias('o')] [object] $object,
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $propertyName,
		[Alias('v')] [object] $defaultVal = $null
	)
	if (HasProperty -object $object -propertyName $propertyName) {
		return $object.$propertyName
	}
	return $defaultVal
}

function _getStaticPropertyIfExists {
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [Alias('t')] [type] $type,
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $propertyName,
		[Alias('v')] [object] $defaultVal = $null
	)
	$prop = $type.GetProperty($propertyName, @([System.Reflection.BindingFlags]::Static, [System.Reflection.BindingFlags]::Public))
	if ($prop) {
		return $prop.GetValue($null)
	}
	return $defaultVal
}

function _addProperty {
	[OutputType([void])]
	param(
		<# [Parameter(Mandatory=$true)] #> [ValidateNotNull()] [Alias('o')] [List[PSObject]] $obj,
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $propName,
		[Alias('v')] [object] $propValue,
		[switch] $allowNull
	)
	if (-not $allowNull -and ($propValue -eq $null -or ($propValue -is [string] -and $propValue -eq ''))) { $propValue = $script:NA }
	$obj.Add([PSCustomObject]@{ Name = $propName; Value = $propValue; })
}

function _setProperty {
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [Alias('o')] [List[PSObject]] $obj,
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $propName,
		[Alias('v')] [object] $propValue,
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
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $varName,
		[string] $defaultIfNotExists = ''
	)
	$value = $defaultIfNotExists
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
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $envVarName
	)
	$value = ''
	$v = Get-Item -Path "env:$envVarName" -ErrorAction SilentlyContinue
	if ($v) {
		$value = $v.Value
	}
	WriteVerboseMessage 'value for envVar |{0}| = |{1}|' @($envVarName, $value)
	return $value
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
namespace GetSysInfo {
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
namespace GetSysInfo {
	public static class Intrinsics {
		public static bool IsVectorHardwareAccelerated { get { return false; } }
		public static bool IsVector64HardwareAccelerated { get { return false; } }
		public static bool IsVector128HardwareAccelerated { get { return false; } }
		public static bool IsVector256HardwareAccelerated { get { return false; } }
	}
}
"@
}

#==============================
Main -saveJson:$asJson -saveCsv:$asCsv -saveText:$asText -saveToFldr $outputFolder
#==============================
