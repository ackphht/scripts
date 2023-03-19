﻿#Requires -RunAsAdministrator
#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$True)]
param(
	[switch] $onlyEnvVars,
	[switch] $onlyWinExplrFlags,
	[switch] $onlyEdgeBrowser,
	[switch] $onlyWinUpdate,
	<# [switch] $onlyPoshGallery, #>
	[switch] $onlyPowerMngmnt,
	[switch] $onlyNetworking,
	[switch] $onlyDefenderExcl
)

Set-StrictMode -Version Latest

. ./setUpSystem.00.common.ps1
. ./setUpSystem.00.SystemData.ps1

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[switch] $onlyEnvVars,
		[switch] $onlyWinExplrFlags,
		[switch] $onlyEdgeBrowser,
		[switch] $onlyWinUpdate,
		<# [switch] $onlyPoshGallery, #>
		[switch] $onlyPowerMngmnt,
		[switch] $onlyNetworking,
		[switch] $onlyDefenderExcl
	)

	# in case we're running < .net 4.6, make sure TLS 1.2 is enabled:
	if ([System.Net.ServicePointManager]::SecurityProtocol -ne 0 <# SystemDefault (added in 4.7/Core) #> -and
		([System.Net.ServicePointManager]::SecurityProtocol -band [System.Net.SecurityProtocolType]::Tls12) -eq 0)
	{
		Write-Verbose "$($MyInvocation.InvocationName): changing default SecurityProtocol to enable TLS 1.2"
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
	}

	$all = $true
	if ($onlyEnvVars -or $onlyWinExplrFlags -or $onlyEdgeBrowser -or $onlyWinUpdate -or `
		$onlyPowerMngmnt -or $onlyNetworking -or $onlyDefenderExcl)
	{
		$all = $false
	}

	$osDetails = Get-OSDetails
	Write-Verbose "$($MyInvocation.InvocationName): osDetails = |$(ConvertTo-Json -InputObject $osdetails -Depth 100)|"

	if ($all -or $onlyWinExplrFlags) {
		WriteStatusHeader
		WriteStatusMessage 'manual steps'
		Write-Host
		Write-Host 'other things to be done manually (haven''t figured out how to automate yet):' -ForegroundColor Magenta
		$yn = Read-Host -Prompt 'Would you like to configure the disk write cache policy? Y/n'
		if ($yn -ne 'n') {
			Start-Process -FilePath "$env:SystemRoot\System32\devmgmt.msc"
		}
		if ($osDetails.Id -in @('win.10', 'win.11')) {
			$yn = Read-Host -Prompt 'Would you like to change the Store app settings? Y/n'
			if ($yn -ne 'n') {
				Start-Process -FilePath 'ms-windows-store:Settings'
			}
		}
		$yn = Read-Host -Prompt 'Would you like to change the Explorer default view properties for General, Documents, Music, Videos? Y/n'
		if ($yn -ne 'n') {
			Start-Process -FilePath "$env:SystemDrive\"
			Start-Process -FilePath "$env:UserProfile\Documents"
			Start-Process -FilePath "$env:UserProfile\Music"
			Start-Process -FilePath "$env:UserProfile\Videos"
			Start-Process -FilePath "$env:UserProfile\Downloads"
		}
		Write-Host
		Read-Host -Prompt 'press Enter to continue...'
	}

	if ($all -or $onlyWinUpdate) {
		WriteStatusHeader
		WriteStatusMessage 'configuring Windows Update'
		ConfigureWindowsUpdate -osDetails $osDetails
	}
	if ($all -or $onlyEnvVars) {
		WriteStatusHeader
		WriteStatusMessage 'configuring environment variables'
		SetNeededEnvironmentVariables -osDetails $osDetails
	}
	if ($all -or $onlyWinExplrFlags) {
		WriteStatusHeader
		WriteStatusMessage 'configuring Windows and Explorer options'
		ConfigureWindowsAndExplorer -osDetails $osDetails
	}
	if ($all -or $onlyEdgeBrowser) {
		WriteStatusHeader
		WriteStatusMessage 'configuring Microsoft Edge browser'
		ConfigureEdge -osDetails $osDetails
	}
	if ($all -or $onlyPowerMngmnt) {
		WriteStatusHeader
		WriteStatusMessage 'configuring power management'
		ConfigurePowerManagement -osDetails $osDetails
	}
	if ($all -or $onlyNetworking) {
		WriteStatusHeader
		WriteStatusMessage 'configuring networking'
		ConfigureNetworking -osDetails $osDetails
	}
	if ($all -or $onlyDefenderExcl) {
		WriteStatusHeader
		WriteStatusMessage 'adding Windows Defender exclusions'
		ConfigureDefenderExclusions -osDetails $osDetails
	}

	if ($all -or $onlyEnvVars -or $onlyWinExplrFlags) {
		WriteStatusHeader
		WriteStatusMessage '"flushing" changes'
		Flush -osDetails $osDetails
	}
}

function SetNeededEnvironmentVariables {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): processing environment variables"
	SetEnvironmentVariable -variableName 'PROMPT' -variableValue '$p$_WHAT!?!$g' -variableScope 'User'
	SetEnvironmentVariable -variableName 'DIRCMD' -variableValue '/ogn' -variableScope 'User'
	SetEnvironmentVariable -variableName 'HOME' -variableValue '%USERPROFILE%' -variableScope 'User'
	SetEnvironmentVariable -variableName '_NT_SYMBOL_PATH' -variableValue 'srv*%ALLUSERSPROFILE%\symbols*http://msdl.microsoft.com/download/symbols' -variableScope 'User'
	SetEnvironmentVariable -variableName 'ASPNETCORE_ENVIRONMENT' -variableValue 'Development' -variableScope 'User'
	SetEnvironmentVariable -variableName 'DOTNET_ENVIRONMENT' -variableValue 'Development' -variableScope 'User'
	SetEnvironmentVariable -variableName 'DOTNET_CLI_TELEMETRY_OPTOUT' -variableValue '1' -variableScope 'User'
	SetEnvironmentVariable -variableName 'EnableNuGetPackageRestore' -variableValue 'true' -variableScope 'User'
	SetEnvironmentVariable -variableName 'NUGET_PACKAGES' -variableValue '%LOCALAPPDATA%\NuGet\packages' -variableScope 'User'
	SetEnvironmentVariable -variableName 'POWERSHELL_UPDATECHECK' -variableValue 'OFF' -variableScope 'User'
}

function ConfigureWindowsAndExplorer {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): configuring windows and explorer settings"

	$hklmSoftware = 'HKLM:\SOFTWARE'
	$hkcuClasses = 'HKCU:\Software\Classes'
	$hklmCurrCtrlSet = 'HKLM:\SYSTEM\CurrentControlSet'
	$hkcuSoftwareMicrosoft = 'HKCU:\Software\Microsoft'
	$hkcuCurrentVersion = "$hkcuSoftwareMicrosoft\Windows\CurrentVersion"
	$hkcuCurrentVersionNT = "$hkcuSoftwareMicrosoft\Windows NT\CurrentVersion"
	$hkcuCurrentVersionExplorer = "$hkcuCurrentVersion\Explorer"
	$hkcuCurrentVersionExplorerAdv = "$hkcuCurrentVersionExplorer\Advanced"
	$hkcuCurrentVersionCntntDlvry = "$hkcuCurrentVersion\ContentDeliveryManager"
	$hkcuCtrlPnl = 'HKCU:\Control Panel'
	$hkcuCtrlDesktop = "$hkcuCtrlPnl\Desktop"
	$hkcuCtrlPnlIntl = "$hkcuCtrlPnl\International"
	$hklmPoliciesMicrosoft = "$hklmSoftware\Policies\Microsoft"

	# disable prefixing 'Shortcut to' when creating shortcuts
	SetRegistryEntry -path $hkcuCurrentVersionExplorer -name 'link' -value ([byte[]](0x00,0x00,0x00,0x00)) -type 'Binary'
	# DateTime preferences:
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'sShortDate' -value 'yyyy-MM-dd' -type 'String'
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'sShortTime' -value 'HH:mm' -type 'String'
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'sTimeFormat' -value 'HH:mm:ss' -type 'String'
	# (not sure if i actually need these, but they were on my list before, so)
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'sDate' -value '-' -type 'String'
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'iDate' -value '2' -type 'String'
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'iTime' -value '1' -type 'String'
	SetRegistryEntry -path $hkcuCtrlPnlIntl -name 'iTLZero' -value '1' -type 'String'
	# Explorer options:
	SetRegistryEntry -path $hkcuCurrentVersionExplorer -name 'ShowRecent' -value 0 -type 'DWord'					# don't show recent files in Quick Access
	SetRegistryEntry -path $hkcuCurrentVersionExplorer -name 'ShowFrequent' -value 1 -type 'DWord'					# do show frequent folders in Quick Access
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'Hidden' -value 1 -type 'DWord'						# show hidden files
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'HideFileExt' -value 0 -type 'DWord'				# don't hide file extensions
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'PersistBrowsers' -value 0 -type 'DWord'			# don't restore previous windows at login
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'ShowEncryptCompressedColor' -value 1 -type 'DWord'	# show compressed & encrypted files names in color
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'AutoCheckSelect' -value 0 -type 'DWord'			# don't use checkboxes for selecting files/folders
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'HideMergeConflicts' -value 0 -type 'DWord'			# don't show folder merge conflicts
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'LaunchTo' -value 1 -type 'DWord'					# Open File Explorer to "This PC" (2 = Quick Access)
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'SeparateProcess' -value 0 -type 'DWord'			# disable launch folders in separate process
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'ShowTaskViewButton' -value 0 -type 'DWord'			# hide Task View button on taskbar
	SetRegistryEntry -path "$hkcuCurrentVersionExplorer\CabinetState" -name 'FullPath' -value 1 -type 'DWord'		# show full path in titlebar
	#SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'NavPaneShowAllFolders' -value 1 -type 'DWord'
	# screen saver grace period before locking system:
	SetRegistryEntry -path "$hkcuCurrentVersion\Winlogon" -name 'ScreenSaverGracePeriod' -value 10 -type 'DWord'
	# disable saving zone information in downloads (that Sophia app/module/whatever writes to somewhere else [function 'SaveZoneInformation'], but below has always worked for me)
	SetRegistryEntry -path "$hkcuCurrentVersion\Policies\Associations" -name 'DefaultFileTypeRisk' -value 0x1808 -type 'DWord'	# 0x1808 = "Low Risk"; 0x1807 = "Moderate", 0x1806 = "High Risk"
	SetRegistryEntry -path "$hkcuCurrentVersion\Policies\Attachments" -name 'SaveZoneInformation' -value 1 -type 'DWord'			# 1 = "Do not preserve zone information", 2 = "Do preserve zone information"
	# show explorer file operations in Detailed/Expanded mode
	SetRegistryEntry -path "$hkcuCurrentVersionExplorer\OperationStatusManager" -name 'EnthusiastMode' -value 1 -type 'DWord'
	# enable Large Icons in Control Panel:
	SetRegistryEntry -path "$hkcuCurrentVersionExplorer\ControlPanel" -name 'AllItemsIconView' -value 0 -type 'DWord'
	SetRegistryEntry -path "$hkcuCurrentVersionExplorer\ControlPanel" -name 'StartupPage' -value 1 -type 'DWord'
	# show Details pane in right side:
	SetRegistryEntry -path "$hkcuCurrentVersionExplorer\Modules\GlobalSettings\DetailsContainer" -name 'DetailsContainer' -value ([byte[]](0x01,0x00,0x00,0x00,0x02,0x00,0x00,0x00)) -type 'Binary'
	SetRegistryEntry -path "$hkcuCurrentVersionExplorer\Modules\GlobalSettings\Sizer" -name 'DetailsContainerSizer' -value ([byte[]](0x15,0x01,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe1,0x04,0x00,0x00)) -type 'Binary'
	# show Libraries on left side (i think):
	SetRegistryEntry -path "$hkcuClasses\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -name 'System.IsPinnedToNameSpaceTree' -value 1 -type 'DWord'
	# set console default params:
	$consoleKey = 'HKCU:\Console'
	SetRegistryEntry -path $consoleKey -name 'WindowSize' -value 0x003200a0 -type 'DWord'	# 160x50
	SetRegistryEntry -path $consoleKey -name 'FaceName' -value 'Consolas' -type 'String'
	SetRegistryEntry -path $consoleKey -name 'FontSize' -value 0x00100000 -type 'DWord'		# 16
	$consoleKey = 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'
	if (Test-Path -LiteralPath $consoleKey) {
		SetRegistryEntry -path $consoleKey -name 'WindowSize' -value 0x003200a0 -type 'DWord'	# 160x50
		SetRegistryEntry -path $consoleKey -name 'FaceName' -value 'Consolas' -type 'String'
		SetRegistryEntry -path $consoleKey -name 'FontSize' -value 0x00100000 -type 'DWord'		# 16
	}
	$consoleKey = 'HKCU:\Console\%SystemRoot%_SYSTEM32_cmd.exe'
	if (Test-Path -LiteralPath $consoleKey) {
		SetRegistryEntry -path $consoleKey -name 'WindowSize' -value 0x003200a0 -type 'DWord'	# 160x50
		SetRegistryEntry -path $consoleKey -name 'FaceName' -value 'Consolas' -type 'String'
		SetRegistryEntry -path $consoleKey -name 'FontSize' -value 0x00100000 -type 'DWord'		# 16
	}
	# enable showing Restart Notifications for Windows Update
	SetRegistryEntry -path "$hklmSoftware\Microsoft\WindowsUpdate\UX\Settings" -name 'RestartNotificationsAllowed2' -value 1 -type 'DWord'
	# disable auto restarting after updates
	SetRegistryEntry -path "$hklmSoftware\Microsoft\WindowsUpdate\UX\Settings" -name 'IsExpedited' -value 0 -type 'DWord'
	# disable expand to open folder on navigation pane
	SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'NavPaneExpandToCurrentFolder' -value 0 -type 'DWord'
	# turn on NumLock by default
	SetRegistryEntry -path "$hkcuCtrlPnl\Keyboard" -name 'InitialKeyboardIndicators' -value '2' -type 'String'
	SetRegistryEntry -path 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' -name 'InitialKeyboardIndicators' -value '2147483650' -type 'String'	# the '.DEFAULT' one has the upper bit set, too ??
	# disable all AutoPlay handlers
	SetRegistryEntry -Path "$hkcuCurrentVersionExplorer\AutoplayHandlers" -name 'DisableAutoplay' -value 1 -type 'DWord'

	if ($osDetails.Id -in @('win.10', 'win.11')) {	# TODO?: maybe could check based on build number, so it would for servers, too, and handle future version of Windows
		# set default color mode to Dark:
		SetRegistryEntry -path "$hkcuCurrentVersion\Themes\Personalize" -name 'SystemUsesLightTheme' -value 0 -type 'DWord'
		SetRegistryEntry -path "$hkcuCurrentVersion\Themes\Personalize" -name 'AppsUseLightTheme' -value 0 -type 'DWord'
		SetRegistryEntry -path "$hkcuCurrentVersion\Themes\Personalize" -name 'EnableTransparency' -value 1 -type 'DWord'	# enable transparency effects
		SetRegistryEntry -path $hkcuCtrlDesktop -name 'AutoColorization' -value 1 -type 'DWord'						# automatically select accent color from background
		SetRegistryEntry -path "$hkcuSoftwareMicrosoft\Windows\DWM" -name 'ColorPrevalence' -value 1 -type 'DWord'	# show accent colors on title bars and window borders
		# set dark wallpaper if it's currently Windows 11 light wallpaper:
		if ($osDetails.Id -eq 'win.11') {
			$wp = GetRegPropertyValue -registryPath $hkcuCtrlDesktop -propertyName 'WallPaper'
			if ($wp -like '*\img0.jpg')	{
				$newWpPath = $wp -replace '\\img0\.jpg','\img19.jpg'
				SetRegistryEntry -path $hkcuCtrlDesktop -name 'WallPaper' -value $newWpPath -type 'String'
				[Wallpaper]::SetWallpaper($newWpPath)
			}
		}
		# show some icons on desktop
		SetRegistryEntry -path "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -name '{59031a47-3f72-44a7-89c5-5595fe6b30ee}' <# home folder #> -value 0 -type 'DWord'
		SetRegistryEntry -path "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -name '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' <# This PC #> -value 0 -type 'DWord'
		SetRegistryEntry -path "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -name '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' <# Network #> -value 0 -type 'DWord'
		#SetRegistryEntry -path "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -name '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}' <# Control Panel #> -value 0 -type 'DWord'
		#SetRegistryEntry -path "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -name '{018D5C66-4533-4307-9B53-224DE2ED1FE6}' <# OneDrive #> -value 0 -type 'DWord'
		# enable clipboard history:
		SetRegistryEntry -path "$hkcuSoftwareMicrosoft\Clipboard" -name 'EnableClipboardHistory' -value 1 -type 'DWord'
		# enable saving and restarting apps
		SetRegistryEntry -Path "$hkcuCurrentVersionNT\Winlogon" -name 'RestartApps' -value 1 -type 'DWord'
		# disable Cortana autostarting: 0 = default (?); 1 = disabled, 2 = enabled
		SetRegistryEntry -Path "$hkcuClasses\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -name 'State' -value 1 -type 'DWord'
		# enable long paths
		SetRegistryEntry -path "$hklmCurrCtrlSet\Control\FileSystem" -name 'LongPathsEnabled' -value 1 -type 'DWord'
		# disable Connected Standby:
		#SetRegistryEntry -path "$hklmCurrCtrlSet\Control\Power" -name 'CsEnabled' -value 0 -type 'DWord'
		if ($osDetails.Id -eq 'win.10') {
			# hide the People taskbar button
			SetRegistryEntry -path "$hkcuCurrentVersionExplorer\Advanced\People" -name 'PeopleBand' -value 0 -type 'DWord'
		} elseif ($osDetails.Id -eq 'win.11') {
			# turn on 'Compact view':
			SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'UseCompactMode' -value 1 -type 'DWord'
			# taskbar alignment: 1 = Center, 0 = Left
			SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'TaskbarAl' -value 1 -type 'DWord'
			# start menu layout: 0 = default; 1 = more pins, 2 = more recommendations
			SetRegistryEntry -path $hkcuCurrentVersionExplorerAdv -name 'Start_Layout' -value 1 -type 'DWord'
			# disable Teams autostarting: 0 = default (?); 1 = disabled, 2 = enabled
			SetRegistryEntry -Path "$hkcuClasses\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" -name 'State' -value 1 -type 'DWord'
		}
		#
		# annoyances:
		#
		# disable Search Highlights:
		SetRegistryEntry -path "$hkcuCurrentVersion\Feeds\DSB" -name 'ShowDynamicContent' -value 0 -type 'DWord'
		SetRegistryEntry -path "$hkcuCurrentVersion\SearchSettings" -name 'IsDynamicSearchBoxEnabled' -value 0 -type 'DWord'
		# disable Search box on Taskbar
		SetRegistryEntry -path "$hkcuCurrentVersion\Search" -name 'SearchboxTaskbarMode' -value 0 -type 'DWord'
		# disable AdvertisingId ('The permission for apps to show me personalized ads by using my advertising ID')
		SetRegistryEntry -path "$hkcuCurrentVersion\AdvertisingInfo" -name 'Enabled' -value 0 -type 'DWord'
		# disable Windows Welcome Experience ('The Windows welcome experiences after updates and occasionally when I sign in to highlight what's new and suggested')
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SubscribedContent-310093Enabled' -value 0 -type 'DWord'
		# disable app suggestions in the Start menu
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SubscribedContent-338388Enabled' -value 0 -type 'DWord'
		# disable Windows Tips ('getting tip and suggestions when I use Windows')
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SubscribedContent-338389Enabled' -value 0 -type 'DWord'
		# disable SuggestedContent ('suggestion content in the Settings app')
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SubscribedContent-338393Enabled' -value 0 -type 'DWord'
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SubscribedContent-353694Enabled' -value 0 -type 'DWord'
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SubscribedContent-353696Enabled' -value 0 -type 'DWord'
		# disable SilentInstalledAppsEnabled ('Automatic installing suggested apps')
		SetRegistryEntry -path $hkcuCurrentVersionCntntDlvry -name 'SilentInstalledAppsEnabled' -value 0 -type 'DWord'
		# disable 'Ways to get the most out of Windows and finish setting up this device'
		SetRegistryEntry -path "$hkcuCurrentVersion\UserProfileEngagement" -name 'ScoobeSystemSettingEnabled' -value 0 -type 'DWord'
		# disable Tailored Experiences ('let Microsoft use your diagnostic data for personalized tips, ads, and recommendations')
		SetRegistryEntry -path "$hkcuCurrentVersion\Privacy" -name 'TailoredExperiencesWithDiagnosticDataEnabled' -value 0 -type 'DWord'
		# disable First Logon Animation
		SetRegistryEntry -path "$hklmSoftware\Microsoft\Windows NT\CurrentVersion\Winlogon" -name 'EnableFirstLogonAnimation' -value 0 -type 'DWord'
		# Hide recently added apps in the Start menu
		SetRegistryEntry -path "$hklmPoliciesMicrosoft\Windows\Explorer" -name 'HideRecentlyAddedApps' -value 1 -type 'DWord'
		## disable XXXXXXXX ('zzzzzzzz')
		#SetRegistryEntry -path 'XXXXXXX' -name 'ZZZZZZZZ' -value 0 -type 'DWord'
	}

	# add Open With Notepad:
	#SetRegistryEntry -path "$hkcuClasses\*\shell\Notepad" -name '(default)' -value 'Open with Notepad' -type 'String'
	#SetRegistryEntry -path "$hkcuClasses\*\shell\Notepad" -name 'Icon' -value '%SystemRoot%\system32\notepad.exe' -type 'ExpandString'
	#SetRegistryEntry -path "$hkcuClasses\*\shell\Notepad\Command" -name '(default)' -value '%SystemRoot%\system32\notepad.exe "%1"' -type 'ExpandString'
	# disable ShutdownEventTracker
	#SetRegistryEntry -path "$hklmPoliciesMicrosoft\Windows NT\Reliability" -name 'ShutdownReasonOn' -value 0 -type 'DWord'

	# disable Google crapware installs
	$googleAds = "$hklmSoftware\Google\No Chrome Offer Until"; $googleAdsWow = "$hklmSoftware\Wow6432Node\Google\No Chrome Offer Until";
	SetRegistryEntry -path $googleAds -name 'Irfan Skiljan' -value 0x01404cff -type 'DWord'
	SetRegistryEntry -path $googleAds -name 'Piriform Ltd' -value 0x01404cff -type 'DWord'
	SetRegistryEntry -path $googleAds -name 'Irfan Skiljan' -value 0x01404cff -type 'DWord'
	SetRegistryEntry -path $googleAds -name 'Piriform Ltd' -value 0x01404cff -type 'DWord'
	if ((Is64BitOs)) {
		SetRegistryEntry -path $googleAdsWow -name 'Irfan Skiljan' -value 0x01404cff -type 'DWord'
		SetRegistryEntry -path $googleAdsWow -name 'Piriform Ltd' -value 0x01404cff -type 'DWord'
		SetRegistryEntry -path $googleAdsWow -name 'Irfan Skiljan' -value 0x01404cff -type 'DWord'
		SetRegistryEntry -path $googleAdsWow -name 'Piriform Ltd' -value 0x01404cff -type 'DWord'
	}
}

function ConfigureEdge {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): configuring MS Edge browser"
	if ($osDetails.Id -in @('win.10', 'win.11')) {		# what's the minimum for edge?
		#
		# TODO: can we set Edge's settings somehow? most of the defaults are awful
		#
		$hklmPoliciesMicrosoft = "HKLM:\Software\Policies\Microsoft"
		# disable Edge adding icon to desktop
		SetRegistryEntry -path "$hklmPoliciesMicrosoft\EdgeUpdate" -Name 'CreateDesktopShortcut{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' -Value 0 -type 'DWord'		# stable
		SetRegistryEntry -path "$hklmPoliciesMicrosoft\EdgeUpdate" -Name 'CreateDesktopShortcut{2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}' -Value 0 -type 'DWord'		# beta
		SetRegistryEntry -path "$hklmPoliciesMicrosoft\EdgeUpdate" -Name 'CreateDesktopShortcut{0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}' -Value 0 -type 'DWord'		# dev
		SetRegistryEntry -path "$hklmPoliciesMicrosoft\EdgeUpdate" -Name 'CreateDesktopShortcut{65C35B14-6C1D-4122-AC46-7148CC9D6497}' -Value 0 -type 'DWord'		# canary
		# (try to) disable Edge First Run Page (not sure if this really works but we'll try it):
		SetRegistryEntry -path "$hklmPoliciesMicrosoft\MicrosoftEdge\Main" -Name 'PreventFirstRunPage' -Value 1 -type 'DWord'

		# there's also a group policy to disable that stupid first-run page, so try setting that too:
		$lgpoExe = LocateLgpoExe
		if ($lgpoExe) {
			$tmpFolder = GetAckTempFolder
			$policiesFile = Join-Path $tmpFolder 'edgePolicies.txt'
			if (Test-Path -Path $policiesFile -PathType Leaf) { Remove-Item -Path $policiesFile -Force }

			# "Prevent the First Run webpage from opening on Microsoft Edge"
			AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path 'Software\Policies\Microsoft\MicrosoftEdge\Main' -valueType 'DWORD' -valueName 'PreventFirstRunPage' -value '1'

			# run it:
			$exitcode = RunLgpo -lgpoPath $lgpoExe -policiesFile $policiesFile
			if ($exitcode) {
				Write-Error "LGPO.exe exited with non-zero exit code configuring Windows Update: $exitcode"
			}
		} else {
			Write-Verbose "no LGPO.exe found; cannot configure MS Edge policies; skipping"
		}
	}
}

function ConfigureWindowsUpdate {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): configuring windows update"
	$lgpoExe = LocateLgpoExe
	if (-not $lgpoExe) { Write-Warning "no LGPO.exe found; cannot configure Windows Update settings; exiting"; return }

	$tmpFolder = GetAckTempFolder
	$policiesFile = Join-Path $tmpFolder 'wuPolicies.txt'
	if (Test-Path -Path $policiesFile -PathType Leaf) { Remove-Item -Path $policiesFile -Force }

	$windowsUpdatePath = 'Software\Policies\Microsoft\Windows\WindowsUpdate'
	$windowsUpdateAuPath = "$windowsUpdatePath\AU"
	# "No auto-restart with logged on users for scheduled automatic updates" - may not apply to >= Win 10 (??), but we'll set it anyway
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DWORD' -valueName 'NoAutoRebootWithLoggedOnUsers' -value '1'
	# notification level: # 0:NotConfigued, 1:Disabled, 2:NotifybeforeDownload, 3:NotifyBeforeInstallation, 4:ScheduledInstallation
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DWORD' -valueName 'AUOptions' -value '2'
	# ???
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DWORD' -valueName 'NoAutoUpdate' -value '0'
	# install during automatic maintenance (only used when AUOptions = 4)
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DELETE' -valueName 'AutomaticMaintenanceEnabled' -value $null
	# install updates on: 0 = Every day, 1 = Every Sunday, ..., 7 = Every Saturday
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DWORD' -valueName 'ScheduledInstallDay' -value '0'
	# install update at hour: 0 thru 23 (there's an 'Automatic' option, too, not sure what value that is)
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DWORD' -valueName 'ScheduledInstallTime' -value '3'
	# if AUOptions = 4 above, then can also "limit updating to a weekly, bi-weekly or monthly occurrence":
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DWORD' -valueName 'ScheduledInstallEveryWeek' -value '1'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DELETE' -valueName 'ScheduledInstallFirstWeek' -value $null
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DELETE' -valueName 'ScheduledInstallSecondWeek' -value $null
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DELETE' -valueName 'ScheduledInstallThirdWeek' -value $null
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DELETE' -valueName 'ScheduledInstallFourthWeek' -value $null
	# ???
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdateAuPath -valueType 'DELETE' -valueName 'AllowMUUpdateService' -value $null
	# "Specifies whether the Windows Update will use the Windows Power Management features to automatically wake up the system from sleep, if there are updates scheduled for installation."
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'AUPowerManagement' -value '0'
	<#
	# => think setting these is causing Windows Update to ignore the AUOptions above
	# "Specify the deadline before the PC will automatically restart to apply updates."
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'SetAutoRestartDeadline' -value '1'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'AutoRestartDeadlinePeriodInDays' -value '30'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'AutoRestartDeadlinePeriodInDaysForFeatureUpdates' -value '30'
	# newer versions of one above ??
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'SetComplianceDeadline' -value '1'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ConfigureDeadlineForQualityUpdates' -value '30'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ConfigureDeadlineGracePeriod' -value '7'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ConfigureDeadlineForFeatureUpdates' -value '30'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ConfigureDeadlineGracePeriodForFeatureUpdates' -value '7'
	#>
	# "Turn off auto-restart for updates during active hours"
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ConfigureDeadlineNoAutoReboot' -value '1'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'SetActiveHours' -value '1'
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ActiveHoursStart' -value '4'	# 4 a.m.
	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $windowsUpdatePath -valueType 'DWORD' -valueName 'ActiveHoursEnd' -value '3'		# 3 a.m.

	# run it:
	$exitcode = RunLgpo -lgpoPath $lgpoExe -policiesFile $policiesFile
	if ($exitcode) {
		Write-Error "LGPO.exe exited with non-zero exit code configuring Windows Update: $exitcode"
	}

	#
	# these don't do anything anymore...;
	## TODO: should probably check against system name maybe?
	#$au = New-Object -ComObject Microsoft.Update.AutoUpdate		# returns an IAutomaticUpdates object: http://msdn.microsoft.com/en-us/library/windows/desktop/aa385821%28v=vs.85%29.aspx
	#$au.Settings.NotificationLevel = 2							# 0:NotConfigued, 1:Disabled, 2:NotifybeforeDownload, 3:NotifyBeforeInstallation, 4:ScheduledInstallation
	#$au.Settings.IncludeRecommendedUpdates = $true
	##$au.Settings.FeaturedUpdatesEnabled = $true				# apparently not supported right now, so should we set it?
	#$au.Settings.Save()
}

function ConfigureDefenderExclusions {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): adding windows defender exclusions"
	$lgpoExe = LocateLgpoExe
	if (-not $lgpoExe) { Write-Warning "no LGPO.exe found; cannot configure Windows defender exclusion; exiting"; return }

	$tmpFolder = GetAckTempFolder
	$policiesFile = Join-Path $tmpFolder 'dfndrPolicies.txt'
	if (Test-Path -Path $policiesFile -PathType Leaf) { Remove-Item -Path $policiesFile -Force }

	AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path 'Software\Policies\Microsoft\Windows Defender\Exclusions' -valueType 'DWORD' -valueName 'Exclusions_Paths' -value '1'
	$path = 'Software\Policies\Microsoft\Windows Defender\Exclusions\Paths'
	@(
		"$env:UserProfile\Apps\Utils\NirSoft"
		"$env:UserProfile\Installs\system utils\NirSoft Utils"
		'D:\Users\michael\Backups\Apps\Utils\NirSoft'
		'D:\Users\michael\Backups\Installs\system utils\NirSoft Utls'
		'I:\utils\NirSoft'
		'W:\Apps\Utils\NirSoft'
		'W:\Installs\system utils\NirSoft Utils'
		'\\wallach9\backups\Arrakis\Apps\Utils\NirSoft'
		'\\wallach9\installs\system utils\NirSoft Utils'
		'\\wallach9\windowsBackup'
	) | ForEach-Object {
		AddPolicySetting -policyFilepath $policiesFile -scope 'Computer' -path $path -valueType 'SZ' -valueName $_ -value '0'
	}

	# run it:
	$exitcode = RunLgpo -lgpoPath $lgpoExe -policiesFile $policiesFile
	if ($exitcode) {
		Write-Error "LGPO.exe exited with non-zero exit code setting Windows Defender exclusions: $exitcode"
	}
}

function ConfigurePowerManagement {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	$isVM = $false
	if ([bool](Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue)) {
		$cs = Get-CimInstance -ClassName 'CIM_ComputerSystem'
	} elseif ([bool](Get-Command -Name 'Get-WmiObject' -ErrorAction SilentlyContinue)) {
		$cs = Get-WmiObject -Class 'Win32_ComputerSystem'
	}
	if ($cs) {
		Write-Verbose "$($MyInvocation.InvocationName): computer system Manufacturer = |$($cs.Manufacturer)|, Model = |$($cs.Model)|"
		if ($cs.Model -eq 'Virtual Machine' <# Hyper-V #> <# TODO add others #>) {
			$isVM = $true
		}
	}
	if (-not $isVM) {
		Write-Verbose "$($MyInvocation.InvocationName): enabling hibernation"
		if ($PSCmdlet.ShouldProcess('/hibernate on', 'powercfg.exe')) {
			& powercfg.exe /hibernate on
		}
	} else {
		Write-Verbose "$($MyInvocation.InvocationName): system looks like a VM; no changes"
	}
}

function ConfigureNetworking {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): turning on Network Discovery, File & Print Sharing"
	# the stuff from Sophia's NetworkDiscovery function
	# TODO: need to understand better what this is doing...
	#if (-not (Get-CimInstance -ClassName 'CIM_ComputerSystem').PartOfDomain) {
	#	Set-NetFirewallRule -Profile 'Private' -Group @('@FirewallAPI.dll,-32752' <# Network discovery #>, '@FirewallAPI.dll,-28502' <# File and printer sharing #>) -Enabled 'True' <# not a bool ?? #>
	#	Set-NetFirewallRule -Profile @('Public', 'Private') -Name 'FPS-SMB-In-TCP' -Enabled 'True'
	#	Set-NetConnectionProfile -NetworkCategory Private
	#}
}

function Flush {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[PSObject] $osDetails
	)
	Write-Verbose "$($MyInvocation.InvocationName): flushing updates"
	# try doing 'gpupdate /force' - brute force way to get windows to notice any reg and/or policy changes we've done (??)
	if ([bool](Get-Command -Name 'gpupdate.exe' -ErrorAction SilentlyContinue)) {
		if ($PSCmdlet.ShouldProcess('/force', 'gpupdate.exe')) {
			& gpupdate.exe /force
		}
	} else {
		Write-Verbose "$($MyInvocation.InvocationName): gpupdate.exe not available"
	}

	# now force-restart Explorer so it picks up changes; try to save any open Explorer Windows and reopen them (from Sophia)
	$currOpenFolders = @((New-Object -ComObject Shell.Application).Windows() | ForEach-Object { $_.Document.Folder.Self.Path })
	Write-Verbose "$($MyInvocation.InvocationName): killing explorer and restarting it"
	Stop-Process -Name 'explorer' -Force
	Start-Sleep -Seconds 2
	Start-Process -FilePath 'explorer.exe'
	foreach ($f in $currOpenFolders) { Start-Process -FilePath $f }
}

function SetEnvironmentVariable {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param(
		[Parameter(Mandatory=$true)] [string] $variableName,
		[Parameter(Mandatory=$true)] [string] $variableValue,
		[System.EnvironmentVariableTarget] $variableScope = [System.EnvironmentVariableTarget]::User
	)
	Write-Verbose "$($MyInvocation.InvocationName): processing environment variable |$variableName|, value |$variableValue|, target |$variableScope|"
	# see if it's already set to the value:
	$currentVal = [System.Environment]::GetEnvironmentVariable($variableName, $variableScope)
	if ($currentVal -and $currentVal -eq $variableValue) {
		Write-Verbose "$($MyInvocation.InvocationName): variable |$variableName| is already set to |$variableValue|; nothing to do"
		return
	}
	# k, need to upsert it:
	if ($PSCmdlet.ShouldProcess("'$variableName' = '$variableValue'", "SetEnvironmentVariable")) {
		Write-Verbose "$($MyInvocation.InvocationName): setting environment variable for |$variableName| = |$variableValue|"
		# according to documentation, Environment.SetEnvironmentVariable will copy new env var into the current process,
		# but apparently that's a lie. Can use "Set-Content env:\$variableName $variableValue" to do that
		[Environment]::SetEnvironmentVariable($variableName, $variableValue, $variableScope)
		Set-Content -Path "env:\$variableName" -Value $variableValue
	}
}

function SetRegistryEntry {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [Alias('path')] [string]$registryPath,
		[Parameter(Mandatory=$true)] [Alias('name')] [string]$propertyName,
		[Parameter(Mandatory=$true)] [Alias('value')] [object]$propertyValue,
		[Parameter(Mandatory=$false)] [Alias('type')] [string]$propertyType = 'String'
	)
	Write-Verbose "$($MyInvocation.InvocationName): registry entry |$registryPath\@$propertyName| = |$propertyValue|"
	VerifyRegKeyExists -registryPath $registryPath
	if (TestRegKeyForProperty -registryPath $registryPath -propertyName $propertyName) {
		$currValue = GetRegPropertyValue -registryPath $registryPath -propertyName $propertyName
		if ($currValue -ne $propertyValue) {
			SetRegPropertyValue -registryPath $registryPath -propertyName $propertyName -propertyValue $propertyValue
		}
	} else {
		NewRegPropertyValue -registryPath $registryPath -propertyName $propertyName -propertyValue $propertyValue -propertyType $propertyType
	}
}

function VerifyRegKeyExists {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [string] $registryPath
	)
	if (!(Test-Path -LiteralPath $registryPath)) {
		Write-Verbose "$($MyInvocation.InvocationName): adding registry key |$registryPath|"
		[void](New-Item -Path $registryPath -Force)
	}
}

function TestRegKeyForProperty {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([bool])]
	param (
		[Parameter(Mandatory=$true)] [string] $registryPath,
		[Parameter(Mandatory=$true)] [string] $propertyName
	)
	if (Test-Path -LiteralPath $registryPath) {
		$test = Get-Item -LiteralPath $registryPath | Where-Object { $_.Property -contains $propertyName }
		return ($test -ne $null)
	}
	return $false
}

function GetRegPropertyValue {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject])]
	param (
		[Parameter(Mandatory=$true)] [string] $registryPath,
		[Parameter(Mandatory=$true)] [string] $propertyName
	)
	(Get-ItemProperty -Path $registryPath -Name $propertyName)."$propertyName"	# use quotes, because the '(default)' value will require it (others don't)
}

function NewRegPropertyValue {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [string] $registryPath,
		[Parameter(Mandatory=$true)] [string] $propertyName,
		[Parameter(Mandatory=$true)] [object] $propertyValue,
		[Parameter(Mandatory=$false)] [ValidateSet('String','ExpandString', 'DWord', 'QWord', 'Binary','MultiString')] [string] $propertyType = 'String'
	)
	# for Binary, value passed in would look like ([byte[]](0x00,0xff,etc))
	# for MultiString, value passed in is a string array: @("value1", "value2", etc)
	Write-Verbose "$($MyInvocation.InvocationName): creating registry entry |$registryPath\@$propertyName| = |$propertyValue|"
	if ($PSCmdlet.ShouldProcess("Item: $registryPath Property: $propertyName", 'New Property')) {	# New-ItemProperty does support WhatIf but it throws error is $registryPath doesn't exist, because it didn't get created because we're WhatIf-ing
		[void](New-ItemProperty -LiteralPath $registryPath -Name $propertyName -PropertyType $propertyType -Value $propertyValue -Force)
	}
}

function SetRegPropertyValue {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [string] $registryPath,
		[Parameter(Mandatory=$true)] [string] $propertyName,
		[Parameter(Mandatory=$true)] [object] $propertyValue
	)
	Write-Verbose "$($MyInvocation.InvocationName): setting registry entry |$registryPath\@$propertyName| = |$propertyValue|"
	Set-ItemProperty -LiteralPath $registryPath -Name $propertyName -Value $propertyValue
}

function RenameRegKey {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [string] $oldKeyName,
		[Parameter(Mandatory=$true)] [string] $newKeyName
	)
	Write-Verbose "$($MyInvocation.InvocationName): renaming registry entry |$oldKeyName| to |$newKeyName|"
	Move-Item -Path $oldKeyName -Destination $newKeyName
}

function AddPolicySetting {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([void])]
	param (
		[Parameter(Mandatory=$true)] [string] $policyFilepath,
		[Parameter(Mandatory=$true)] [ValidateSet('Computer', 'User')] [string] $scope,
		[Parameter(Mandatory=$true)] [string] $path,
		[Parameter(Mandatory=$true)] [ValidateSet('DWORD', 'SZ', 'EXSZ', 'CLEAR', 'DELETE')] [string] $valueType,
		[Parameter(Mandatory=$true)] [string] $valueName,
		[Parameter(Mandatory=$false)] [string] $value
	)
	switch ($valueType) {
		{ $_ -in @('CLEAR' <# this is what Sophia has #>, 'DELETE' <# but this is what i see when exporting/converting with lgpo.exe #>) } {
			$policy = '{1}{0}{2}{0}{3}{0}{4}{0}' -f [Environment]::NewLine, $scope, $path, $valueName, $valueType
			break
		}
		default {
			$policy = '{1}{0}{2}{0}{3}{0}{4}:{5}{0}' -f [Environment]::NewLine, $scope, $path, $valueName, $valueType, $value
			break
		}
	}
	Add-Content -Path $policyFilepath -Value $policy -Encoding utf8 -Force		# will add one more newline after, so we get blank lines between values
}

function RunLgpo {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([int])]
	param (
		[Parameter(Mandatory=$true)] [string] $lgpoPath,
		[Parameter(Mandatory=$true)] [string] $policiesFile
	)
	if ($PSCmdlet.ShouldProcess("/t $policiesFile", $lgpoPath)) {
		& $lgpoPath /t $policiesFile
		$exitcode = $LASTEXITCODE
	} else {
		$exitcode = 0
	}
	return $exitcode
}

Add-Type -TypeDefinition  @"
using System.Runtime.InteropServices;
public class Wallpaper {
	public const int SetDesktopWallpaper = 20;
	public const int UpdateIniFile = 0x01;
	public const int SendWinIniChange = 0x02;

	[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
	private static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);

	public static void SetWallpaper(string path) {
		SystemParametersInfo(SetDesktopWallpaper, 0, path, UpdateIniFile | SendWinIniChange);
	}
}
"@

#==============================
Main -onlyEnvVars:$onlyEnvVars -onlyWinExplrFlags:$onlyWinExplrFlags -onlyEdgeBrowser:$onlyEdgeBrowser -onlyWinUpdate:$onlyWinUpdate  `
		-onlyPowerMngmnt:$onlyPowerMngmnt -onlyNetworking:$onlyNetworking -onlyDefenderExcl:$onlyDefenderExcl
#==============================