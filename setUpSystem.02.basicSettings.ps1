#Requires -RunAsAdministrator
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

. $PSScriptRoot/setUpSystem.00.common.ps1
Import-Module -Name $PSScriptRoot/setUpSystem.00.SystemData

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
	SetRegistryEntry -p $hkcuCurrentVersionExplorer -n 'link' -v ([byte[]](0x00,0x00,0x00,0x00)) -t 'Binary'
	# DateTime preferences:
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'sShortDate' -v 'yyyy-MM-dd' -t 'String'
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'sShortTime' -v 'HH:mm' -t 'String'
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'sTimeFormat' -v 'HH:mm:ss' -t 'String'
	# (not sure if i actually need these, but they were on my list before, so)
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'sDate' -v '-' -t 'String'
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'iDate' -v '2' -t 'String'
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'iTime' -v '1' -t 'String'
	SetRegistryEntry -p $hkcuCtrlPnlIntl -n 'iTLZero' -v '1' -t 'String'
	# Explorer options:
	SetRegistryEntry -p $hkcuCurrentVersionExplorer -n 'ShowRecent' -v 0 -t 'DWord'					# don't show recent files in Quick Access
	SetRegistryEntry -p $hkcuCurrentVersionExplorer -n 'ShowFrequent' -v 1 -t 'DWord'					# do show frequent folders in Quick Access
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'Hidden' -v 1 -t 'DWord'						# show hidden files
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'HideFileExt' -v 0 -t 'DWord'				# don't hide file extensions
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'PersistBrowsers' -v 0 -t 'DWord'			# don't restore previous windows at login
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'ShowEncryptCompressedColor' -v 1 -t 'DWord'	# show compressed & encrypted files names in color
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'AutoCheckSelect' -v 0 -t 'DWord'			# don't use checkboxes for selecting files/folders
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'HideMergeConflicts' -v 0 -t 'DWord'			# don't show folder merge conflicts
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'LaunchTo' -v 1 -t 'DWord'					# Open File Explorer to "This PC" (2 = Quick Access)
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'SeparateProcess' -v 0 -t 'DWord'			# disable launch folders in separate process
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'ShowTaskViewButton' -v 0 -t 'DWord'			# hide Task View button on taskbar
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\CabinetState" -n 'FullPath' -v 1 -t 'DWord'		# show full path in titlebar
	#SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'NavPaneShowAllFolders' -v 1 -t 'DWord'
	# screen saver grace period before locking system:
	SetRegistryEntry -p "$hkcuCurrentVersion\Winlogon" -n 'ScreenSaverGracePeriod' -v 10 -t 'DWord'
	# disable saving zone information in downloads (that Sophia app/module/whatever writes to somewhere else [function 'SaveZoneInformation'], but below has always worked for me)
	SetRegistryEntry -p "$hkcuCurrentVersion\Policies\Associations" -n 'DefaultFileTypeRisk' -v 0x1808 -t 'DWord'	# 0x1808 = "Low Risk"; 0x1807 = "Moderate", 0x1806 = "High Risk"
	SetRegistryEntry -p "$hkcuCurrentVersion\Policies\Attachments" -n 'SaveZoneInformation' -v 1 -t 'DWord'			# 1 = "Do not preserve zone information", 2 = "Do preserve zone information"
	# show explorer file operations in Detailed/Expanded mode
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\OperationStatusManager" -n 'EnthusiastMode' -v 1 -t 'DWord'
	# enable Large Icons in Control Panel:
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\ControlPanel" -n 'AllItemsIconView' -v 0 -t 'DWord'
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\ControlPanel" -n 'StartupPage' -v 1 -t 'DWord'
	# show Details pane in right side:
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\Modules\GlobalSettings\DetailsContainer" -n 'DetailsContainer' -v ([byte[]](0x01,0x00,0x00,0x00,0x02,0x00,0x00,0x00)) -t 'Binary'
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\Modules\GlobalSettings\Sizer" -n 'DetailsContainerSizer' -v ([byte[]](0x15,0x01,0x00,0x00,0x01,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xe1,0x04,0x00,0x00)) -t 'Binary'
	# show Libraries on left side (i think):
	SetRegistryEntry -p "$hkcuClasses\CLSID\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" -n 'System.IsPinnedToNameSpaceTree' -v 1 -t 'DWord'
	# set console default params:
	$consoleKey = 'HKCU:\Console'
	SetRegistryEntry -p $consoleKey -n 'WindowSize' -v 0x003200a0 -t 'DWord'	# 160x50
	SetRegistryEntry -p $consoleKey -n 'FaceName' -v 'Consolas' -t 'String'
	SetRegistryEntry -p $consoleKey -n 'FontSize' -v 0x00100000 -t 'DWord'		# 16
	$consoleKey = 'HKCU:\Console\%SystemRoot%_System32_WindowsPowerShell_v1.0_powershell.exe'
	if (Test-Path -LiteralPath $consoleKey) {
		SetRegistryEntry -p $consoleKey -n 'WindowSize' -v 0x003200a0 -t 'DWord'	# 160x50
		SetRegistryEntry -p $consoleKey -n 'FaceName' -v 'Consolas' -t 'String'
		SetRegistryEntry -p $consoleKey -n 'FontSize' -v 0x00100000 -t 'DWord'		# 16
	}
	$consoleKey = 'HKCU:\Console\%SystemRoot%_SYSTEM32_cmd.exe'
	if (Test-Path -LiteralPath $consoleKey) {
		SetRegistryEntry -p $consoleKey -n 'WindowSize' -v 0x003200a0 -t 'DWord'	# 160x50
		SetRegistryEntry -p $consoleKey -n 'FaceName' -v 'Consolas' -t 'String'
		SetRegistryEntry -p $consoleKey -n 'FontSize' -v 0x00100000 -t 'DWord'		# 16
	}
	# enable showing Restart Notifications for Windows Update
	SetRegistryEntry -p "$hklmSoftware\Microsoft\WindowsUpdate\UX\Settings" -n 'RestartNotificationsAllowed2' -v 1 -t 'DWord'
	# disable auto restarting after updates
	SetRegistryEntry -p "$hklmSoftware\Microsoft\WindowsUpdate\UX\Settings" -n 'IsExpedited' -v 0 -t 'DWord'
	# disable expand to open folder on navigation pane
	SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'NavPaneExpandToCurrentFolder' -v 0 -t 'DWord'
	# always underline access key menu shortcuts:
	SetRegistryEntry -p "$hkcuCtrlPnl\Accessibility\Keyboard Preference" -n 'On' -v '1' -t 'String'
	# turn on NumLock by default
	SetRegistryEntry -p "$hkcuCtrlPnl\Keyboard" -n 'InitialKeyboardIndicators' -v '2' -t 'String'
	SetRegistryEntry -p 'Registry::HKEY_USERS\.DEFAULT\Control Panel\Keyboard' -n 'InitialKeyboardIndicators' -v '2147483650' -t 'String'	# the '.DEFAULT' one has the upper bit set, too ??
	# disable all AutoPlay handlers
	SetRegistryEntry -p "$hkcuCurrentVersionExplorer\AutoplayHandlers" -n 'DisableAutoplay' -v 1 -t 'DWord'

	if ($osDetails.ReleaseVersion.Major -ge 6) {	# Vista and up
		# make sure current account has user right to create symlinks:
		[AckWare.LsaHelper]::AddUserRight($env:Username, 'SeCreateSymbolicLinkPrivilege')
	}

	if ($osDetails.ReleaseVersion.Major -in @(10, 11)) {	# TODO?: maybe could check based on build number, so it would for servers, too, and handle future version of Windows
		# set default color mode to Dark:
		SetRegistryEntry -p "$hkcuCurrentVersion\Themes\Personalize" -n 'SystemUsesLightTheme' -v 0 -t 'DWord'
		SetRegistryEntry -p "$hkcuCurrentVersion\Themes\Personalize" -n 'AppsUseLightTheme' -v 0 -t 'DWord'
		SetRegistryEntry -p "$hkcuCurrentVersion\Themes\Personalize" -n 'EnableTransparency' -v 1 -t 'DWord'	# enable transparency effects
		SetRegistryEntry -p $hkcuCtrlDesktop -n 'AutoColorization' -v 1 -t 'DWord'						# automatically select accent color from background
		SetRegistryEntry -p "$hkcuSoftwareMicrosoft\Windows\DWM" -n 'ColorPrevalence' -v 1 -t 'DWord'	# show accent colors on title bars and window borders
		# set dark wallpaper if it's currently Windows 11 light wallpaper:
		if ($osDetails.ReleaseVersion.Major -eq 11) {
			$wp = GetRegPropertyValue -registryPath $hkcuCtrlDesktop -propertyName 'WallPaper'
			if ($wp -like '*\img0.jpg')	{
				$newWpPath = $wp -replace '\\img0\.jpg','\img19.jpg'
				SetRegistryEntry -p $hkcuCtrlDesktop -n 'WallPaper' -v $newWpPath -t 'String'
				[AckWare.WallpaperHelper]::SetWallpaper($newWpPath)
			}
		}
		# show some icons on desktop
		SetRegistryEntry -p "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -n '{59031a47-3f72-44a7-89c5-5595fe6b30ee}' <# home folder #> -v 0 -t 'DWord'
		SetRegistryEntry -p "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -n '{20D04FE0-3AEA-1069-A2D8-08002B30309D}' <# This PC #> -v 0 -t 'DWord'
		SetRegistryEntry -p "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -n '{F02C1A0D-BE21-4350-88B0-7367FC96EF3C}' <# Network #> -v 0 -t 'DWord'
		#SetRegistryEntry -p "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -n '{5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0}' <# Control Panel #> -v 0 -t 'DWord'
		#SetRegistryEntry -p "$hkcuCurrentVersionExplorer\HideDesktopIcons\NewStartPanel" -n '{018D5C66-4533-4307-9B53-224DE2ED1FE6}' <# OneDrive #> -v 0 -t 'DWord'
		# enable clipboard history:
		SetRegistryEntry -p "$hkcuSoftwareMicrosoft\Clipboard" -n 'EnableClipboardHistory' -v 1 -t 'DWord'
		# enable saving and restarting apps
		SetRegistryEntry -p "$hkcuCurrentVersionNT\Winlogon" -n 'RestartApps' -v 1 -t 'DWord'
		# disable Cortana autostarting: 0 = default (?); 1 = disabled, 2 = enabled
		SetRegistryEntry -p "$hkcuClasses\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\Microsoft.549981C3F5F10_8wekyb3d8bbwe\CortanaStartupId" -n 'State' -v 1 -t 'DWord'
		# enable long paths
		SetRegistryEntry -p "$hklmCurrCtrlSet\Control\FileSystem" -n 'LongPathsEnabled' -v 1 -t 'DWord'
		# disable Connected Standby:
		#SetRegistryEntry -p "$hklmCurrCtrlSet\Control\Power" -n 'CsEnabled' -v 0 -t 'DWord'
		if ($osDetails.ReleaseVersion.Major -eq 10) {
			# hide the People taskbar button
			SetRegistryEntry -p "$hkcuCurrentVersionExplorer\Advanced\People" -n 'PeopleBand' -v 0 -t 'DWord'
		} elseif ($osDetails.ReleaseVersion.Major -eq 11) {
			# turn on 'Compact view':
			SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'UseCompactMode' -v 1 -t 'DWord'
			# taskbar alignment: 1 = Center, 0 = Left
			SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'TaskbarAl' -v 1 -t 'DWord'
			# start menu layout: 0 = default; 1 = more pins, 2 = more recommendations
			SetRegistryEntry -p $hkcuCurrentVersionExplorerAdv -n 'Start_Layout' -v 1 -t 'DWord'
			# disable Teams autostarting: 0 = default (?); 1 = disabled, 2 = enabled
			SetRegistryEntry -p "$hkcuClasses\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData\MicrosoftTeams_8wekyb3d8bbwe\TeamsStartupTask" -n 'State' -v 1 -t 'DWord'
		}
		#
		# annoyances:
		#
		# disable Search Highlights:
		SetRegistryEntry -p "$hkcuCurrentVersion\Feeds\DSB" -n 'ShowDynamicContent' -v 0 -t 'DWord'
		SetRegistryEntry -p "$hkcuCurrentVersion\SearchSettings" -n 'IsDynamicSearchBoxEnabled' -v 0 -t 'DWord'
		# disable Search box on Taskbar
		SetRegistryEntry -p "$hkcuCurrentVersion\Search" -n 'SearchboxTaskbarMode' -v 0 -t 'DWord'
		# disable AdvertisingId ('The permission for apps to show me personalized ads by using my advertising ID')
		SetRegistryEntry -p "$hkcuCurrentVersion\AdvertisingInfo" -n 'Enabled' -v 0 -t 'DWord'
		# disable Windows Welcome Experience ('The Windows welcome experiences after updates and occasionally when I sign in to highlight what's new and suggested')
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SubscribedContent-310093Enabled' -v 0 -t 'DWord'
		# disable app suggestions in the Start menu
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SubscribedContent-338388Enabled' -v 0 -t 'DWord'
		# disable Windows Tips ('getting tip and suggestions when I use Windows')
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SubscribedContent-338389Enabled' -v 0 -t 'DWord'
		# disable SuggestedContent ('suggestion content in the Settings app')
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SubscribedContent-338393Enabled' -v 0 -t 'DWord'
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SubscribedContent-353694Enabled' -v 0 -t 'DWord'
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SubscribedContent-353696Enabled' -v 0 -t 'DWord'
		# disable SilentInstalledAppsEnabled ('Automatic installing suggested apps')
		SetRegistryEntry -p $hkcuCurrentVersionCntntDlvry -n 'SilentInstalledAppsEnabled' -v 0 -t 'DWord'
		# disable 'Ways to get the most out of Windows and finish setting up this device'
		SetRegistryEntry -p "$hkcuCurrentVersion\UserProfileEngagement" -n 'ScoobeSystemSettingEnabled' -v 0 -t 'DWord'
		# disable Tailored Experiences ('let Microsoft use your diagnostic data for personalized tips, ads, and recommendations')
		SetRegistryEntry -p "$hkcuCurrentVersion\Privacy" -n 'TailoredExperiencesWithDiagnosticDataEnabled' -v 0 -t 'DWord'
		# disable First Logon Animation
		SetRegistryEntry -p "$hklmSoftware\Microsoft\Windows NT\CurrentVersion\Winlogon" -n 'EnableFirstLogonAnimation' -v 0 -t 'DWord'
		# Hide recently added apps in the Start menu
		SetRegistryEntry -p "$hklmPoliciesMicrosoft\Windows\Explorer" -n 'HideRecentlyAddedApps' -v 1 -t 'DWord'
		## disable XXXXXXXX ('zzzzzzzz')
		#SetRegistryEntry -p 'XXXXXXX' -n 'ZZZZZZZZ' -v 0 -t 'DWord'
	}

	# add Open With Notepad:
	#SetRegistryEntry -p "$hkcuClasses\*\shell\Notepad" -n '(default)' -v 'Open with Notepad' -t 'String'
	#SetRegistryEntry -p "$hkcuClasses\*\shell\Notepad" -n 'Icon' -v '%SystemRoot%\system32\notepad.exe' -t 'ExpandString'
	#SetRegistryEntry -p "$hkcuClasses\*\shell\Notepad\Command" -n '(default)' -v '%SystemRoot%\system32\notepad.exe "%1"' -t 'ExpandString'
	# disable ShutdownEventTracker
	#SetRegistryEntry -p "$hklmPoliciesMicrosoft\Windows NT\Reliability" -n 'ShutdownReasonOn' -v 0 -t 'DWord'

	# disable Google crapware installs
	$googleAds = "$hklmSoftware\Google\No Chrome Offer Until"; $googleAdsWow = "$hklmSoftware\Wow6432Node\Google\No Chrome Offer Until";
	SetRegistryEntry -p $googleAds -n 'Irfan Skiljan' -v 0x01404cff -t 'DWord'
	SetRegistryEntry -p $googleAds -n 'Piriform Ltd' -v 0x01404cff -t 'DWord'
	SetRegistryEntry -p $googleAds -n 'Irfan Skiljan' -v 0x01404cff -t 'DWord'
	SetRegistryEntry -p $googleAds -n 'Piriform Ltd' -v 0x01404cff -t 'DWord'
	if ((Is64BitOs)) {
		SetRegistryEntry -p $googleAdsWow -n 'Irfan Skiljan' -v 0x01404cff -t 'DWord'
		SetRegistryEntry -p $googleAdsWow -n 'Piriform Ltd' -v 0x01404cff -t 'DWord'
		SetRegistryEntry -p $googleAdsWow -n 'Irfan Skiljan' -v 0x01404cff -t 'DWord'
		SetRegistryEntry -p $googleAdsWow -n 'Piriform Ltd' -v 0x01404cff -t 'DWord'
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
		$hkcuPoliciesMicrosoft = "HKCU:\Software\Policies\Microsoft"
		# disable Edge adding icon to desktop
		SetRegistryEntry -p "$hklmPoliciesMicrosoft\EdgeUpdate" -n 'CreateDesktopShortcut{56EB18F8-B008-4CBD-B6D2-8C97FE7E9062}' -v 0 -t 'DWord'		# stable
		SetRegistryEntry -p "$hklmPoliciesMicrosoft\EdgeUpdate" -n 'CreateDesktopShortcut{2CD8A007-E189-409D-A2C8-9AF4EF3C72AA}' -v 0 -t 'DWord'		# beta
		SetRegistryEntry -p "$hklmPoliciesMicrosoft\EdgeUpdate" -n 'CreateDesktopShortcut{0D50BFEC-CD6A-4F9A-964C-C7416E3ACB10}' -v 0 -t 'DWord'		# dev
		SetRegistryEntry -p "$hklmPoliciesMicrosoft\EdgeUpdate" -n 'CreateDesktopShortcut{65C35B14-6C1D-4122-AC46-7148CC9D6497}' -v 0 -t 'DWord'		# canary
		# (try to) disable Edge First Run Page (not sure if this really works but we'll try it):
		SetRegistryEntry -p "$hklmPoliciesMicrosoft\MicrosoftEdge\Main" -n 'PreventFirstRunPage' -v 1 -t 'DWord'
		SetRegistryEntry -p "$hkcuPoliciesMicrosoft\MicrosoftEdge\Main" -n 'PreventFirstRunPage' -v 1 -t 'DWord'

		# there's also a group policy to disable that stupid first-run page, so try setting that too:
		$lgpoExe = LocateLgpoExe
		if ($lgpoExe) {
			$tmpFolder = GetAckTempFolder
			$policiesFile = Join-Path $tmpFolder 'edgePolicies.txt'
			if (Test-Path -Path $policiesFile -PathType Leaf) { Remove-Item -Path $policiesFile -Force }

			# "Prevent the First Run webpage from opening on Microsoft Edge"
			AddPolicySetting -f $policiesFile -s 'Computer' -p 'Software\Policies\Microsoft\MicrosoftEdge\Main' -t 'DWORD' -n 'PreventFirstRunPage' -v '1'
			AddPolicySetting -f $policiesFile -s 'User' -p 'Software\Policies\Microsoft\MicrosoftEdge\Main' -t 'DWORD' -n 'PreventFirstRunPage' -v '1'

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
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DWORD' -n 'NoAutoRebootWithLoggedOnUsers' -v '1'
	# notification level: # 0:NotConfigued, 1:Disabled, 2:NotifybeforeDownload, 3:NotifyBeforeInstallation, 4:ScheduledInstallation
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DWORD' -n 'AUOptions' -v '2'
	# ???
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DWORD' -n 'NoAutoUpdate' -v '0'
	# install during automatic maintenance (only used when AUOptions = 4)
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DELETE' -n 'AutomaticMaintenanceEnabled' -v $null
	# install updates on: 0 = Every day, 1 = Every Sunday, ..., 7 = Every Saturday
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DWORD' -n 'ScheduledInstallDay' -v '0'
	# install update at hour: 0 thru 23 (there's an 'Automatic' option, too, not sure what value that is)
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DWORD' -n 'ScheduledInstallTime' -v '3'
	# if AUOptions = 4 above, then can also "limit updating to a weekly, bi-weekly or monthly occurrence":
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DWORD' -n 'ScheduledInstallEveryWeek' -v '1'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DELETE' -n 'ScheduledInstallFirstWeek' -v $null
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DELETE' -n 'ScheduledInstallSecondWeek' -v $null
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DELETE' -n 'ScheduledInstallThirdWeek' -v $null
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DELETE' -n 'ScheduledInstallFourthWeek' -v $null
	# ???
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdateAuPath -t 'DELETE' -n 'AllowMUUpdateService' -v $null
	# "Specifies whether the Windows Update will use the Windows Power Management features to automatically wake up the system from sleep, if there are updates scheduled for installation."
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'AUPowerManagement' -v '0'
	<#
	# => think setting these is causing Windows Update to ignore the AUOptions above
	# "Specify the deadline before the PC will automatically restart to apply updates."
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'SetAutoRestartDeadline' -v '1'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'AutoRestartDeadlinePeriodInDays' -v '30'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'AutoRestartDeadlinePeriodInDaysForFeatureUpdates' -v '30'
	# newer versions of one above ??
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'SetComplianceDeadline' -v '1'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ConfigureDeadlineForQualityUpdates' -v '30'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ConfigureDeadlineGracePeriod' -v '7'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ConfigureDeadlineForFeatureUpdates' -v '30'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ConfigureDeadlineGracePeriodForFeatureUpdates' -v '7'
	#>
	# "Turn off auto-restart for updates during active hours"
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ConfigureDeadlineNoAutoReboot' -v '1'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'SetActiveHours' -v '1'
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ActiveHoursStart' -v '4'	# 4 a.m.
	AddPolicySetting -f $policiesFile -s 'Computer' -p $windowsUpdatePath -t 'DWORD' -n 'ActiveHoursEnd' -v '3'		# 3 a.m.

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

	AddPolicySetting -f $policiesFile -s 'Computer' -p 'Software\Policies\Microsoft\Windows Defender\Exclusions' -t 'DWORD' -n 'Exclusions_Paths' -v '1'
	$path = 'Software\Policies\Microsoft\Windows Defender\Exclusions\Paths'
	@(
		"$env:UserProfile\Apps\Utils\NirSoft"
		"$env:UserProfile\Installs\system utils\NirSoft Utils"
		("$env:UserProfile\Backups\Apps\Utils\NirSoft" -replace 'C:\\'<#regex#>,'D:\')
		("$env:UserProfile\Backups\Installs\system utils\NirSoft Utils" -replace 'C:\\'<#regex#>,'D:\')
		'I:\utils\NirSoft'
		'W:\Apps\Utils\NirSoft'
		'W:\Installs\system utils\NirSoft Utils'
		'\\wallach9\backups\Arrakis\Apps\Utils\NirSoft'
		'\\wallach9\installs\system utils\NirSoft Utils'
		'\\wallach9\windowsBackup'
	) | ForEach-Object {
		AddPolicySetting -f $policiesFile -s 'Computer' -p $path -t 'SZ' -n $_ -v '0'
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
		[Parameter(Mandatory=$true)] [Alias('p','path')] [string]$registryPath,
		[Parameter(Mandatory=$true)] [Alias('n','name')] [string]$propertyName,
		[Parameter(Mandatory=$true)] [Alias('v','value')] [object]$propertyValue,
		[Parameter(Mandatory=$false)] [Alias('t','type')] [string]$propertyType = 'String'
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
		[Parameter(Mandatory=$true)] [Alias('f')] [string] $policyFilepath,
		[Parameter(Mandatory=$true)] [Alias('s')] [ValidateSet('Computer', 'User')] [string] $scope,
		[Parameter(Mandatory=$true)] [Alias('p')] [string] $path,
		[Parameter(Mandatory=$true)] [Alias('t')] [ValidateSet('DWORD', 'SZ', 'EXSZ', 'CLEAR', 'DELETE')] [string] $valueType,
		[Parameter(Mandatory=$true)] [Alias('n')] [string] $valueName,
		[Parameter(Mandatory=$false)] [Alias('v')] [string] $value
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
namespace AckWare {
	using System.Runtime.InteropServices;

	internal class Natives {
		//
		// for setting wallpapaer:
		internal const int SetDesktopWallpaper = 20;
		internal const int UpdateIniFile = 0x01;
		internal const int SendWinIniChange = 0x02;

		[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
		internal static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
		//

		//
		// for setting user rights:
		// from ntlsa.h:
		internal const uint POLICY_ALL_ACCESS = 0x000f0fff;

		internal const uint STATUS_SUCCESS = 0;
		internal const uint STATUS_ACCESS_DENIED = 0xc0000022;
		internal const uint STATUS_INSUFFICIENT_RESOURCES = 0xc000009a;
		internal const uint STATUS_NO_MEMORY = 0xc0000017;

		[StructLayout(LayoutKind.Sequential)]
		internal struct LSA_OBJECT_ATTRIBUTES {
			public int Length;
			public IntPtr RootDirectory;
			public IntPtr ObjectName;
			public int Attributes;
			public IntPtr SecurityDescriptor;
			public IntPtr SecurityQualityOfService;
		}

		[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
		internal struct LSA_UNICODE_STRING {
			public ushort Length;
			public ushort MaximumLength;
			[MarshalAs(UnmanagedType.LPWStr)]
			public string Buffer;
		}

		[StructLayout(LayoutKind.Sequential)]
		internal struct LSA_TRANSLATED_SID2 {
			public int Use;		// SID_NAME_USE; see winnt.h
			public IntPtr Sid;
			public int DomainIndex;
			public uint Flags;
		}

		[DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true)]
		internal static extern uint LsaOpenPolicy(LSA_UNICODE_STRING[] systemName, ref LSA_OBJECT_ATTRIBUTES objectAttributes, uint desiredAccess, out SafeLsaPolicyHandle policyHandle);

		[DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true)]
		internal static extern uint LsaAddAccountRights(SafeLsaPolicyHandle policyHandle, IntPtr pSid, LSA_UNICODE_STRING[] userRights, int countOfRights);

		[DllImport("advapi32", CharSet = CharSet.Unicode, SetLastError = true)]
		internal static extern uint LsaLookupNames2(SafeLsaPolicyHandle policyHandle, uint flags, uint count, LSA_UNICODE_STRING[] names, ref IntPtr referencedDomains, ref IntPtr sids);

		[DllImport("advapi32")]
		internal static extern /*u*/int LsaNtStatusToWinError(uint ntStatus);

		[DllImport("advapi32")]
		internal static extern uint LsaClose(IntPtr policyHandle);

		[DllImport("advapi32")]
		internal static extern int LsaFreeMemory(IntPtr buffer);
	}

	public class WallpaperHelper {
		public static void SetWallpaper(string path) {
			Natives.SystemParametersInfo(Natives.SetDesktopWallpaper, 0, path, Natives.UpdateIniFile | Natives.SendWinIniChange);
		}
	}

	public class SafeLsaPolicyHandle : Microsoft.Win32.SafeHandles.SafeHandleZeroOrMinusOneIsInvalid {
		internal SafeLsaPolicyHandle() : base(true) { }

		protected override bool ReleaseHandle() {
			return Natives.LsaClose(base.handle) == Natives.STATUS_SUCCESS;
		}
	}

	public static class LsaHelper {
		public static void AddUserRight(string accountName, string privilegeName) {    // for privilege names, see winnt.h, "NT Defined Privileges"
			using (SafeLsaPolicyHandle policyHandle = GetPolicyHandle()) {
				AddAccountRights(policyHandle, accountName, privilegeName);
			}
		}

		private static SafeLsaPolicyHandle GetPolicyHandle() {
			// https://learn.microsoft.com/en-us/windows/win32/secmgmt/opening-a-policy-object-handle
			// https://learn.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaopenpolicy
			Natives.LSA_OBJECT_ATTRIBUTES objAttrs = new Natives.LSA_OBJECT_ATTRIBUTES();
			objAttrs.RootDirectory = objAttrs.ObjectName = objAttrs.SecurityDescriptor = objAttrs.SecurityQualityOfService = IntPtr.Zero;
			objAttrs.Attributes = 0;
			objAttrs.Length = Marshal.SizeOf(typeof(Natives.LSA_OBJECT_ATTRIBUTES));
			Natives.LSA_UNICODE_STRING[] systemName = null;
			SafeLsaPolicyHandle policyHandle = null;

			uint ntStatus = Natives.LsaOpenPolicy(systemName, ref objAttrs, Natives.POLICY_ALL_ACCESS, out policyHandle);
			ValidateNtStatus(ntStatus);
			return policyHandle;
		}

		private static void AddAccountRights(SafeLsaPolicyHandle policyHandle, string accountName, string privilegeName) {
			// https://learn.microsoft.com/en-us/windows/win32/secmgmt/managing-account-permissions
			// https://learn.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaaddaccountrights
			IntPtr accountSid = GetSidForName(policyHandle, accountName);
			Natives.LSA_UNICODE_STRING[] lsaPrivileges = new Natives.LSA_UNICODE_STRING[1];
			lsaPrivileges[0] = InitLsaString(privilegeName);

			uint ntStatus = Natives.LsaAddAccountRights(policyHandle, accountSid, lsaPrivileges, lsaPrivileges.Length);
			ValidateNtStatus(ntStatus);
		}

		private static IntPtr GetSidForName(SafeLsaPolicyHandle policyHandle, string accountName) {
			// https://learn.microsoft.com/en-us/windows/win32/secmgmt/translating-between-names-and-sids
			// but using LsaLookupNames2 here
			// TODO?: could also get SID in powershell with
			//    [System.Security.Principal.NTAccount]::new(`$env:UserName).Translate([System.Security.Principal.SecurityIdentifier]).Value
			// but that's a string, has to be converted with ConvertStringSidToSid back to a PSID
			Natives.LSA_UNICODE_STRING[] names = new Natives.LSA_UNICODE_STRING[1];
			names[0] = InitLsaString(accountName);
			IntPtr pSids = IntPtr.Zero;
			IntPtr pDomains = IntPtr.Zero;

			uint ntStatus = Natives.LsaLookupNames2(policyHandle, 0, 1, names, ref pDomains, ref pSids);
			ValidateNtStatus(ntStatus);
			Natives.LSA_TRANSLATED_SID2 lts = (Natives.LSA_TRANSLATED_SID2)Marshal.PtrToStructure(pSids, typeof(Natives.LSA_TRANSLATED_SID2));
			Natives.LsaFreeMemory(pSids);
			Natives.LsaFreeMemory(pDomains);
			return lts.Sid;		// TODO: does this need to be freed? cuz we're just returning raw IntPtr and caller above is not freeing anything
		}

		private static Natives.LSA_UNICODE_STRING InitLsaString(string value) {
			// https://learn.microsoft.com/en-us/windows/win32/secmgmt/using-lsa-unicode-strings
			if (value.Length > 32766) throw new ArgumentException("value is too long");
			Natives.LSA_UNICODE_STRING lus = new Natives.LSA_UNICODE_STRING();
			lus.Buffer = value;
			lus.Length = (ushort)(value.Length * sizeof(char));
			lus.MaximumLength = (ushort)(lus.Length + sizeof(char));	// length including null term
			return lus;
		}

		private static void ValidateNtStatus(uint ntStatus) {
			switch (ntStatus) {
				case Natives.STATUS_SUCCESS:
					return;
				case Natives.STATUS_ACCESS_DENIED:
					throw new UnauthorizedAccessException("Access Denied: make sure you're running with elevated privs");
				case Natives.STATUS_INSUFFICIENT_RESOURCES:
				case Natives.STATUS_NO_MEMORY:
					throw new OutOfMemoryException();
				default:
					throw new System.ComponentModel.Win32Exception(Natives.LsaNtStatusToWinError(ntStatus));
			}
		}
	}
}
"@

#==============================
Main -onlyEnvVars:$onlyEnvVars -onlyWinExplrFlags:$onlyWinExplrFlags -onlyEdgeBrowser:$onlyEdgeBrowser -onlyWinUpdate:$onlyWinUpdate  `
		-onlyPowerMngmnt:$onlyPowerMngmnt -onlyNetworking:$onlyNetworking -onlyDefenderExcl:$onlyDefenderExcl
#==============================