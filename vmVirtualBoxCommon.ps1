Set-StrictMode -Version 'Latest'

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