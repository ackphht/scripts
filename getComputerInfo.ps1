<# Requires -RunAsAdministrator#>
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$false)]
param(
	[switch] [Alias('f', 'full')] $fullInfo
)

$script:bigDivider = [string]::new('=', 80)
$script:smallDivider = [string]::new('-', 80)

. $PSScriptRoot/helpers.ps1
Set-StrictMode -Off # helpers.ps1 above is turning it on

function Main {
	[CmdletBinding(SupportsShouldProcess=$false)]
	param(
		[switch] $writeAll
	)
	# make sure we're on Windows; can use $IsWindows; if $IsWindows is not defined, then it's non-Core powershell, which is Windows only
	if (([bool](Get-Variable -Name 'IsWindows' -ErrorAction Ignore) -and -not $IsWindows)) {
		Write-Error 'this script is for Windows only'
		return
	}

	if ($writeAll) {
		WriteHeader 'Get-ComputerInfo'
		$ci = Get-ComputerInfo
		$ci | Format-List (GetSortedPropertyNames $ci)
	}

	_dumpCimProperties -cn 'CIM_ComputerSystem' -a:$writeAll -p  @('Manufacturer', 'Model', 'SystemFamily', 'SystemSKUNumber', 'SystemType', 'NumberOfProcessors', @{ name='TotalPhysicalMemory'; expression={ GetFriendlyBytes -value $_.TotalPhysicalMemory }; }, 'Name', 'Domain')
	_dumpCimProperties -cn 'CIM_BIOSElement' -a:$writeAll -p  @('Manufacturer', @{ name='BIOSVersion'; expression={ Coalesce -object $_ -props @('SMBIOSBIOSVersion', 'SoftwareElementID', 'Name', 'Description', 'Caption') }; }, 'ReleaseDate', 'SerialNumber')
	_dumpCimProperties -cn 'CIM_Chassis' -a:$writeAll -p  @('Manufacturer', @{ name='Name'; expression={ Coalesce -object $_ -props @('Name', 'Description', 'Caption') }; }, 'SerialNumber')
	_dumpCimProperties -cn 'CIM_Processor' -a:$writeAll -p  @('Manufacturer', 'Name', 'Description', 'ProcessorId', @{ name='Architecture'; expression={ MapCimProcArch $_.Architecture }; }, 'NumberOfCores', 'NumberOfLogicalProcessors', 'AddressWidth', 'DataWidth', 'MaxClockSpeed', 'SocketDesignation', 'L2CacheSize', 'L3CacheSize', 'Family', 'Level')
	_dumpCimProperties -cn 'CIM_OperatingSystem' -a:$writeAll -p  @('Manufacturer', 'Caption', 'Description', 'Version', 'BuildNumber', 'OSArchitecture', @{ name='OperatingSystemSKU'; expression={ MapCimOsSku -cimOsSku $_.OperatingSystemSKU -cimOsCaption $_.Caption }; }, 'CurrentTimeZone', 'InstallDate', 'LastBootUpTime')
	_dumpCimProperties -cn 'CIM_DiskDrive' -a:$writeAll -p  @('Manufacturer', 'Model', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, 'Status', 'Index', 'CapabilityDescriptions', 'InterfaceType', 'FirmwareRevision', 'SerialNumber', 'MediaType', 'Partitions', 'PNPDeviceID')
	_dumpCimProperties -cn 'CIM_CDROMDrive' -a:$writeAll -p  @('Manufacturer', 'Name', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, 'Status', 'CapabilityDescriptions', 'MfrAssignedRevisionLevel', 'SerialNumber', 'MediaType', 'PNPDeviceID')
	_dumpCimProperties -cn 'CIM_LogicalDisk' -a:$writeAll -p  @('Name', 'Description', 'FileSystem', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, @{ name='FreeSpace'; expression={ GetFriendlyBytes -value $_.FreeSpace }; }, 'VolumeName', 'VolumeSerialNumber')
	_dumpCimProperties -cn 'CIM_DiskPartition' -a:$writeAll -p  @('Name', 'Type', 'Bootable', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, 'DiskIndex', 'Index', 'NumberOfBlocks', 'BlockSize', 'StartingOffset')
	_dumpCimProperties -cn 'CIM_StorageVolume' -a:$writeAll -p  @('Name' ,'DriveLetter', 'Label', 'DeviceId', 'FileSystem', @{ name='Capacity'; expression={ GetFriendlyBytes -value $_.Capacity }; }, @{ name='FreeSpace'; expression={ GetFriendlyBytes -value $_.FreeSpace }; }, 'BlockSize', 'SerialNumber')
	_dumpCimProperties -cn 'CIM_VideoController' -a:$writeAll -p @('Name', 'VideoProcessor', 'DriverVersion', 'PNPDeviceID', 'Status', @{ name='AdapterRAM'; expression={ GetFriendlyBytes -value $_.AdapterRAM }; }, 'VideoModeDescription', 'CurrentRefreshRate')
}

function _dumpCimProperties {
	param(
		[Parameter(Mandatory=$true)] [Alias('cn', 'n')] [string] $className,
		[Parameter(Mandatory=$true)] [Alias('p')] [PSObject[]] $stdPropList,
		[switch] [Alias('a')] $writeAllProps
	)
	$info = Get-CimInstance -ClassName $className
	if ($info) {
		WriteHeader $className
		$arr = @($info)
		if ($arr.Length -eq 1) {
			if ($writeAllProps) {
				$info | Format-List -Property (GetSortedPropertyNames $info)
			} else {
				$info | Format-List -Property $stdPropList
			}
		} else {
			if ($writeAllProps) {
				$propNames = GetSortedPropertyNames @($info)[0]
			}
			for ($idx = 0; $idx -lt $arr.Length; ++$idx) {
				if ($writeAllProps) {
					$arr[$idx] | Format-List -Property $propNames
				} else {
					$arr[$idx] | Format-List -Property $stdPropList
				}
				if ($idx -lt ($arr.Length - 1)) {
					Write-Output $script:smallDivider
				}
			}
		}
	}
}

function WriteHeader {
	param(
		[string] $header
	)
	Write-Output $script:bigDivider
	Write-Output $header
	Write-Output $script:bigDivider
}

#==============================
Main -writeAll:$fullInfo
#==============================
