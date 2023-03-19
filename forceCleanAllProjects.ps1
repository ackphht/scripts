[CmdletBinding(SupportsShouldProcess=$true)]
param()

Set-StrictMode -Version 3.0

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param()

	$rootFolder = (Get-Location).Path
	$separator = [System.String]::new('=', 80)

	Get-ChildItem -Include '*.csproj','*.vbproj','*.nuproj' -Recurse -Force |
		ForEach-Object {
			DoCleaning $_.Directory.FullName $separator
		}

	Write-Host
	Write-Host 'Done'
}

function DoCleaning {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[string] $folder,
		[string] $separator
	)
	DeleteFolder (Join-Path $folder 'bin\Debug')
	DeleteFolder (Join-Path $folder 'bin\Release')
	DeleteFolder (Join-Path $folder 'obj')
}

function DeleteFolder {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[string] $folderPath
	)
	if (Test-Path $folderPath -PathType Container) {
		Write-Output "removing folder '$folderPath'"
		Remove-Item -Force -Recurse -Path $folderPath
	}
}

#==============================
Main
#==============================
