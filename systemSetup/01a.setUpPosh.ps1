#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $noWingetForGithubDownload,
	[switch] $keepGithubMsi
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. $PSScriptRoot/00.common.ps1
Import-Module -Name $PSScriptRoot/../populateSystemData -ErrorAction Stop

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[switch] $noWingetForGh,
		[switch] $keepGhMsi
	)
	$osDetails = Get-OSDetails
	WriteVerboseMessage -msgScript { "osDetails = |$(ConvertTo-Json -InputObject $osdetails -Depth 100)|" }

	# TODO?: should maybe figure out these next two paths from $PROFILE, but how?
	$desktopProfileFolder = "$env:UserProfile\Documents\WindowsPowerShell"
	$coreProfileFolder = "$env:UserProfile\Documents\PowerShell"
	$appdataFolder = "$env:LocalAppData\PowerShell"
	$coreProfileModulesFolder = Join-Path $coreProfileFolder 'Modules'
	$coreProfileHelpFolder = Join-Path $coreProfileFolder 'Help'
	$appdataModulesFolder = Join-Path $appdataFolder 'Modules'
	$appdataHelpFolder = Join-Path $appdataFolder 'Help'
	#
	# make sure we have a Documents/PowerShell folder and a Documents/WindowsPowerShell that is a junction pointing to it
	#
	SetUpDocumentsProfileFolders -desktopFolder $desktopProfileFolder -coreFolder $coreProfileFolder
	SetCorePoshExecutionPolicy -coreFolder $coreProfileFolder
	#
	# now want to move Modules and Help folder out of the Documents folder (sigh)
	#
	RepointDocumentsFolderToAppData -documentsPath $coreProfileModulesFolder -appdataPath $appdataModulesFolder
	RepointDocumentsFolderToAppData -documentsPath $coreProfileHelpFolder -appdataPath $appdataHelpFolder
	#
	# make sure core powershell is installed:
	#
	VerifyPowerShellCoreInstalled -osDetails $osDetails -noWingetForGithubDwnld:$noWingetForGh -dontDeleteMsi:$keepGhMsi
}

function SetUpDocumentsProfileFolders {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $desktopFolder,
		[Parameter(Mandatory=$true)] [string] $coreFolder
	)
	if (-not (Test-Path -Path $coreFolder -PathType Container) -or -not (Test-Path -Path $desktopFolder -PathType Container)) {
		if (-not (Test-Path -Path $coreFolder -PathType Container)) {
			if (Test-Path -Path $desktopFolder -PathType Container) {
				WriteVerboseMessage -message 'renaming existing |{0}| to |{1}|' -formatParams $desktopFolder, $coreFolder
				Rename-Item -Path $desktopFolder -NewName (Split-Path -Path $coreFolder -Leaf)
			} else {
				WriteVerboseMessage -message 'creating new folder |{0}|' -formatParams $coreFolder
				[void](New-Item -Path $coreFolder -ItemType Directory -Force)
			}
		}
		if (-not (Test-Path -Path $desktopFolder -PathType Container)) {
			CreateJunction -originalFolderPath $coreFolder -junctionPath $desktopFolder
		}
	} else {
		$desktopFi = Get-Item -Path $desktopFolder
		$coreFi = Get-Item -Path $coreFolder
		if ($desktopFi.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint) -and -not $coreFi.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
			WriteVerboseMessage -message 'both Documents’’ profile folders already exist and appear to be set up appropriately'
		} else {
			Write-Warning "both profile folders for powershell already exist; you may need to do some manual cleanup"
		}
	}
}

