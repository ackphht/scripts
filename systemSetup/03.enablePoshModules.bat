@echo off

cd /d %~dp0
set SCRIPTNAME=%~dpn0.ps1

:: have to run this once for each version of powershell (desktop and core); they mostly have their own settings

echo.
echo setting up modules for desktop powershell:
::powershell.exe -File "%SCRIPTNAME%" -ExecutionPolicy Unrestricted
powershell.exe -File "%SCRIPTNAME%"

where pwsh.exe /q
if ERRORLEVEL 1 goto :NoPwsh

echo.
echo.
echo.
echo setting up modules for core powershell:
::pwsh.exe -File "%SCRIPTNAME%" -ExecutionPolicy Unrestricted
pwsh.exe -File "%SCRIPTNAME%"
goto :END

:NoPwsh
echo Cannot find executable for PowerShellCore; may need to re-run this script after installing it

:END
pause
