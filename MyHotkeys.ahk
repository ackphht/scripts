#Requires AutoHotkey >=2.0
#SingleInstance force	; if script is launched while a previous instance is already running, automatically reload

gHomeComputerName := "arrakis"
;gWorkComputerName := "corrin"
;gNotebookName := "binkley"

gOSVersion := Float(RegExReplace(A_OSVersion, "(\d+\.\d+)\.\d+", "$1"))
gOSBuild := Integer(RegExReplace(A_OSVersion, "\d+\.\d+\.(\d+)", "$1"))
gEnableExplorerMultiTab := true
gWin1122h2Build := 22621
gWin1123h2Build := 22631

gProgramFiles := EnvGet("ProgramFiles")			; default for the platform (64 or 32 bit)
gProgramFiles64 := EnvGet("ProgramW6432")		; explicit for 64 bit
if (!gProgramFiles64)							; 32bit OS won't have above
	gProgramFiles64 := gProgramFiles
gProgramFiles32 := EnvGet("ProgramFiles(x86)")	; explicit for 32 bit
if (!gProgramFiles32)							; 32bit OS won't have above
	gProgramFiles32 := gProgramFiles
OutputDebug(gProgramFiles . ' is equal to "' . gProgramFiles . '", gProgramFiles32 is equal to "' . gProgramFiles32 . '"')

gOneDrive := EnvGet("OneDriveConsumer")
if (!gOneDrive)
	gOneDrive := EnvGet("OneDrive")
if (!gOneDrive)
	gOneDrive := EnvGet("UserProfile") . "\OneDrive"

;gUseXplorer2 := false

WS_EX_APPWINDOW := 0x40000
WS_EX_TOOLWINDOW := 0x80
GW_OWNER := 4

gExplorerMyComputerGuid := "::{20d04fe0-3aea-1069-a2d8-08002b30309d}"
; used in OpenFolderXxxxx() below for opening Explorer windows:
gExplorerClassPostVista := "ahk_class CabinetWClass"
GroupAdd "Explorer", "ahk_class ExploreWClass" ; Unused on Vista and later
GroupAdd "Explorer", gExplorerClassPostVista

/*
	# = Windows key
	^ = Control key
	+ = Shift key
	! = Alt key
*/
#Numpad0:: {
	newline := "`n"
	msg := ""
	msg .= "A_AhkVersion = " . A_AhkVersion . newline
	msg .= "A_ScriptName = '" . A_ScriptName . newline
	msg .= "A_ScriptDir = '" . A_ScriptDir . newline
	msg .= newline
	msg .= "A_OSVersion = " . A_OSVersion . newline
	msg .= "A_Is64bitOS = " . A_Is64bitOS . newline
	msg .= "A_Language = '" . A_Language . "'" . newline
	msg .= "A_ComputerName = '" . A_ComputerName . "'" . newline
	msg .= "A_UserName = '" . A_UserName . "'" . newline
	msg .= "UserProfile = '" . EnvGet("UserProfile") . "'" . newline
	msg .= "A_IsAdmin = " . A_IsAdmin . newline
	;msg .= "A_StringCaseSense  = '" . A_StringCaseSense . "'" . newline	; removed in v2
	msg .= "A_ScreenWidth = " . A_ScreenWidth . newline
	msg .= "A_ScreenHeight = " . A_ScreenHeight . newline
	msg .= "A_ScreenDPI  = " . A_ScreenDPI  . newline
	for (index,address in SySGetIPAddresses())
		msg .= "IPAddress #" . index . " = " . address . newline
	msg .= newline
	msg .= "A_ThisHotkey = " . A_ThisHotkey . newline
	msg .= "A_PriorHotkey = " . A_PriorHotkey . newline
	msg .= "A_Priorkey = " . A_Priorkey . newline
	MsgBox(msg)
}
#Numpad1:: {
	newline := "`n"
	msg := "active window properties:" . newline
	msg .= "Title = |" . WinGetTitle("A") . "|" . newline
	msg .= "Class = |" . WinGetClass("A") . "|" . newline
	msg .= "HWND = 0x" . Format("{1:08x}", WinGetID("A")) . newline
	msg .= "PID = " . WinGetPID("A") . newline
	msg .= "Process name = |" . WinGetProcessName("A") . "|" . newline
	msg .= "Process path = |" . WinGetProcessPath("A") . "|" . newline
	MsgBox(msg)
}