function SetCorePoshExecutionPolicy {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $coreFolder,
		[string] $policy = 'RemoteSigned'
	)
	# PowerShell Core might not be installed yet, but just need a simple json file, so just read/write that:
	$writeFile = $false
	$executionPolicyFilePath = Join-Path $coreFolder 'powershell.config.json'
	if (Test-Path -Path $executionPolicyFilePath -PathType Leaf) {
		WriteVerboseMessage -message 'checking existing "powershell.config.json" file'
		$pol = Get-Content -Path $executionPolicyFilePath | ConvertFrom-Json
		if ($pol.'Microsoft.PowerShell:ExecutionPolicy' -ne $policy) {
			WriteVerboseMessage -message 'updating "powershell.config.json" file to policy "{0}"' -formatParams $policy
			$writeFile = $true
		}
	} else {
		WriteVerboseMessage -message 'creating "powershell.config.json" file with policy "{0}"' -formatParams $policy
		$writeFile = $true
	}
	if ($writeFile) {
		Set-Content -Path $executionPolicyFilePath -Encoding utf8 -Force -NoNewline -Value "{`"Microsoft.PowerShell:ExecutionPolicy`":`"$policy`"}"
	}
}

function RepointDocumentsFolderToAppData {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $documentsPath,
		[Parameter(Mandatory=$true)] [string] $appdataPath
	)
	WriteVerboseMessage -message 'processing {0} folder: |{1}|' -formatParams (Split-Path -Path $documentsPath -Leaf), $documentsPath
	$fi = Get-Item -Path $documentsPath -ErrorAction SilentlyContinue
	if ($fi) {
		if (-not $fi.Attributes.HasFlag([System.IO.FileAttributes]::Directory)) {
			# $documentsPath is an existing file ; write warning and move on
			Write-Warning "`"$documentsPath`" is a file and will not be moved to AppData folder; if you want, you can clean that up and run the script again"
		} elseif (-not $fi.Attributes.HasFlag([System.IO.FileAttributes]::ReparsePoint)) {
			# need to move $documentsPath to $appdataPath
			if (-not (Test-Path -Path $appdataPath -PathType Container)) {
				WriteVerboseMessage -message 'moving folder |{0}| to |{1}|' -formatParams $documentsPath, $appdataPath
				Move-Item -Path $documentsPath -Destination $appdataPath -Force
				# create junctions in profile folder to appdata folder
				CreateJunction -originalFolderPath $appdataPath -junctionPath $documentsPath
			} else {
				Write-Warning "cannot move Documents’ $($fi.Name) folder to the AppData folder because the AppData folder already exists: |$appdataPath|; manual cleanup will be needed"
			}
		} else {
			# $documentsPath is already an existing junction or symlink or something
			WriteVerboseMessage -message '`"{0}`" is already a reparsepoint, so leaving it alone (points to `"{1}`")' -formatParams $documentsPath, $fi.Target
			# still need to make sure appdata folder exists:
			if (-not (Test-Path -Path $appdataPath -PathType Container)) {
				WriteVerboseMessage -message 'creating folder |{0}|' -formatParams $appdataPath
				[void](New-Item -Path $appdataPath -ItemType Directory -Force)
			}
		}
	} else {
		# nothing existing to move from $documentsPath, so just make sure $appdataPath exists
		WriteVerboseMessage -message 'no existing Documents’’ |{0}| folder' -formatParams (Split-Path -Path $documentsPath -Leaf)
		if (-not (Test-Path -Path $appdataPath -PathType Container)) {
			WriteVerboseMessage -message 'creating folder |{0}|' -formatParams $appdataPath
			[void](mkdir -Path $appdataPath -Force)
		}
		# create junctions in profile folder to appdata folder
		CreateJunction -originalFolderPath $appdataPath -junctionPath $documentsPath
	}
}

