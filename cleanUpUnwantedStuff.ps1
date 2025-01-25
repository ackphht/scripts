#Requires -RunAsAdministrator
#Requires -Version 5.1
#Requires -Modules 'AckWare.AckLib'

[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $nonInteractive,
	[switch] $removeStoreApps,
	[switch] $onlyServices,
	[switch] $onlyScheduledTasks,
	[switch] $onlyDesktopIcons,
	[switch] $onlyStartMenu,
	[switch] $onlyAutoruns,
	[switch] $onlyBackground,
	[switch] $onlyEnvVars,
	[switch] $onlyFolders,
	[switch] $onlyMisc
)

Import-Module -Name $PSScriptRoot/ackPoshHelpers

Set-StrictMode -Off #-Version Latest	# helpers.ps1 above is turning it on, which i didn't think was supposed to happen ??
#[System.Environment]::CurrentDirectory = (Get-Location).Path

$script:regClassesRootPath = 'HKLM:\Software\Classes'
$script:regSysClassesRootPath = 'HKLM:\Software\Classes'
$script:regUserClassesRootPath = 'HKCU:\Software\Classes'
$script:regUserFileExtsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts'
$script:regDefaultPropName = '(Default)'
$script:regDefaultIconName = 'DefaultIcon'
$script:msgIndent = '   '

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	if ([System.Environment]::Is64BitOperatingSystem -and ![System.Environment]::Is64BitProcess) {
		Write-Error "You need to run this script in a 64 bit PowerShell console.";	# why ?
		return;
	}
	$all = $false
	if (!$onlyServices -and !$onlyScheduledTasks -and !$onlyDesktopIcons -and !$onlyStartMenu -and `
			!$onlyAutoruns -and !$onlyBackground -and !$onlyEnvVars -and !$onlyMisc -and !$onlyFolders) {
		$all = $true
	}

 	if ($all) {
		SetWindowsOptions
	}

	if ($all -and !$nonInteractive) {
		UninstallUnwantedApps
	}
	if ($all -and $removeStoreApps) {
		UninstallUnwantedStoreApps
	}
	if ($all -and [Environment]::OSVersion.Version.Major -lt 6 -and [Environment]::OSVersion.Version.Minor -lt 2) {
		# skip for Win8+
		CleanUpFlashUpdateFiles
	}
	if ($all) {
		CleanUpNvidiaFiles
		CleanUpOtherFiles
	}
	if ($all -or $onlyServices) {
		DisableUnwantedServices
	}
	if ($all -or $onlyScheduledTasks) {
		DisableUnwantedScheduledTasks
	}
	if ($all -or $onlyDesktopIcons) {
		CleanUpDesktopIcons
	}
	if ($all -or $onlyStartMenu) {
		CleanUpStartMenuItems
	}
	if ($all -or $onlyAutoruns) {
		CleanUpRegistryAutoruns
		CleanUpStartMenuAutoruns
	}
	if ($all -or $onlyBackground) {
		KillBackgroundProcesses
	}
	if ($all -or $onlyEnvVars) {
		CleanUpEnvVars
	}
	if ($all -or $onlyFolders) {
		CleanUpCrapFolders
	}
	if ($all -or $onlyMisc) {
		CleanUpRandomStuff
	}
}

function SetWindowsOptions {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	# disable prefixing 'Shortcut to' when creating shortcuts
	Set-RegistryEntry -registryPath 'HKCU:Software\Microsoft\Windows\CurrentVersion\Explorer' -valueName 'link' -valueData ([byte[]](0x00,0x00,0x00,0x00)) -valueType 'Binary'
	# disable saving zone information in downloads
	Set-RegistryEntry -registryPath 'HKCU:Software\Microsoft\Windows\CurrentVersion\Policies\Associations' -valueName 'DefaultFileTypeRisk' -valueData 0x1808 -valueType 'DWord'	# 0x1808 = "Low Risk"; 0x1807 = "Moderate", 0x1806 = "High Risk"
	Set-RegistryEntry -registryPath 'HKCU:Software\Microsoft\Windows\CurrentVersion\Policies\Attachments' -valueName 'SaveZoneInformation' -valueData 1 -valueType 'DWord'			# 1 = "Do not preserve zone information", 2 = "Do preserve zone information"
}

function UninstallUnwantedApps {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'uninstalling unwanted apps'
	$appsList = $null
	@(
		"Microsoft Advertising *"	# got installed by older Visual Studios
		"NVIDIA PhysX System Software *"
		"NVIDIA PhysX"
		"NVIDIA Update *"
		"NVIDIA GeForce Experience *"
		"NVIDIA 3D Vision Driver *"
		"NVIDIA nView*"
		"NVIDIA Stereoscopic 3D *"
		"NVIDIA FrameView SDK *"
		"Logi Bolt"
		<#
		"NVIDIA Network Service"
		"NVIDIA Optimus Update *"
		"NVIDIA Update Core"
		"NVIDIA Install Application"
		"NVIDIA HD Audio *"					# keep this last because it thinks it needs a restart, and the other nVidia crap won't run because now a restart is needed
		#>
	) | ForEach-Object { $appsList = UninstallApp -displayName $_ -cachedInstalledApps $appsList }
}

function UninstallUnwantedStoreApps {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'uninstalling unwanted store apps'
	@(
		#'Facebook.Facebook'
		#'9E2F88E3.Twitter'
		#'PandoraMediaInc.29680B314EFC2'
		'king.com.CandyCrushSodaSaga'
		'A278AB0D.MarchofEmpires'
		'flaregamesGmbH.RoyalRevolt2'
		'KeeperSecurityInc.Keeper'
		'SlingTVLLC.SlingTV'
		'D5EA27B7.Duolingo-LearnLanguagesforFree'
		'AdobeSystemsIncorporated.AdobePhotoshopExpress'
		'46928bounde.EclipseManager'
		'ActiproSoftwareLLC.562882FEEB491'
		'Microsoft.MinecraftUWP'
		'Microsoft.MicrosoftOfficeHub'							# 'Get Office'
		'Microsoft.MicrosoftSolitaireCollection'
		'Microsoft.OneConnect'									# 'Paid WiFi and Cellular'
		'Microsoft.3DBuilder'
		'Microsoft.XboxApp'
		'Microsoft.Xbox.TCUI'
		#'Microsoft.XboxGameCallableUI'						# can't uninstall this one, but maybe someday...
		'Microsoft.XboxSpeechToTextOverlay'
		'Microsoft.XboxGameOverlay'
		'Microsoft.XboxGamingOverlay'
		'Microsoft.XboxIdentityProvider'
		<#
		'Xxxxx'
		#>
	) |
		ForEach-Object {
			WriteVerboseMessage 'check for store app "{0}"' $_
			$a = Get-AppxPackage -Name $_
			if ($a) {
				WriteStatusMessage "uninstalling store app '$_'"
				Remove-AppxPackage -Package $a -WhatIf:$WhatIfPreference <#-Confirm:$ConfirmPreference#>
			}
		}
}

function CleanUpFlashUpdateFiles {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up Adobe Flash files'
	@(
		# 64 bit exe's in System32 for 64 bit OS
		"C:\Windows\System32\Macromed\Flash\FlashUtil64_*_Plugin.exe"
		"C:\Windows\System32\Macromed\Flash\FlashUtil64_*_ActiveX.exe"
		"C:\Windows\System32\Macromed\Flash\FlashUtil_ActiveX*.exe"		# on Win8+, protected file; can't do anything to it
		# 32 bit exe's in SysWOW64 for 64 bit OS
		"C:\Windows\SysWOW64\Macromed\Flash\FlashPlayerPlugin_*.exe"
		"C:\Windows\SysWOW64\Macromed\Flash\FlashPlayerUpdateService*.exe"
		"C:\Windows\SysWOW64\Macromed\Flash\FlashUtil32_*_ActiveX.exe"
		"C:\Windows\SysWOW64\Macromed\Flash\FlashUtil32_*_Plugin.exe"
		"C:\Windows\SysWOW64\Macromed\Flash\FlashUtil_ActiveX*.exe"		# on Win8+, protected file; can't do anything to it
		# 32 bit exe's in System32 for 32 bit OS
		"C:\Windows\System32\Macromed\Flash\FlashPlayerPlugin_*.exe"
		"C:\Windows\System32\Macromed\Flash\FlashPlayerUpdateService*.exe"
		"C:\Windows\System32\Macromed\Flash\FlashUtil32_*_ActiveX.exe"
		"C:\Windows\System32\Macromed\Flash\FlashUtil32_*_Plugin.exe"
	) |	ForEach-Object { RenameUnwantedFiles $_; }
}

function CleanUpNvidiaFiles {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up extra nVidia files'

	#
	# TODO: these might be running; we should try to kill them first
	#

	@(
		<#"C:\Program Files\NVIDIA Corporation\Display\nvxdsync.exe",#>		# renaming this one causes a long hang every time i right click on the desktop; thanks nVidia!
		"C:\Program Files (x86)\NVIDIA Corporation\Update Core\NvBackend.exe"
	) |	ForEach-Object { RenameUnwantedFiles $_; }
}

function CleanUpOtherFiles {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up various files'
	@(
		"$env:LocalAppData\GitHubDesktop\Update.exe"
		"$env:LocalAppData\GitKraken\Update.exe"
		"$env:LocalAppData\Postman\Update.exe"
		"$env:LocalAppData\SourceTree\Update.exe"
	) |	ForEach-Object { RenameUnwantedFiles $_; }
}

function CleanUpCrapFolders {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up junk folders'
	@(
		"$env:UserProfile\.DVDFab64"

		"$env:UserProfile\Documents\Audacity"
		"$env:UserProfile\Documents\CyberLink"
		"$env:UserProfile\Documents\Dell"
		"$env:UserProfile\Documents\Diablo II"
		"$env:UserProfile\Documents\DVDFab*"
		"$env:UserProfile\Documents\Frostwire"
		"$env:UserProfile\Documents\HeidiSQL"	# db ide, supposed to be portable, but...
		"$env:UserProfile\Documents\LiveUpdate"
		"$env:UserProfile\Documents\My Web Sites"
		"$env:UserProfile\Documents\SQL Server Management Studio"
		"$env:UserProfile\Documents\Visual Studio 2017"
		"$env:UserProfile\Documents\Visual Studio 2019"
		#"$env:UserProfile\Documents\Visual Studio 20*"
		"$env:UserProfile\Documents\Zoom"

		"$env:UserProfile\Downloads\Remote Desktop"
		"$env:UserProfile\Downloads\Microsoft.RemoteDesktop_8wekyb3d8bbwe!App"	# uses desktop.ini to make name appear as above

		"$env:UserProfile\Pictures\PowerDVD 12"
		"$env:UserProfile\Pictures\MPC-HC Capture"

		"$env:UserProfile\Videos\UltraViolet"
	) |	ForEach-Object {
		if (Test-Path -Path $_ -PathType Container) {
			WriteStatusMessage "removing folder `"$_`""
			Remove-Item -Path $_ -Force -Recurse
		}
	}
}

