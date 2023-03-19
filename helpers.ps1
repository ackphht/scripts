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

$script:properIndentsCache = @{ 1 = "`t"; 2 = "`t`t"; 3 = "`t`t`t"; 4 = "`t`t`t`t"; }
$script:stupidIndentsCache = @{ 1 = '    '; 2 = '        '; 3 = '            '; 4 = '                '; }
$script:twoSpaceIndentRegex = [regex]::new('^((?<fu>  )+)', @('MultiLine', 'Compiled'))
$script:arrayObjStartRegex = [regex]::new('\[[\r\n\s]+{', @('MultiLine', 'Compiled'))
$script:multiObjRegex = [regex]::new('},[\r\n\s]+{', @('MultiLine', 'Compiled'))
function ConvertTo-ProperFormattedJson {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true, ValueFromPipeline = $true)] [object] $inputObject,
		[switch] $useSpaces,
		[switch] $moreCompact
	)
	process {
		if ($PSEdition -eq 'Core') {
			$json = ConvertTo-Json -InputObject $inputObject -Depth 100 -EnumsAsStrings
		} else {
			$json = ConvertTo-Json -InputObject $inputObject -Depth 100
		}
		# do this first as it might avoid some replacements below:
		if ($moreCompact) {
			#$json = (($json -replace $script:arrayObjStartRegex,'[{') -replace $script:arrayObjEndRegex,'}]') -replace $script:multiObjRegex,'},{'
			$json = ($json -replace $script:arrayObjStartRegex,'[{') -replace $script:multiObjRegex,'},{'
		}
		if ($PSEdition -eq 'Core') {
			# old powershell's is already 4 space indented (or some crap), so just leave that alone;
			# plus this regex stuff doesn't work for that for some reason i'm not bothering to figure out:
			$json = $json -replace $script:twoSpaceIndentRegex, {
					$indentCount = $_.Groups['fu'].Captures.Count
					if ($useSpaces) {
						if ($script:stupidIndentsCache.ContainsKey($indentCount)) {
							return $script:stupidIndentsCache[$indentCount]
						} else {
							return [string]::new(' ', $indentCount * 4)
						}
					} else {
						if ($script:properIndentsCache.ContainsKey($indentCount)) {
							return $script:properIndentsCache[$indentCount]
						} else {
							return [string]::new("`t", $indentCount)
						}
					}
				}
		}
		return $json
	}
}