/*
	Starting programs
	# = Win  /  ^ = Ctrl  /  + = Shift  /  ! = Alt
*/
#Esc::Run("procexp.exe /e")
^#a::Run(gOneDrive . "\Utils\RandomMusicPicker.exe randomPlaylist")
^#b::Run(FindSyncBackPro(false))
^!#b::Run(FindSyncBackPro(true))
^#c::Run('wt.exe --window last --profile "PowerShell"')		; https://learn.microsoft.com/en-us/windows/terminal/command-line-arguments
^!#c::RunElevated("wt.exe", '--window last --profile "PowerShell"')
^+#c::Run(FindPowerShellCore(), EnvGet("UserProfile"))
^+!#c::RunElevated(FindPowerShellCore(), '-NoExit -Command &{Set-Location -LiteralPath "$env:UserProfile"}')
^#e::Run('wt.exe --window last --profile "Windows PowerShell"')
^!#e::RunElevated("wt.exe", '--window last --profile "Windows PowerShell"')
^+#e::Run(FindPowerShell(), EnvGet("UserProfile"))
^+!#e::RunElevated(FindPowerShell(), '-NoExit -Command &{Set-Location -LiteralPath "$env:UserProfile"}')
^#h::ToggleSuperHiddenFiles()
^#m::LookForAndRunMsdnHelp()
^#n::RunAndActivate(FindNotepad3())
^!#n::RunNotepadPlusPlus()
^#o::RunOneNote()
!#p::RunAndActivate("shell:AppsFolder\8bitSolutionsLLC.bitwardendesktop_h4e712dmw3xyy!bitwardendesktop")
^#s::RunAndActivate(gOneDrive . "\Utils\RandomMusicPicker.exe randomSongs")
+#t::Run("control.exe AdminTools")		; think there used to be a CLSID for this but doesn't exist anymore ??
^#x::Run('wt.exe --window last --profile "Command Prompt"')
^#!x::RunElevated("wt.exe", '--window last --profile "Command Prompt"')
^+#x::Run(A_ComSpec . ' /k "cd "%UserProfile%""')
^+#!x::RunElevated(A_ComSpec, ' /k "cd "%UserProfile%""')
^#z::Run("zoomit.exe")

/*
	opening folders
	# = Win  /  ^ = Ctrl  /  + = Shift  /  ! = Alt
*/
+#a::OpenFolder(A_AppData)
^+#a::OpenFolder(EnvGet("UserProfile") . "\Apps")
^+#b::OpenFolder(EnvGet("UserProfile") . "\Books")
+#c::Run("control.exe")				; open Control Panel
+#d::OpenFolder(A_MyDocuments)
^+#d::OpenFolder(EnvGet("UserProfile") . "\Downloads")
^+#f::OpenFolder(EnvGet("UserProfile") . "\Development\foss")
+#h::OpenFolder(EnvGet("UserProfile"))
^+#h::OpenFolder(StrReplace(EnvGet("UserProfile"), "C:\", "D:\"))
+#l::OpenFolder(EnvGet("LocalAppData"))
+#m::OpenFolder(EnvGet("UserProfile") . "\Music\MyMusic")
+#o::OpenFolder(EnvGet("UserProfile") . "\OneDrive")
+#p::OpenFolder(EnvGet("UserProfile") . "\Pictures")
^+#p::OpenFolder(gProgramFiles)								; open program files
!+#p::OpenFolder(gProgramFiles32)							; open program files (x86)
^!#p::OpenFolder(EnvGet("LocalAppData") . "\Programs")				; open user program files
+#q::OpenFolder(EnvGet("UserProfile") . "\Development\MyProjects")
^+#s:: {
	OpenFolder(A_ProgramsCommon)
	OpenFolder(A_Programs)
}
^+#t::OpenFolder(A_Temp)
+#u::OpenFolder(EnvGet("UserProfile") . "\Apps\Utils")
^+#u::OpenFolder(EnvGet("UserProfile") . "\OneDrive\Utils")
^+#v::OpenFolder(EnvGet("UserProfile") . "\Videos")
+#w::LookForAndOpenWarezFolder()
^+#w::LookForAndOpenWorkProjectsFolder()
+#y::OpenFolder(gExplorerMyComputerGuid)	; open My Computer
+#1::OpenFolder("C:\")
+#2::OpenFolder("D:\")
+#3::OpenFolder("E:\")
+#4::OpenFolder("F:\")
+#5::OpenFolder("G:\")
+#6::OpenFolder("H:\")
+#7::OpenFolder("I:\")
;+#8::OpenFolder("M:\")
+#0::OpenFolder("\\wallach9")

