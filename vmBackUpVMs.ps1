# Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $vmName = ''
)

$script:backupFolder = 'D:\Users\michael\temp\VMs'

function Main {
	Get-VM |
		Where-Object { -not $vmName -or $_.Name -like $vmName } |
		Where-Object { $_.Name -notlike '*_diff' } |
		ForEach-Object { BackUpVM $_ }
}

function BackUpVM {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Microsoft.HyperV.PowerShell.VirtualMachine] $vm
	)
	$vmHdFileInfo = Get-Item -LiteralPath $vm.HardDrives[0].Path -ErrorAction SilentlyContinue
	if (-not $vmHdFileInfo) {
		Write-Warning "hard drive for VM '$($vm.Name)' was not found"
		return
	}

	$backupHdFile = Join-Path $script:backupFolder $vm.Name 'Virtual Hard Disks' $vmHdFileInfo.Name
	$backupHdFileInfo = Get-Item -LiteralPath $backupHdFile -ErrorAction SilentlyContinue
	if ($backupHdFileInfo -and $backupHdFileInfo.LastWriteTimeUtc -ge $vmHdFileInfo.LastWriteTimeUtc) {
		Write-Host "skipping backup for VM '$($vm.Name)': current backup already exists" -ForegroundColor DarkYellow
		return
	}

	# if a backup already exists, have to remove it or Export-VM errors out:
	$vmBackupFolder = (Join-Path $backupFolder $vm.Name)
	if (Test-Path -LiteralPath $vmBackupFolder -PathType Container) {
		Write-Host "removing old backup folder for VM '$($vm.Name)'" -ForegroundColor DarkGray
		Remove-Item -LiteralPath $vmBackupFolder -Force -Recurse
	}

	Write-Host "backing up VM '$($vm.Name)'" -ForegroundColor Cyan
	Export-VM -VM $vm -Path $backupFolder
}

function BackUpVM_old {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param([string] $vmName)

	if (-not (Test-Path -LiteralPath (Join-Path $backupFolder $vmName) -PathType Container)) {
		Write-Host "backing up VM '$vmName'" -ForegroundColor Cyan
		Export-VM -Name $vmName -Path $backupFolder
	} else {
		Write-Host "skipping backup for VM '$vmName': backup already exists" -ForegroundColor DarkYellow
	}
}

#==============================
Main
#==============================
