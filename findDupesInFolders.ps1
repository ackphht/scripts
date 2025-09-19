#Requires -Version 7

using namespace System
using namespace System.Collections.Generic
using namespace System.IO

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	# would be nice to make this a DirectoryInfo[], but the paths are resolved according to
	# [System.Environment]::CurrentDirectory rather than PowerShell's path, so, e.g., using "."
	# doesn't necessarily resolve to the correct path (at least as of PowerShell 7.3)
	[string[]] $folders = @((Get-Location).Path),
	[ValidateSet('SHA1','SHA256','SHA384','SHA512','MD5')] [string] $hashType = 'SHA256'
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

Import-Module -Name $PSScriptRoot/ackPoshHelpers -ErrorAction Stop

WriteVerboseMessage -message 'pwd = |{0}|' -formatParams ((Get-Location).Path)
$resolvedFldrs = @()
foreach ($f in $folders) {
	$newFldr = Convert-Path -Path $f -ErrorAction Stop
	WriteVerboseMessage -message 'adding folder |{0}|' -formatParams $newFldr -continuation
	$resolvedFldrs += [DirectoryInfo]$newFldr
}
WriteVerboseMessage -message 'total input folders count {0}' -formatParams $resolvedFldrs.Length

$hashes = [Dictionary[string,FileInfo[]]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($fldr in $resolvedFldrs) {
	WriteVerboseMessage -message 'reading files in folder |{0}|' -formatParams $fldr.FullName
	Get-ChildItem -LiteralPath $fldr -File -Recurse |
		ForEach-Object {
			$fileInfo = $_
			$h = Get-FileHash -Algorithm $hashType -LiteralPath $fileInfo.FullName
			if ($hashes.ContainsKey($h.Hash)) {
				$hashes[$h.Hash] += $fileInfo
			} else {
				[void]$hashes.Add($h.Hash, @($fileInfo))
			}
		}
}
$hashes.GetEnumerator() |
	Where-Object { $_.Value.Length -gt 1 } |
	ForEach-Object {
		$hash = $_.Key
		$_.Value |
			Sort-Object LastWriteTime |
			ForEach-Object {
				Add-Member -InputObject $_ -MemberType NoteProperty -Name 'FileHash' -Value $hash.ToLowerInvariant()
				Write-Output $_
			}
	} |
	Format-Table -GroupBy FileHash -Property @{Label='Modified';Expression={$_.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')};},`
												@{Label='Path';Expression={($_ | Resolve-Path -Relative)};}
