#Requires -Version 7

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $keepDownloads
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	$fontsFolderBase = Convert-Path -Path '~/Installs/fonts'
	$sevenZipPath = (Get-Command -Name '7z.exe').Source
	$githubApiAddressFormat = 'https://api.github.com/repos/ryanoasis/nerd-fonts/releases/latest'

	$tempWorkingFolder = "$env:TEMP/nerdfonts"
	if (-not (Test-Path -Path $tempWorkingFolder -PathType Container)) { [void](mkdir -Path $tempWorkingFolder -Force) }

	# call api, get latest release info
	$resp = Invoke-RestMethod -Method Get -Uri $githubApiAddressFormat
	$ver = $resp.name
	# TODO?: anything else we need ??
	Write-Host "getting NerdFonts for version '$ver'" -ForegroundColor DarkCyan

	# process list of fonts:
	$results = @()
	@(
		'CascadiaCode'
		'ComicShannsMono'
		'Cousine'
		'FantasqueSansMono'
		'FiraCode'
		'Hack'
		'Hasklig'
		'Hermit'
		'Inconsolata'
		'JetBrainsMono'
		'Meslo'
		'Monofur'
		'Noto'
		'RobotoMono'
		'SourceCodePro'
		'UbuntuMono'
	) | ForEach-Object {
		$results += ProcessNerdFont -fontName $_ -versionNumber $ver -workFolderBase $tempWorkingFolder -fontsFolderBase $fontsFolderBase -sevenZipPath $sevenZipPath
	}

	Write-Host ''
	Write-Host ''
	foreach ($r in $results) {
		if ($r.Skipped) {
			if ($r.Warning) {
				Write-Host "$($r.Name): $($r.Warning)" -ForegroundColor Red
			} elseif ($r.Message) {
				Write-Host "$($r.Name): $($r.Message)" -ForegroundColor DarkGray
			}
		} else {
			Write-Host "NerdFont '$($r.Name)' added to folder '$($r.Folder)'" -ForegroundColor DarkCyan
		}
	}

	# clean up $tempWorkingFolder:
	if (-not $keepDownloads -and (Test-Path -Path $tempWorkingFolder -PathType Container)) {
		Remove-Item -Path $tempWorkingFolder -Recurse -Force
	}
}

class ProcessNerdFontResult {
	ProcessNerdFontResult([string] $name, [string] $folder) {
		$this.Name = $name
		$this.Folder = $folder.Substring(([System.Environment]::GetFolderPath('UserProfile')).Length + 1)
	}

	[string] $Name
	[string] $Folder
	[bool] $Skipped
	[string] $Warning
	[string] $Message
}

