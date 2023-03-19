#Requires -Version 7.0

using namespace System
using namespace System.Collections.Generic
using namespace System.IO
using namespace System.Text

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# would be nice if this could work from \\live.sysinternals.com\tools, but the timestamps
# don't match, and can't get the version info to work reliably, so we'll just download the zip file

function WriteWorkingMessage { param([string] $msg) Write-Host $msg -ForegroundColor DarkYellow; }

$downloadUrl = 'https://download.sysinternals.com/files/SysinternalsSuite.zip'
$targetFolder = Convert-Path -Path '~/Apps/SysInternals' -ErrorAction Stop
$tmpFolder = [Path]::GetTempPath()
$tmpFile = Join-Path $tmpFolder ([Path]::GetRandomFileName() + '.zip')
$versionZero = [Version]::new(0, 0, 0, 0)
$maxTimestampDiffSecs = 14403	# 4 hours + 3 seconds, for zip file / timestamp offset weirdness + a little wiggle room...
								# zip files only store timestamps in local time, and that's all Windows' builtin extractor reads,
								# and all that .NET's ZipArchive reads; but some of the files in the SysInternals zip have the 'extra'
								# field populated, with the NTFS last modified FILETIME, which is UTC, and 7-zip will use that if available
								# so long-ish story short: can have some mismatches depending on how we got the files, so need some tolerance in the compares

# first do a HEAD request so we can check if we actually need to download the file (may have already downloaded it, e.g., doing a -WhatIf):
$response = Invoke-webRequest -Method Head -Uri $downloadUrl -PassThru -OutFile $tmpFile <# still have to specify this, and it does get created, for some reason... #>
Remove-Item -Path $tmpFile -Force -ErrorAction SilentlyContinue -WhatIf:$false		# try to clean up...

$lastWriteTime = [DateTimeOffset]::Parse($response.Headers['Last-Modified'])
Write-Verbose "SysInternals zip file last write time = |$($lastWriteTime.ToString('u'))|"
$zipFilename = Join-Path $tmpFolder ('SysInternals.{0:yyyyMMddHHmmss}.zip' -f $lastWriteTime.ToUniversalTime())

if (-not (Test-Path -Path $zipFilename -PathType Leaf)) {
	# need to download for reals:
	Write-Verbose "downloading |$downloadUrl| to file |$zipFilename|"
	Invoke-webRequest -Method Get -Uri $downloadUrl -OutFile $zipFilename
	Unblock-File -Path $zipFilename		# just in case
} else {
	Write-Verbose "re-using already downloaded file |$zipFilename|"
}