/*
	management-type stuff
	# = Win  /  ^ = Ctrl  /  + = Shift  /  ! = Alt
*/
; see http://support.microsoft.com/kb/192806 and http://support.microsoft.com/kb/180025/en-us for some more of these
#F2::Run("mmc.exe " . A_WinDir . "\system32\compmgmt.msc")
+#F2::LookForAndStartServerManager()
#F3::Run("mmc.exe " . A_WinDir . "\system32\devmgmt.msc")
+#F3::Run("mmc.exe " . A_WinDir . "\system32\diskmgmt.msc")
#F4::Run("control.exe /name Microsoft.NetworkAndSharingCenter")
+#F4::Run("control.exe netconnections")	; or can run ncpa.cpl
#F5::Run("control.exe schedtasks")
+#F5::RunElevated("RunAsS.exe", A_WinDir . "\system32\mmc.exe " . A_WinDir . "\system32\taskschd.msc")
#F6::Run("mmc.exe " . A_WinDir . "\system32\lusrmgr.msc")
#F7::Run("control.exe powercfg.cpl")
#F8::Run(A_WinDir . "\system32\inetsrv\InetMgr.exe")
#F9::Run("mmc.exe " . A_WinDir . "\system32\eventvwr.msc")
#F10::Run("mmc.exe " . A_WinDir . "\system32\services.msc")
+#F10::RunElevated("RunAsS.exe", A_WinDir "\system32\mmc.exe " A_WinDir "\system32\services.msc")
#F11:: {
	if (gOSBuild < 10240) {	; if < Win10; actually this probably needs more accurate build# since it was later versions of Win10 that moved this
		Run("control.exe appwiz.cpl")
	} else {
		Run("ms-settings:appsfeatures")
	}
}
+#F11:: {
	if (gOSBuild < 10240) {	; if < Win10; actually this probably needs more accurate build# since it was later versions of Win10 that moved this
		Run("control.exe wuaucpl.cpl")
	} else {
		Run("ms-settings:windowsupdate")
	}
}
^+#F11:: {
	if (gOSBuild >= 22000) {
		Run("ms-settings:defaultapps")
	}
}
!+#F11:: {
	if (gOSBuild >= 22000) {
		Run("ms-windows-store://downloadsandupdates")
	}
}
^#F11::Run("optionalFeatures.exe")
!#F11::Run("control.exe appwiz.cpl")
#F12::Run("regedit.exe")
+^#F12::Run("taskkill.exe /f /im explorer.exe")		; kill explorer.exe (since Win11 took away the taskbar way to do it); and have to use '/F', explorer doesn't exit when asked politely
+#!d::RunElevated("cleanmgr.exe", "")	; Disk Cleanup
+#!i::Run("inetcpl.cpl")	; internet/IE properties
+#!m::Run("mmsys.cpl")		; Sound control panel applet
+#!s::Run("sysdm.cpl")		; old system properties dialog
^!#i::ResetIconCache()
^!#o::TurnOffMonitors()
^!#s::StartScreenSaver()
+^!#s::Run("control.exe desk.cpl,,@screensaver")
;^!#v::EnvUpdate		;RefreshEnvVars()		; EnvUpdate was removed for v2; didn't really work anyway, i don't think
; to refresh env vars in the script, have to use OnMessage(), and then there's this that some dudes wrote:
;    https://www.autohotkey.com/board/topic/63858-function-to-refresh-environment-variables/#post_id_402972
;    https://www.autohotkey.com/board/topic/63858-function-to-refresh-environment-variables/#post_id_735136

