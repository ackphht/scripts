#Requires -Version 5

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Alias('nf')] [switch] $includeNerdFontChars
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

Write-Output ''
Write-Output 'ABCDEFGHIJKLMNOPQRSTUVWXYZ abcdefghijklmnopqrstuvwxyz 0123456789'
Write-Output '!?@#$%^&* ;: `''"‘’“” ~-_=+ /\|¦ () [] {} <> oO0 iIlL1 g9qCGQ ~-+=>'
Write-Output 'Áá Ää Åå Ææ Çç Éé Ùù Ïï İı Ññ ß '
if ($includeNerdFontChars) {
	Write-Output '<TBD>'
}