using namespace System.IO

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $pauseBeforeCleanup,
	[switch] $writeOnesFirst,
	[switch] $forceRemountCompressibleFS
)

$ErrorActionPreference = 'Stop'	#'Continue'
Set-StrictMode -Version Latest

$script:bufferSize = 64KB
$script:passesFor1MB = (1MB / $script:bufferSize)
$script:passesFor10MB = (10MB / $script:bufferSize)
$script:passesFor100MB = (100MB / $script:bufferSize)
$script:passesFor1GB = (1GB / $script:bufferSize)
$script:zeroesBuffer = [byte[]]::new($script:bufferSize)
$script:onesBuffer = [byte[]]::new($script:bufferSize)
$script:zeroFile = "$env:HOME/zeroes"

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[switch] $pauseCleanup,
		[switch] $writeOnes,
		[switch] $forceRemount
	)

	if (-not (isLinuxOs)) { Write-Error "this script is only intended for Linux"; return; }
	if (-not (isRunningAsRoot)) { Write-Error "this script requires root; please run PowerShell with sudo or something"; return; }

	InitBuffer -buffer $script:zeroesBuffer -value 0
	if ($writeOnes) {
		$script:onesBuffer = [byte[]]::new($script:bufferSize)
		InitBuffer -buffer $script:onesBuffer -value 0xff
	}

	$fsInfo = Get-FSInfo

	$remountedRoot = $false
	if ($forceRemount -and $fsInfo.FileSystem -eq 'btrfs' -and $fsInfo.Compression -and $fsInfo.Compression -ne 'none') {
		# some distro's seem to be ignoring it if we set specific files to not use compressions, so remount drive without compression ???
		Write-Host "remounting root filesystem with no compression" -ForegroundColor DarkYellow
		mount -o remount,compress=none /
		$remountedRoot = $true
	}

	$progressBarCaption = 'Zero''ing free space'
	# create our file we're going to write to
	Write-Host "writing zeroes to file '$script:zeroFile' (writeOnesFirst = $writeOnes)" -ForegroundColor DarkCyan
	$trgFile = [File]::Open($script:zeroFile, [FileMode]::Create)
	try {
		if ($fsInfo.FileSystem -eq 'btrfs' -and $fsInfo.Compression) {
			# try to disable compression on the file (in case we don't remount above...):
			Write-Verbose "$($MyInvocation.InvocationName): disabling btrfs compression for file '$script:zeroFile'"
			btrfs property set $script:zeroFile compression none
		}
		# start loop:
		$startFreeSpace = $freeSpace = (Get-PSDrive -Name '/').Free
		while ($freeSpace -gt 0) {
			$percentDone = ($startFreeSpace - $freeSpace) * 100.0 / $startFreeSpace
			Write-Progress -Activity $progressBarCaption -PercentComplete $percentDone
			if ($freeSpace -ge 1.1GB) {
				Write-Verbose "$($MyInvocation.InvocationName): freespace = $freeSpace, writing 1GB data"
				WriteSomeData -file $trgFile -passes $script:passesFor1GB -writeOnes:$writeOnes
			} elseif ($freeSpace -ge 110MB) {
				Write-Verbose "$($MyInvocation.InvocationName): freespace = $freeSpace, writing 100MB data"
				WriteSomeData -file $trgFile -passes $script:passesFor100MB -writeOnes:$writeOnes
			} elseif ($freeSpace -ge 20MB) {
				Write-Verbose "$($MyInvocation.InvocationName): freespace = $freeSpace, writing 10MB data"
				WriteSomeData -file $trgFile -passes $script:passesFor10MB -writeOnes:$writeOnes
			} elseif ($freeSpace -ge 10MB) {
				Write-Verbose "$($MyInvocation.InvocationName): freespace = $freeSpace, writing 1MB data"
				WriteSomeData -file $trgFile -passes $script:passesFor1MB -writeOnes:$writeOnes
			} else {
				Write-Verbose "$($MyInvocation.InvocationName): freespace = $freeSpace, breaking out of loop"
				sync
				break
			}
			sync
			$freeSpace = (Get-PSDrive -Name '/').Free
		}
	} finally {
		Write-Progress -Activity $progressBarCaption -PercentComplete 100 -Completed
		if ($pauseCleanup) {
			Read-Host -Prompt 'press enter to clean up space'
		}
		if ($trgFile) { $trgFile.Dispose() }
		if (Test-Path -Path $script:zeroFile) {
			Remove-Item -Path $script:zeroFile
		}
		if ($remountedRoot) {
			Write-Host "remounting root filesystem with defaults" -ForegroundColor DarkYellow
			mount -o remount /
		}
	}

	Write-Host "done; you can shut down the system" -ForegroundColor DarkMagenta
}

function WriteSomeData {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [FileStream] $file,
		[Parameter(Mandatory=$true)] [int] $passes,
		[switch] $writeOnes
	)
	for ($i = 0; $i -lt $passes; ++$i) {
		if ($writeOnes) {
			$startPos = $file.Position
			$file.Write($script:onesBuffer)
			$file.Position = $startPos
		}
		$file.Write($script:zeroesBuffer)
	}
}

function InitBuffer {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [byte[]] $buffer,
		[Parameter(Mandatory=$true)] [byte] $value
	)
	Write-Verbose "$($MyInvocation.InvocationName): init'ing buffer with value '$value'"
	for ($i = 0; $i -lt $buffer.Length; ++$i) { $buffer[$i] = $value }
}

function Get-FSInfo {
	[OutputType([PSObject])]
	param()
	$m = mount | Select-String -Pattern '^(?<drv>/dev/\w+) on / type (?<fs>\w+) \((?<opts>.*)\)' -NoEmphasis
	if (-not ($m -and $m.Matches -and $m.Matches[0].Success)) { Write-Error "could not determine filesystem type"; return; }
	$drv = $m.Matches[0].Groups['drv'].Value
	$fs = $m.Matches[0].Groups['fs'].Value
	# couldn't figure out a regex to get this all in one go above, so second step:
	$cmp = ''
	$m2 = $m.Matches[0].Groups['opts'] | Select-String -Pattern 'compress=(?<cmp>[^,]+)' -NoEmphasis
	if ($m2 -and $m2.Matches -and $m2.Matches[0].Success) {
		$cmp = $m2.Matches[0].Groups['cmp'].Value
	}
	Write-Verbose "$($MyInvocation.InvocationName): filesystem info: drive = '$drv', filesystem = '$fs', compression = '$cmp'"
	return [PSCustomObject]@{ Drive = $drv; FileSystem = $fs; Compression = $cmp; }
}

function isLinuxOs {
	[OutputType([bool])]
	param()
	return (Test-Path Variable:IsCoreCLR -PathType Leaf) -and (Test-Path Variable:IsLinux -PathType Leaf) -and $IsCoreCLR -and $IsLinux
}

function isRunningAsRoot {
	[OutputType([bool])]
	param()
	return [int](id -u) -eq 0
}

#==============================
Main -pauseCleanup:$pauseBeforeCleanup -writeOnes:$writeOnesFirst -forceRemount:$forceRemountCompressibleFS
#==============================