/*
	utility stuff
	# = Win  /  ^ = Ctrl  /  + = Shift  /  ! = Alt
*/
^#!g:: {					; create a guid and paste it into the current window
	guid := CreateGuid()
	;A_Clipboard := guid
	;SendInput("^v")
	SendInput(guid)
}
^#!m:: {
	static pattern := "https://www\.amazon\.com/music/player/albums/(\w+)\?.*"
	maybeUrl := A_Clipboard
	if (RegExMatch(maybeUrl, pattern)) {
		A_Clipboard := RegExReplace(maybeUrl, pattern, "https://www.amazon.com/dp/$1")
	}
}
$^q:: {	; '$' needed so that we can do the Send below without getting in a loop??
	activeWinProcName := WinGetProcessName("A")
	if (activeWinProcName != "OUTLOOK.EXE" && activeWinProcName != "devenv.exe" && activeWinProcName != "kleopatra.exe") {
		SendInput("{LAlt down}{F4}{LAlt up}")
	} else {
		Send("^q")
	}
}

/*
	text replacements
	see https://textfac.es/ or http://cutekaomoji.com/ for more face thingys
*/
:*:/dunno/::¯\_(ツ)_/¯
:*:/shrug/::¯\_(ツ)_/¯
:*:/lenny/::( ͡° ͜ʖ ͡°)
:*:/dealwithit/::(▀̿Ĺ̯▀̿ ̿)
:*:/what/::ಠ_ಠ
:*:/happy/::ᕕ( ᐛ )ᕗ

/*
	functions
*/
FindApp(regAppPathName, programFilesRelPath := "", fallbackExe := "") {
	appPath := CheckRegistryForAppPath(regAppPathName)
	if (!appPath or !FileExist(appPath)) {
		if (programFilesRelPath) {
			appPath := gProgramFiles . programFilesRelPath
			if (!FileExist(appPath)) {
				appPath := gProgramFiles32 . programFilesRelPath
				if (!FileExist(appPath)) {
					appPath := fallbackExe
				}
			}
		} else {
			appPath := fallbackExe
		}
	}
	OutputDebug('FindApp: returning path "' . appPath . '"')
	return appPath
}

RunOneNote() {
	if (WinExist("ahk_exe onenote.exe")) {
		OutputDebug('RunOneNote: activating existing OneNote instance')
		WinActivate("ahk_exe onenote.exe")
	} else {
		OutputDebug('RunOneNote: no existing OneNote instance found, getting path')
		oneNotePath := FindApp("OneNote")
		if (oneNotePath != "") {
			RunAndActivate(oneNotePath)
		} else {
			MsgBox("Could not find OneNote.")
		}
	}
}

FindPowerShell() {
	poshPath := CheckRegistryForAppPath("PowerShell")
	if (!FileExist(poshPath)) {
		poshPath := A_WinDir . "\system32\WindowsPowerShell\v1.0\powershell.exe"
		if (!FileExist(poshPath)) {
			poshPath := "powershell.exe"	; just hope it's on the path
		}
	}
	OutputDebug('FindPowerShell: returning powershell path "' . poshPath . '"')
	return poshPath
}

FindPowerShellCore() {
	return FindApp("pwsh", "", "pwsh.exe")
}

FindNotepad3() {
	return FindApp("notepad3", "\Notepad3\notepad3.exe", "notepad.exe")
}

FindNotepadPlusPus() {
	return FindApp("notepad++", "\Notepad++\notepad++.exe")
}

FindSyncBackPro(asAdmin := false) {
	appPath := FindApp("SyncBackPro", "\2BrightSparks\SyncBackPro\SyncBackPro.exe")
	if (appPath and !asAdmin) {
		appPath := RegExReplace(appPath, "(\.exe)$", ".NE$1")
	}
	OutputDebug('FindSyncBackPro: returning path "' . appPath . '"')
	return appPath
}

RunNotepadPlusPlus() {
	notepadPlusPlusPath := FindNotepadPlusPus()
	if (notepadPlusPlusPath != "") {
		RunAndActivate(notepadPlusPlusPath)
	} else {
		MsgBox("Could not find Notepad++.")
	}
}

