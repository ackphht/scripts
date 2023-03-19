#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[Parameter(Mandatory=$true, ParameterSetName='ById')] 
	[string] $id,
	[Parameter(Mandatory=$false, ParameterSetName='ById')] 
	[string] $formatCode = $null,
	
	[Parameter(Mandatory=$true, ParameterSetName='ByCsv')] 
	[string] $csvPath,		# needs at least VideoName,YouTubeId

	[switch] $useLegacy		# use old youtube-dl rather than newer yt-dlp.exe
)

$ErrorActionPreference = 'Stop'	#'Continue'
Set-StrictMode -Version Latest
[System.Environment]::CurrentDirectory = (Get-Location).Path

$script:ytdlCmd = ''

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	if ($useLegacy) {
		$script:ytdlCmd = 'py -3 "{0}"' -f (Convert-Path "~\OneDrive\Utils\youtube-dl")
	} else {
		$script:ytdlCmd = Convert-Path "~\OneDrive\Utils\yt-dlp.exe"
	}

	# put your script here:
	if ($csvPath) {
		$hdr = [string]::new('#', 80)
		Import-Csv -Path $csvPath |
			ForEach-Object {
				Write-Host $hdr -ForegroundColor Magenta
				Write-Host "getting video '$($_.VideoName)'" -ForegroundColor Cyan
				Write-Host ''
				GetVideo -videoId $_.YouTubeId
				Write-Host ''
			}
	} else {
		GetVideo -videoId $id -format $formatCode
	}
}

function GetVideo {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $videoId,
		[string] $format = $null
	)
	$youtubeUrl = 'https://www.youtube.com/watch?v={0}' -f $videoId
	if (-not $format) {
		Invoke-Expression -Command ('& "{0}" "{1}" --list-formats' -f $script:ytdlCmd, $youtubeUrl)
		Write-Host ''
		Write-Host ''
		$format = Read-Host -Prompt 'which format [default is 18 if nothing is entered]'
		if (-not $format) { $format = '18' }
	}
	Invoke-Expression -Command ('& "{0}" "{1}" --format {2}' -f $script:ytdlCmd, $youtubeUrl, $format)
}

#==============================
Main
#==============================
