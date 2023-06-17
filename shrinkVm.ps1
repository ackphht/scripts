#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules 'AckWare.AckLib'
#Requires -Modules 'Hyper-V'

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true, ParameterSetName = 'ByVm')]
	[string] $vmName,
	[Parameter(Mandatory=$true, ParameterSetName = 'ByVhd')]
	[string] $vhd
)

$ErrorActionPreference = 'Stop'	#'Continue'
Set-StrictMode -Version Latest

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[string] $vm,
		[string] $vhd
	)
	if ($vm) {
		_optimizeVm -vmName $vm
	} else {
		_optimizeVhd -vhd $vhd
	}
}

function _optimizeVm {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject])]
	param(
		[Parameter(Mandatory=$true)] [string] $vmName
	)
	$vm = Get-VM -VMName $vmName -ErrorAction Continue
	if (-not $vm) {
		# above should print error message for non-existent vm
		return
	}
	if (-not $vm.HardDrives -or $vm.HardDrives.Count -eq 0) {
		Write-Warning "VM '$vmName' does not have any hard drives"
		return
	}
	foreach ($drv in $vm.HardDrives) {
		_optimizeVhd -vhd $drv.Path
	}
}

function _optimizeVhd {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject])]
	param(
		[Parameter(Mandatory=$true)] [string] $vhd
	)
	if (-not (Test-Path -Path $vhd -PathType Leaf)) {
		Write-Warning "VM hard drive path does not exist: `"$vhd`""
		return
	}
	Write-Verbose "optimizing VHD |$vhd|"
	$preSize = Format-Bytes -value (Get-Item -LiteralPath $vhd).Length
	Optimize-VHD -Mode Full -Path $vhd
	$postSize = Format-Bytes -value (Get-Item -LiteralPath $vhd).Length
	Write-Host "optimized VHD file `"$vhd`"`n    size before optimizing: $preSize, size after: $postSize" -ForegroundColor Cyan
}

#==============================
Main -vm $vmName -vhd $vhd
#==============================