@echo off

:: following upserts reg entry in HKCU\Software\Microsoft\PowerShell\1\ShellIds\Microsoft.PowerShell, value = ExecutionPolicy = "RemoteSigned"
:: if scope is LocalMachine, same entry is under HKLM instead:
powershell.exe -Command "& { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false }"

where pwsh.exe /q
if ERRORLEVEL 1 goto :NoPwsh

:: following create a file in profile directory called "powershell.config.json, with contents |{"Microsoft.PowerShell:ExecutionPolicy":"RemoteSigned"}|
:: not sure where things go if scope is LocalMachine...:
pwsh.exe -Command "& { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Confirm:$false }"

:NoPwsh

pause
