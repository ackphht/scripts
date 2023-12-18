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
	#
	# back up Hyper-V VMs:
	$hyperVBackupFolder = Join-Path $baseBackupFolder 'HyperV'
	Get-VM |
		Where-Object { -not $name -or $_.Name -like $name } |
		Where-Object { $_.Name -notlike '*_diff' -and $_.Name -notlike '*_test' } |
		ForEach-Object { BackUpHyperVVM -vm $_ -backupFolder $hyperVBackupFolder }
	#
	# back up VirtualBox VMs:
	if ((Get-Command -Name 'VBoxManage.exe' -ErrorAction SilentlyContinue)) {
		$virtualBoxBackupFolder = Join-Path $baseBackupFolder 'VirtualBox'
		GetVirtualBoxVms |
			Where-Object { -not $name -or $_.Name -like $name -or $_.Uuid -like $name } |
			Where-Object { $_.Name -notlike '*_diff' -and $_.Name -notlike '*_test' } |
			ForEach-Object { BackUpVirtualBoxVM -vm $_ -backupFolder $virtualBoxBackupFolder }
	} else {
		Write-Host "VBoxManage.exe not found, cannot back up any VirtualBox VMs" -ForegroundColor Yellow
	}
}

function BackUpHyperVVM {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [Microsoft.HyperV.PowerShell.VirtualMachine] $vm,
		[Parameter(Mandatory=$false)] [string] $backupFolder
	)
	$vmHdFileInfo = Get-Item -LiteralPath $vm.HardDrives[0].Path -ErrorAction SilentlyContinue
	if (-not $vmHdFileInfo) {
		Write-Warning "hard drive for HyperV VM '$($vm.Name)' was not found"
		return
	}
	$vmBackupFolder = (Join-Path $backupFolder $vm.Name)
	# see if any existing backup is up-to-date by comparing mod times of disk files:
	$backupHdFile = Join-Path $vmBackupFolder 'Virtual Hard Disks' $vmHdFileInfo.Name
	$backupHdFileInfo = Get-Item -LiteralPath $backupHdFile -ErrorAction SilentlyContinue
	if ($backupHdFileInfo -and $backupHdFileInfo.LastWriteTimeUtc -ge $vmHdFileInfo.LastWriteTimeUtc) {
		Write-Host "skipping backup for HyperV VM '$($vm.Name)': current backup already exists" -ForegroundColor Green
		return
	}
	# if a backup already exists, have to remove it or Export-VM errors out:
	if (Test-Path -LiteralPath $vmBackupFolder -PathType Container) {
		Write-Host "removing old backup folder for HyperV VM '$($vm.Name)'" -ForegroundColor DarkGray
		Remove-Item -LiteralPath $vmBackupFolder -Force -Recurse
	}
	# now create the backup:
	Write-Host "backing up HyperV VM '$($vm.Name)'" -ForegroundColor Cyan
	Export-VM -VM $vm -Path $backupFolder
}

