#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess=$true)]
param()

$ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop
Set-StrictMode -Version 'Latest'

function WriteHeaderMessage {
	param (
		[Parameter(Mandatory=$true)] [string]$message
	)
	Write-Host
	Write-Host $message -ForegroundColor DarkMagenta
}

function WriteSubHeaderMessage {
	param (
		[Parameter(Mandatory=$true)] [string]$message
	)
	Write-Host $message -ForegroundColor Blue
}

function WriteStatusMessage {
	param (
		[Parameter(Mandatory=$true)] [string]$message
	)
	Write-Host $message -ForegroundColor DarkCyan
}

function WriteStatusMessageLow {
	param (
		[Parameter(Mandatory=$true)] [string]$message
	)
	Write-Host $message -ForegroundColor DarkGray
}

function WriteStatusMessageWarning {
	param (
		[Parameter(Mandatory=$true)] [string]$message
	)
	Write-Host $message -ForegroundColor DarkYellow
}

function WriteVerboseMessage {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([void])]
	param(
		# pass in a simple string to write out, or a .NET format string with params
		[Parameter(ParameterSetName='ByString',Mandatory=$true,Position=0,ValueFromPipeline=$true)] [string] $message,
		[Parameter(ParameterSetName='ByString',Mandatory=$false,Position=1)] [object[]] $formatParams = $null,
		# or can alternately pass in a script block that returns a message;
		# it will only be invoked if Verbose is turned on, that way, if there's
		# something 'expensive' you need to calculate, it will only be done if necessary
		[Parameter(ParameterSetName='ByScript',Mandatory=$true,Position=0)] [scriptblock] $msgScript,
		# if message is a 'continuation' of a previous message, no invocationName will be written and message will be indented
		[Parameter(Mandatory=$false)] [switch] $continuation
	)
	process {
		if ($VerbosePreference -ne [System.Management.Automation.ActionPreference]::Continue) { return }

		$msg = if ($msgScript) { $msgScript.Invoke() } elseif ($formatParams) { $message -f $formatParams } else { $message }
		if (-not $continuation) {
			# get invocation name from first stack frame that's not this function and is not a script block:
			foreach ($frame in (@(Get-PSCallStack) | Select-Object -Skip 1 <# skip current #>)) {
				if ($frame -and $frame.InvocationInfo -and $frame.InvocationInfo.InvocationName <# empty for script blocks #>) {
					$msg = '[{0}] {1}' -f $frame.InvocationInfo.InvocationName,$msg
					break
				}
			}
		} else { $msg = '    ' + $msg }
		# now write out the message [some platforms can't use Write-Verbose (??) (e.g. Azure Functions). Fall back to Write-Output in that case]:
		try { Write-Verbose $msg } catch { Write-Output "VERBOSE: $msg" }
	}
}