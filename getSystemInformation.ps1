#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Continue
#Set-StrictMode -Version Latest

$script:NA = 'N/A'

function Main {
	[CmdletBinding(SupportsShouldProcess=$false)]
	param()
	WriteHeader -text 'Environment Variables' -includeExtraSpace $false
	WriteVerbose 'dumping environment vars'
	Get-ChildItem -Path env:

	# dump out special folder paths (??)
	WriteHeader -text 'System Special Folders'
	WriteVerbose 'getting special folders'
	[System.Enum]::GetValues([System.Environment+SpecialFolder]) |
		ForEach-Object {
			[PSCustomObject]@{ Folder = $_.ToString(); Path = [System.Environment]::GetFolderPath($_); }
		} |
		Sort-Object -Property Folder |
		Format-Table -Property Folder,Path

	$unameAvail = [bool](Get-Command -Name 'uname' -ErrorAction Ignore)
	$cimInstanceAvail = [bool](Get-Command -Name 'Get-CimInstance' -ErrorAction Ignore)

	if ($unameAvail) {
		WriteHeader -text 'uname'
		WriteVerbose 'getting uname info'
		@(@{ nm = 'kernel-name'; op = 's'; }, @{ nm = 'kernel-release'; op = 'r'; }, @{ nm = 'kernel-version'; op = 'v'; },
			@{ nm = 'machine'; op = 'm'; }, @{ nm = 'processor'; op = 'p'; }, @{ nm = 'hardware-platform'; op = 'i'; },
			@{ nm = 'operating-system'; op = 'o'; }) |
			ForEach-Object {
				$v = uname -$($_.op) 2>/dev/null
				if ($LASTEXITCODE -eq 0) {
					[PSCustomObject]@{ Name = $_.nm; Value = $v; }
				}
			} | Format-Table
	}

	# get system properties/data/etc:
	WriteHeader -text 'System Properties'
	WriteVerbose 'getting system properties'

	$results = [PSObject]::new()
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

	WriteVerbose 'getting runtime info'
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

	WriteVerbose 'getting Computer info'
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

	WriteVerbose 'getting OS info'
	@('Name', 'Manufacturer', 'Version', 'OSArchitecture', 'Kernel', 'SKU', 'OSType', 'Codename') |
		ForEach-Object { _addProperty -obj $results -propName "OS_$_" -propValue '' }
	if ($cimInstanceAvail) {
		$os = Get-CimInstance -ClassName 'CIM_OperatingSystem'
		if ($os) {
			_setProperty -obj $results -propName 'OS_Manufacturer' -propValue $os.Manufacturer
			_setProperty -obj $results -propName 'OS_Name' -propValue $os.Caption	# .Name has other crap in it
			_setProperty -obj $results -propName 'OS_Version' -propValue $os.Version
			_setProperty -obj $results -propName 'OS_OSArchitecture' -propValue $os.OSArchitecture
			_setProperty -obj $results -propName 'OS_Kernel' -propValue $os.Version
			_addProperty -obj $results -propName 'OS_SKU' -propValue $os.OperatingSystemSKU
			_addProperty -obj $results -propName 'OS_OSType' -propValue $os.OSType
		}
	} elseif ($IsMacOS) {
		_setProperty -obj $results -propName 'OS_Manufacturer' -propValue 'Apple'
		_setProperty -obj $results -propName 'OS_Name' -propValue $macOsData.SPSoftwareDataType.os_version
		_setProperty -obj $results -propName 'OS_Version' -propValue (sysctl -hin kern.osproductversion)	# simple version without parsing above
		_setProperty -obj $results -propName 'OS_Kernel' -propValue $macOsData.SPSoftwareDataType.kernel_version
		# haven't found anything good for this next one in system_profiler or sysctl; and macOS doesn't support 'uname -i', so:
		_setProperty -obj $results -propName 'OS_OSArchitecture' -propValue $(if ([System.Environment]::Is64BitOperatingSystem) { '64-bit' } else { '32-bit' })
	} else {
		if ((Get-Command -Name 'lsb_release' -ErrorAction Ignore)) {
			$lsb = lsb_release --all 2>/dev/null
			_setProperty -obj $results -propName 'OS_Name' -propValue (_parseLinuxLines -lines $lsb -lookFor 'Description' -type 1)
			_setProperty -obj $results -propName 'OS_Manufacturer' -propValue (_parseLinuxLines -lines $lsb -lookFor 'Distributor ID' -type 1)
			_setProperty -obj $results -propName 'OS_Version' -propValue (_parseLinuxLines -lines $lsb -lookFor 'Release' -type 1)
			$oscodename = (_parseLinuxLines -lines $lsb -lookFor 'Codename' -type 1)
			if ($oscodename -and $oscodename -ne 'n/a') {
				_addProperty -obj $results -propName 'OS_Codename' -propValue $oscodename
			}
		} elseif ((Test-Path -Path '/etc/os-release' -ErrorAction Ignore)) {
			$osrelease = Get-Content -Path '/etc/os-release'
			_setProperty -obj $results -propName 'OS_Name' -propValue (_parseLinuxLines -lines $osrelease -lookFor 'PRETTY_NAME' -type 2)
			_setProperty -obj $results -propName 'OS_Manufacturer' -propValue (_parseLinuxLines -lines $osrelease -lookFor <#'NAME'#> 'ID' -type 2)
			$osversion = (_parseLinuxLines -lines $osrelease -lookFor 'VERSION' -type 2)
			if (-not $osversion) {
				$osversion = (_parseLinuxLines -lines $osrelease -lookFor 'VERSION_ID' -type 2)
			}
			_setProperty -obj $results -propName 'OS_Version' -propValue $osversion
			$oscodename = (_parseLinuxLines -lines $osrelease -lookFor 'VERSION_CODENAME' -type 2)
			if ($oscodename -and $oscodename -ne 'n/a') {
				_addProperty -obj $results -propName 'OS_Codename' -propValue $oscodename
			}
		}
		if ($unameAvail) {
			$osarch = (uname --hardware-platform <# OS architecture, right ?? #>)
			if (-not $osarch -or $osarch -eq 'unknown') {
				$osarch = (uname --machine)	<# fall back; or should we just leave it blank ?? #>
			}
			_setProperty -obj $results -propName 'OS_OSArchitecture' -propValue $osarch
			_setProperty -obj $results -propName 'OS_Kernel' -propValue (uname --kernel-release)
		}
	}

	WriteVerbose 'getting processor info'
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
		$lscpu = lscpu
		_setProperty -obj $results -propName 'Processor_Name' -propValue (_parseLinuxLines -lines $lscpu -lookFor 'Model name' -type 1)
		_setProperty -obj $results -propName 'Processor_Architecture' -propValue (_parseLinuxLines -lines $lscpu -lookFor 'Architecture' -type 1)
		_setProperty -obj $results -propName 'Processor_AddressWidth' -propValue (_parseLinuxLines -lines $lscpu -lookFor 'Address sizes' -type 1)
		$coresPerSocket = (_parseLinuxLines -lines $lscpu -lookFor 'Core(s) per socket' -type 1)
		$socketCnt = (_parseLinuxLines -lines $lscpu -lookFor 'Socket(s)' -type 1)
		if ($coresPerSocket -and $socketCnt) {
			_setProperty -obj $results -propName 'Processor_NumberOfCores' -propValue ([int]$coresPerSocket * [int]$socketCnt)
		}
		_setProperty -obj $results -propName 'Processor_LogicalProcessors' -propValue (_parseLinuxLines -lines $lscpu -lookFor 'CPU(s)' -type 1)
		_setProperty -obj $results -propName 'Processor_L2CacheSize' -propValue (_parseLinuxLines -lines $lscpu -lookFor 'L2 cache' -type 1)
		_setProperty -obj $results -propName 'Processor_L3CacheSize' -propValue (_parseLinuxLines -lines $lscpu -lookFor 'L3 cache' -type 1)
	} elseif ((Test-Path -Path '/proc/cpuinfo' -ErrorAction Ignore)) {
		$cpuinfo = Get-Content -Path '/proc/cpuinfo'
		_setProperty -obj $results -propName 'Processor_Name' -propValue (_parseLinuxLines -lines $cpuinfo -lookFor 'model name' -type 1)
		_setProperty -obj $results -propName 'Processor_AddressWidth' -propValue (_parseLinuxLines -lines $cpuinfo -lookFor 'address sizes' -type 1)
		_setProperty -obj $results -propName 'Processor_NumberOfCores' -propValue (_parseLinuxLines -lines $cpuinfo -lookFor 'cpu cores' -type 1)
		# ???:
		_setProperty -obj $results -propName 'Processor_LogicalProcessors' -propValue (_parseLinuxLines -lines $cpuinfo -lookFor 'siblings' -type 1)
		_setProperty -obj $results -propName 'Processor_L3CacheSize' -propValue (_parseLinuxLines -lines $cpuinfo -lookFor 'cache size' -type 1)
	}
	if ((-not $results.Processor_Architecture -or $results.Processor_Architecture -eq $script:NA) -and $unameAvail) {
		$procarch = (uname --processor <# right ?? #>)
		if (-not $procarch -or $procarch -eq 'unknown') {
			$procarch = (uname --machine)	<# fall back; or should we just leave it blank ?? #>
		}
		_setProperty -obj $results -propName 'Processor_Architecture' -propValue $procarch
	}
	if (-not $results.Processor_Description -or $results.Processor_Description -eq $script:NA) {
		$results.Processor_Description = $results.Processor_Name
	}
	_addProperty -obj $results -propName 'Processor_IsVectorHardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVectorHardwareAccelerated)
	_addProperty -obj $results -propName 'Processor_IsVector64HardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVector64HardwareAccelerated)
	_addProperty -obj $results -propName 'Processor_IsVector128HardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVector128HardwareAccelerated)
	_addProperty -obj $results -propName 'Processor_IsVector256HardwareAccelerated' -propValue ([AckWare.Intrinsics]::IsVector256HardwareAccelerated)

	WriteVerbose 'getting env var info'
	_addProperty -obj $results -propName 'EnvVar_ProcessorArchitecture' -propValue (_getEnvVarValue -envVarName 'Processor_Architecture')
	_addProperty -obj $results -propName 'EnvVar_ProcessorIdentifier' -propValue (_getEnvVarValue -envVarName 'Processor_Identifier')
	_addProperty -obj $results -propName 'EnvVar_CPU' -propValue (_getEnvVarValue -envVarName 'CPU')
	_addProperty -obj $results -propName 'EnvVar_HostType' -propValue (_getEnvVarValue -envVarName 'HostType')
	_addProperty -obj $results -propName 'EnvVar_OsType' -propValue (_getEnvVarValue -envVarName 'OsType')

	#return $results
	$results | Format-List -Property *
}

function _addProperty {
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [PSObject] $obj,
		[Parameter(Mandatory=$true)] [string] $propName,
		[object] $propValue,
		[switch] $allowNull
	)
	if (-not $allowNull -and ($propValue -eq $null -or ($propValue -is [string] -and $propValue -eq ''))) { $propValue = $script:NA }
	Add-Member -InputObject $obj -MemberType NoteProperty -Name $propName -Value $propValue
}

function _setProperty {
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [PSObject] $obj,
		[Parameter(Mandatory=$true)] [string] $propName,
		[object] $propValue,
		[switch] $allowNull
	)
	if (-not $allowNull -and -not $propValue) { $propValue = $script:NA }
	$obj.$propName = $propValue
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
	WriteVerbose 'value for variable |{0}| = |{1}|' @($varName, $value)
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
	WriteVerbose 'value for envVar |{0}| = |{1}|' @($envVarName, $value)
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

function _parseLinuxLines {
	[OutputType([string])]
	param(
		<# [Parameter(Mandatory=$true)] #> [string[]] $lines,	# some BS error on linux sometimes from calling Get-Content if this mandatory, and it makes no forking sense
		[Parameter(Mandatory=$true)] [string] $lookFor,
		[Parameter(Mandatory=$true)] [ValidateSet(1, 2)] [int] $type = 1
	)
	if ($lines) {
		$re = ''
		if ($type -eq 1) {
			$re = "^\s*$([regex]::Escape($lookFor))\s*:\s+(?<val>.+)$"
		} elseif ($type -eq 2) {
			$re = "^\s*$([regex]::Escape($lookFor))\s*=\s*`"?(?<val>.*?)`"?$"
		}
		$match = $lines | ForEach-Object { [regex]::Match($_, $re) } | Where-Object { $_.Success } | Select-Object -First 1
		if ($match) {
			return $match.Groups['val'].Value
		}
	}
	return ''
}

$script:nonDisplayCharsMap = @{
	[char]0 = '␀'; [char]1 = '␁'; [char]2 = '␂'; [char]3 = '␃'; [char]4 = '␄'; [char]5 = '␅'; [char]6 = '␆'; [char]7 = '␇';
	[char]8 = '␈'; [char]9 = '␉'; [char]0x0a = '␊'; [char]0x0b = '␋'; [char]0x0c = '␌'; [char]0x0d = '␍'; [char]0x0e = '␎'; [char]0x0f = '␏'; [char]0x10 = '␐';
	[char]0x11 = '␑'; [char]0x12 = '␒'; [char]0x13 = '␓'; [char]0x14 = '␔'; [char]0x15 = '␕'; [char]0x16 = '␖'; [char]0x17 = '␗';
	[char]0x18 = '␘'; [char]0x19 = '␙'; [char]0x1a = '␚'; [char]0x1b = '␛'; [char]0x1c = '␜'; [char]0x1d = '␝'; [char]0x1e = '␞'; [char]0x1f = '␟';
	[char]0x20 = '␠'; [char]0x7f = '␡'; [char]0xa0<#NBSP#> = ' '; [char]0x85<#NEL#> = ' '; [char]0x2028<#LS#> = ' '; [char]0x2029<#PS#> = ' ';
}

function _charsToString {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param(
		[char[]] $chars
	)
	if ($chars) {
		$sb = [System.Text.StringBuilder]::new(512)
		foreach ($c in $chars) {
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

function WriteVerbose {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([void])]
	param(
		# pass in a simple string to write out, or a .NET format string with params
		[Parameter(ParameterSetName='ByString',Mandatory=$true,Position=0,ValueFromPipeline=$true)] [string] $message,
		[Parameter(ParameterSetName='ByString',Mandatory=$false,Position=1)] [object[]] $formatParams = $null,
		# if message is a 'continuation' of a previous message, no invocationName will be written and message will be indented
		[Parameter(Mandatory=$false)] [switch] $continuation
	)
	process {
		if ($VerbosePreference -ne [System.Management.Automation.ActionPreference]::Continue) { return }

		$msg = if ($formatParams) { $message -f $formatParams } else { $message }
		if (-not $continuation) {
			# get invocation name from first stack frame that's not this function and is not a script block:
			foreach ($frame in (@(Get-PSCallStack) | Select-Object -Skip 1 <# skip current #>)) {
				if ($frame -and $frame.InvocationInfo -and $frame.InvocationInfo.InvocationName <# empty for script blocks #>) {
					$msg = '[{0}] {1}' -f $frame.InvocationInfo.InvocationName,$msg
					break
				}
			}
		} else { $msg = '    ' + $msg }
		# now write out the message [some platforms can't use Write-Verbose (??) (e.g. Azure Functions). Fall back to Write-Output in that case]:
		try { Write-Verbose $msg } catch { Write-Output "VERBOSE: $msg" }
	}
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
Main
#==============================
