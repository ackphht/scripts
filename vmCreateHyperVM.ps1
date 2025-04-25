<#
	.Synopsis
	Creates a new Hyper-V VM

	.Description
	Creates a new Hyper-V VM

	.Parameter newVmName
	The name of the new VM to create.

	.Parameter generation
	Which generation of Hyper-V VM to create. Either 1 or 2; the default is 2.

	.Parameter memorySize
	How much virtual memory to allocate the VM. The default is 4GB.

	.Parameter hardDriveSize
	How big a hard rive to create for the VM. This will be a dynamically sized drive. The default size is 64GB.

	.Parameter processorCount
	How many virtual processors to allocate to the VM. The default is 4.

	.Parameter isopath
	Optional path to an ISO image to attach. If specified, the VM will also have a virtual DVD drive attached to it; if no path is specified, an empty drive will be added.

	.Parameter hardDrivesPath
	The folder in which to store the virtual hard drive. The default is '$env:UserProfile\Virtual Machines\Hyper-V\Virtual Hard Disks'.

	.Parameter networkSwitchName
	The friendly name of the virtual switch to connect the new virtual machine to an existing virtual switch to provide connectivity to a network. The default is 'Default Switch'.

	.Parameter enableSecureBoot
	Whether or not to enable secure boot. The default is $true.

	.Inputs
	None.

	.Outputs
	None.
#>


#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)]
	[ValidateNotNullOrEmpty()]
	[string]$newVmName,

	[ValidateSet(1, 2)]
	[Int16]$generation = 2,

	[Int64]$memorySize = 4GB,

	[UInt64]$hardDriveSize = 64GB,

	[Int64]$processorCount = 4,

	[string]$isopath = '',

	[ValidateNotNullOrEmpty()]
	[string]$hardDrivesPath = "$env:UserProfile\Virtual Machines\Hyper-V\Virtual Hard Disks",

	[ValidateScript( { if (-not $_ -or -not (Get-VMSwitch -Name $_ -ErrorAction SilentlyContinue)) { throw "The network switch name '$_' does not exist: valid values are: $((Get-VMSwitch).Name -join ', ')" } return $true } )]
	[string]$networkSwitchName = 'Default Switch',

	#[ValidateSet('On', 'Off')]
	#[string]$enableSecureBoot = 'On'
	[bool]$enableSecureBoot = $true
)

Set-StrictMode -Version Latest

#create the VM:
$hddPath = "${hardDrivesPath}\${newVmName}.vhdx"
Write-Verbose "creating new VM: name = |$newVmName|, HDD path = |$hddPath|"
$newvm = New-VM -Name $newVmName -Generation $generation -MemoryStartupBytes $memorySize `
				-NewVHDPath $hddPath -NewVHDSizeBytes $hardDriveSize -SwitchName $networkSwitchName
# change some settings from defaults:
Write-Verbose "adjusting VM: memory = |$memorySize|, proc count = |$processorCount|"
Set-VM -VM $newvm -DynamicMemory -MemoryMaximumBytes $memorySize -ProcessorCount $processorCount `
		-AutomaticCheckpointsEnabled $false -CheckpointType Disabled
# see if we want to move the Smart Paging File Location (i.e. to the same physical drive where we're putting the HDD)
# (not sure what "Smart Paging File Location" actually does, but probably want it on external drive if that's where the HDD is):
Write-Verbose "newvm.SmartPagingFilePath = |$($newvm.SmartPagingFilePath)|"
$hddDirInfo = Get-Item -Path $hardDrivesPath
Write-Verbose "hddDirInfo.ResolvedTarget = |$($hddDirInfo.ResolvedTarget)|"
if ($newvm.SmartPagingFilePath) {
	$spgDirInfo = Get-Item -Path $newvm.SmartPagingFilePath
	Write-Verbose "spgDirInfo.ResolvedTarget = |$($spgDirInfo.ResolvedTarget)|"
}
if ($hddDirInfo -and $spgDirInfo -and $hddDirInfo.ResolvedTarget -and $spgDirInfo.ResolvedTarget) {
	$hddRoot = [System.IO.Path]::GetPathRoot($hddDirInfo.ResolvedTarget)
	$spgRoot = [System.IO.Path]::GetPathRoot($spgDirInfo.ResolvedTarget)
	if ($hddRoot -ne $spgRoot) {
		$newSmartPagingFilePath = Join-Path $hddRoot ($newvm.SmartPagingFilePath.Substring($spgRoot.Length))
		Write-Verbose "new SmartPagingFilePath = |$newSmartPagingFilePath|"
		Set-VM -VM $newvm -SmartPagingFilePath $newSmartPagingFilePath
	}
}

Write-Verbose 'enabling Guest Services'
Enable-VMIntegrationService -VM $newvm -Name 'Guest Service Interface'

$newvmhd = Get-VMHardDiskDrive -VM $newvm

if ($generation -eq 2) {
	if ($isopath) {
		Write-Verbose "adding dvd drive with ISO Image |$isopath|"
		$newvmdvd = Add-VMDvdDrive -VM $newvm -ControllerLocation 7 -Path $isopath
	} else {
		Write-Verbose 'adding empty dvd drive'
		$newvmdvd = Add-VMDvdDrive -VM $newvm -ControllerLocation 7
	}
	if (-not $newvmdvd) {	# according to docs, above is supposed to return the new drive, but it doesn't, but maybe it will get fixed
		$newvmdvd = Get-VMDvdDrive -VM $newvm
	}

	Write-Verbose 'enabling dynamic memoy'
	Set-VMMemory -VM $newvm -DynamicMemoryEnabled $true -StartupBytes $memorySize -MaximumBytes ($memorySize * 2)

	#Set-VMFirmware -VM $newvm -BootOrder $newvmhd,$newvmdvd -EnableSecureBoot $enableSecureBoot
	#if ($enableSecureBoot -eq 'On') {
	$secureBoot = if ($enableSecureBoot) { 'On' } else { 'Off' }
	Write-Verbose "adjusting boot order and setting secure boot to '$secureBoot'"
	Set-VMFirmware -VM $newvm -BootOrder $newvmhd,$newvmdvd -EnableSecureBoot $secureBoot
	if ($enableSecureBoot) {
		Write-Verbose 'adding secure boot local key info'
		Set-VMKeyProtector -VM $newvm -NewLocalKeyProtector
		Enable-VMTPM -VM $newvm
	}
} else {
	if ($isopath) {
		Write-Verbose "adding ISO Image |$isopath| to dvd drive"
		$newvmdvd = Get-VMDvdDrive -VM $newvm
		Set-VMDvdDrive -VMDvdDrive $newvmdvd -Path $isopath
	}
	Write-Verbose "enabling numlock, setting boot order"
	Set-VMBios -VM $newvm -EnableNumLock -StartupOrder IDE,CD,Floppy,LegacyNetworkAdapter
}