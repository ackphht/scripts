#Requires -Version 5

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Alias('nf')] [switch] $includeNerdFontChars
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

Write-Output ''
Write-Output 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
Write-Output 'abcdefghijklmnopqrstuvwxyz'
Write-Output '0123456789 oO0 IiLl1 g9qCGQ'
Write-Output '!?@#$%^&* ;: `''"‘’“” ~-_=+ /\|¦ () [] {} <> ~-+=>'
Write-Output 'Áá Ää Åå Ææ Çç Éé Ùù Ïï İı Ññ ß '
if ($includeNerdFontChars) {
	Write-Output '<TBD>'
}