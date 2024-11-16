@echo off
call :CleanTempFileType *.7z
call :CleanTempFileType *.args
call :CleanTempFileType *.bat
call :CleanTempFileType *.bmp
call :CleanTempFileType *.cab
call :CleanTempFileType *.cache
call :CleanTempFileType *.cg
call :CleanTempFileType *.cmd
call :CleanTempFileType *.cmdline
call :CleanTempFileType *.cpuprofile
call :CleanTempFileType *.cs
call :CleanTempFileType *.csv
call :CleanTempFileType *.cvr
call :CleanTempFileType *.dat
call :CleanTempFileType *.db
call :CleanTempFileType *.dic
call :CleanTempFileType *.dll
call :CleanTempFileType *.doc
call :CleanTempFileType *.epub
call :CleanTempFileType *.err
call :CleanTempFileType *.etl*
call :CleanTempFileType *.exe
call :CleanTempFileType *.gif
call :CleanTempFileType *.hta
call :CleanTempFileType *.htm
call :CleanTempFileType *.html
call :CleanTempFileType *.ica
call :CleanTempFileType *.ico
call :CleanTempFileType *.ifo
call :CleanTempFileType *.ini
call :CleanTempFileType *.jfm
call :CleanTempFileType *.jpg
call :CleanTempFileType *.json
call :CleanTempFileType *.lock
call :CleanTempFileType *-lockfile
call :CleanTempFileType *.lockfile
call :CleanTempFileType *.log
call :CleanTempFileType *.model
call :CleanTempFileType *.mof
call :CleanTempFileType *.msi
call :CleanTempFileType *.mtx
call :CleanTempFileType *.mvu
call :CleanTempFileType *.node
call :CleanTempFileType *.od
call :CleanTempFileType *.out
call :CleanTempFileType *.part
call :CleanTempFileType *.pdb
call :CleanTempFileType *.pdf
call :CleanTempFileType *.png
call :CleanTempFileType *.proj
call :CleanTempFileType *-lockfile
call :CleanTempFileType *.rar
call :CleanTempFileType *.reg
call :CleanTempFileType *.scr
call :CleanTempFileType *.ses
call :CleanTempFileType *.shd
call :CleanTempFileType *.sql
call :CleanTempFileType *.sqm
call :CleanTempFileType *.temp
call :CleanTempFileType *.tmp
call :CleanTempFileType *.torrent
call :CleanTempFileType *.txt
call :CleanTempFileType *.url
call :CleanTempFileType *.vb
call :CleanTempFileType *.vbs
call :CleanTempFileType *.webp
call :CleanTempFileType *.xls
call :CleanTempFileType *.xml
call :CleanTempFileType *.xpi
call :CleanTempFileType *.xsl
call :CleanTempFileType *.zip
call :CleanTempFileType _CL_*
call :CleanTempFileType zeal*
call :CleanTempFileType ~clean.ack
call :CleanTempFileType *.diagsession
call :CleanTempFileType gdbus-nonce-file-*
call :CleanTempFileType PowerToysMSIInstaller_*
call :CleanTempFileType VSIX*
call :CleanTempFileType .ses			:: not a file type, just a file
call :CleanTempFileType MTShell.m3u8	:: not a file type, just a file

call :CleanTempFolder ActivityVisualCache
call :CleanTempFolder Adobe
call :CleanTempFolder ai_prompt_builder_tmp
call :CleanTempFolder com.logi.optionsplus.agent.logs
call :CleanTempFolder Deployment
call :CleanTempFolder Diagnostics
call :CleanTempFolder FrontPageTempDir
call :CleanTempFolder iisexpress
call :CleanTempFolder JetBrains
call :CleanTempFolder JetLogs
call :CleanTempFolder LCFEM
call :CleanTempFolder LinqPad
call :CleanTempFolder lptmp
call :CleanTempFolder MicroThemePackDir
call :CleanTempFolder MM_UPNP_Images
call :CleanTempFolder MSBuildTemp
call :CleanTempFolder msohtml
call :CleanTempFolder msohtml1
call :CleanTempFolder msohtmlclip
call :CleanTempFolder msohtmlclip1
call :CleanTempFolder nppLocalization
call :CleanTempFolder nunit20
call :CleanTempFolder OneNote
call :CleanTempFolder "Outlook Logging"
call :CleanTempFolder PdnSetup
call :CleanTempFolder PhotoCache
call :CleanTempFolder RazorVSFeedbackLogs
call :CleanTempFolder RemoteHelp
call :CleanTempFolder Roslyn
call :CleanTempFolder servicehub
call :CleanTempFolder SmartScreen
call :CleanTempFolder Ssms
call :CleanTempFolder SsmsSetup
call :CleanTempFolder SymbolCache
call :CleanTempFolder symbols
call :CleanTempFolder system-commandline-sentinel-files
call :CleanTempFolder TFSTemp
call :CleanTempFolder TortoiseGit
call :CleanTempFolder VBCSCompiler
call :CleanTempFolder VBE
call :CleanTempFolder windowssdk
call :CleanTempFolder WPF
call :CleanTempFolder WSLDVCPlugin
call :CleanTempFolder "Temporary ASP.NET Files"
call :CleanTempMultiFolder *.tmp
call :CleanTempMultiFolder appInsights-*
call :CleanTempMultiFolder calibre_*
call :CleanTempMultiFolder chrome_BITS*
call :CleanTempMultiFolder chrome_drag*
call :CleanTempMultiFolder chrome_url_fetcher_*
call :CleanTempMultiFolder dotnet-sdk-*
call :CleanTempMultiFolder edge_BITS*
call :CleanTempMultiFolder GoogleUpdateSetup*
call :CleanTempMultiFolder hb.*
call :CleanTempMultiFolder Log*
call :CleanTempMultiFolder Micro*
call :CleanTempMultiFolder MMCache*
call :CleanTempMultiFolder Nuget*
call :CleanTempMultiFolder nw*
call :CleanTempMultiFolder PSES-*
call :CleanTempMultiFolder pyright-*
call :CleanTempMultiFolder python-*
call :CleanTempMultiFolder Rar$*
call :CleanTempMultiFolder remote-file-*
call :CleanTempMultiFolder remoteIp*
call :CleanTempMultiFolder Report.*
call :CleanTempMultiFolder scoped_dir*
call :CleanTempMultiFolder Sigil*
call :CleanTempMultiFolder ssh-*
call :CleanTempMultiFolder TCD*.tmp
call :CleanTempMultiFolder VS*
call :CleanTempMultiFolder WebCompiler*
call :CleanTempMultiFolder {*}

