#Requires -Version 7.4

[CmdletBinding(SupportsShouldProcess=$false, DefaultParameterSetName='formatted')]
param(
	[Parameter(Mandatory=$false, Position=0)] [ValidateRange(1, [int]::MaxValue)] [Alias('count')] [int]$numberOfDigits = 100,
	[Parameter(ParameterSetName='formatted', Mandatory=$false, Position=1)] [ValidateRange(1, [int]::MaxValue)]  [int]$digitsPerGroup = 5,
	[Parameter(ParameterSetName='formatted', Mandatory=$false, Position=2)] [ValidateRange(1, [int]::MaxValue)] [int]$digitsPerLine = 50,
	[Parameter(ParameterSetName='raw', Mandatory=$false, Position=1)] [switch]$raw
)

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

if ($raw) {
	Write-Output @(Get-SecureRandom -Minimum 0 -Maximum 10 -Count $numberofDigits)
	return
}

$sb = [System.Text.StringBuilder]::new(1024)
$groupCount = 0
$lineCount = 0
Get-SecureRandom -Minimum 0 -Maximum 10 -Count $numberofDigits |
	ForEach-Object {
		[void] $sb.Append($_)
		++$groupCount
		++$lineCount
		if ($lineCount -ge $digitsPerLine) {
			[void] $sb.Append([System.Environment]::NewLine)
			$groupCount = 0
			$lineCount = 0
		} elseif($groupCount -ge $digitsPerGroup) {
			[void] $sb.Append(' ')
			$groupCount = 0
		}
	}
Write-Output $sb.ToString()