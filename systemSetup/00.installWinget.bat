@echo off

cd /d %~dp0
set SCRIPTNAME=%~dpn0.ps1

set POSH=pwsh.exe
where pwsh.exe /q
if ERRORLEVEL 1 set POSH=powershell.exe

::%POSH% -File "%SCRIPTNAME%" -ExecutionPolicy Unrestricted
%POSH% -File "%SCRIPTNAME%"

pause