# now open zip file and check files:
$archive = [Compression.ZipFile]::OpenRead($zipFilename)
try {
	$entriesMap = @{}
	# create dict of filenames to zip entries (need to know all files so we know whether we need to swap 32s & 64s)
	foreach ($e in $archive.Entries) {
		$o = [PSCustomObject]@{ SourceName = $e.Name; SourceBaseName = [Path]::GetFileNameWithoutExtension($e.Name);
								TargetName = $e.Name; LastWriteTime = $e.LastWriteTime; ZipEntry = $e;  }
		$entriesMap.Add($e.Name, $o)
	}
	# figure out target names (i.e. swap the 32s & 64s as needed):
	foreach ($e in ($entriesMap.Values |
						Where-Object { $_.SourceName -like '*.exe' -and $_.SourceName -notlike '*64.exe' }) |
						Where-Object { $entriesMap.ContainsKey(('{0}64.exe' -f $_.SourceBaseName)) }) {
		$entry32 = $e
		$entry64 = $entriesMap[('{0}64.exe' -f $entry32.SourceBaseName)]
		$entry64.TargetName = $entry32.TargetName
		$entry32.TargetName = ('{0}32.exe' -f $entry32.SourceBaseName)
	}
	# now make simpler list:
	$entries = $entriesMap.Values | Sort-Object -Property TargetName
	# compare each timestamp to targetFolder/targetName;
	foreach ($e in $entries) {
		if ($e.SourceName -like '*.dll' -or $e.SourceName -like '*64a.exe')  {	# think these are all gone from the zip, but just in case
			Write-Verbose "skipping file |$($e.SourceName)|"
			continue
		}
		$targetPath = Join-Path $targetFolder $e.TargetName
		Write-Verbose "checking source file |$($e.SourceName)|, targetPath = |$targetPath|"
		$targetItem = Get-Item -Path $targetPath -ErrorAction SilentlyContinue
		if ($targetItem) {
			Write-Verbose "    target file exists, comparing timestamps (source = |$($e.LastWriteTime.ToUniversalTime().ToString('u'))|, target = |$($targetItem.LastWriteTimeUtc.ToString('u'))|)"
			if ([Math]::Abs(($e.LastWriteTime.ToUniversalTime() - $targetItem.LastWriteTimeUtc).TotalSeconds) -gt $maxTimestampDiffSecs) {
				Write-Verbose '    timestamps differ, extracting source file, checking versions'
				$tmpSrcFile = Join-Path $tmpFolder $e.SourceName
				try {
					# not same timestamps, extract file to temp and compare versions;
					[Compression.ZipFileExtensions]::ExtractToFile($e.ZipEntry, $tmpSrcFile)
					$sourceItem = Get-Item -Path $tmpSrcFile
					# if both versions are 0.0.0, then just copy the file
					# (the FileVersionRaw that posh populates will always have full version, so can just do straight compare to 0.0.0.0 [normal Version object, you can't always do that])
					# and for non-exe files (txt, chm, etc) that are in the zip, this will be populated with a zero version
					if ($sourceItem.VersionInfo.FileVersionRaw -eq $versionZero -and $targetItem.VersionInfo.FileVersionRaw -eq $versionZero) {
						Write-Verbose '    source and target both are version 0.0.0.0, and since timestamps are different, updating file'
						WriteWorkingMessage "updating file $($e.TargetName) [source file '$($e.LastWriteTime.ToUniversalTime().ToString('u'))', target file '$($targetItem.LastWriteTimeUtc.ToString('u'))']"
						Move-Item -Path $tmpSrcFile -Destination $targetPath -Force
					} elseif ($sourceItem.VersionInfo.FileVersionRaw -gt $targetItem.VersionInfo.FileVersionRaw) {
						Write-Verbose "    source version $($sourceItem.VersionInfo.FileVersion) is > target version $($targetItem.VersionInfo.FileVersion), updating file"
						WriteWorkingMessage "updating file $($e.TargetName) [source file v$($sourceItem.VersionInfo.FileVersion), target file v$($targetItem.VersionInfo.FileVersion)]"
						Move-Item -Path $tmpSrcFile -Destination $targetPath -Force
					} else {
						Write-Verbose "    source version $($sourceItem.VersionInfo.FileVersion) is <= target version $($targetItem.VersionInfo.FileVersion), NOT updating file"
					}
					# or maybe just update file, screw the version checking ???
				} finally {
					# make sure we clean things up, just in case:
					Remove-Item -Path $tmpSrcFile -Force -ErrorAction SilentlyContinue -WhatIf:$false
				}
			} else {
				Write-Verbose '    timestamps match (within tolerance), skipping file'
			}
		} else {
			# target doesn't exist yet, just copy source to target
			WriteWorkingMessage "adding new file '$($e.SourceName)'"
			if ($PSCmdlet.ShouldProcess($targetPath, 'ExtractToFile')) {
				[Compression.ZipFileExtensions]::ExtractToFile($e.ZipEntry, $targetPath)
			}
		}
	}
} finally {
	if ($archive) { $archive.Dispose() }
}

## should we remove the zip file? might still want to look at it...
#if (-not $WhatIfPreference) {
#	Remove-Item -Path $zipFilename -Force -ErrorAction SilentlyContinue		# try to clean up...
#}