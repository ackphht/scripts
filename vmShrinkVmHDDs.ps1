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

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version Latest

. $PSScriptRoot/vmVirtualBoxCommon.ps1

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[string] $vmName,
		[string] $vmDrive
	)
	if ($vmName) {
		foreach ($vm in Get-VM -Name $vmName) {
			Write-Verbose "found Hyper-V VM for name |$vmName|"
			_optimizeHyperVVm -vm $vm
		}
		foreach ($vm in (GetVirtualBoxVms | Where-Object { $_.Name -like $vmName })) {
			Write-Verbose "found VirtualBox VM for name |$vmName|"
			_optimizeVirtualBoxVm -vm $vm
		}
	} else {
		_optimizeVhd -vhdPath $vmDrive -vhdType 'Unknown'
	}
}

function _optimizeHyperVVm {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param([Parameter(Mandatory=$true)] [Microsoft.HyperV.PowerShell.VirtualMachine] $vm)

	if (-not $vm.HardDrives -or $vm.HardDrives.Count -eq 0) {
		Write-Warning "Hyper-V VM '$vmName' does not have any hard drives"
		return
	}
	foreach ($drv in $vm.HardDrives) {
		_optimizeVhd -vhdPath $drv.Path -vhdType 'HyperV'
	}
}

function _optimizeVirtualBoxVm {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param([Parameter(Mandatory=$true)] [VirtualBoxVm] $vm)

	if (-not $vm.HardDrives -or $vm.HardDrives.Count -eq 0) {
		Write-Warning "VirtualBox VM '$vmName' does not have any hard drives"
		return
	}
	foreach ($drv in $vm.HardDrives) {
		_optimizeVhd -vhdPath $drv.Path -vhdType 'VirtualBox'
	}
}

function _optimizeVhd {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $vhdPath,
		[Parameter(Mandatory=$true)] [ValidateSet('HyperV', 'VirtualBox', 'Unknown')] [string] $vhdType
	)
	if (-not (Test-Path -Path $vhdPath -PathType Leaf)) {
		Write-Warning "VM hard drive path does not exist: `"$vhdPath`""
		return
	}
	if (-not $vhdType -or $vhdType -eq 'Unknown') {
		$type = Split-Path -Path $vhdPath -Extension
		switch ($type) {
			'.vhdx' { $vhdType = 'HyperV'; break; }
			'.vdi' { $vhdType = 'VirtualBox'; break; }
			default { Write-Error "unrecognized VHD type for path `"$vhdPath`""; return; }
		}
	}
	Write-Verbose "optimizing VHD |$vhdPath| (type = $vhdType)"
	$preSize = Format-Bytes -value (Get-Item -LiteralPath $vhdPath).Length
	switch ($vhdType) {
		'HyperV' {
			Optimize-VHD -Mode Full -Path $vhdPath
			break
		}
		'VirtualBox' {
			if ($PSCmdlet.ShouldProcess($vhdPath, 'VBoxManage.exe')) {
				VBoxManage.exe modifyhd $vhdPath --compact
			}
			break
		}
	}
	$postSize = Format-Bytes -value (Get-Item -LiteralPath $vhdPath).Length
	Write-Host "optimized VHD file `"$vhdPath`"" -ForegroundColor Cyan
	Write-Host "    before: $preSize" -ForegroundColor Cyan
	Write-Host "     after: $postSize" -ForegroundColor Cyan
}

#==============================
Main -vmName $vmName -vmDrive $vhd
#==============================