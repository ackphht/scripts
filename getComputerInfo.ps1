<# Requires -RunAsAdministrator#>
#Requires -Version 4

[CmdletBinding(SupportsShouldProcess=$false)]
param(
	[switch] [Alias('f', 'full')] $fullInfo
)

$script:bigDivider = '=' * 80
$script:smallDivider = '-' * 80

Import-Module -Name $PSScriptRoot/ackPoshHelpers
Set-StrictMode -Off # helpers.ps1 above is turning it on

$script:cimAvailable = [bool](Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue)

function Main {
	[CmdletBinding(SupportsShouldProcess=$false)]
	param(
		[switch] $writeAll
	)
	# make sure we're on Windows; can use $IsWindows; if $IsWindows is not defined, then it's non-Core powershell, which is Windows only
	if (([bool](Get-Variable -Name 'IsWindows' -ErrorAction SilentlyContinue) -and -not $IsWindows)) {
		Write-Error 'this script is for Windows only'
		return
	}

	if ($writeAll -and (Get-Command -Name 'Get-ComputerInfo' -ErrorAction SilentlyContinue)) {
		_writeHeader 'Get-ComputerInfo'
		$ci = Get-ComputerInfo
		$ci | Format-List (GetSortedPropertyNames $ci)
	}

	_dumpCimProperties -cn 'ComputerSystem' -a:$writeAll -p  @('Manufacturer', 'Model', 'SystemFamily', 'SystemSKUNumber', 'SystemType', 'NumberOfProcessors', @{ name='TotalPhysicalMemory'; expression={ GetFriendlyBytes -value $_.TotalPhysicalMemory }; }, 'Name', 'Domain')
	_dumpCimProperties -cn 'BIOSElement' -a:$writeAll -p  @('Manufacturer', @{ name='BIOSVersion'; expression={ Coalesce -object $_ -props @('SMBIOSBIOSVersion', 'SoftwareElementID', 'Name', 'Description', 'Caption') }; }, 'ReleaseDate', 'SerialNumber') -wmiClass 'BIOS'
	_dumpCimProperties -cn 'Chassis' -a:$writeAll -p  @('Manufacturer', @{ name='Name'; expression={ Coalesce -object $_ -props @('Name', 'Description', 'Caption') }; }, 'SerialNumber') -wmiClass 'SystemEnclosure'
	_dumpCimProperties -cn 'Processor' -a:$writeAll -p  @('Manufacturer', 'Name', 'Description', 'ProcessorId', @{ name='Architecture'; expression={ MapCimProcArch $_.Architecture }; }, 'NumberOfCores', 'NumberOfLogicalProcessors', 'AddressWidth', 'DataWidth', 'MaxClockSpeed', 'SocketDesignation', 'L2CacheSize', 'L3CacheSize', 'Family', 'Level')
	_dumpCimProperties -cn 'OperatingSystem' -a:$writeAll -p  @('Manufacturer', 'Caption', 'Description', 'Version', 'BuildNumber', 'OSArchitecture', @{ name='OperatingSystemSKU'; expression={ MapCimOsSku -cimOsSku $_.OperatingSystemSKU -cimOsCaption $_.Caption }; }, 'CurrentTimeZone', 'InstallDate', 'LastBootUpTime')
	_dumpCimProperties -cn 'DiskDrive' -a:$writeAll -p  @('Manufacturer', 'Model', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, 'MediaType', 'Partitions', 'Status', 'Index', 'CapabilityDescriptions', 'InterfaceType', 'FirmwareRevision', 'SerialNumber', 'PNPDeviceID') -sortBy 'Index'
	_dumpCimProperties -cn 'LogicalDisk' -a:$writeAll -p  @('Name', 'Description', 'FileSystem', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, @{ name='FreeSpace'; expression={ GetFriendlyBytes -value $_.FreeSpace }; }, 'VolumeName', 'VolumeSerialNumber') -sortBy 'Name'
	_dumpCimProperties -cn 'DiskPartition' -a:$writeAll -p  @('Name', 'Type', 'Bootable', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, 'Index', 'DiskIndex', 'NumberOfBlocks', 'BlockSize', 'StartingOffset') -sortBy 'Index','DiskIndex'
	_dumpCimProperties -cn 'CDROMDrive' -a:$writeAll -p  @('Manufacturer', 'Name', @{ name='Size'; expression={ GetFriendlyBytes -value $_.Size }; }, 'Status', 'CapabilityDescriptions', 'MfrAssignedRevisionLevel', 'SerialNumber', 'MediaType', 'PNPDeviceID')
	if ($script:cimAvailable) {		# no equivalent for WMI (?)
		_dumpCimProperties -cn 'StorageVolume' -a:$writeAll -p  @('Name' ,'DriveLetter', 'Label', 'FileSystem', @{ name='Capacity'; expression={ GetFriendlyBytes -value $_.Capacity }; }, @{ name='FreeSpace'; expression={ GetFriendlyBytes -value $_.FreeSpace }; }, 'BlockSize', 'SerialNumber', 'DeviceId')
	}
	_dumpCimProperties -cn 'VideoController' -a:$writeAll -p @('Name', 'VideoProcessor', 'DriverVersion', 'Status', @{ name='AdapterRAM'; expression={ GetFriendlyBytes -value $_.AdapterRAM }; }, 'VideoModeDescription', 'CurrentRefreshRate', 'PNPDeviceID')
	_dumpCimProperties -cn 'NetworkAdapter' -a:$writeAll -p @('Name'<#,'Description'#>,'Manufacturer','ProductName','ServiceName','AdapterType','Speed','MACAddress','PhysicalAdapter','NetEnabled','NetConnectionID','NetConnectionStatus'<#,'NetworkAddresses'#>,'PNPDeviceID'<#,'Index','DeviceID','InterfaceIndex'#>) -sortBy 'Index'
}

function _dumpCimProperties {
	param(
		[Parameter(Mandatory=$true)] [Alias('cn', 'n')] [string] $className,
		[Parameter(Mandatory=$true)] [Alias('p')] [PSObject[]] $stdPropList,
		[switch] [Alias('a')] $writeAllProps,
		[string] $wmiClass,
		[string[]] $sortBy
	)
	if ($script:cimAvailable) {
		$info = Get-CimInstance -ClassName ('CIM_' + $className)
	} else {
		$info = Get-WmiObject -Class ('Win32_' + $(if ($wmiClass) { $wmiClass } else { $className }))
	}
	if ($sortBy) {
		$info = $info | Sort-Object -Property $sortBy
	}
	if ($info) {
		_writeHeader $className
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

function _writeHeader {
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
