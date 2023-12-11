#Requires -RunAsAdministrator
#Requires -Version 7
#Requires -Modules 'Microsoft.PowerShell.Security'

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true)] [string] $vmName
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

$vm = Get-VM -VMName $vmName
if (-not $vm.HardDrives -or $vm.HardDrives.Count -eq 0) {
	Write-Error "VM '$vmName' does not have any hard drives"
	return
}
$vmId = $vm.Id.ToString().ToUpperInvariant()
$accountName = 'NT VIRTUAL MACHINE\{0}' -f $vmId
Write-Verbose "using account name = `"$accountName`""

# command line way:
#	icacls <Path of .vhd or .avhd file> /grant "NT VIRTUAL MACHINE\<Virtual Machine ID>":(F)
# but can do it with Get-Acl/Set-Acl:
foreach ($drv in $vm.HardDrives) {
	$drivePath = $drv.Path
	if (-not (Test-Path -Path $drivePath -PathType Leaf)) {
		Write-Warning "VM '$vmName' hard drive path does not exist: `"$drivePath`""
		continue
	}
	Write-Verbose "checking rights for drive `"$drivePath`""
	$driveAcl = Get-Acl -Path $drivePath
	$accountRule = $driveAcl.Access | Where-Object { $_.IdentityReference.Value -eq $accountName } | Select-Object -First 1
	if (-not $accountRule -or -not ($accountRule.FileSystemRights.HasFlag([System.Security.AccessControl.FileSystemRights]::FullControl))) {
		# has no rights at all yet, or doesn't have full access, upsert rights:
		if (-not $accountRule) { Write-Verbose "no existing permission for '$accountName'" } else { Write-Verbose "found existing rights: $($accountRule.FileSystemRights)" }
		$newRule = [System.Security.AccessControl.FileSystemAccessRule]::new($accountName, [System.Security.AccessControl.FileSystemRights]::FullControl, [System.Security.AccessControl.AccessControlType]::Allow)
		$driveAcl.SetAccessRule($newRule)
		Set-Acl -Path $drivePath -AclObject $driveAcl
		Write-Host "full access granted to `"$accountName`" for VM hard drive `"$drivePath`"" -ForegroundColor Cyan
	} else {
		Write-Host "account `"$accountName`" already has full rights for VM drive `"$drivePath`"" -ForegroundColor Cyan
	}
}