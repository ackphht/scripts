[CmdletBinding(SupportsShouldProcess=$True)]
param(
	[switch]$renameOnly
)

$sysinternalsFolder = "$env:UserProfile\Apps\Sysinternals"
$maxTimestampDiff = [TimeSpan]::FromHours(1)

if (Test-Path 'Autoruns64.dll') {
	Write-Verbose 'deleting file Autoruns64.dll'
	Remove-Item 'Autoruns64.dll' -WhatIf:$WhatIfPreference
}

Write-Output "renaming exe's"
Get-ChildItem *.exe -Exclude *64.exe |
	Where-Object { Test-Path ("{0}64.exe" -f $_.BaseName) } |
	#Select-Object -First 1 |
	ForEach-Object {
		$basename = $_.BaseName
		Write-Verbose "moving '$($_.FullName)' to '$(Join-Path $_.DirectoryName ("{0}32.exe" -f $basename))'"
		Move-Item $_.FullName (Join-Path $_.DirectoryName ("{0}32.exe" -f $basename)) -WhatIf:$WhatIfPreference
		Write-Verbose "moving '$(Join-Path $_.DirectoryName ("{0}64.exe" -f $basename))' to '$(Join-Path $_.DirectoryName ("{0}.exe" -f $basename))'"
		Move-Item (Join-Path $_.DirectoryName ("{0}64.exe" -f $basename)) (Join-Path $_.DirectoryName ("{0}.exe" -f $basename)) -WhatIf:$WhatIfPreference
	}

if (!$renameOnly) {
	Write-Output "moving updated files"
	Get-ChildItem *.* -Exclude *.cnt |
		ForEach-Object {
			$sourceFile = $_
			$targetName = Join-Path $sysinternalsFolder $sourceFile.Name
			Write-Verbose "checking for target file '$targetName'"
			if (Test-Path $targetName) {
				$targetFile = Get-Item $targetName
				Write-Verbose "    target file exists; comparing versions [source file v$($sourceFile.VersionInfo.FileVersion), target file v$($targetFile.VersionInfo.FileVersion)]"
				if ($sourceFile.VersionInfo.FileVersionRaw -gt $targetFile.VersionInfo.FileVersionRaw) {
					Write-Host "moving file $($sourceFile.Name) [source file v$($sourceFile.VersionInfo.FileVersion), target file v$($targetFile.VersionInfo.FileVersion)]" -ForegroundColor DarkYellow
					Move-Item $sourceFile $targetName -Force -WhatIf:$WhatIfPreference
				} elseif (-not ($sourceFile.VersionInfo.FileVersionRaw -lt $targetFile.VersionInfo.FileVersionRaw) -and
						$sourceFile.VersionInfo.FileVersionRaw -eq $targetFile.VersionInfo.FileVersionRaw) {
					Write-Verbose "    versions are same, comparing timestamps [source file $($sourceFile.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')), target file $($targetFile.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))]"
					if (($sourceFile.LastWriteTimeUtc - $targetFile.LastWriteTimeUtc) -gt $maxTimestampDiff) {
						Write-Host "moving file $($sourceFile.Name) [source file $($sourceFile.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss')), target file $($targetFile.LastWriteTimeUtc.ToString('yyyy-MM-dd HH:mm:ss'))]" -ForegroundColor DarkYellow
						Move-Item $sourceFile $targetName -Force -WhatIf:$WhatIfPreference
					} else {
						Write-Verbose "    skipping file '$($sourceFile.Name)': source file version is same or lower and timestamps differ by < $($maxTimestampDiff.ToString())"
					}
				} else {
					Write-Verbose "    skipping file '$($sourceFile.Name)': source file version is lower"	# ???
				}
			} else {
				Write-Host "moving new file $($sourceFile.Name)" -ForegroundColor DarkYellow
				Move-Item $sourceFile $targetName -WhatIf:$WhatIfPreference
			}
		}
}