$script:logDivider = [string]::new('=', 80)
$script:githubFileAddressFormat = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/{0}.zip'
function ProcessNerdFont {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([ProcessNerdFontResult])]
	param(
		[Parameter(Mandatory=$true)] [string] $fontName,
		[Parameter(Mandatory=$true)] [string] $versionNumber,
		[Parameter(Mandatory=$true)] [string] $workFolderBase,
		[Parameter(Mandatory=$true)] [string] $fontsFolderBase,
		[Parameter(Mandatory=$true)] [string] $sevenZipPath
	)

	Write-Verbose $script:logDivider
	Write-Verbose "$($MyInvocation.InvocationName): processing nerd font |$fontName|"
	if (-not $versionNumber.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) { $versionNumber = 'v' + $versionNumber }
	$fontDestBaseFolder = Join-Path $fontsFolderBase ('{0}NF' -f $fontName)
	if (-not (Test-Path -Path $fontDestBaseFolder -PathType Container)) { [void](mkdir -Path $fontDestBaseFolder -Force) }

	$fontOut7zPath = Join-Path $fontDestBaseFolder ('{0}NF {1}.7z' -f $fontName, $versionNumber)
	$fontOutVerFolder = Join-Path $fontDestBaseFolder ('{0}NF {1}' -f $fontName, $versionNumber)

	$result = [ProcessNerdFontResult]::new($fontName, $fontOutVerFolder)

	if ((Test-Path -Path $fontOut7zPath -PathType Leaf) -and (Test-Path -Path $fontOutVerFolder -PathType Container)) {
		$msg = "font file '$(Split-Path -Path $fontOut7zPath -Leaf)' and folder for '$versionNumber' already exist; skipping font"
		Write-Verbose "$($MyInvocation.InvocationName): $msg"
		$result.Message = $msg
		$result.Skipped = $true
		return $result
	}

	$tempZipFile = Join-Path $workFolderBase ('{0}_{1}.zip' -f $fontName, $versionNumber)
	$tempUnzipFolder = Join-Path $workFolderBase ('{0}_{1}' -f $fontName, $versionNumber)
	if ((Test-Path -Path $tempZipFile -PathType Leaf)) { Remove-Item -Path $tempZipFile -Force }
	if ((Test-Path -Path $tempUnzipFolder -PathType Container)) { Remove-Item -Path $tempUnzipFolder -Recurse -Force }
	if ((Test-Path -Path $fontOut7zPath -PathType Leaf)) { Remove-Item -Path $fontOut7zPath -Force }
	if ((Test-Path -Path $fontOutVerFolder -PathType Container)) { Remove-Item -Path $fontOutVerFolder -Recurse -Force }

	# download zip file:
	$url = $script:githubFileAddressFormat -f $fontName
	Write-Verbose "$($MyInvocation.InvocationName): downloading nerd font at url = |$url|"
	if ($PSCmdlet.ShouldProcess($url, "Invoke-WebRequest")) {
		Invoke-WebRequest -Method GET -Uri $url -OutFile $tempZipFile
	}

	# unzip it:
	$unzipExitCode = UnzipFile -zipFile $tempZipFile -folderToExtractTo $tempUnzipFolder -sevenZipPath $sevenZipPath
	if ($unzipExitCode -ne 0) {
		$msg = "unzipping file '$tempZipFile' failed; skipping font '$fontName'"
		Write-Verbose "$($MyInvocation.InvocationName): $msg"
		$result.Warning = $msg
		$result.Skipped = $true
		return $result
	}

	# create new 7zip file from $tempUnzipFolder, output to $fontOut7zPath:
	$zipExitCode = ZipFolderToFile -folderToZip $tempUnzipFolder -outputFile $fontOut7zPath -sevenZipPath $sevenZipPath
	if ($zipExitCode -ne 0) {
		$msg = "creating file '$fontOut7zPath' failed; skipping font '$fontName'"
		Write-Verbose "$($MyInvocation.InvocationName): $msg"
		$result.Warning = $msg
		$result.Skipped = $true
		return $result
	}

	# => as of v3.0, they've simplified the fonts and changed the naming; not sure if we still really need to clean them up, or how, so for now, don't do it
	## clean up unwanted fonts out of $tempUnzipFolder:
	#Write-Verbose "$($MyInvocation.InvocationName): cleaning out unwanted font files in |$tempUnzipFolder|"
	#if ($PSCmdlet.ShouldProcess($tempUnzipFolder, 'remove unwanted font files')) {		# if -WhatIf, then folder won't exist and Get-ChildItem complains
	#	Get-ChildItem -Path $tempUnzipFolder -Recurse -File -Include @('*.ttf', '*.otf') |
	#		Where-Object { $_.Name -notlike '*Windows Compatible*' -or $_.Name -like '* Mono Windows Compatible*' } |
	#		Remove-Item -Force
	#}

	# move $tempUnzipFolder to $fontOutVerFolder
	Write-Verbose "$($MyInvocation.InvocationName): moving folder |$tempUnzipFolder| to |$fontOutVerFolder|"
	if ($PSCmdlet.ShouldProcess($tempUnzipFolder, 'move font files')) {		# if -WhatIf, then folder won't exist and Move-Item complains
		Move-Item -Path $tempUnzipFolder -Destination $fontOutVerFolder -Force
	}

	return $result
}

function ZipFolderToFile {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([int])]
	param(
		[Parameter(Mandatory=$true)] [string] $folderToZip,
		[Parameter(Mandatory=$true)] [string] $outputFile,
		[Parameter(Mandatory=$true)] [string] $sevenZipPath
	)
	Write-Verbose "$($MyInvocation.InvocationName): creating 7zip archive |$outputFile| for folder |$folderToZip|"
	$arguments = 'a -r -ssc -snh -snl -mx9 -ms8G -mqs+ -m0=LZMA:d=2G "{0}" *' -f $outputFile
	$exitCode = RunApplication -fileToRun $sevenZipPath -arguments $arguments -workingDirectory $folderToZip
	Write-Verbose "$($MyInvocation.InvocationName): exit code from 7zip was |$exitCode|"
	switch ($exitCode) {
		0 { break }
		1 { Write-Warning '7-zip: Some files could not be added'; break; } # this one is returned e.g. for access denied errors
		2 { Write-Warning '7-Zip encountered a fatal error while adding one or more files'; break; }
		7 { Write-Warning '7-Zip command line error'; break; }
		8 { Write-Warning '7-Zip out of memory'; break; }
		255 { Write-Warning 'Extraction cancelled by the user'; break; }
		default { Write-Warning "7-Zip signalled an unknown error (code $exitCode)" }
	}
	return $exitCode
}