function CleanUpDesktopIcons {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up desktop icons'
	@(
		'IDrive'
		'iSpy*'
		'FrostWire*'
		'SourceTree'
		'Stellarium'
		'Microsoft Edge'
		'McAfee*'
		'HandBrake'
		'SQL Operations Studio'
		'Azure Data Studio'
		'Vivaldi'
		'VeraCrypt'
		'Kindle'
		'Postman'
		'Brave'
		'ConEmu*'
		'Zoom'
		'Free Download Manager'
		'Configure FileMenu Tools'
		'foobar2000'
		'AIMP'
		'Audacity'
		'Mp3tag'
		'Sigil'
		'JetBrains*'
		'MPC-HC*'
		'Docker Desktop'
		'GitHub Desktop'
		'Lens'
		'VLC *'
		'SumatraPDF'
		'Kleopatra'
		'Steam'
		'Inkscape'
		'DVDFab*'
		'Kobo*'
		'Logi Options+'
		'Quick Share from Google'
		'Exact Audio Copy'
		'Dashboard'					# WD Dashboard
	) |	ForEach-Object { RemoveDesktopIcon $_ }
}

function RemoveDesktopIcon {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)] [string]$iconName
	)
	$maybeFiles = "$env:UserProfile\Desktop\$iconName.lnk"
	if (Test-Path $maybeFiles) {
		Get-ChildItem $maybeFiles |
			ForEach-Object {
				$filename = $_.FullName
				WriteStatusMessage "removing |$($_.Name)| from user's Desktop folder"
				Remove-Item -LiteralPath $filename -Force -WhatIf:$WhatIfPreference -ErrorAction Stop
			}
	}
	$maybeFiles = "$env:Public\Desktop\$iconName.lnk"
	if (Test-Path $maybeFiles) {
		Get-ChildItem $maybeFiles |
			ForEach-Object {
				$filename = $_.FullName
				WriteStatusMessage "removing |$($_.Name)| from Public Desktop folder"
				Remove-Item -LiteralPath $filename -Force -WhatIf:$WhatIfPreference -ErrorAction Stop
			}
	}
}

function DisableUnwantedServices {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up unwanted services'
	@(
		@{ Name = 'AdobeFlashPlayerUpdateSvc'; Start = ''; }
		@{ Name = 'AdobeARMservice'; Start = ''; }					# Adobe Acrobat Update Service
		@{ Name = 'AMD External Events Utility'; Start = ''; }
		@{ Name = 'FoxitCloudUpdateService'; Start = ''; }
		@{ Name = 'NvNetworkService'; Start = ''; }
		#@{ Name = 'gupdate'; Start = ''; }							# "Google Update Service (gupdate)",	# this one is set to "Automatic (Delayed Start)" when Chrome is installed for all users; probably does the check at system startup and then shuts down ???
		#@{ Name = 'gupdatem'; Start = ''; }						# "Google Update Service (gupdatem)",	# when Chrome is installed for all users, this one is started manually, think it's the one run to do a manual upgrade (like from Chrome itself) ???
		@{ Name = 'Intel(R) Capability Licensing Service TCP IP Interface'; Start = ''; }
		@{ Name = 'Intel(R) Content Protection HECI Service'; Start = ''; }
		@{ Name = 'Intel(R) Content Protection HDCP Service'; Start = ''; }
		@{ Name = 'Intel(R) Dynamic Application Loader Host Interface Service'; Start = ''; }
		@{ Name = 'Intel(R) Dynamic Platform and Thermal Framework Processor Participant Service Application'; Start = ''; }
		@{ Name = 'Intel(R) Dynamic Platform and Thermal Framework Critical Service Application'; Start = ''; }
		@{ Name = 'Intel(R) Dynamic Platform and Thermal Framework Low Power Mode Service Application'; Start = ''; }
		@{ Name = 'Intel(R) Dynamic Platform and Thermal Framework service'; Start = ''; }
		@{ Name = 'Intel(R) Dynamic Tuning service'; Start = ''; }
		@{ Name = 'Intel(R) PROSet/Wireless Event Log'; Start = ''; }
		@{ Name = 'Intel(R) PROSet/Wireless Registry Service'; Start = ''; }
		@{ Name = 'Intel(R) PROSet/Wireless Zero Configuration Service'; Start = ''; }
		@{ Name = 'Intel(R) Rapid Storage Technology'; Start = ''; }
		@{ Name = 'Intel(R) Storage Middleware Service'; Start = ''; }
		@{ Name = 'Intel® SGX AESM'; Start = 'Manual'; }
		@{ Name = 'Intel(R) Smart Connect Technology Agent'; Start = ''; }						# "Refreshes online content while system is asleep"
		@{ Name = 'Intel(R) Management and Security Application Local Management Service'; Start = ''; }
		@{ Name = 'Intel(R) HD Graphics Control Panel Service*'; Start = ''; }
		@{ Name = 'Intel(R) Graphics Command Center Service*'; Start = ''; }
		@{ Name = 'Intel(R) System Usage Report Service*'; Start = ''; }
		@{ Name = 'NvTelemetryContainer'; Start = ''; }				# "Container service for NVIDIA Telemetry",
		@{ Name = 'Killer Network Service'; Start = ''; }
		@{ Name = 'Killer Analytics Service'; Start = ''; }
		@{ Name = 'Killer Dynamic Bandwidth Management'; Start = ''; }
		@{ Name = 'Killer Smart AP Selection Service'; Start = 'Manual'<# ??? #>; }
		@{ Name = 'Killer Provider Data Helper Service'; Start = ''; }
		@{ Name = 'QcomWlanSrv'; Start = 'Manual'; }				# "Qualcomm Atheros WLAN Driver Service"
		@{ Name = 'Dell Hardware Support'; Start = 'Manual'; }
		@{ Name = 'Dell SupportAssist*'; Start = 'Manual'; }
		@{ Name = 'Dell Optimizer'; Start = 'Manual'; }
		@{ Name = 'Dell Digital Delivery Services'; Start = 'Manual'; }
		@{ Name = 'Dell TechHub'; Start = 'Manual'; }
		@{ Name = 'Docker Desktop Service'; Start = 'Manual'; }
		@{ Name = 'Realtek Audio Universal Service'; Start = ''; }
		@{ Name = 'Waves Audio Services'; Start = ''; }
		@{ Name = 'Waves Audio Universal Services'; Start = ''; }
		@{ Name = 'Microsoft Edge Update Service (edgeupdate)'; Start = 'Manual'; }
		@{ Name = 'Microsoft Edge Update Service (edgeupdatem)'; Start = 'Manual'; }
		@{ Name = 'SyncBackPro Schedules Monitor'; Start = 'Manual'; }
		#@{ Name = 'OptionsPlusUpdaterService'; Start = 'Manual'; }		# Logitech Options+ Updater; nevermind, apparently needed
		#@{ Name = 'xxxxxxxxxxxxxxxx'; Start = ''; }
	) | ForEach-Object { DisableService $_; }
}

function DisableService {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		#[Parameter(Mandatory=$true)] [string]$serviceName
		[Parameter(Mandatory=$true)] [PSObject]$service
	)
	WriteVerboseMessage 'checking for serviceName = |{0}| / desired StartMode = |{1}|' $service.Name,$service.Start
	$desiredStartMode = if ($service.Start) { $service.Start } else { 'Disabled' }
	$services = @(Get-Service -Name $service.Name -ErrorAction Ignore)
	if (-not $services) {
		$services = @(Get-Service -DisplayName $service.Name -ErrorAction Ignore)
	}
	#if ($services -ne $null -and $services.Count -gt 0) {
	if ($services) {
		WriteSubHeaderMessage "found $($services.Count) services to disable for param |$($service.Name)|"
		$services |
			ForEach-Object {
				## why the heck am i using WMI for this??
				#$wmiService = Get-WmiObject -Query "SELECT * FROM Win32_Service WHERE Name='$($_.ServiceName)'";
				#if ($wmiService -eq $null) { Write-Warning "${script:msgIndent}could not find WMI object for service |$_.DisplayName|; will try to disable anyway"; }
				#if (($wmiService -eq $null -or $wmiService.StartMode -ne $desiredStartMode) -or $_.Status -ne "Stopped") {
				if ($_.StartType -ne $desiredStartMode -or $_.Status -ne 'Stopped') {
					# can stop service and disable it at same time with Set-Service, but doesn't work right for some services, so we'll do it in two steps
					WriteStatusMessage "${script:msgIndent}stopping service |$($_.DisplayName)|"
					Stop-Service -Name $_.Name -WhatIf:$WhatIfPreference
					WriteStatusMessage "${script:msgIndent}setting service |$($_.DisplayName)| to '$desiredStartMode'"
					Set-Service -InputObject $_ -StartupType $desiredStartMode -WhatIf:$WhatIfPreference
				} else {
					WriteStatusMessageLow "${script:msgIndent}service |$($_.DisplayName)| already disabled; skipping..."
				}
			}
	} else {
		WriteStatusMessageLow "no services found for |$($service.Name)|"
	}
}

