<# Requires -RunAsAdministrator#>
#Requires -Version 5.1

$script:bigDivider = [string]::new('=', 80)
$script:smallDivider = [string]::new('-', 80)

. $PSScriptRoot/helpers.ps1

function Main {
	WriteHeader 'Get-ComputerInfo'
	$ci = Get-ComputerInfo
	$ci | Format-List (GetSortedPropertyNames $ci)

	_dumpCimProperties 'CIM_ComputerSystem'
	_dumpCimProperties 'CIM_BIOSElement'
	_dumpCimProperties 'CIM_Chassis'
	_dumpCimProperties 'CIM_Processor'
	_dumpCimProperties 'CIM_OperatingSystem'
	_dumpCimProperties 'CIM_DiskDrive'
	_dumpCimProperties 'CIM_LogicalDisk'
	_dumpCimProperties 'CIM_DiskPartition'
	_dumpCimProperties 'CIM_StorageVolume'
	_dumpCimProperties 'CIM_VideoController'
}

function _dumpCimProperties {
	param(
		[string] $className
	)
	WriteHeader $className
	$info = Get-CimInstance -ClassName $className
	if ($info) {
		$arr = @($info)
		if ($arr.Length -eq 1) {
			$info | Format-List (GetSortedPropertyNames $info)
		} else {
			$propNames = GetSortedPropertyNames @($info)[0]
			for ($idx = 0; $idx -lt $arr.Length; ++$idx) {
				$arr[$idx] | Format-List $propNames
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
Main
#==============================