function VerifyPowerShellCoreInstalled {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		<#[OSDetails]#> [PSObject] $osDetails,
		[switch] $noWingetForGithubDwnld,
		[switch] $dontDeleteMsi
	)

	if ([bool](Get-Command -Name 'pwsh.exe' -ErrorAction SilentlyContinue)) {
		WriteVerboseMessage -message 'PowerShellCore already installed; skipping'
		return
	}
	$wingetCapableOs = ($osDetails.BuildNumber -ge 16299)	# Win10 1709
	$wingetAvailable = $wingetCapableOs -and (Test-UsableVersionOfWinget)
	# figure out what we want to try to install:
	$installStoreVersion = $false; $installStandaloneWinget = $false; $installStandaloneDownload = $false;
	WriteVerboseMessage -message 'installing PowerShellCore (wingetAvailable = {0})' -formatParams $wingetAvailable
	if ($env:PROCESSOR_ARCHITECTURE -notlike 'ARM*') {
		if ($wingetCapableOs) {
			$caption = 'Installing PowerShellCore'
			$message = "You can install either the direct download version of PowerShellCore from Github`nor you can install the Store version."
			$choices = @(
				[System.Management.Automation.Host.ChoiceDescription]::new('&Github', 'download from Github')
				[System.Management.Automation.Host.ChoiceDescription]::new('&Store', 'install from MS Store')
			)
			$selection = $Host.UI.PromptForChoice($caption, $message, $choices, 0)
		} else {
			$selection = 1
		}
		if ($selection -eq 2) {
			WriteVerboseMessage -message 'x64: setting flag to install Store version of PowerShellCore'
			$installStoreVersion = $true
		} else {
			if ($wingetAvailable -and -not $noWingetForGithubDwnld) {
				WriteVerboseMessage -message 'x64: setting flag to install standalone version of PowerShellCore using winget'
				$installStandaloneWinget = $true
			} else {
				WriteVerboseMessage -message 'x64: setting flag to install standalone PowerShellCore by direct download (winget not available)'
				$installStandaloneDownload = $true
			}
		}
	} else {
		# currently have to install store version of posh core for ARM, so must have winget
		WriteVerboseMessage -message 'Arm64: setting flag to install Store version of PowerShellCore'
		$installStoreVersion = $true
	}
	# make sure we have what we need to install it:
	if (($installStoreVersion -or $installStandaloneWinget) -and -not $wingetAvailable) {
		#
		# TODO: if $wingetCapableOs, ask if we want to try installing latest winget;
		#   if so and after it's done, check again for winget; if still not good, show warning and return
		#
		Write-Warning "cannot install PowerShellCore using winget.exe as a suitable version is not available. Please ensure the latest version of 'App Installer' is installed from the Store, and then run the script again."
		return
	}
	# install it:
	if ($installStoreVersion) {
		WriteVerboseMessage -message 'installing Store version of PowerShellCore'
		InstallAppWithWinget -appId '9MZ1SNWT0N5D' -source 'msstore'
	} elseif ($installStandaloneWinget) {
		WriteVerboseMessage -message 'installing standalone PowerShellCore using winget'
		InstallAppWithWinget -appId 'Microsoft.PowerShell' -source 'winget' # TODO: -installerType 'msix'
	} elseif ($installStandaloneDownload) {
		WriteVerboseMessage -message 'downloading and installing standalone PowerShellCore from Github'
		DownloadAndInstallFromGithub -dontDeleteMsi:$dontDeleteMsi
	}
}

function InstallAppWithWinget {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $appId,
		[Parameter(Mandatory=$true)] [string] $source
	)
	$interactive = if ($source -ne 'msstore') { '--interactive' } else { '' }
	$exitCode = RunApplication -fileToRun 'winget.exe' -arguments "install --id $appId --exact --source $source $interactive --accept-package-agreements --accept-source-agreements"
	Write-Verbose "$($MyInvocation.InvocationName): exitCode from winget.exe =|$exitCode"
}

