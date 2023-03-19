[CmdletBinding(SupportsShouldProcess=$true)]
param(
	[switch] $invocation
)

$ErrorActionPreference = 'Stop'	#'Continue'
#Set-StrictMode -Version Latest		# not setting this because some of the vars below might not exist in all editions, so just accept it

$script:divider = [string]::new('=',80)
function WriteHeader {
	param([string] $value)
	Write-Host $script:divider -ForegroundColor DarkCyan
	Write-Host $value -ForegroundColor DarkCyan
	Write-Host $script:divider -ForegroundColor DarkCyan
}

Write-Host ''
WriteHeader '"global" variables:'
$vars = [PSCustomObject]@{
	'$PSVersionTable' = $($PSVersionTable | Select-Object -Property @{Label='PSVersion';Expression={$_.PSVersion.ToString()}},PSEdition,OS,Platform,@{Label='CLRVersion';Expression={$_.CLRVersion.ToString()}} | ConvertTo-Json -Depth 10 -Compress)
	'$Host' = "$($Host.Name), v$($Host.Version)"
	'$ShellId' = $ShellId
	'$PSScriptRoot' = $PSScriptRoot
	'$PSCommandPath' = $PSCommandPath
	'$PWD' = $PWD
	'$PSHOME' = $PSHOME
	'$PROFILE' = $PROFILE
	'$HOME' = $HOME
	'$OutputEncoding' = $($OutputEncoding | Select-Object -Property EncodingName,WebName,CodePage,WindowsCodePage | ConvertTo-Json -Depth 10 -Compress)
	'$PSCulture' = $PSCulture
	'$PSUICulture' = $PSUICulture
	'$PSEdition' = $PSEdition
	'$IsCoreCLR' = $IsCoreCLR
	'$IsLinux' = $IsLinux
	'$IsMacOS' = $IsMacOS
	'$IsWindows' = $IsWindows
	'[Environment]::CommandLine' = [Environment]::CommandLine
	'[Environment]::CurrentDirectory' = [Environment]::CurrentDirectory
	'[Environment]::Is64BitOperatingSystem' = [Environment]::Is64BitOperatingSystem
	'[Environment]::Is64BitProcess' = [Environment]::Is64BitProcess
	'[Environment]::MachineName' = [Environment]::MachineName
	'[Environment]::NewLine' = $(ConvertTo-Json -InputObject ([Environment]::NewLine) -Depth 10 -Compress).Trim(' "')
	'[Environment]::OSVersion' = $(ConvertTo-Json -InputObject ([Environment]::OSVersion) -Depth 10 -Compress)
	'[Environment]::ProcessorCount' = [Environment]::ProcessorCount
	'[Environment]::SystemDirectory' = [Environment]::SystemDirectory
	'[Environment]::UserDomainName' = [Environment]::UserDomainName
	'[Environment]::UserInteractive' = [Environment]::UserInteractive
	'[Environment]::UserName' = [Environment]::UserName
	'[Environment]::Version' = [Environment]::Version.ToString()
	'[Path]::DirectorySeparatorChar' = [System.IO.Path]::DirectorySeparatorChar
	'[Path]::AltDirectorySeparatorChar' = [System.IO.Path]::AltDirectorySeparatorChar
	'[Path]::PathSeparator' = [System.IO.Path]::PathSeparator
	'[Path]::VolumeSeparatorChar' = [System.IO.Path]::VolumeSeparatorChar
	#'[Path]::InvalidPathChars' = $(ConvertTo-Json -InputObject ([System.IO.Path]::InvalidPathChars -join ' ') -Depth 10 -Compress).Trim(' "')
	'[Path]::GetInvalidPathChars()' = $(ConvertTo-Json -InputObject ([System.IO.Path]::GetInvalidPathChars() -join ' ') -Depth 10 -Compress).Trim(' "')
	'[Path]::GetInvalidFileNameChars()' = $(ConvertTo-Json -InputObject ([System.IO.Path]::GetInvalidFileNameChars() -join ' ') -Depth 10 -Compress).Trim(' "')
	'$ConfirmPreference' = $ConfirmPreference
	'$DebugPreference' = $DebugPreference
	'$ErrorActionPreference' = $ErrorActionPreference
	'$InformationPreference' = $InformationPreference
	'$ProgressPreference' = $ProgressPreference
	'$VerbosePreference' = $VerbosePreference
	'$WarningPreference' = $WarningPreference
	'$WhatIfPreference' = $WhatIfPreference
	'$ErrorView' = $ErrorView
	'$PSCmdlet.ParameterSetName' = $PSCmdlet.ParameterSetName
}
Format-List -Property * -InputObject $vars

if ($invocation) {
	WriteHeader '$MyInvocation (these can change depending on context):'
	Format-List -InputObject $MyInvocation -Property *
}