function BackUpVirtualBoxVM {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [VirtualBoxVm] $vm,
		[Parameter(Mandatory=$false)] [string] $backupFolder
	)
	# make sure there's a hard drive and a config file:
	if (-not $vm.HardDrives) { Write-Warning "no hard drives found for VirtualBox VM '$($vm.Name)'"; return; }
	$vmHdFileInfo = Get-Item -LiteralPath $vm.HardDrives[0].Path -ErrorAction SilentlyContinue
	if (-not $vmHdFileInfo) { Write-Warning "hard drive for VirtualBox VM `"$($vm.Name)`" at path `"$($vm.HardDrives[0])`" was not found"; return; }
	$vmConfigFileInfo = Get-Item -LiteralPath $vm.ConfigFile -ErrorAction SilentlyContinue
	if (-not $vmConfigFileInfo) { Write-Warning "config file for VirtualBox VM `"$($vm.Name)`" at path `"$($vm.ConfigFile)`" was not found"; return; }

	$vmBackupFilePath = Join-Path $backupFolder "$($vm.Name).ova"	# use OVA format so it all gets written to one file
	# see if any existing backup is up-to-date by comparing mod times of VM's files:
	$backupFileInfo = Get-Item -LiteralPath $vmBackupFilePath -ErrorAction SilentlyContinue
	if ($backupFileInfo -and $backupFileInfo.LastWriteTimeUtc -ge $vmHdFileInfo.LastWriteTimeUtc -and $backupFileInfo.LastWriteTimeUtc -ge $vmConfigFileInfo.LastWriteTimeUtc) {
		Write-Host "skipping backup for VirtualBox VM '$($vm.Name)': current backup already exists" -ForegroundColor Green
		return
	}
	# if a backup already exists, remove it first:
	if (Test-Path -LiteralPath $vmBackupFilePath -PathType Leaf) {
		Write-Host "removing old backup file for VirtualBox VM '$($vm.Name)'" -ForegroundColor DarkGray
		Remove-Item -LiteralPath $vmBackupFilePath -Force
	}
	# now create the backup:
	Write-Host "backing up VirtualBox VM '$($vm.Name)'" -ForegroundColor Cyan
	if ($PSCmdlet.ShouldProcess("$($vm.Name) [backup file: $vmBackupFilePath]", 'VBoxManage.exe export')) {
		# TODO?: not sure about the 'nomacsbutnat'; since this is just for backup purposes, might want to leave that off and get all mac addresses ???
		VBoxManage.exe export $vm.Uuid --output $vmBackupFilePath --options=manifest,nomacsbutnat
	}
}

function GetVirtualBoxVms {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([VirtualBoxVm[]])]
	param()
	$vms = [VirtualBoxVm[]]@()
	VBoxManage.exe list vms |
		Select-String -Pattern '"(?<name>[^"]+)" {(?<id>[0-9a-f\-]+)}' -NoEmphasis |
		ForEach-Object {
			$vms += ([VirtualBoxVm]::new($_.Matches[0].Groups['name'].Value, $_.Matches[0].Groups['id'].Value))
		}
	#
	# get hard drives
	# could get drives from the showvminfo below, but parsing the drive info
	# out of that would be gnarly (it's not really a very friendly output format)
	$hdds = @(GetVirtualBoxHdds)
	#
	# get some more VM props:
	foreach ($vm in $vms) {
		$lines = VBoxManage.exe showvminfo $vm.Uuid --machinereadable
		foreach ($line in $lines) {
			$line = $line.Trim()
			switch -regex ($line) {
				'^CfgFile="?(?<cfg>[^"]+)"?$' { $vm.ConfigFile = $matches['cfg'].Replace('\\','\'); break; }
				'^memory="?(?<mem>\d+)"?$' { $vm.MemoryMB = [int]$matches['mem']; break; }
				'^cpus="?(?<cpu>\d+)"?$' { $vm.CpuCount = [int]$matches['cpu']; break; }
				# lots more props...
			}
		}
		foreach ($hdd in $hdds) {
			if ($hdd.VmUuid -eq $vm.Uuid) {
				$vm.HardDrives += $hdd
			}
		}
	}
	return $vms
}

function GetVirtualBoxHdds {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([VirtualBoxHdd[]])]
	param()
	$hdds = [VirtualBoxHdd[]]@()
	$currHdd = $null
	$lines = VBoxManage.exe list hdds --long	# errors if we try to pipe straight into a ForEach ???
	foreach ($line in $lines) {
		$line = $line.Trim()
		# if blank line, start new object:
		if (-not $line) {
			if ($currHdd) { $hdds += $currHdd; $currHdd = $null; }
			continue
		}
		if (-not $currHdd) { $currHdd = [VirtualBoxHdd]::new() }
		# parse values out of the line:
		switch -regex ($line) {
			'^UUID:\s+(?<id>[0-9a-f\-]+)$' { $currHdd.HddUuid = $matches['id']; break; }
			'^Parent UUID:\s+(?<id>.+)$' { $currHdd.ParentHddUuid = $matches['id']; break; }
			'^State:\s+(?<state>.+)$' { $currHdd.State = $matches['state']; break; }
			'^Type:\s+(?<type>.+)$' { $currHdd.Type = $matches['type']; break; }
			'^Location:\s+(?<loc>.+)$' { $currHdd.Path = $matches['loc']; break; }
			'^In use by VMs:\s+(?<name>.+) \(UUID: (?<id>[0-9a-f\-]+)\)$' { $currHdd.VmName = $matches['name']; $currHdd.VmUuid = $matches['id']; break; }
		}
	}
	if ($currHdd) { $hdds += $currHdd }
	return $hdds
}

class VirtualBoxHdd {
	[string] $HddUuid
	[string] $ParentHddUuid
	[string] $State
	[string] $Type
	[string] $Path
	[string] $VmName
	[string] $VmUuid
}

class VirtualBoxVm {
	[string] $Uuid
	[string] $Name
	[string] $ConfigFile
	[int] $MemoryMB
	[int] $CpuCount
	[VirtualBoxHdd[]] $HardDrives

	VirtualBoxVm([string] $name, [string] $uuid) {
		$this.Name = $name
		$this.Uuid = $uuid

		$this.HardDrives = @()
	}
}

#==============================
Main -name $vmName
#==============================
