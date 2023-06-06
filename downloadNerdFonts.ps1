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

	$staticProperties = [StaticProperties]::new($ver, $tempWorkingFolder, $fontsFolderBase, $sevenZipPath)
	# process list of fonts:
	$results = @()
	@(
		# https://www.nerdfonts.com/font-downloads
		# https://github.com/ryanoasis/nerd-fonts/releases/latest
		# https://github.com/ryanoasis/nerd-fonts/raw/HEAD/patched-fonts/
		[NerdFontProperties]::new('CascadiaCode')
		[NerdFontProperties]::new('ComicShannsMono')
		[NerdFontProperties]::new('Cousine')
		[NerdFontProperties]::new('FantasqueSansMono')
		[NerdFontProperties]::new('FiraCode')
		[NerdFontProperties]::new('Hack')
		[NerdFontProperties]::new('Hasklig')
		[NerdFontProperties]::new('Hermit')
		[NerdFontProperties]::new('Inconsolata')
		[NerdFontProperties]::new('JetBrainsMono', { param([System.IO.FileInfo] $fi) $fi.Name -like 'JetBrainsMonoNL*' })	# also don't keep NoLigatures(??) fonts
		[NerdFontProperties]::new('Lilex')
		[NerdFontProperties]::new('Meslo', { param([System.IO.FileInfo] $fi) $fi.Name -like 'MesloLGL*' -or $fi.Name -like 'MesloLGM*' -or $fi.Name -like 'MesloLGSDZ*' })	# also don't keep DottedZero fonts
		[NerdFontProperties]::new('Monofur')
		#[NerdFontProperties]::new('Noto')
		[NerdFontProperties]::new('Overpass')
		[NerdFontProperties]::new('RobotoMono', 'Roboto')
		[NerdFontProperties]::new('ShareTechMono')
		[NerdFontProperties]::new('SourceCodePro')
		[NerdFontProperties]::new('SpaceMono')
		[NerdFontProperties]::new('UbuntuMono', 'UbuntuFonts')
		[NerdFontProperties]::new('VictorMono')
	) | ForEach-Object {
		$results += ProcessNerdFont -fontProps $_ -staticProps $staticProperties
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

class StaticProperties {
	StaticProperties([string] $nfVersion, [string] $workFolderBase, [string] $fontsFolderBase, [string] $sevenZipPath) {
		$this.VersionNumber = $nfVersion
		$this.WorkFolderBase = $workFolderBase
		$this.FontsFolderBase = $fontsFolderBase
		$this.SevenZipPath = $sevenZipPath
	}

	[string] $VersionNumber
	[string] $WorkFolderBase
	[string] $FontsFolderBase
	[string] $SevenZipPath
}

class NerdFontProperties {
	NerdFontProperties([string] $nfName) {
		$this.FontName = $nfName
		$this.FolderName = $nfName
		$this.FontFilter = $null
	}

	NerdFontProperties([string] $nfName, [string] $folderName) {
		$this.FontName = $nfName
		$this.FolderName = $folderName
		$this.FontFilter = $null
	}

	NerdFontProperties([string] $nfName, [scriptblock] $filter) {
		$this.FontName = $nfName
		$this.FolderName = $nfName
		$this.FontFilter = $filter
	}

	NerdFontProperties([string] $nfName, [string] $folderName, [scriptblock] $filter) {
		$this.FontName = $nfName
		$this.FolderName = $folderName
		$this.FontFilter = $filter
	}

	[string] $FontName
	[string] $FolderName
	[scriptblock] $FontFilter	# input one param: a FileInfo; return true if we don't want to keep the font
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
$script:archiveExtension = '.zip'	# with v3.0.2, there's also .tar.xz files (much smaller), but 7zip's only extracting the tar file; have to figure out how to get it to extract the rest
$script:githubFileAddressFormat = 'https://github.com/ryanoasis/nerd-fonts/releases/latest/download/{0}{1}'
function ProcessNerdFont {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([ProcessNerdFontResult])]
	param(
		[Parameter(Mandatory=$true)] [NerdFontProperties] $fontProps,
		[Parameter(Mandatory=$true)] [StaticProperties] $staticProps
	)

	Write-Verbose $script:logDivider
	Write-Verbose "$($MyInvocation.InvocationName): processing nerd font |$($fontProps.FontName)|"
#	if (-not $versionNumber.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) { $versionNumber = 'v' + $versionNumber }
	$versionNumber = $staticProps.VersionNumber.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase) ? $staticProps.VersionNumber : ('v' + $staticProps.VersionNumber)
	$fontDestBaseFolder = Join-Path $staticProps.FontsFolderBase $fontProps.FolderName
	if (-not (Test-Path -Path $fontDestBaseFolder -PathType Container)) { [void](mkdir -Path $fontDestBaseFolder -Force) }

	$fontOut7zPath = Join-Path $fontDestBaseFolder ('{0}-NerdFonts {1}.7z' -f $fontProps.FontName, $versionNumber)
	$fontOutVerFolder = Join-Path $fontDestBaseFolder ('{0}-NerdFonts {1}' -f $fontProps.FontName, $versionNumber)
	Write-Verbose "$($MyInvocation.InvocationName): 7z file: |$fontOut7zPath|, output folder: |$fontOutVerFolder|"

	$result = [ProcessNerdFontResult]::new($fontProps.FontName, $fontOutVerFolder)

	# see if we actually need to do anything:
	if ((Test-Path -Path $fontOut7zPath -PathType Leaf)) {
		$msg = "font file '$(Split-Path -Path $fontOut7zPath -Leaf)' already exists; skipping font"
		Write-Verbose "$($MyInvocation.InvocationName): $msg"
		$result.Message = $msg
		$result.Skipped = $true
		return $result
	}

	# clean up any leftovers:
	$tempZipFile = Join-Path $staticProps.WorkFolderBase ('{0}_{1}{2}' -f $fontProps.FontName, $versionNumber, $script:archiveExtension)
	$tempUnzipFolder = Join-Path $staticProps.WorkFolderBase ('{0}_{1}' -f $fontProps.FontName, $versionNumber)
	if ((Test-Path -Path $tempZipFile -PathType Leaf)) { Remove-Item -Path $tempZipFile -Force }
	if ((Test-Path -Path $tempUnzipFolder -PathType Container)) { Remove-Item -Path $tempUnzipFolder -Recurse -Force }
	if ((Test-Path -Path $fontOut7zPath -PathType Leaf)) { Remove-Item -Path $fontOut7zPath -Force }
	if ((Test-Path -Path $fontOutVerFolder -PathType Container)) { Remove-Item -Path $fontOutVerFolder -Recurse -Force }

	# download zip file:
	$url = $script:githubFileAddressFormat -f $fontProps.FontName, $script:archiveExtension
	Write-Verbose "$($MyInvocation.InvocationName): downloading nerd font at url = |$url|"
	if ($PSCmdlet.ShouldProcess($url, "Invoke-WebRequest")) {
		Invoke-WebRequest -Method GET -Uri $url -OutFile $tempZipFile
	}

	# unzip it:
	$errorMsg = UnzipFile -archiveFile $tempZipFile -folderToExtractTo $tempUnzipFolder -sevenZipPath $staticProps.SevenZipPath
	if ($errorMsg) {
		# message will have been written to console in function so don't need that here...
		$result.Warning = $errorMsg
		$result.Skipped = $true
		return $result
	}

	# create new 7zip file from $tempUnzipFolder, output to $fontOut7zPath:
	$zipExitCode = ZipFolderToFile -folderToZip $tempUnzipFolder -outputFile $fontOut7zPath -sevenZipPath $staticProps.SevenZipPath
	if ($zipExitCode -ne 0) {
		$msg = "creating file '$fontOut7zPath' failed; skipping font '$($fontProps.FontName)'"
		Write-Verbose "$($MyInvocation.InvocationName): $msg"
		$result.Warning = $msg
		$result.Skipped = $true
		return $result
	}

	# clean up unwanted fonts out of $tempUnzipFolder before we move it to final folder:
	Write-Verbose "$($MyInvocation.InvocationName): cleaning out unwanted font files in |$tempUnzipFolder|"
	if ($PSCmdlet.ShouldProcess($tempUnzipFolder, 'remove unwanted font files')) {		# if -WhatIf, then folder won't exist and Get-ChildItem complains
		Get-ChildItem -Path $tempUnzipFolder -Recurse -File -Include @('*.ttf', '*.otf') |
			# < v3.0 names:
			#Where-Object { $_.Name -notlike '*Windows Compatible*' -or $_.Name -like '* Mono Windows Compatible*' } |
			# >= v3.0 names:
			Where-Object { <# $_.Name -like '*NerdFontMono-*' -or #> $_.Name -like '*NerdFontPropo-*' -or ($fontProps.FontFilter -and (& $fontProps.FontFilter $_)) } |
			Remove-Item -Force
	}

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
	$exitCode = RunApplication -fileToRun $sevenZipPath -arguments $arguments -workingDirectory $folderToZip -useShellExecute $true # useShellExecute so it opens in separate window, because 7zip does weird things with console
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
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)] [string] $archiveFile,
		[Parameter(Mandatory=$true)] [string] $folderToExtractTo,
		[Parameter(Mandatory=$true)] [string] $sevenZipPath
	)
	Write-Verbose "$($MyInvocation.InvocationName): unzipping file |$archiveFile|, extracting to |$folderToExtractTo|"
	$resultMsg = ''
	if ([System.IO.Path]::GetExtension($archiveFile) -eq '.zip') {
		try {
			# PSCX also has an Expand-Archive, so until we stop using PSCX, make sure we use posh one:
			Microsoft.PowerShell.Archive\Expand-Archive -Path $tempZipFile -DestinationPath $tempUnzipFolder -ErrorAction Stop
		} catch {
			$resultMsg = "unzipping file '$tempZipFile' failed; skipping font '$($fontProps.FontName)';`nexception: $($Error.Exception.Message)"
			Write-Warning $resultMsg
		}
	} else {
		$unzipExitCode = UnzipFileWith7zip -archiveFile $archiveFile -folderToExtractTo $folderToExtractTo -sevenZipPath $sevenZipPath
		if ($unzipExitCode -ne 0) {
			$resultMsg = "unzipping file '$tempZipFile' failed; skipping font '$($fontProps.FontName)'"
			Write-Verbose "$($MyInvocation.InvocationName): $resultMsg"
		}
	}
	return $resultMsg
}

function UnzipFileWith7zip {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([int])]
	param(
		[Parameter(Mandatory=$true)] [string] $archiveFile,
		[Parameter(Mandatory=$true)] [string] $folderToExtractTo,
		[Parameter(Mandatory=$true)] [string] $sevenZipPath
	)
	$workingDir = [System.IO.Path]::GetDirectoryName($archiveFile)

	Write-Verbose "$($MyInvocation.InvocationName): running 7zip for file |$archiveFile|, extracting to |$folderToExtractTo|"
	$arguments = 'x -o"{0}" -y "{1}"' -f $folderToExtractTo,$archiveFile
	$exitCode = RunApplication -fileToRun $sevenZipPath -arguments $arguments -workingDirectory $workingDir -useShellExecute $true # useShellExecute so it opens in separate window, because 7zip does weird things with console
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
	$startInfo.Verb = <# if ($asAdmin) { 'runas' } else { #> 'open' <# } #>

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