function UnzipFile {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([int])]
	param(
		[Parameter(Mandatory=$true)] [string] $zipFile,
		[Parameter(Mandatory=$true)] [string] $folderToExtractTo,
		[Parameter(Mandatory=$true)] [string] $sevenZipPath
	)
	$workingDir = [System.IO.Path]::GetDirectoryName($zipFile)

	Write-Verbose "$($MyInvocation.InvocationName): running 7zip for file |$zipFile|, extracting to |$folderToExtractTo|"
	$arguments = 'x -o"{0}" -y "{1}"' -f $folderToExtractTo,$zipFile
	$exitCode = RunApplication -fileToRun $sevenZipPath -arguments $arguments -workingDirectory $workingDir
	Write-Verbose "$($MyInvocation.InvocationName): exit code from 7zip was |$exitCode|"
	switch ($exitCode) {
		0 { break }
		1 { Write-Warning '7-zip: Some files could not be extracted'; break; } # this one is returned e.g. for access denied errors
		2 { Write-Warning '7-Zip encountered a fatal error while extracting the files'; break; }
		7 { Write-Warning '7-Zip command line error'; break; }
		8 { Write-Warning '7-Zip out of memory'; break; }
		255 { Write-Warning 'Extraction cancelled by the user'; break; }
		default { Write-Warning "7-Zip signalled an unknown error (code $exitCode)" }
	}
	return $exitCode
}

# from AckApt:
function RunApplication {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([int])]
	param(
		[Parameter(Position=0, Mandatory=$true)] [ValidateNotNullOrEmpty()] [string] $fileToRun,
		[Parameter(Position=1)] [string] $arguments = '',
		[Parameter(Position=2)] [string] $workingDirectory = '',
		[Parameter(Position=3)] [switch] $asAdmin,
		[Parameter(Position=3)] [switch] $useShellExecute		# running a command line exe with UseShellExecute = true causes a new console window, so only use it if we need to
	)
	if ( $arguments -eq $null) { $arguments = '' }
	if ( $workingDirectory -eq $null) { $workingDirectory = '' }
	Write-Verbose "$($MyInvocation.InvocationName): fileToRun=|$fileToRun|, arguments=|$arguments|, workingDirectory=|$workingDirectory|, asAdmin=|$asAdmin|"
	$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
	$startInfo.FileName = $fileToRun
	$startInfo.UseShellExecute = [bool]$useShellExecute
	if ($arguments) { $startInfo.Arguments = [Environment]::ExpandEnvironmentVariables($arguments) }
	if ($workingDirectory) { $startInfo.WorkingDirectory = $workingDirectory }
	$startInfo.Verb = if ($asAdmin) { 'runas' } else { 'open' }

	#if ($PSCmdlet.ShouldProcess($(Split-Path $fileToRun -Leaf), "Process.Start")) {
	if ($PSCmdlet.ShouldProcess($arguments, (Split-Path $fileToRun -Leaf))) {
	#if ($PSCmdlet.ShouldProcess($(Split-Path $fileToRun -Leaf), "Start-Process")) {     # Start-Process doesn't support -WhatIf
		try {
			$process = [System.Diagnostics.Process]::Start($startInfo)
			if ($process) {
				$process.WaitForExit()
				Write-Verbose "$($MyInvocation.InvocationName): process exited; exit code = $($process.ExitCode)"
				return $process.ExitCode
			} else {
				Write-Verbose "[Process]::Start() returned null for application '$fileToRun'"
				return -2
			}
			#$process = Start-Process -FilePath $fileToRun -ArgumentList <String[]> -WorkingDirectory $workingDirectory -Verb $verb -Wait -PassThru
			#Write-Verbose "$($MyInvocation.InvocationName): process exited; exit code = $($process.ExitCode)"
			#$process.ExitCode
		} catch {
			Write-Warning "There was an exception running the application '$fileToRun': $($_.Exception.Message)"
			return -1
		}
	} else {
		return 0
	}
}

#==============================
Main
#==============================