:::CLEANFLASHFILES
::echo.
::echo.
::choice /c yn /m "Do you want to clean Flash files?"
::if errorlevel 2 goto :AFTERFLASHFILES
::call :CleanMultiFolderContents "%APPDATA%\Macromedia\Flash Player\*"
::
:::AFTERFLASHFILES

:CLEANBROWSERFILES
::echo.
::echo.
::choice /c yn /m "Do you want to clean browser files?"
::if errorlevel 2 goto :AFTERBROWSERFILES
::::call :CleanFileType "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\q52vk44x.default\Cache\*"		::arrakis
::::call :CleanMultiFolders "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\q52vk44x.default\Cache\*"	::arrakis
::::call :CleanFolder "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\q52vk44x.default\Cache\*"			::arrakis
::::call :CleanMultiFolder2 "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\q52vk44x.default\Cache\*"	::arrakis
::::call :CleanFolder "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\lv5vt7ba.default\Cache\*"			::scytale
::::call :CleanFolder "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\c5y6jyec.default\Cache\*"			::e6500
::::call :CleanFolder "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\ol8r39up.default\Cache\*"			::corrin/erasmus
::::call :CleanFolder "%LOCALAPPDATA%\Mozilla\Firefox\Profiles\81a1pvrl.default\Cache\*"			::e6530
::
::call :CleanFolderContents "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Cache\*"
::call :CleanFolderContents "%LOCALAPPDATA%\Google\Chrome\User Data\Default\GPUCache\*"
::call :CleanFolderContents "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Media Cache\*"
::call :CleanFolderContents "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Pepper Data\*"
::::call :CleanFolderContents "%LOCALAPPDATA%\Google\Chrome\User Data\Default\Sync Data\*"
::
::call :CleanFolderContents "%LOCALAPPDATA%\Vivaldi\User Data\Default\Cache\*"
::call :CleanFolderContents "%LOCALAPPDATA%\Vivaldi\User Data\Default\GPUCache\*"
::call :CleanFolderContents "%LOCALAPPDATA%\Vivaldi\User Data\Default\Media Cache\*"
::::call :CleanFolderContents "%LOCALAPPDATA%\Vivaldi\User Data\Default\Pepper Data\*"

:AFTERBROWSERFILES

::call :CleanFolder "%APPDATA%\Dropbox\cache\*"

goto :END

:CleanTempFileType
	call :CleanFileType "%TEMP%"\%1
	goto :EOF

:CleanTempFolder
	call :CleanFolder "%TEMP%"\%1
	goto :EOF

:CleanTempMultiFolder
	call :CleanMultiFolder "%TEMP%"\%1
	goto :EOF

:CleanFileType
	if exist %1 del /f /q %1
	::if exist %1 sdelete -a -p 3 %1
	goto :EOF

:CleanFolder
	if exist %1 rmdir /q /s %1
	::if exist %1 sdelete -a -p 3 -r %1
	goto :EOF

:CleanFolderContents
	if exist %1 del /q /f /s %1
	::if exist %1 sdelete -a -p 3 -r %1
	goto :EOF

:CleanMultiFolder
	::for /d %%f in (%1) do rmdir /q /s "%%f"
	::for /d %%f in (%1) do sdelete -a -r -p 3 "%%f"
	for /d %%f in (%1) do call :CleanFolder "%%f"
	goto :EOF

:CleanMultiFolderContents
	::for /d %%f in (%1) do rmdir /q /s "%%f"
	::for /d %%f in (%1) do sdelete -a -r -p 3 "%%f"
	for /d %%f in (%1) do call :CleanFolderContents "%%f"
	goto :EOF

:CleanMultiFolder2
	::for /r %1 %%f in (.) do sdelete -r -p 3 "%%f"
	::for /r %1 %%f in (*) do echo would call sdelete on "%%f"
	::for /d %%f in (%1) do echo would call sdelete on "%%f"
	for /d %%f in (%1) do call :CleanMultiFolder2 "%%f"
	for /d %%f in (%1) do rmdir /q /s "%%f"
	::for /d %%f in (%1) do sdelete -a -r -p 3 "%%f"
	goto :EOF

:END
echo.
echo.
pause