CheckRegistryForAppPath(appName) {
	try{
		appPath := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\App Paths\" . appName . ".exe", "")
	} catch OSError {
		appPath := ""		; reg key or value does not exist
	}
	if (!appPath) {
		try{
			appPath := RegRead("HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . appName . ".exe", "")
		} catch OSError {
			appPath := ""	; reg key or value does not exist
		}
	}
	OutputDebug('CheckRegistryForAppPath: for appName "' . appName . '", returning path "' . appPath . '"')
	return appPath
}

OpenFolder(folderName, asAdmin := false) {
	if (gEnableExplorerMultiTab and gOSBuild >= gWin1122h2Build) {
		; with Win11 22H2 they added tabs to Explorer, but it's lame, so we have to explicitly open
		; new tabs ourselves; this is not pretty and kinda janky, but it's working:
		OpenFolderWithExplicitTabs(folderName)
	} else {
		OpenFolderDefault(folderName, asAdmin)
	}
}

gMaxExplorerActivationAttempts := 20
OpenFolderWithExplicitTabs(folderName) {
	explorerHwnd := WinExist(gExplorerClassPostVista)
	if (not explorerHwnd) {
		; no window currently open, open a new explorer window, make sure it's activated
		Run('"' . folderName . '"')
		attemptNumber := 0
		while (!WinExist(gExplorerClassPostVista) && attemptNumber < gMaxExplorerActivationAttempts) {
			Sleep(100)
		}
		if (attemptNumber >= gMaxExplorerActivationAttempts) {
			throw Error("could not find instance of Explorer to activate")
		}
		WinActivate(gExplorerClassPostVista)
	} else {
		WinActivate {Hwnd: explorerHwnd}
		;while (!WinActive(gExplorerClassPostVista)) {
		;	Sleep(50)
		;}
		WinWaitActive(gExplorerClassPostVista)
		Sleep(250)
		Send("^t")
		Sleep(250)
		;Sleep(500)
		;Send("{F4}") ;Send("!d")
		;Sleep(250)
		;;SendText(folderName)
		;SendInput("{Text}" . folderName)
		;Sleep(500)
		;Send("{Enter}")
		;;if (gOSBuild >= gWin1123h2Build) {	; new explorer pita
		;;	Sleep(250)
		;;	Send("{F4}")
		;;	Send("{Escape}")
		;;}
		; .Navigate() doesn't work with the guid thing, but we're only using one for MyComputer and that should be what opens by default anyway, so:
		if (folderName != gExplorerMyComputerGuid) {
			; from https://www.reddit.com/r/AutoHotkey/comments/ybumnu/windows_11_launch_a_directory_in_windows_explorer/
			explorerWin := ComObject("Shell.Application").Windows()
			if (explorerWin.Count > 0) {
				last := explorerWin.Item(explorerWin.Count - 1)
				;MsgBox(last.LocationName " :: " last.LocationURL)
				last.Navigate(folderName)
			} else {
				MsgBox("no Windows")
			}
		}
	}
}

OpenFolderDefault(folderName, asAdmin := false) {
	;global gXplorer2Path, gUseXplorer2
	;if (InStr(FileExist(folderName), "D")) {	; FileExist()/DirExist() doen't work very well with network shares
		;if (gUseXplorer2 AND gXplorer2Path != "" AND IsXplorer2Running()) {
		;	RunXplorer2(folderName, asAdmin)
		;} else {
			try {
				Run('"' . folderName . '"')
				Sleep(1000)	; give it a moment otherwise next part happens to soon and brings up wrong window
				try {
					WinActivate("ahk_group Explorer")	; should only activate the most recently active explorer window, which should be the one we just opened; but do we need a short sleep or something?
				} catch TargetError {
					; above throws if no Explorer window was open before; eat it
				}
			} catch {	; only throws generic Error object, and Message is unhelpful, so just display generic message
				MsgBox("could not open folder '" . folderName . "'")
			}
		;}
	;} else {
	;	OutputDebug('folder "' . folderName . '" does not exist')
	;}
}

RunAndActivate(target, arguments := "", workingDir := "") {
	if (arguments) {
		Run(target . " " . arguments, workingDir,, &newAppPid)
	} else {
		Run(target, workingDir,, &newAppPid)
	}
	if (newAppPid) {	; 'target' has to point to an actual .exe in order to get back a valid process id; if you try to start something like a url or a document (doing a ShellExecute kinda thing), this will not be populated
		WinWait("ahk_pid " . newAppPid)
		WinActivate("ahk_pid " . newAppPid)
	}
}

RunElevated(target := "", arguments := "", workingDir := "") {
	;DllCall("shell32\ShellExecuteW", "UInt", 0, "WStr", "RunAs", "WStr", target, "WStr", arguments, "WStr", workingDir, "Int", 1)  ; Last parameter: SW_SHOWNORMAL = 1
	Run("*RunAs " . target . " " . arguments, workingDir)
}

SendInputU(p_text) {
	;StringLen, len, p_text
	len := StrLen(p_text)

	INPUT_size := 28

	event_count := (len // 4) * 2
	;VarSetCapacity(events, INPUT_size * event_count, 0)
	events := Buffer(INPUT_size * event_count)

	;loop, % event_count//2	;% notepad++ syntax highlighting gets confused with the mod operator (thinks it's an unclosed percent sign)
	loop (event_count // 2) {
		;StringMid, code, p_text, ( A_Index-1 )*4+1, 4
		code := SubStr(p_text, ((A_Index - 1) * 4 + 1), 4)

		base := ( ( A_Index-1 )*2 )*INPUT_size+4
		EncodeInteger(1, 4, &events, base - 4)
		EncodeInteger("0x" code, 2, &events, base + 2)
		EncodeInteger(4, 4, &events, base + 4) ; KEYEVENTF_UNICODE

		base += INPUT_size
		EncodeInteger(1, 4, &events, base - 4)
		EncodeInteger("0x" code, 2, &events, base + 2)
		EncodeInteger(2 | 4, 4, &events, base + 4) ; KEYEVENTF_KEYUP|KEYEVENTF_UNICODE
	}

	result := DllCall("SendInput", "UInt", event_count, "UInt", &events, "Int", INPUT_size)
	;if (ErrorLevel OR result < event_count) {
	if (A_LastError OR result < event_count) {	; ???
		;MsgBox, [SendInput] failed: EL = %ErrorLevel% ~ %result% of %event_count%
		MsgBox("[SendInput] failed: error code = " . A_LastError . " ~ " . result . " of " . event_count)
		return false
	}
	return true
}

EncodeInteger(p_value, p_size, p_address, p_offset) {
	loop p_size {
		DllCall( "RtlFillMemory", "UInt", (p_address + p_offset + A_Index - 1), "UInt", 1, "UChar", (p_value >> (8 * (A_Index - 1))) & 0xFF)
	}
}

ToggleSuperHiddenFiles() {
	try {
		HiddenFiles_Status := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowSuperHidden")
	} catch OSError {
		; reg key or value does not exist, default to 0:
		HiddenFiles_Status := 0
	}
	if (HiddenFiles_Status = 1) {
		RegWrite(0, "REG_DWORD", "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowSuperHidden")
	} else {
		RegWrite(1, "REG_DWORD", "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced", "ShowSuperHidden")
	}
	eh_Class := WinGetClass("A")
	if (eh_Class = "#32770" OR gOSVersion < 10.0) {		; if active window has class "#32770" (Explorer?) or OS is Win8.1 or less ???
		Send("{F5}")
	} else {
		PostMessage(0x111, 28931,,, "A")
	}
}

LookForAndRunMsdnHelp() {
	global gProgramFiles32
	if (FileExist(gProgramFiles32 . "\Microsoft Help Viewer\v2.3\HlpViewer.exe")) {
		Run(gProgramFiles32 . "\Microsoft Help Viewer\v2.3\HlpViewer.exe /catalogName VisualStudio15") ; /locale en-US ;/sku 1800
	} else if (FileExist(gProgramFiles32 . "\Microsoft Help Viewer\v2.2\HlpViewer.exe")) {
		Run(gProgramFiles32 . "\Microsoft Help Viewer\v2.2\HlpViewer.exe /catalogName VisualStudio14 /locale en-US") ;/sku 1800
	} else if (FileExist(gProgramFiles32 . "\Microsoft Help Viewer\v2.1\HlpViewer.exe")) {
		Run(gProgramFiles32 . "\Microsoft Help Viewer\v2.1\HlpViewer.exe /catalogName VisualStudio12 /locale en-US") ;/sku 2000
	} else if (FileExist(A_ProgramsCommon . "\Microsoft Visual Studio 2012\Microsoft Help Viewer.lnk")) {
		Run(A_ProgramsCommon . "\Microsoft Visual Studio 2012\Microsoft Help Viewer.lnk")
	} else if (FileExist(A_ProgramsCommon . "\Microsoft Visual Studio 2010\Microsoft Visual Studio 2010 Documentation.lnk")) {
		Run(A_ProgramsCommon . "\Microsoft Visual Studio 2010\Microsoft Visual Studio 2010 Documentation.lnk")
	} else if (FileExist(gProgramFiles32 . "\Common Files\Microsoft Shared\Help 9\dexplore.exe")) {
		Run(gProgramFiles32 . "\Common Files\Microsoft Shared\Help 9\dexplore.exe /helpcol ms-help://ms.vscc.v90 /LaunchNamedUrlTopic DefaultPage /usehelpsettings VisualStudio.9.0")
	} else {
		MsgBox("couldn't find a help viewer to start")
	}
}

LookForAndOpenWarezFolder() {
	userProfile := EnvGet("UserProfile")
	if (InStr(FileExist(userProfile . "\Installs"), "D")) {
		OpenFolder(userProfile . "\Installs")
	} else if (InStr(FileExist(userProfile . "\warez"), "D")) {
		OpenFolder(userProfile . "\warez")
	}
}

LookForAndOpenWorkProjectsFolder() {
	userProfile := EnvGet("UserProfile")
	if (InStr(FileExist(userProfile . "\Development"), "D")) {
		OpenFolder(userProfile . "\Development")
	} else if (InStr(FileExist("C:\Dev"), "D")) {
		OpenFolder("C:\Dev")
	}
}

LookForAndStartServerManager() {
	if (FileExist(A_WinDir . "\system32\ServerManager.msc")) {
		Run("mmc.exe " . A_WinDir . "\system32\ServerManager.msc")
	}
}

TurnOffMonitors() {
	Sleep(1000)	; give user time to release keys, so we don't wake up again when keys are released
	if (A_ComputerName != gHomeComputerName) {
		;Send #l	; lock workstation	;in AutoHotKey 1.0.48.01+, #l doesn't work anymore; see release notes for 1.0.48.01
		DllCall("LockWorkStation")
		Sleep(500)
	}
	PostMessage(0x112, 0xF170, 2,, "Program Manager")	; 0x112 is WM_SYSCOMMAND, 0xF170 is SC_MONITORPOWER.
}

StartScreenSaver() {
	PostMessage(0x112, 0xF140, 0,, "Program Manager")		; 0x112 is WM_SYSCOMMAND, and 0xF140 is SC_SCREENSAVE.
}

ResetIconCache() {
	DllCall("Shell32\SHChangeNotify", "UInt", 0x08000000, "UInt", 0, "Int", 0, "Int", 0)	; SHCNE_ASSOCCHANGED
}

;RefreshEnvVars() {
;	SendMessage, 0x001A,,,, ahk_id 0xFFFF  ; 0xFFFF is WM_BROADCAST, 0x001A is WM_SETTINGCHANGE.
;	or
;	SendMessage, 0x001A, 0, StrPtr("Environment"), , ahk_id 0xFFFF  ; 0xFFFF is WM_BROADCAST, 0x001A is WM_SETTINGCHANGE.
;}

CreateGuid() {
	pGuid := Buffer(16)
	DllCall("ole32\CoCreateGuid", "Ptr", pGuid)
	strGuid := Buffer(39 * 2)	; (32 guid chars, plus dashes, plus curly braces, plus null term) * 2 for utf16
	DllCall("ole32\StringFromGUID2", "Ptr", pGuid, "Ptr", strGuid, "Int", 39)
	return StrLower(SubStr(StrGet(strGuid, "UTF-16"), 2, 36))	; strip curly braces, null term
}