#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules 'Hyper-V'

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[string] $vmName = ''
)

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param([string] $name)

	$baseBackupFolder = 'D:\Users\michael\temp\VMs'
	# back up Hyper-V VMs:
	$hyperVBackupFolder = Join-Path $baseBackupFolder 'HyperV'
	Get-VM |
		Where-Object { -not $name -or $_.Name -like $name } |
		Where-Object { $_.Name -notlike '*_diff' -and $_.Name -notlike '*_test' } |
		ForEach-Object { BackUpHyperVVM -vm $_ -backupFolder $hyperVBackupFolder }
	# back up VirtualBox VMs:
	$virtualBoxBackupFolder = Join-Path $baseBackupFolder 'VirtualBox'
	# TODO:
	#	find path for vboxmanage.exe in the registry (HKLM\Software\Oracle\VirtualBox\@InstallPath [i think])
	#	run "vboxmange.exe list vms" to get list of vms; have to parse out the names (each line looks like: "<vm name>" {<vm guid>})
	#	for each one: vboxmanae.exe export <vm name or id> --output <outputFile.ova> --options=manifest,nomacsbutnat
	#	(if we use .OVA format, then everything will be written to single file, and we can just put all VMs in the same folder; if we use .OVF, everything is a separate file, and need to use subfolder for each VM)
	#	(and not sure about the nomacsbutnat; since this is just for backup purposes, might want to leave that off and get all mac addresses)
}

function BackUpHyperVVM {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [Microsoft.HyperV.PowerShell.VirtualMachine] $vm,
		[Parameter(Mandatory=$false)] [string] $backupFolder
	)
	$vmHdFileInfo = Get-Item -LiteralPath $vm.HardDrives[0].Path -ErrorAction SilentlyContinue
	if (-not $vmHdFileInfo) {
		Write-Warning "hard drive for VM '$($vm.Name)' was not found"
		return
	}
	$vmBackupFolder = (Join-Path $backupFolder $vm.Name)
	# see if any existing backup is up-to-date by comparing mod times of disk files:
	$backupHdFile = Join-Path $vmBackupFolder 'Virtual Hard Disks' $vmHdFileInfo.Name
	$backupHdFileInfo = Get-Item -LiteralPath $backupHdFile -ErrorAction SilentlyContinue
	if ($backupHdFileInfo -and $backupHdFileInfo.LastWriteTimeUtc -ge $vmHdFileInfo.LastWriteTimeUtc) {
		Write-Host "skipping backup for VM '$($vm.Name)': current backup already exists" -ForegroundColor Green
		return
	}
	# if a backup already exists, have to remove it or Export-VM errors out:
	if (Test-Path -LiteralPath $vmBackupFolder -PathType Container) {
		Write-Host "removing old backup folder for VM '$($vm.Name)'" -ForegroundColor DarkGray
		Remove-Item -LiteralPath $vmBackupFolder -Force -Recurse
	}
	# now create the backup:
	Write-Host "backing up VM '$($vm.Name)'" -ForegroundColor Cyan
	Export-VM -VM $vm -Path $backupFolder
}

#==============================
Main -name $vmName
#==============================