function DownloadAndInstallFromGithub {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[switch] $dontDeleteMsi
	)
	# call github api for latest release, from list of assets find one like '*-win-x64.msi', install it
	$resp = Invoke-RestMethod -Method Get -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest' -ErrorAction Stop
	$pattern = if ([System.Environment]::Is64BitOperatingSystem) { '*-win-x64.msi' } else { '*-win-x86.msi' }
	$downloadUrl = ($resp.assets | Where-Object { $_.name -like $pattern } | ForEach-Object { $_.browser_download_url })
	if (-not $downloadUrl) {
		Write-Warning "could not find a download url matching pattern '$pattern'; exiting install"
		return
	}
	Write-Host "found '$($resp.tag_name)' of PowerShellCore" -ForegroundColor DarkCyan
	Write-Host "from url $downloadUrl" -ForegroundColor DarkCyan
	Write-Host "see release page at $($resp.html_url)" -ForegroundColor DarkCyan
	# downloadUrl it and install
	if (-not (Test-Path -LiteralPath $env:Temp -PathType Container)) {
		WriteVerboseMessage -message 'creating temp folder |{0}|' -formatParams $env:Temp
		[void](New-Item -LiteralPath $env:Temp -ItemType Directory -Force)
	}
	$tempFilename = Join-Path $env:Temp (Split-Path -Path $downloadUrl -Leaf)
	if (-not $dontDeleteMsi -and (Test-Path -LiteralPath $tempFilename -PathType Leaf)) { Remove-Item -Path $tempFilename -Force }
	try {
		if (-not (Test-Path -LiteralPath $tempFilename -PathType Leaf)) {
			WriteVerboseMessage -message 'downloading |{0}| to file |{1}|' -formatParams $downloadUrl, $tempFilename
			if ($PSCmdlet.ShouldProcess($downloadUrl, 'Invoke-WebRequest')) {
				Invoke-WebRequest -Method Get -Uri $downloadUrl -OutFile $tempFilename
			}
		} else {
			WriteVerboseMessage -message 'using already downloaded msi installer |{0}|' -formatParams $tempFilename
		}

		WriteVerboseMessage -message 'starting msi installer |{0}|' -formatParams $tempFilename
		$exitCode = RunApplication -fileToRun 'msiexec.exe' -arguments "-i `"$tempFilename`""

		if ($exitCode -in @(1602, 2322) <# canceled #>) {
			Write-Host "PowerShell Core installation canceled" -ForegroundColor DarkYellow
		} elseif ($exitCode -ne 0) {
			Write-Warning "PowerShell Core installer exited with code $exitCode`n    maybe can decipher it here: https://learn.microsoft.com/en-us/windows/win32/msi/windows-installer-error-messages"
		} else {
			Write-Host
			Write-Host "PowerShell Core installation completed" -ForegroundColor DarkCyan
		}
	} finally {
		if (-not $dontDeleteMsi -and (Test-Path -LiteralPath $tempFilename -PathType Leaf)) { Remove-Item -Path $tempFilename -Force }
	}
}

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
	WriteVerboseMessage -message 'fileToRun=|{0}|, arguments=|{1}|, workingDirectory=|{2}|, asAdmin=|{3}|' -formatParams $fileToRun, $arguments, $workingDirectory, $asAdmin
	$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
	$startInfo.FileName = $fileToRun
	$startInfo.UseShellExecute = [bool]$useShellExecute
	if ($arguments) { $startInfo.Arguments = [Environment]::ExpandEnvironmentVariables($arguments) }
	if ($workingDirectory) { $startInfo.WorkingDirectory = $workingDirectory }
	$startInfo.Verb = if ($asAdmin) { 'runas' } else { 'open' }

	if ($PSCmdlet.ShouldProcess($arguments, (Split-Path $fileToRun -Leaf))) {
		try {
			$process = [System.Diagnostics.Process]::Start($startInfo)
			if ($process) {
				$process.WaitForExit()
				WriteVerboseMessage -message 'process exited; exit code = |{0}|' -formatParams $process.ExitCode
				return $process.ExitCode
			} else {
				WriteVerboseMessage -message '[Process]::Start() returned null for application |{0}|' -formatParams $fileToRun
				return -2
			}
		} catch {
			Write-Error "There was an exception running the application '$fileToRun': $($_.Exception.Message)"
			return -1
		}
	} else {
		return 0
	}
}

function CreateJunction {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $originalFolderPath,
		[Parameter(Mandatory=$true)] [string] $junctionPath
	)
	WriteVerboseMessage -message 'creating junction |{0}| -> |{1}|' -formatParams $junctionPath, $originalFolderPath
	[void](New-Item -ItemType Junction -Path $junctionPath -Value $originalFolderPath)
}

#==============================
Main -noWingetForGh:$noWingetForGithubDownload -keepGhMsi:$keepGithubMsi
#==============================