function DisableUnwantedScheduledTasks {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up unwanted scheduled tasks'
	$allTasks = @(Get-ScheduledTask)
	@(
		@{ Name = 'User_Feed_Synchronization*'; Path='\'; }
		@{ Name = 'Adobe Flash Player Updater'; Path=''; }
		#@{ Name = 'GoogleUpdateTask*'; Path=''; }
		@{ Name = 'FreeDownloadManager*'; Path=''; }
		@{ Name = 'Intel *'; Path=''; }
		@{ Name = 'Dell SupportAssistAgent AutoUpdate'; Path=''; }
		@{ Name = 'PDVDServ12 Task'; Path='\'; }		# CyberLink PowerDVD
		@{ Name = 'NVProfileUpdater*'; Path=''; }
		@{ Name = 'NVTmMon*'; Path=''; }
		@{ Name = 'NVTmRep*'; Path=''; }
		@{ Name = 'VSIX Auto Update*'; Path='\Microsoft\VisualStudio\'; }
		@{ Name = 'BackgroundDownload*'; Path='\Microsoft\VisualStudio\Updates\'; }
		@{ Name = 'UpdateConfiguration_*'; Path='\Microsoft\VisualStudio\Updates\'; }
		@{ Name = 'XblGameSaveTask'; Path='\Microsoft\XblGameSave\'; }
		@{ Name = 'MicrosoftEdgeUpdateTask*'; Path=''; }
		@{ Name = 'VivaldiUpdateCheck*'; Path=''; }
		@{ Name = 'Firefox Default Browser Agent *'; Path='\Mozilla\'; }
		@{ Name = 'G2MUp*'; Path='\'; }							# GoToMeeting
		@{ Name = 'DashboardNotificationManager*'; Path='\'; }	# WD Dashboard
		@{ Name = 'RNIdle*'; Path='\'; }						# Killer network something
		@{ Name = 'IntelSURQC*'; Path='\'; }					# Intel driver update thing (there was another one with some random looking name that i deleted before remembering to put it in here)
		@{ Name = 'Dell SupportAssistAgent AutoUpdate'; Path='\'; }
	) | ForEach-Object { DisableScheduledTask -allSchedTasks $allTasks -taskName $_.Name -taskPath $_.Path }
}

function DisableScheduledTask {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)] [Microsoft.Management.Infrastructure.CimInstance[]] $allSchedTasks,
		[Parameter(Mandatory=$true)] [string] $taskName,
		[Parameter(Mandatory=$false)] [string] $taskPath
	)
	WriteVerboseMessage 'checking for task = |{0}|' $taskName
	if ($taskPath) {
		$tasks = $allSchedTasks | Where-Object { $_.TaskName -like $taskName -and $_.TaskPath -eq $taskPath }
	} else {
		$tasks = $allSchedTasks | Where-Object { $_.TaskName -like $taskName }
	}
	if ($tasks -ne $null -and $tasks.Count -gt 0) {
		WriteSubHeaderMessage "found $($tasks.Count) scheduled tasks for |${taskPath}${taskName}|"
		$tasks |
			ForEach-Object {
				if ($_.Settings.Enabled) {
					# Disable-ScheduleTask does not have a -WhatIf
					if ($PSCmdlet.ShouldProcess($_.TaskName, "Disable-ScheduledTask")) {
						WriteStatusMessage "${script:msgIndent}disabling scheduled task |$($_.URI)|"
						[void] (Disable-ScheduledTask -InputObject $_)
					}
				} else {
					WriteStatusMessageLow "${script:msgIndent}scheduled task |$($_.URI)| already disabled; skipping..."
				}
			}
	} else {
		WriteStatusMessageLow "no scheduled tasks found for |${taskPath}${taskName}|"
	}
}

function CleanUpRegistryAutoruns {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up unwanted registry Autoruns'
	$autorunsToLookFor = @(
		@{ Name = 'Adobe ARM'; Value = '' }
		@{ Name = 'SunJavaUpdateSched'; Value = '' }
		@{ Name = 'Google Update'; Value = '' }
		@{ Name = 'Logitech Download Assistant'; Value = '' }
		@{ Name = 'Zune Launcher'; Value = '' }
		@{ Name = 'MySQL Notifier'; Value = '' }
		@{ Name = 'ConnectionCenter'; Value = '' }				# Citrix
		@{ Name = 'Redirector'; Value = '' }					# Citrix
		@{ Name = 'DptfPolicyLpmServiceHelper'; Value = '' }	# Intel(R) Dynamic Platform and Thermal Framework LPM Policy Service Helper
		@{ Name = 'SPEnroll'; Value = '' }						# Quest Software, Inc. (some password reset stupid thing at work)
		@{ Name = 'Vivaldi Update Notifier'; Value = '' }
		@{ Name = 'Microsoft Edge'; Value = '' }
		@{ Name = 'IAStorIcon'; Value = '' }
		@{ Name = 'Free Download Manager'; Value = '' }
		@{ Name = 'RtkAudUService'; Value = '' }				# Realtek HD Audio Universal Service
		@{ Name = 'WavesSvc'; Value = '' }						# Waves MaxxAudio Service Application
		@{ Name = 'IDrive Background process'; Value = '' }
		#@{ Name = 'IDrive Tray'; Value = '' }
		@{ Name = 'Docker Desktop'; Value = '' }
		@{ Name = 'KeePass 2 PreLoad'; Value = '' }
		@{ Name = ''; Value = '*\DVDFab\*\LiveUpdate.exe*'; FriendlyName = 'DVDFab LiveUpdate' }	# uses a random name, grrrrr
	);
	$placesToCheck = @(
		'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
		'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
		'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
		'HKCU:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Run'
	);
	foreach ($app in $autorunsToLookFor) {
		foreach ($location in $placesToCheck) {
			WriteVerboseMessage 'looking for Autorun |{0}| in |{1}|' @($(if ($app.Name) { $app.Name } else { $app.Value }),$location)
			if ($app.Name) {
				if ((Get-RegistryKeyValue -registryPath $location -valueName $app.Name)) {
					DisableRegistryAutorun -regPath $location -valueName $app.Name -friendlyName $app.Name
				}
			} elseif ($app.Value) {
				foreach ($regVal in Get-RegistryKeyValues -registryPath $location) {
					if ($regVal.Data -like $app.Value) {
						DisableRegistryAutorun -regPath $location -valueName $regVal.Value -friendlyName $(if ($app.FriendlyName) { $app.FriendlyName } else { $regVal.Value })
						break
					}
				}
			}
		}
	}
}

function DisableRegistryAutorun {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)] [string] $regPath,
		[Parameter(Mandatory=$true)] [string] $valueName,
		[Parameter(Mandatory=$true)] [string] $friendlyName
	)
	WriteStatusMessage "disabling Autorun |$friendlyName| from |$regPath|"
	$disabledLocation = Join-Path $regPath 'AutorunsDisabled'
	# make sure disabled key exists
	Confirm-RegistryKeyExists -registryPath $disabledLocation
	# if already exists in disabled key, remove it
	if (Test-RegistryKeyValue -registryPath $disabledLocation -valueName $valueName) {
		WriteVerboseMessage 'removing existing disabled entry |{0}| from |{1}|' $valueName,$disabledLocation
		Remove-RegistryKeyValue -registryPath $disabledLocation -valueName $valueName
	}
	# now move to disabled folder
	WriteVerboseMessage 'moving entry |{0}| to |{1}|' $valueName,$disabledLocation
	Move-RegistryKeyValue -registryPath $regPath -newRegistryPath $disabledLocation -valueName $valueName
}

function CleanUpStartMenuAutoruns {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up unwanted StartMenu Autoruns'
	$autorunsToLookFor = @(
		'Send to OneNote'
	);
	$placesToCheck = @(
		[Environment]::GetFolderPath([Environment+SpecialFolder]::Startup),
		[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartup)
	);
	foreach ($app in $autorunsToLookFor) {
		$filename = "$app.lnk";
		foreach ($location in $placesToCheck) {
			WriteVerboseMessage 'looking for Autorun |{0}| in |{1}|' $app,$location
			$filepath = Join-Path $location $filename;
			if (Test-Path $filepath) {
				WriteStatusMessage "disabling Autorun |$app| from |$location|"
				$disabledLocation = Join-Path $location 'AutorunsDisabled';
				$disabledFilepath = Join-Path $disabledLocation $filename;
				# make sure disabled folder exists
				if (!(Test-Path $disabledLocation)) {
					WriteVerboseMessage 'creating folder location |{0}|' $disabledLocation
					[void] (New-Item -Path $disabledLocation -ItemType Directory -WhatIf:$WhatIfPreference);
					# make it hidden to match what Sysinternals Autoruns does (???)
					$temp = Get-Item -Path $disabledLocation -ErrorAction Ignore;
					if ($temp) {
						$temp.Attributes = $temp.Attributes -bor [System.IO.FileAttributes]::Hidden; # 'Hidden';
					}
				}
				# if already exists in disabled folder, remove it
				if (Test-Path $disabledFilepath) {
					WriteVerboseMessage 'removing existing disabled entry |{0}| from |{1}|' $app,$disabledLocation
					Remove-Item -Path $disabledFilepath -WhatIf:$WhatIfPreference;
				}
				# now move to disabled folder
				WriteVerboseMessage 'moving entry |{0}| to |{1}|' $app,$disabledLocation
				Move-Item -Path $filepath -Destination $disabledFilepath -WhatIf:$WhatIfPreference;
			}
		}
	}
}

function CleanUpStartMenuItems {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'cleaning up StartMenu entries'
	$applications = 'Applications'
	$development = 'Development'
	#$systemApps = 'Maintenance'	# shown in Explorer as 'System'
	$systemApps = 'System'
	$winAccessories = 'Accessories'
	@(
		# moves:
		[StartMenuCleanupItem]::FromCommonPrograms('Access.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Audacity.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Excel.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonStartMenu('Docker Desktop.lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Cloud Nine Keyboard Application.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('Dashboard.lnk', $systemApps)	# WD app
		[StartMenuCleanupItem]::FromCommonPrograms('Everything.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Firefox.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('foobar2000.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('GIMP*.lnk', $applications, 'GIMP.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('Git Extensions.lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Google Chrome.lnk', $applications, 'Google Chrome.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('Google Drive.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('GPA.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Intel Driver & Support Assistant.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('KeePass 2.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Kleopatra.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Logi Plugin Service.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Edge.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Edge Beta.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Mouse and Keyboard Center.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('Notepad++.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Notepad3.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('OneDrive for Business.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('OneNote.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('OneNote 2016.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Orca.lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Outlook.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('paint.net.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('PerfectDisk.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('PowerPoint.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Private Internet Access.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Publisher.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Skype for Business.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Sticky Notes*.lnk', $winAccessories)
		[StartMenuCleanupItem]::FromCommonStartMenu('SumatraPDF.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('SumatraPDF.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('SyncBackSE.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('SyncBackPro.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('SyncBackPro (Not Elevated).lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('SyncBackPro.NE.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('TeamViewer*.lnk', 'Work')
		[StartMenuCleanupItem]::FromCommonStartMenu('TeraCopy.lnk')							# think this was a bug, but if it shows up, delete it
		[StartMenuCleanupItem]::FromCommonPrograms('TeraCopy.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Waves MaxxAudioPro.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('Windows Media Player.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Windows Sandbox.lnk', $winAccessories)
		[StartMenuCleanupItem]::FromCommonPrograms('Wireshark.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Word.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('WSL Settings.lnk', $winAccessories)
		[StartMenuCleanupItem]::FromCommonPrograms('WSL.lnk', $winAccessories)
		[StartMenuCleanupItem]::FromCommonPrograms('2BrightSparks\SyncBackSE x64\SyncBackSE.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('7-Zip\7-Zip File Manager.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('AIMP\AIMP.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Attribute Changer\Attribute Changer.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Audacity\Audacity.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('AudioShell\AudioShell Settings.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('AutoHotkey\AutoHotkey Help File.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('AutoHotkey\AutoHotkey.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Battle.net\Battle.net.lnk', 'Games', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('C989M Application Software\C989M Application Software.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('calibre 64bit - E-book Management\E-book viewer 64bit.lnk', $applications, 'calibre E-book viewer.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('calibre 64bit - E-book Management\calibre 64bit - E-book management.lnk', $applications, 'calibre.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('ConEmu\ConEmu (x64).lnk', $applications, 'ConEmu.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Dell\Dell Display Manager\Dell Display Manager*.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Dell\*.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('DVDFab 12 (x64)\DVDFab 12 (x64).lnk', $applications, 'DVDFab.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('DVDFab 13 (x64)\DVDFab 13 (x64).lnk', $applications, 'DVDFab.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Exact Audio Copy\Exact Audio Copy.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('FileMenu Tools\Configure FileMenu Tools.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('FileZilla FTP Client\FileZilla.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Free Download Manager\Free Download Manager.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Git\Git Bash.lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Git\Git CMD (Deprecated).lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Git\Git GUI.lnk', $development, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('GitAhead\GitAhead.lnk', $development, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('GnuCash\GnuCash.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('HandBrake\HandBrake.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('IDrive\IDrive.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('ImageMagick\ImageMagick Display.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('ImHex\ImHex.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Intel\Intel(R) Rapid Storage Technology.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('JetBrains\JetBrains DataGrip*.lnk', $development, 'DataGrip.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('JetBrains\JetBrains PyCharm*.lnk', $development, 'PyCharm.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Kobo\Kobo.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('KMyMoney\KMyMoney.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Logi\Logi Options+.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('Logitech\Logitech Capture.lnk', $systemApps)
		[StartMenuCleanupItem]::FromCommonPrograms('Logitech\Logitech Options.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Logi Firmware Update Tool\BRIO.lnk', $systemApps, 'Logitech BRIO Firmware Update.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Logitech Camera Settings\Logitech Camera Settings.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 5 (AnyCPU).lnk', $development, 'LINQPad 5.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 6 (x86).lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 6 (x64).lnk', $development, 'LINQPad 6.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 7 (x86).lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 7 (x64).lnk', $development, 'LINQPad 7.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 8 (x86).lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('LINQPad\LINQPad 8 (x64).lnk', $development, 'LINQPad 8.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('McAfee\McAfee® AntiVirus Plus.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('MediaMonkey\MediaMonkey.lnk', $applications, 'MediaMonkey [skinned].lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Azure Storage Explorer\Microsoft Azure Storage Explorer.lnk', $development, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Money Plus\Money Plus.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Mouse and Keyboard Center\Microsoft Mouse and Keyboard Center.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('MKVToolNix\MKVToolNix GUI.lnk', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('MKVToolNix\MKVToolNix.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Mp3tag\Mp3tag.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('MPC-HC\MPC-HC.lnk', $applications, 'MPC-HC.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('MPC-HC x64\MPC-HC x64.lnk', $applications, 'MPC-HC.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Node.js\Node.js command prompt.lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Node.js\Node.js.lnk', $development, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('NVIDIA Corporation\nView Desktop Manager.lnk', $systemApps, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Oracle VirtualBox\Oracle VirtualBox.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Plex\Plex.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('PostgreSQL 13\pgAdmin 4.lnk', $development, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('PowerShell\PowerShell 6*.lnk', $development, 'PowerShell 6.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('PowerToys (Preview)\PowerToys (Preview).lnk', $applications, 'PowerToys.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Sigil\Sigil.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Steam\*.url', 'Games')		# steam uses a protocol handler ('steam://') to launch its games
		[StartMenuCleanupItem]::FromCommonPrograms('Steam\*.lnk', 'Games', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Stellarium\Stellarium.lnk', $applications, $true)
		#[StartMenuCleanupItem]::FromCommonPrograms('TortoiseGit\TortoiseGit.lnk', $development, $false)
		#[StartMenuCleanupItem]::FromCommonPrograms('TortoiseGit\TortoiseGitBlame.lnk', $development, $false)
		#[StartMenuCleanupItem]::FromCommonPrograms('TortoiseGit\TortoiseGitIDiff.lnk', $development, $false)
		#[StartMenuCleanupItem]::FromCommonPrograms('TortoiseGit\TortoiseGitMerge.lnk', $development, $false)
		[StartMenuCleanupItem]::FromCommonPrograms('TortoiseGit\Help.lnk', $development, 'TortoiseGitHelp.lnk', $false)
		[StartMenuCleanupItem]::FromCommonPrograms('TortoiseGit\Settings.lnk', $development, 'TortoiseGitSettings.lnk', $true)
		[StartMenuCleanupItem]::FromCommonPrograms('VideoLAN\VLC media player.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio Code\Visual Studio Code.lnk', $development, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('VeraCrypt\VeraCrypt.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('WinRAR\WinRAR.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('WinMerge\WinMerge.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromCommonPrograms('Zoom\Zoom.lnk', $applications, $true)
		# first move VS links to their own folders; then below we'll move those folders to Development:
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio Installer.lnk', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio 2019.lnk', 'Visual Studio 2019')
		[StartMenuCleanupItem]::FromCommonPrograms('Blend for Visual Studio 2019.lnk', 'Visual Studio 2019')
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio 2022 Current.lnk', 'Visual Studio 2022', 'Visual Studio 2022.lnk')	# think this name and next one were bugs...
		[StartMenuCleanupItem]::FromCommonPrograms('Blend for Visual Studio 2022 Current.lnk', 'Visual Studio 2022', 'Blend for Visual Studio 2022.lnk')
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio 2022.lnk', 'Visual Studio 2022')
		[StartMenuCleanupItem]::FromCommonPrograms('Blend for Visual Studio 2022.lnk', 'Visual Studio 2022')

		[StartMenuCleanupItem]::FromCommonPrograms('Amazon Web Services', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Azure', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Office Tools', $applications)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server 2017', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server 2019', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server 2022', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server Tools 17', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server Tools 18', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server Tools 19', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft SQL Server Tools 20', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('PostSharp*', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Python 2.7', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Python 3.*', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('TortoiseSVN', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio 2017', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio 2019', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Visual Studio 2022', $development)
		[StartMenuCleanupItem]::FromCommonPrograms('Windows Kits', $development)

		[StartMenuCleanupItem]::FromCommonPrograms('ForeScout SecureConnector', 'Work')
		[StartMenuCleanupItem]::FromCommonPrograms('FortiClient', 'Work')
		[StartMenuCleanupItem]::FromCommonPrograms('IncrediBuild', 'Work')
		[StartMenuCleanupItem]::FromCommonPrograms('Microsoft Intune Management Extension', 'Work')
		[StartMenuCleanupItem]::FromCommonPrograms('Symantec Endpoint Protection', 'Work')

		[StartMenuCleanupItem]::FromUserStartMenu('Dashboard.lnk', $systemApps, 'WD Dashboard.lnk')
		[StartMenuCleanupItem]::FromUserStartMenu('Notepad2-mod.lnk', $applications)
		[StartMenuCleanupItem]::FromUserStartMenu('Notepad3.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('AutoHotkey Window Spy.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('AutoHotkey.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('AutoHotkey Dash.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Cloud Nine Keyboard Application.lnk', $systemApps)
		[StartMenuCleanupItem]::FromUserPrograms('Fiddler 4.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Fiddler Classic.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Fiddler ScriptEditor.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Firefox.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Firefox Private Browsing.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('GIMP*.lnk', $applications, 'GIMP.lnk')
		[StartMenuCleanupItem]::FromUserPrograms('ILSpy.lnk', $development)
		[StartMenuCleanupItem]::FromUserPrograms('Lens.lnk', $development)
		[StartMenuCleanupItem]::FromUserPrograms('MaxxAudio Pro by Waves*.lnk', $systemApps)
		[StartMenuCleanupItem]::FromUserPrograms('Microsoft Teams.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Nearby Share from Google.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('NSIS.lnk', $development)
		[StartMenuCleanupItem]::FromUserPrograms('Outlook.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Quick Share from Google.lnk', $applications)
		[StartMenuCleanupItem]::FromUserStartMenu('SumatraPDF.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('SumatraPDF.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('SyncBackSE.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('SyncBackPro.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('SyncBackPro (Not Elevated).lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('SyncBackPro.NE.lnk', $applications, 'SyncBackPro (Not Elevated).lnk')
		[StartMenuCleanupItem]::FromUserPrograms('Vivaldi.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Amazon\Amazon Kindle\Kindle.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Atlassian\Sourcetree.lnk', $development, $true)
		[StartMenuCleanupItem]::FromUserPrograms('AutoHotkey\AutoHotkey Window Spy.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('AutoHotkey\AutoHotkey.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Azure Data Studio\Azure Data Studio.lnk', $development, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Bing Wallpaper\Bing Wallpaper.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('C989M Application Software\C989M Application Software.lnk', $systemApps, $true)
		#[StartMenuCleanupItem]::FromUserPrograms('DVDFab 11\DVDFab 11.lnk', $applications, 'DVDFab.lnk', $true)
		#[StartMenuCleanupItem]::FromUserPrograms('DVDFab 11 (x64)\DVDFab 11 (x64).lnk', $applications, 'DVDFab.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('DVDFab 12 (x64)\DVDFab 12 (x64).lnk', $applications, 'DVDFab.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('DVDFab 13 (x64)\DVDFab 13 (x64).lnk', $applications, 'DVDFab.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('Free Download Manager\Free Download Manager.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('GitHub, Inc\GitHub Desktop.lnk', $development, $true)
		[StartMenuCleanupItem]::FromUserPrograms('grepWin\grepWin.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('HandBrake\HandBrake.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('FrostWire 6\FrostWire 6.lnk', $applications, 'FrostWire.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('Inkscape\Inkscape.lnk', $applications)
		[StartMenuCleanupItem]::FromUserPrograms('Inkscape\Inkview.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('IrfanView\IrfanView 4*.lnk', $applications, 'IrfanView.lnk')
		[StartMenuCleanupItem]::FromUserPrograms('IrfanView\IrfanView 64 4*.lnk', $applications, 'IrfanView64.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('JetBrains\JetBrains dotCover*.lnk', $development, 'JetBrains dotCover.lnk')
		[StartMenuCleanupItem]::FromUserPrograms('JetBrains\JetBrains dotMemory*.lnk', $development, 'JetBrains dotMemory.lnk')
		[StartMenuCleanupItem]::FromUserPrograms('JetBrains\JetBrains dotPeek*.lnk', $development, 'JetBrains dotPeek.lnk')
		[StartMenuCleanupItem]::FromUserPrograms('JetBrains\JetBrains dotTrace*.lnk', $development, 'JetBrains dotTrace.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('KMyMoney\KMyMoney.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Link Shell Extension\LSEConfig.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Microsoft Azure Storage Explorer\Microsoft Azure Storage Explorer.lnk', $development, $true)
		[StartMenuCleanupItem]::FromUserPrograms('pgAdmin 4\pgAdmin*.lnk', $development, 'pgAdmin 4.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('Postman\Postman.lnk', $development, $true)
		[StartMenuCleanupItem]::FromUserPrograms('PowerToys (Preview)\PowerToys (Preview).lnk', $applications, 'PowerToys.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('Python 3.*', $development)
		[StartMenuCleanupItem]::FromUserPrograms('QTTabBar\Explorer SafeMode.lnk', $applications, 'QTTabBar Explorer SafeMode.lnk', $true)
		[StartMenuCleanupItem]::FromUserPrograms('Slack Technologies\Slack.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Slack Technologies Inc\Slack.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Sigil\Sigil.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Steam\*.url', 'Games')		# steam uses a protocol handler ('steam://') to launch its games
		[StartMenuCleanupItem]::FromUserPrograms('Steam\*.lnk', 'Games', $true)
		[StartMenuCleanupItem]::FromUserPrograms('VeraCrypt\VeraCrypt.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Visual Studio Code\Visual Studio Code.lnk', $development, $true)
		[StartMenuCleanupItem]::FromUserPrograms('WinRAR\WinRAR.lnk', $applications, $true)
		[StartMenuCleanupItem]::FromUserPrograms('Zoom\Start Zoom.lnk', $applications, $true)

		# deletes:
		[StartMenuCleanupItem]::FromCommonPrograms('2BrightSparks')
		[StartMenuCleanupItem]::FromCommonPrograms('Go Programming Language')
		[StartMenuCleanupItem]::FromCommonPrograms('IIS')
		[StartMenuCleanupItem]::FromCommonPrograms('Java')
		[StartMenuCleanupItem]::FromCommonPrograms('Java Development Kit')
		[StartMenuCleanupItem]::FromCommonPrograms('Logi')		# logitech options installing some app for some other device, Logi Bolt ??
		[StartMenuCleanupItem]::FromUserPrograms('Amazon')
		[StartMenuCleanupItem]::FromUserPrograms('docker-desktop')
		[StartMenuCleanupItem]::FromUserPrograms('docker-desktop-data')
		[StartMenuCleanupItem]::FromUserPrograms('Windows Terminal.url')
	) | ForEach-Object { CleanUpStartMenuItem $_ }
}

function KillBackgroundProcesses {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param ()
	WriteHeaderMessage 'killing background processes'
	@(
		# Name is required (no '.exe'), Description and Company can be extra checks to make sure we get the right one:
		<#@{ Name = ''; Description = ''; Company = ''; },#>
		@{ Name = 'update_notifier'; Company = 'Vivaldi'; }
		@{ Name = 'igfxEM'; Company = 'Intel'; }
		@{ Name = 'igfxEMN'; Company = 'Intel'; }
		@{ Name = 'helperservice'; Description = 'Free Download Manager'; }
		@{ Name = 'Amazon Music Helper'; Company = 'Amazon.com Services LLC'; }
		@{ Name = 'LiveUpdate'; Path = 'DVDFab'; }
		@{ Name = 'MicrosoftEdgeUpdate'; }
		@{ Name = 'RtkAudUService64'; Company = 'Realtek Semiconductor'; }
		@{ Name = 'WavesSvc64'; Company = 'Waves Audio Ltd.'; }
		@{ Name = 'jusched'; Description = 'Java Update Scheduler'; }
		#@{ Name = 'id_tray'; Description = 'IDrive Tray'; }
		@{ Name = 'id_bglaunch'; Description = 'IDrive Background'; }
	) |
	ForEach-Object {
		$app = $_
		WriteVerboseMessage 'looking for background proces |{0}|' $app.Name
		$p = Get-Process -Name $app.Name -ErrorAction Ignore |
				ForEach-Object { WriteVerboseMessage 'found process, id {0}, checking Description |{1}|, Company |{2}|, Path |{3}|' $_.Id,$_.Description,$_.Company,$_.Path -continuation; $_ } |
				Where-Object { (-not $app.Description) -or ($_.Description -match $app.Description) } |
				Where-Object { (-not $app.Company) -or ($_.Company -match $app.Company) } |
				Where-Object { (-not $app.Path) -or ($_.Path -match $app.Path) }
		if ($p) {
			$desc = "'$($p.ProcessName)'"
			if ($p.Description) { $desc += "/'$($p.Description)'" } elseif ($p.Company) { $desc += "/'$($p.Company)'" }
			WriteStatusMessage "${script:msgIndent}killing background process $desc with PID $($p.Id)"
			if ($PSCmdlet.ShouldProcess("PID $($p.Id) [$desc]", "Kill")) {
				$p.Kill()
			}
		} else {
			WriteStatusMessageLow "${script:msgIndent}background process named '$($app.Name)' not found"
		}
	}
}

function RenameUnwantedFiles {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)] [string]$filePattern
	)
	WriteVerboseMessage 'checking pattern |{0}|' $_
	if (Test-Path $filePattern) {
		WriteVerboseMessage 'renaming files for pattern |{0}|' $_ -continuation
		$files = @(Get-ChildItem $filePattern | ForEach-Object { $_.FullName })
		for ($index = 0; $index -lt $files.Count; $index++) {
			if ($index -eq 0) {
				CleanUpOldFilesForPattern $filePattern
			}
			RenameFile $files[$index]
		}
	}
}

function GetMutatedFilename {
	param (
		[Parameter(Mandatory=$true)] [string]$origFileName
	)
	$fullFilePattern = Split-Path $origFileName -Leaf
	$origFilePattern = [System.IO.Path]::GetFilenameWithoutExtension($fullFilePattern)
	$origFileExtension = [System.IO.Path]::GetExtension($fullFilePattern)
	if ($origFileExtension.StartsWith(".")) { $origFileExtension = $origFileExtension.Substring(1); }
	"~$origFilePattern.~$origFileExtension"
}

function CleanUpOldFilesForPattern {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)] [string]$filePattern
	)
	WriteVerboseMessage 'checking for/cleaning up old files for |{0}|' $_
	$folderName = Split-Path $_ -Parent
	$mutatedFilePattern = GetMutatedFilename $filePattern
	$mutatedFilePath = Join-Path $folderName $mutatedFilePattern
	WriteVerboseMessage 'checking for old files pattern |{0}|' $mutatedFilePath -continuation
	Get-ChildItem $mutatedFilePath -ErrorAction Ignore |
		ForEach-Object {
			$fullname = $_.FullName
			WriteStatusMessage "deleting file |$fullname|"
			try {
				# telling cmdlet to make all errors 'terminating' errors so that the catch will see them
				Remove-Item -LiteralPath $fullname -Force -WhatIf:$WhatIfPreference -ErrorAction Stop
			} catch {
				Write-Warning "could not remove file |$fullname|: $($Error[0].Exception.Message)"
			}
		}
}

function RenameFile {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param (
		[Parameter(Mandatory=$true)] [string]$filename
	)
	$folderName = Split-Path $filename -Parent
	$mutatedFileName = GetMutatedFilename $filename
	$mutatedFilePath = Join-Path $folderName $mutatedFileName
	WriteStatusMessage "renaming file |$filename| to |$mutatedFileName|"
	try {
		# telling cmdlet to make all errors 'terminating' errors so that the catch will see them
		Move-Item -LiteralPath $filename -Destination $mutatedFilePath -Force -WhatIf:$WhatIfPreference -ErrorAction Stop
	} catch [System.Exception] {
		Write-Warning "could not rename file |$filename|: $($Error[0].Exception.Message)"
	}
}

function GetListOfInstalledApps {
	$result = @();
	$result += Get-ChildItem HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall |
					ForEach-Object { Get-ItemProperty $_.PSPath } |
					Select-Object PSChildName,DisplayName,UninstallString
	$result += Get-ChildItem HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall |
					ForEach-Object { Get-ItemProperty $_.PSPath } |
					Select-Object PSChildName,DisplayName,UninstallString
	if (Test-RegistryKey -registryPath "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") {
		$result += Get-ChildItem HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
						ForEach-Object { Get-ItemProperty $_.PSPath } |
						Select-Object PSChildName,DisplayName,UninstallString
	}
	if (Test-RegistryKey -registryPath "HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall") {
		$result += Get-ChildItem HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall |
						ForEach-Object { Get-ItemProperty $_.PSPath } |
						Select-Object PSChildName,DisplayName,UninstallString
	}
	$result;
}

function UninstallApp {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject[]])]
	param (
		[Parameter(Mandatory=$true)][string]$displayName,
		[PSObject[]] $cachedInstalledApps
	)
	WriteVerboseMessage 'displayName = |{0}|' $displayName
	$found = $false
	$batFileName = Join-Path $env:Temp ~ackUninstall.bat
	# getting the list of apps is pretty slow, so try to cache it; but if we actually uninstall something, it needs to be reloaded
	# (some apps [e.g. Nvidia's] uninstall other things, which then causes an error when we try to install that)
	if (-not $cachedInstalledApps) {
		$cachedInstalledApps = GetListOfInstalledApps
	}
	$cachedInstalledApps |
		ForEach-Object {
			if ($_.DisplayName -match $displayName) {
				$found = $true
				WriteStatusMessage "starting uninstall of |$($_.DisplayName)|"
				$uninstallCommand = $_.UninstallString
				if (![System.String]::IsNullOrWhitespace($uninstallCommand)) {
					WriteVerboseMessage 'running command |{0}|' $uninstallCommand -continuation
					<#
					# Invoke-Expression does not support -WhatIf, so do that ourselves:
					if ($PSCmdlet.ShouldProcess($uninstallCommand, "Invoke-Expression")) {
						# if $uninstallCommand has curly braces in it (the MSI ones usually have a GUID), Invoke-Expression will try to interpret that as a script block;
						# can just put quotes around that part (e.g. the GUID), but the call operator is working without any of that, i think; we'll see what issues that causes...
						#Invoke-Expression "cmd.exe /c $uninstallCommand";
						cmd.exe /c $uninstallCommand;
						#& $uninstallCommand;
					}
					#>
					# the UninstallString's are very inconsistent: some are just an exe, most have arguments, most include quotes with spaces, some don't;
					# can't think of anything that will work for all that's not a huge amount of work, so we'll try just creating a batch file with the
					# command in it and let the command interpreter figure it out, since it already knows how;
					# TODO?: could maybe try WMI, the Win32_Product is supposed to have an Uninstall() once you get the object, but
					# (a) the lookup is really freaking slow, and (b) think it only works for MSI packages, not things like InnoSetup, etc
					if ($uninstallCommand -notlike '*"*' -and $uninstallCommand -like '*Program Files*' <# anything else?? #>) {
						# not quoted when it should have been, so assume it's just a simple app name to run:
						Start-Process -FilePath $uninstallCommand
					} else {
						if ($PSCmdlet.ShouldProcess($uninstallCommand, "Run Batch File")) {
							try {
								$uninstallCommand | Out-File $batFileName -Encoding ASCII -Force
								cmd.exe /c $batFileName
							} finally {
								Remove-Item $batFileName -Force
							}
						}
					}
				} else {
					Write-Warning "app |$($_.DisplayName)| does not have an uninstall command; skipping"
				}
			}
		};
	if (!$found) {
		WriteStatusMessageLow "no apps matching |$displayName| found..."
	} else {
		$cachedInstalledApps = $null
	}
	return $cachedInstalledApps
}

function CleanUpEnvVars {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	WriteHeaderMessage 'cleaning up unwanted environment variables'
	@(
		'POSH_THEMES_PATH'
		'POSH_INSTALLER'
		'IGCCSVC_DB'	# very long Intel connection string or whatever; don't need it
	) | ForEach-Object { RemoveUnwantedEnvVar -envVarName $_ }

	WriteHeaderMessage 'cleaning up unwanted Path variable entries'
	CleanUpPathVars
}

function CleanUpPathVars {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	$crap = @(
		'*\javapath'
		#'*\Microsoft SQL Server\*'
		#'*\Windows Performance Toolkit\'
		'*\Windows Kits\*'
		'*\UltraEdit'
		'*\UltraCompare'
		'*\Intel\*'
		'*\Intel(R) Management Engine Components\*'
		'*\Web Platform Installer*'
		'*\Fiddler'
		'*\Azure Data Studio\*'
		'*\oh-my-posh\themes'
		#'C:\ProgramData\DockerDesktop\version-bin'
		'*\GitHubDesktop\*'
		#'C:\Program Files (x86)\GnuPG\bin'
		#'C:\Program Files (x86)\Gpg4win\..\GnuPG\bin'
		#'*\go\bin'
		'*\Python\Launcher\'
		'*\TortoiseGit\bin'
		#'*\gsudo\*'
	)
	if ($VerbosePreference -eq 'Continue') {
		WriteVerboseMessage 'removals:'
		foreach ($r in $crap) { WriteVerboseMessage $r -continuation }
	}
	$rep = @(
		#@{ SearchFor = 'C:\Program Files (x86)\Gpg4win\..\GnuPG\bin'; ReplaceWith = { param([string] $val) 'C:\Program Files (x86)\GnuPG\bin' } }
	)

	RemoveUnwantedPathsForTarget -envVarName 'Path' -targetName 'SYSTEM' -removals $crap -replacements $rep
	RemoveUnwantedPathsForTarget -envVarName 'Path' -targetName 'USER' -removals $crap -replacements $rep
}

function CleanUpRandomStuff {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	#WriteHeaderMessage 'cleaning up some random stuff'
	#FixUpHtmlFileIcon
	#FixUpXmlFileIcon
	#FixUpIrfanViewIcons
}

function SetDefaultIcon {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[string] $progId,
		[string] $checkMatch,
		[string] $nameForLogging,
		[string] $newValue,
		[switch] $asExpandString
	)
	$madeChanges = $false
	# can be under HKEY_CURRENT_USER or under HKEY_LOCAL_MACHINE, HKEY_CURRENT_USER has precedence:
	$userProgIdPath = Join-Path $script:regUserClassesRootPath $progId
	$sysProgIdPath = Join-Path $script:regSysClassesRootPath $progId
	$progIdPath = ''
	if (Test-RegistryKey -registryPath $userProgIdPath) {
		$progIdPath = $userProgIdPath
	} elseif (Test-RegistryKey -registryPath $sysProgIdPath) {
		$progIdPath = $sysProgIdPath
	}
	if (-not $progIdPath) {
		WriteStatusMessageLow "prog id '$progId' not found under HKEY_CLASSES_ROOT"
		return $madeChanges
	}
	WriteVerboseMessage 'using progId |{0}|' $progIdPath
	$defaultIconPath = Join-Path $progIdPath $script:regDefaultIconName

	$currDefIcon = Get-RegistryKeyValue -registryPath $defaultIconPath -valueName $script:regDefaultPropName
	if ($currDefIcon -notlike $checkMatch) {
		WriteStatusMessage "setting icon path to $nameForLogging"
		if ($currDefIcon) {
			# make a backup of the existing one (just in case ... of something ...):
			$backupPropName = "${progId}.Default"
			WriteVerboseMessage 'backing up existing icon path |{0}| value to |{1}|' $currDefIcon,$backupPropName
			New-RegistryKeyValue -registryPath $defaultIconPath -valueName $backupPropName -valueData $currDefIcon -valueType 'String' -force
		}
		# set '(Default)' value to specified value (if the type doesn't match 'ExpandString' vs 'String', that's okay, it will get changed):
		WriteVerboseMessage 'setting |{0}| value to |{1}|' $script:regDefaultPropName,$defaultIconValue
		$type = if ($asExpandString) { 'ExpandString' } else { 'String' }
		New-RegistryKeyValue -registryPath $defaultIconPath -valueName $script:regDefaultPropName -valueData $newValue -valueType $type -force
		$madeChanges = $true
	} else {
		WriteStatusMessageLow "icon path is already set to $nameForLogging"
	}
	return $madeChanges
}

function FixUpXmlFileIcon {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	$defaultIconValue = '"%UserProfile%\OneDrive\Pictures\icons\msxml3_128.ico",0'
	$madeChanges = $false

	# make sure Office hasn't set it's broken IconHandler:
	WriteSubHeaderMessage 'checking XML File icon'
	$xmlfileRegPathBase = Join-Path $script:regSysClassesRootPath 'xmlfile'
	$xmlfileIconHandler = Join-Path $xmlfileRegPathBase 'ShellEx\IconHandler'
	if (Test-RegistryKey -registryPath $xmlfileIconHandler) {
		WriteStatusMessage 'removing IconHandler'
		Remove-RegistryKey -registryPath $xmlfileIconHandler
		$madeChanges = $true
	} else {
		WriteStatusMessageLow 'no IconHandler found'
	}

	# now check that the default icon path is set to somethig decent:
	$madeChanges = (SetDefaultIcon -progId 'xmlfile' -checkMatch '*msxml3_128.ico*' -nameForLogging 'msxml3' -newValue $defaultIconValue -asExpandString) -or $madeChanges

	if ($madeChanges) {
		WriteStatusMessageWarning "-> be sure to refresh the icon cache"
	}
}

function FixUpHtmlFileIcon {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	$defaultIconValue = '"%UserProfile%\OneDrive\Pictures\icons\iexplore_17.ico",0'
	$madeChanges = $false

	WriteSubHeaderMessage 'checking HTML File icon'

	$userHtmlSelRegPath = Join-Path $script:regUserFileExtsPath '.html\UserChoice'
	$userProgId = Get-RegistryKeyValue -registryPath $userHtmlSelRegPath -valueName 'ProgId'
	if (-not $userProgId) { WriteStatusMessageLow 'no user selection for HTML files found'; return }
	WriteVerboseMessage 'found user progId |{0}|' $userProgId

	$madeChanges = (SetDefaultIcon -progId $userProgId -checkMatch '*iexplore_17.ico*' -nameForLogging 'iexplore.ico' -newValue $defaultIconValue -asExpandString) -or $madeChanges

	if ($userProgId -like 'Firefox*') {
		WriteSubHeaderMessage 'checking Firefox URL File icon'
		# firefox has two (FirefoxHTML-xxxxxx and FirefoxURL-xxxxxx, need to set URL one too)
		$userProgId = $userProgId -replace 'FirefoxHTML','FirefoxURL'
		$madeChanges = (SetDefaultIcon -progId $userProgId -checkMatch '*iexplore_17.ico*' -nameForLogging 'iexplore.ico' -newValue $defaultIconValue -asExpandString) -or $madeChanges
	}

	if ($madeChanges) {
		WriteStatusMessageWarning "-> be sure to refresh the icon cache"
	}
}

function FixUpIrfanViewIcons {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	WriteSubHeaderMessage 'checking IrfanView icons'
	$madeChanges = $false
	@(
		@{ ProgId = 'IrfanView.bmp'; Icon = '"%UserProfile%\OneDrive\Pictures\icons\imageres_70.bmp.ico",0'; Match = '*imageres_70.bmp.ico*'; LogName = 'imageres_70.bmp.ico'; }
		@{ ProgId = 'IrfanView.gif'; Icon = '"%UserProfile%\OneDrive\Pictures\icons\imageres_71.gif.ico",0'; Match = '*imageres_71.gif.ico*'; LogName = 'imageres_71.gif.ico'; }
		@{ ProgId = 'IrfanView.jpg'; Icon = '"%UserProfile%\OneDrive\Pictures\icons\imageres_72.jpeg.ico",0'; Match = '*imageres_72.jpeg.ico*'; LogName = 'imageres_72.jpeg.ico'; }
		@{ ProgId = 'IrfanView.png'; Icon = '"%UserProfile%\OneDrive\Pictures\icons\imageres_83.png.ico",0'; Match = '*imageres_83.png.ico*'; LogName = 'imageres_83.png.ico'; }
		@{ ProgId = 'IrfanView.tif'; Icon = '"%UserProfile%\OneDrive\Pictures\icons\imageres_122.tiff.ico",0'; Match = '*imageres_122.tiff.ico*'; LogName = 'imageres_122.tiff.ico'; }
	) |
		ForEach-Object {
			$madeChanges = (SetDefaultIcon -progId $_.ProgId -checkMatch $_.Match -nameForLogging $_.LogName -newValue $_.Icon -asExpandString) -or $madeChanges
		}

	if ($madeChanges) {
		WriteStatusMessageWarning "-> be sure to refresh the icon cache"
	}
}

function RemoveUnwantedEnvVar {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [string] $envVarName
	)
	WriteVerboseMessage 'removing envirnment variable |{0}|' $envVarName
	if ([System.Environment]::GetEnvironmentVariable($envVarName, [System.EnvironmentVariableTarget]::User)) {
		WriteSubHeaderMessage "${script:msgIndent}removing environment variable 'USER/$envVarName'"
		if ($PSCmdlet.ShouldProcess("User/$envVarName = <null>", 'SetEnvironmentVariable')) {
			[System.Environment]::SetEnvironmentVariable($envVarName, $null, [System.EnvironmentVariableTarget]::User)
		}
	}
	if ([System.Environment]::GetEnvironmentVariable($envVarName, [System.EnvironmentVariableTarget]::Machine)) {
		WriteSubHeaderMessage "${script:msgIndent}removing environment variable 'SYSTEM/$envVarName'"
		if ($PSCmdlet.ShouldProcess("System/$envVarName = <null>", 'SetEnvironmentVariable')) {
			[System.Environment]::SetEnvironmentVariable($envVarName, $null, [System.EnvironmentVariableTarget]::Machine)
		}
	}
}

function RemoveUnwantedPathsForTarget {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [string] $envVarName,
		[Parameter(Mandatory=$true)] [ValidateSet('SYSTEM', 'USER')] [string] $targetName,
		[Parameter(Mandatory=$true)] [string[]] $removals,
		[PSObject[]] $replacements
	)
	WriteVerboseMessage 'checking {0} path variable |{1}|' $targetName,$envVarName
	try {
		# go straight to reg keys because want to read value without expanding the value:
		switch ($targetName) {
			'SYSTEM' { $regKey = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('SYSTEM\CurrentControlSet\Control\Session Manager\Environment', $true); break; }
			'USER' { $regKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment', $true); break; }
		}
		$originalPathVar = $regKey.GetValue($envVarName, $null, 'DoNotExpandEnvironmentNames');
		if ($originalPathVar) {
			$originalPathVar = $originalPathVar.Trim([System.IO.Path]::PathSeparator)	# ends with ';' sometimes
		}
		$keyType = $regKey.GetValueKind($envVarName)
		WriteVerboseMessage 'original: {0} (type: {1})' $originalPathVar,$keyType -continuation
		if ($keyType -notin @([Microsoft.Win32.RegistryValueKind]::String, [Microsoft.Win32.RegistryValueKind]::ExpandString)) {
			WriteStatusMessage "${script:msgIndent}$targetName $envVarName variable is type $keyType; skipping processing"
			return
		}
		$cleanedPathVar = RemoveUnwantedPaths -pathValue $originalPathVar -targetName $targetName -removals $removals -replacements $replacements
		if ($cleanedPathVar -ne $originalPathVar) {
			WriteStatusMessage "${script:msgIndent}updating $targetName $envVarName variable"
			WriteVerboseMessage 'cleaned: {0}' $cleanedPathVar -continuation
			if ($PSCmdlet.ShouldProcess("$targetName/@$envVarName", 'SetEnvironmentVariable')) {
				$regKey.SetValue($envVarName, $cleanedPathVar, [Microsoft.Win32.RegistryValueKind]::ExpandString)
			}
		} else {
			WriteStatusMessageLow "${script:msgIndent}no changes for $targetName Path variable"
		}
	} finally {
		if ($regKey) { $regKey.Dispose() }
	}
}

function RemoveUnwantedPaths {
	param(
		[Parameter(Mandatory=$true)] [string] $pathValue,
		[Parameter(Mandatory=$true)] [string] $targetName,
		[Parameter(Mandatory=$true)] [string[]] $removals,
		[PSObject[]] $replacements
	)
	$intermedResults = @(); $results = @();
	$ps = $pathValue -split [System.IO.Path]::PathSeparator
	# remove any specified values, do any replacements:
	foreach ($p in $ps) {
		if (!$p) { continue; }
		$matched = $false
		foreach ($c in $removals) {
			if ($p -like $c) {
				WriteSubHeaderMessage "${script:msgIndent}removing $targetName path '$p'"
				$matched = $true
				break
			}
		}
		if (!$matched) {
			if ($replacements) {
				foreach ($r in $replacements) {
					if ($p -like $r.SearchFor) {
						$p2 = (& $r.ReplaceWith -val $p)
						WriteSubHeaderMessage "${script:msgIndent}patching $targetName path '$p' with '$p2'"
						$p = $p2
						break
					}
				}
			}
			$intermedResults += $p
		}
	}
	# normalize all the values, use env vars as much as possible, remove dupes, non-existant paths:
	foreach ($p in $intermedResults) {
		$p2 = NormalizePathValue -value $p
		if ($p2) {
			if ($results -notcontains $p2) {
				WriteVerboseMessage 'keeping path value = |{0}|' $p2
				$results += $p2
			} else {
				WriteSubHeaderMessage "${script:msgIndent}removing dupe $targetName path '$p' [normalized: '$p2']"
			}
		} else {
			WriteSubHeaderMessage "${script:msgIndent}removing $targetName path value '$p': path does not exist(?)"
		}
	}
	if ($results -and $results[0] -like '%*' -and $results[0] -notlike '%SystemRoot%*') {
		# the edit env vars thing for paths has a bug if first char is a '%' (https://superuser.com/a/1594989/8672),
		# but if it starts with '%SystemRoot%', then it works
		WriteVerboseMessage 'prepending %SystemRoot% to {0} path' $targetName
		$results = @('%SystemRoot%') + $results		# we'll just prepend this because it's a small directory
	}

	return $results -join ';'
}

function NormalizePathValue {
	param(
		[string] $value
	)
	WriteVerboseMessage 'input value = |{0}|' $value
	if (-not $value) { return $value }
	$value = [System.Environment]::ExpandEnvironmentVariables($value)			# expand it all the way out so we can replace with preferred stuff
	WriteVerboseMessage 'expanded value = |{0}|' $value -continuation
	$value = Convert-Path -LiteralPath $value -ErrorAction SilentlyContinue		# get rid of any relative paths
	if (-not $value) { return $value }
	while ($value.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or $value.EndsWith([System.IO.Path]::AltDirectorySeparatorChar)) {
		# remove trailing backslashes
		$value = $value.Substring(0, $value.Length - 1)
	}
	WriteVerboseMessage 'converted value = |{0}|' $value -continuation
	$value = ReplaceWithEnvVars -value $value
	WriteVerboseMessage 'returning value = |{0}|' $value -continuation
	return $value
}

$script:cachedEnvVars = $null
function ReplaceWithEnvVars {
	param(
		[string] $value
	)
	if (-not $value) { return $value }
	if (-not $script:cachedEnvVars) {
		$script:cachedEnvVars = @(
			[PSCustomObject]@{ Name = 'LocalAppData'; Value = [System.Environment]::GetEnvironmentVariable('LocalAppData'); }
			[PSCustomObject]@{ Name = 'AppData'; Value = [System.Environment]::GetEnvironmentVariable('AppData'); }
			[PSCustomObject]@{ Name = 'OneDrive'; Value = [System.Environment]::GetEnvironmentVariable('OneDrive'); }
			[PSCustomObject]@{ Name = 'UserProfile'; Value = [System.Environment]::GetEnvironmentVariable('UserProfile'); }
			[PSCustomObject]@{ Name = 'ProgramData'; Value = [System.Environment]::GetEnvironmentVariable('ProgramData'); }
			[PSCustomObject]@{ Name = 'ProgramFiles'; Value = [System.Environment]::GetEnvironmentVariable('ProgramFiles'); }
			[PSCustomObject]@{ Name = 'ProgramFiles(x86)'; Value = [System.Environment]::GetEnvironmentVariable('ProgramFiles(x86)'); }
			[PSCustomObject]@{ Name = 'SystemRoot'; Value = [System.Environment]::GetEnvironmentVariable('SystemRoot'); }
		)
		if ($VerbosePreference -eq 'Continue') {
			WriteVerboseMessage 'cachedEnvVars:'
			foreach ($nv in $script:cachedEnvVars) { WriteVerboseMessage '"{0}" = "{1}"' $nv.Name,$nv.Value -continuation }
		}
	}
	foreach ($nv in $script:cachedEnvVars) {
		# -icontains, -ireplace aren't working(?), use .net methods:
		if ($value.StartsWith($nv.Value, [System.StringComparison]::CurrentCultureIgnoreCase)) {
			# and need this to be case-insensitive, but old .net's String.Replace doesn't support that, so regex it is
			$re = [regex]::new(('^{0}' -f [regex]::Escape($nv.Value)), [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
			$value = $re.Replace($value, ('%{0}%' -f $nv.Name))
			break
		}
	}
	return $value
}

function CleanUpStartMenuItem {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [StartMenuCleanupItem] $startMenuItem
	)
	# looks like (??) class methods don't support CmdletBinding, or at least the WhatIf param, so do it with plain function
	if (-not $startMenuItem.Source) { Write-Error "$($MyInvocation.InvocationName): `$Source property is empty" -ErrorAction Stop }
	$deleteThese = @()
	if (Test-Path -Path $startMenuItem.Source) {	# might have '*' in it, this will return true for any
	WriteVerboseMessage 'processing start menu item |{0}|' $startMenuItem.Source
		if ($startMenuItem.TargetFolder) {
			# if target exists and is a file, error:
			if (Test-Path $startMenuItem.TargetFolder -PathType Leaf) {
				Write-Warning "$($MyInvocation.InvocationName): `$TargetFolder is specified but is not a folder: '$($startMenuItem.TargetFolder)'"
				return
			}
			# if target folder doesn't exist, create it:
			if (-not (Test-Path $startMenuItem.TargetFolder -PathType Container)) {
				[void](New-Item -Path $startMenuItem.TargetFolder -ItemType Directory -Force -WhatIf:$WhatIfPreference -ErrorAction Stop)
			}
			# figure out real target:
			if ($startMenuItem.NewFilename) {
				$trg = Join-Path $startMenuItem.TargetFolder $startMenuItem.NewFilename
				WriteVerboseMessage 'NewFilename = |{0}|, setting start menu target to |{1}|' $startMenuItem.NewFilename,$trg
			} else {
				$trg = $startMenuItem.TargetFolder
				WriteVerboseMessage 'setting start menu target to |{0}|' $trg
			}
			# do move (might have '*' in Source, so expand it; the move doesn't work with folders and a '*' in the source, think our exception handling move only works for single folder):
			foreach ($srcPath in @(Convert-Path -Path $startMenuItem.Source)) {
				WriteStatusMessage "${script:msgIndent}moving item: |$(GetStartMenuPathForLogging -path $srcPath)| to |$(GetStartMenuPathForLogging -path $trg)|"
				$canDeleteSource = $false
				try {
					# telling cmdlet to make all errors 'terminating' errors so that the catch will see them
					# and not using -LiteralPath because that doesn't work with '*'s; if we need to use -LiteralPath, we'll have to come up with something:
					Move-Item -Path $srcPath -Destination $trg -Force -ErrorAction Stop
					$canDeleteSource = $true
				} catch [System.IO.IOException] {
					if ((Test-Path -Path $srcPath -PathType Container) -and
							($Error[0].Exception.Message -like '*Cannot create a file when that file already exists*' -or
							$Error[0].Exception.Message -like '*because a file or directory with the same name already exists*' <# Core #>))
					{
						# posh/.NET won't let you move a folder to a folder that already exists, so try the windows shell:
						WriteVerboseMessage 'trying to move folder |{0}| to |{1}| using Shell.Application' $srcPath,$startMenuItem.TargetFolder
						$shellApp = New-Object -ComObject Shell.Application
						$srcFolder = $shellApp.NameSpace($srcPath)
						$trgFolder = $shellApp.NameSpace($startMenuItem.TargetFolder)
						$trgFolder.MoveHere($srcFolder, 16<# 'Yes to ALl' #>)
						$canDeleteSource = $true
						$trgFolder = $null
						$srcFolder = $null
						$shellApp = $null
					} else {
						Write-Warning "could not move file |$srcPath|: $($Error[0].Exception.Message)";
					}
				} catch <#[System.Exception]#> {
					Write-Warning "could not move file |$srcPath|: $($Error[0].Exception.Message)";
				}
				if ($canDeleteSource -and $startMenuItem.DeleteSourceFolder) {
					$deletePath = Split-Path -Path $srcPath -Parent
					if ($deletePath -notin $deleteThese) { $deleteThese += $deletePath }
				}
			}
		} else {
			if ($startMenuItem.Source -notin $deleteThese) { $deleteThese += $startMenuItem.Source }
		}
	} elseif ($startMenuItem.DeleteSourceFolder) {
		$sourceFolder = (Split-Path $startMenuItem.Source)
		if (Test-Path $sourceFolder) {
			WriteVerboseMessage 'start menu item |{0}| not found but DeleteSourceFolder == true; deleting source folder' $startMenuItem.Source
			$deletePath = Split-Path -Path $startMenuItem.Source -Parent
			if ($deletePath -notin $deleteThese) { $deleteThese += $deletePath }
		} else {
			WriteVerboseMessage 'start menu item |{0}| not found, DeleteSourceFolder == true but sourceFolder does not exist; skipping' $startMenuItem.Source
			return
		}
	} else {
		#WriteStatusMessageLow "start menu item not found: '$($startMenuItem.Source)'; skipping"
		WriteVerboseMessage 'start menu item |{0}| not found and DeleteSourceFolder != true; skipping' $startMenuItem.Source
		return
	}
	# do we need to clean anything up?
	foreach ($deleteThis in $deleteThese) {
		if ($deleteThis -and [StartMenuCleanupItem]::SafeToDelete($deleteThis)) {
			WriteStatusMessage "deleting folder: |$(GetStartMenuPathForLogging -path $deleteThis)|"
			try {
				# telling cmdlet to make all errors 'terminating' errors so that the catch will see them
				Remove-Item -LiteralPath $deleteThis -Force -Recurse -ErrorAction Stop
			} catch [System.Exception] {
				Write-Warning "could not delete file |$deleteThis|: $($Error[0].Exception.Message)";
			}
		} elseif ($deleteThis) {
			Write-Warning "skipping deletion of folder '$deleteThis': it is not safe to delete"
		}
	}
}

$script:commonStartMenu = [regex]::Escape([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartMenu))
$script:userStartMenu = [regex]::Escape([Environment]::GetFolderPath([Environment+SpecialFolder]::StartMenu))
function GetStartMenuPathForLogging {
	param (
		[Parameter(Mandatory=$true)] [string] $path
	)
	return (($path -replace $script:commonStartMenu, '<CommonStartMenu>') -replace $script:userStartMenu, '<UserStartMenu>')
}

class StartMenuCleanupItem {
	static [string[]] $_neverDelete = @(
		[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonPrograms),
		[Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartMenu),
		[Environment]::GetFolderPath([Environment+SpecialFolder]::Programs),
		[Environment]::GetFolderPath([Environment+SpecialFolder]::StartMenu)
	)
	[string] $Source
	[string] $TargetFolder
	[string] $NewFilename
	[bool] $DeleteSourceFolder

	StartMenuCleanupItem([string] $cleanupSource) { $this.Source = $cleanupSource }
	StartMenuCleanupItem([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename, [bool] $deleteSourceFolder) {
		$this.Source = $cleanupSource
		$this.TargetFolder = $cleanupTarget
		$this.NewFilename = $newFilename
		$this.DeleteSourceFolder = $deleteSourceFolder
	}

	static [bool] SafeToDelete([string] $folder) {
		return ($folder -notin [StartMenuCleanupItem]::_neverDelete)
	}

	static [StartMenuCleanupItem] FromCommonPrograms([string] $cleanupSource) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonPrograms)) $cleanupSource
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item '$src'"
		return [StartMenuCleanupItem]::new($src)
	}

	static [StartMenuCleanupItem] FromCommonPrograms([string] $cleanupSource, [string] $cleanupTarget) {
		return [StartMenuCleanupItem]::FromCommonPrograms($cleanupSource, $cleanupTarget, $null, $false)
	}

	static [StartMenuCleanupItem] FromCommonPrograms([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename) {
		return [StartMenuCleanupItem]::FromCommonPrograms($cleanupSource, $cleanupTarget, $newFilename, $false)
	}

	static [StartMenuCleanupItem] FromCommonPrograms([string] $cleanupSource, [string] $cleanupTarget, [bool] $deleteSourceFolder) {
		return [StartMenuCleanupItem]::FromCommonPrograms($cleanupSource, $cleanupTarget, $null, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromCommonPrograms([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename, [bool] $deleteSourceFolder) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonPrograms)) $cleanupSource
		$trg = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonPrograms)) $cleanupTarget
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item source |$src|, target |$trg|, newFilename |$newFilename|, deleteSourceFolder |$deleteSourceFolder|"
		return [StartMenuCleanupItem]::new($src, $trg, $newFilename, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromCommonStartMenu([string] $cleanupSource) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartMenu)) $cleanupSource
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item '$src'"
		return [StartMenuCleanupItem]::new($src)
	}

	static [StartMenuCleanupItem] FromCommonStartMenu([string] $cleanupSource, [string] $cleanupTarget) {
		return [StartMenuCleanupItem]::FromCommonStartMenu($cleanupSource, $cleanupTarget, $null, $false)
	}

	static [StartMenuCleanupItem] FromCommonStartMenu([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename) {
		return [StartMenuCleanupItem]::FromCommonStartMenu($cleanupSource, $cleanupTarget, $newFilename, $false)
	}

	static [StartMenuCleanupItem] FromCommonStartMenu([string] $cleanupSource, [string] $cleanupTarget, [bool] $deleteSourceFolder) {
		return [StartMenuCleanupItem]::FromCommonStartMenu($cleanupSource, $cleanupTarget, $null, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromCommonStartMenu([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename, [bool] $deleteSourceFolder) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonStartMenu)) $cleanupSource
		$trg = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::CommonPrograms)) $cleanupTarget
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item source |$src|, target |$trg|, newFilename |$newFilename|, deleteSourceFolder |$deleteSourceFolder|"
		return [StartMenuCleanupItem]::new($src, $trg, $newFilename, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromUserPrograms([string] $cleanupSource) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) $cleanupSource
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item '$src'"
		return [StartMenuCleanupItem]::new($src)
	}

	static [StartMenuCleanupItem] FromUserPrograms([string] $cleanupSource, [string] $cleanupTarget) {
		return [StartMenuCleanupItem]::FromUserPrograms($cleanupSource, $cleanupTarget, $null, $false)
	}

	static [StartMenuCleanupItem] FromUserPrograms([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename) {
		return [StartMenuCleanupItem]::FromUserPrograms($cleanupSource, $cleanupTarget, $newFilename, $false)
	}

	static [StartMenuCleanupItem] FromUserPrograms([string] $cleanupSource, [string] $cleanupTarget, [bool] $deleteSourceFolder) {
		return [StartMenuCleanupItem]::FromUserPrograms($cleanupSource, $cleanupTarget, $null, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromUserPrograms([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename, [bool] $deleteSourceFolder) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) $cleanupSource
		$trg = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) $cleanupTarget
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item source |$src|, target |$trg|, newFilename |$newFilename|, deleteSourceFolder |$deleteSourceFolder|"
		return [StartMenuCleanupItem]::new($src, $trg, $newFilename, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromUserStartMenu([string] $cleanupSource) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::StartMenu)) $cleanupSource
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item '$src'"
		return [StartMenuCleanupItem]::new($src)
	}

	static [StartMenuCleanupItem] FromUserStartMenu([string] $cleanupSource, [string] $cleanupTarget) {
		return [StartMenuCleanupItem]::FromUserStartMenu($cleanupSource, $cleanupTarget, $null, $false)
	}

	static [StartMenuCleanupItem] FromUserStartMenu([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename) {
		return [StartMenuCleanupItem]::FromUserStartMenu($cleanupSource, $cleanupTarget, $newFilename, $false)
	}

	static [StartMenuCleanupItem] FromUserStartMenu([string] $cleanupSource, [string] $cleanupTarget, [bool] $deleteSourceFolder) {
		return [StartMenuCleanupItem]::FromUserStartMenu($cleanupSource, $cleanupTarget, $null, $deleteSourceFolder)
	}

	static [StartMenuCleanupItem] FromUserStartMenu([string] $cleanupSource, [string] $cleanupTarget, [string] $newFilename, [bool] $deleteSourceFolder) {
		$src = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::StartMenu)) $cleanupSource
		$trg = Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Programs)) $cleanupTarget
		#Write-Verbose "$($MyInvocation.InvocationName): creating start menu cleanup item source |$src|, target |$trg|, newFilename |$newFilename|, deleteSourceFolder |$deleteSourceFolder|"
		return [StartMenuCleanupItem]::new($src, $trg, $newFilename, $deleteSourceFolder)
	}
}

#==============================
Main
#==============================
