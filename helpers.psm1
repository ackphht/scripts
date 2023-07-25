#Requires -Version 4

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

function GetSortedPropertyNames {
	param(
		[PSObject] $object
	)
	return [string[]]($object | Get-Member -MemberType Property | ForEach-Object { $_.Name } | Sort-Object)
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

$script:splitLine = [regex]::new('^\s*(?<nam>.+?)\s*[:=]\s*("?)\s*(?<val>.+?)\s*\1\s*$', 'Compiled')
function ParseLinesToLookup {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([hashtable])]
	param(
		[Parameter(Mandatory=$false, ValueFromPipeline = $true)] [string[]] $inputs,
		[switch] $saveFirstValue
	)
	begin { $results = @{} }
	process {
		WriteVerboseMessage 'trying to match line |{0}|' $_
		if ($_) {
			$match = $script:splitLine.Match($_)
			if ($match.Success) {
				$nam = $match.Groups['nam'].Value; $val = $match.Groups['val'].Value;
				# if value is just an empty pair of quotes (e.g. Fedora's os-release), regex doesn't catch that; but this is probably
				# better anyway because we still get the key instead of no match at all; could probably get regex to handle that but meh
				if ($val -eq '""') { $val = '' }
				WriteVerboseMessage 'matched line: nam = |{0}|, val = |{1}|' $nam,$val
				if (-not $saveFirstValue -or -not $results.ContainsKey($nam)) {
					$results[$nam] = $val
				}
			}
		}
	}
	end { return $results }
}

$script:_formatSizes = @('', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB' <# ulong can't hold anything this big, but including just to be a nerd #>, 'YB')
$script:_formatBase = 1024
function GetFriendlyBytes {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([string])]
	param(
		[Parameter(Mandatory = $true, ValueFromPipeline = $true)] [System.Uint64] $value
	)
	process {
		if ($value -eq 0) { return '0' }
		$exp = [Math]::Floor([Math]::Log($value, $script:_formatBase))
		$coeff = $value / [Math]::Pow($script:_formatBase, $exp)
		$dispValue = $(
				if ($value -lt $script:_formatBase) { '{0:n0}' }
				elseif ($coeff -ge 100.0) { '{0:n0} ' }
				elseif ($coeff -ge 10.0) { '{0:n1} ' }
				else { '{0:n2} ' }
			) -f $coeff
		return "$dispValue$($script:_formatSizes[$exp])"
	}
}

# returns value of first property from $props on $object that is not null or empty
function Coalesce {
	[CmdletBinding(SupportsShouldProcess=$false)]
	[OutputType([PSObject])]
	param(
		[Parameter(Mandatory = $true)] [PSObject] $object,
		[Parameter(Mandatory = $true)] [string[]] $props
	)
	foreach ($prop in $props) {
		$val = $object.$prop
		if ($val) {
			return $val
		}
	}
	return $null
}

if ([bool](Get-Command -Name 'Get-CimInstance' -ErrorAction SilentlyContinue)) {
	function MapCimOsSku {
		[CmdletBinding(SupportsShouldProcess=$false)]
		[OutputType([string])]
		param([Parameter(Mandatory = $true)] [System.UInt32] $cimOsSku, [string] $cimOsCaption)
		$result = '<unknown>'
		# https://learn.microsoft.com/en-us/windows/win32/cimwin32prov/win32-operatingsystem, search for 'OperatingSystemSKU':
		switch ($cimOsSku) {
			# PRODUCT_UNDEFINED (0): Undefined
			0 { $result = 'Undefined' }
			# PRODUCT_ULTIMATE (1): Ultimate Edition, e.g. Windows Vista Ultimate.
			1 { $result = 'Ultimate' }
			# PRODUCT_HOME_BASIC (2): Home Basic Edition
			2 { $result = 'HomeBasic' }
			# PRODUCT_HOME_PREMIUM (3): Home Premium Edition
			3 { $result = 'HomePremium' }
			# PRODUCT_ENTERPRISE (4): Enterprise Edition
			4 { $result = 'Enterprise' }
			5 { $result = 'HomeBasicN' }
			# PRODUCT_BUSINESS (6): Business Edition
			6 { $result = 'Business' }
			# PRODUCT_STANDARD_SERVER (7): Windows Server Standard Edition (Desktop Experience installation)
			7 { $result = 'ServerStandard' }
			# PRODUCT_DATACENTER_SERVER (8): Windows Server Datacenter Edition (Desktop Experience installation)
			8 { $result = 'ServerDatacenter' }
			# PRODUCT_SMALLBUSINESS_SERVER (9): Small Business Server Edition
			9 { $result = 'ServerSmallBusiness' }
			# PRODUCT_ENTERPRISE_SERVER (10): Enterprise Server Edition
			10 { $result = 'ServerEnterprise' }
			# PRODUCT_STARTER (11): Starter Edition
			11 { $result = 'Starter' }
			# PRODUCT_DATACENTER_SERVER_CORE (12): Datacenter Server Core Edition
			12 { $result = 'ServerDatacenterCore' }			# only < Srvr2012
			# PRODUCT_STANDARD_SERVER_CORE (13): Standard Server Core Edition
			13 { $result = 'ServerStandardCore' }			# only < Srvr2012
			# PRODUCT_ENTERPRISE_SERVER_CORE (14): Enterprise Server Core Edition
			14 { $result = 'ServerEnterpriseCore' }			# only < Srvr2012
			# PRODUCT_WEB_SERVER (17): Web Server Edition
			17 { $result = 'ServerWeb' }
			# PRODUCT_HOME_SERVER (19): Home Server Edition
			19 { $result = 'HomeServer' }
			# PRODUCT_STORAGE_EXPRESS_SERVER (20): Storage Express Server Edition
			20 { $result = 'StorageServerExpress' }
			# PRODUCT_STORAGE_STANDARD_SERVER (21): Windows Storage Server Standard Edition (Desktop Experience installation)
			21 { $result = 'StorageServerStandard' }
			# PRODUCT_STORAGE_WORKGROUP_SERVER (22): Windows Storage Server Workgroup Edition (Desktop Experience installation)
			22 { $result = 'StorageServerWorkgroup' }
			# PRODUCT_STORAGE_ENTERPRISE_SERVER (23): Storage Enterprise Server Edition
			23 { $result = 'StorageServerEnterprise' }
			# PRODUCT_SERVER_FOR_SMALLBUSINESS (24): Server For Small Business Edition
			24 { $result = 'ServerSmallBusiness' }
			# PRODUCT_SMALLBUSINESS_SERVER_PREMIUM (25): Small Business Server Premium Edition
			25 { $result = 'ServerSmallBusinessPremium' }
			26 { $result = 'HomePremiumN' }
			# PRODUCT_ENTERPRISE_N (27): Windows Enterprise Edition
			27 { $result = 'EnterpriseN' }
			# PRODUCT_ULTIMATE_N (28): Windows Ultimate Edition
			28 { $result = 'UltimateN' }
			# PRODUCT_WEB_SERVER_CORE (29): Windows Server Web Server Edition (Server Core installation)
			29 { $result = 'ServerWebCore' }			# only < Srvr2012
			# PRODUCT_STANDARD_SERVER_V (36): Windows Server Standard Edition without Hyper-V
			# PRODUCT_DATACENTER_SERVER_V (37): Windows Server Datacenter Edition without Hyper-V (full installation)
			# PRODUCT_ENTERPRISE_SERVER_V (38): Windows Server Enterprise Edition without Hyper-V (full installation)
			# PRODUCT_DATACENTER_SERVER_CORE_V (39): Windows Server Datacenter Edition without Hyper-V (Server Core installation)
			# PRODUCT_STANDARD_SERVER_CORE_V (40): Windows Server Standard Edition without Hyper-V (Server Core installation)
			# PRODUCT_ENTERPRISE_SERVER_CORE_V (41): Windows Server Enterprise Edition without Hyper-V (Server Core installation)
			# PRODUCT_HYPERV (42): Microsoft Hyper-V Server
			42 { $result = 'ServerHyperV' }
			# PRODUCT_STORAGE_EXPRESS_SERVER_CORE (43): Storage Server Express Edition (Server Core installation)
			43 { $result = 'StorageServerExpressCore' }
			# PRODUCT_STORAGE_STANDARD_SERVER_CORE (44): Storage Server Standard Edition (Server Core installation)
			44 { $result = 'StorageServerStandardCore' }
			# PRODUCT_STORAGE_WORKGROUP_SERVER_CORE (45): Storage Server Workgroup Edition (Server Core installation)
			45 { $result = 'StorageServerWorkgroupCore' }
			# PRODUCT_STORAGE_ENTERPRISE_SERVER_CORE (46): Storage Server Enterprise Edition (Server Core installation)
			46 { $result = 'StorageServerEnterpriseCore' }
			47 { $result = 'StarterN' }
			# PRODUCT_PROFESSIONAL (48): Windows Professional
			48 {
				# Pro Education originally had same SKU as Pro; real SKU below added later...
				if ($cimOsCaption -notlike '*Education*') {
					$result = 'Professional'
				} else {
					$result = 'ProfessionalEducation'
				}
			}
			49 {
				if ($cimOsCaption -notlike '*Education*') {
					$result = 'ProfessionalN'
				} else {
					$result = 'ProfessionalEducationN'
				}
			}
			# PRODUCT_SB_SOLUTION_SERVER (50): Windows Server Essentials (Desktop Experience installation)
			50 { $result = 'ServerEssentials' }
			# PRODUCT_SMALLBUSINESS_SERVER_PREMIUM_CORE (63); Small Business Server Premium (Server Core installation)
			63 { $result = 'ServerSmallBusinessPremiumCore' }
			# PRODUCT_CLUSTER_SERVER_V (64): Windows Compute Cluster Server without Hyper-V
			# PRODUCT_CORE_ARM (97): Windows RT
			97 { $result = 'WindowsRT' }	# the original Windows ARM version (??)
			98 { $result = 'HomeN' }
			100 { $result = 'HomeSingleLanguage' }
			# PRODUCT_CORE (101): Windows Home
			101 { $result = 'Home' }
			# PRODUCT_PROFESSIONAL_WMC (103): Windows Professional with Media Center
			103 { $result = 'ProfessionalWithMediaCenter' }
			# PRODUCT_MOBILE_CORE (104): Windows Mobile
			104 { $result = 'WindowsMobile' }
			121 { $result = 'Education' }
			122 { $result = 'EducationN' }
			# PRODUCT_IOTUAP (123): Windows IoT (Internet of Things) Core
			123 { $result = 'WindowsIoTCore' }
			# PRODUCT_DATACENTER_NANO_SERVER (143): Windows Server Datacenter Edition (Nano Server installation)
			143 { $result = 'ServerDataCenterNano' }
			# PRODUCT_STANDARD_NANO_SERVER (144): Windows Server Standard Edition (Nano Server installation)
			144 { $result = 'ServerStandardNano' }
			#145 { $result = 'dcCore' }			# ?????
			#146 { $result = 'stdCore' }			# ?????
			# PRODUCT_DATACENTER_WS_SERVER_CORE (147): Windows Server Datacenter Edition (Server Core installation)
			147 { $result = 'ServerDatacenterCoreWS' }
			# PRODUCT_STANDARD_WS_SERVER_CORE (148): Windows Server Standard Edition (Server Core installation)
			148 { $result = 'ServerStandrdCoreWS' }
			161 { $result = 'ProfessionalWorkstation' }
			162 { $result = 'ProfessionalWorkstationN' }
			164 { $result = 'ProfessionalEducation' }
			165 { $result = 'ProfessionalEducationN' }
			# PRODUCT_ENTERPRISE_FOR_VIRTUAL_DESKTOPS (175): Windows Enterprise for Virtual Desktops (Azure Virtual Desktop)
			175 { $result = 'EnterpriseForVirtualDesktop' }
		}
		WriteVerboseMessage 'trying to map OS edition: ossku = "{0}" ==> "{1}"' $cimOsSku,$result
		return $result
	}

	function MapCimProcArch {
		[OutputType([string])]
		param([Parameter(Mandatory = $true)] [int] $arch)
		switch ($arch) {
			0 { return '0 [x86]' }
			1 { return '1 [MIPS]' }
			2 { return '2 [Alpha]' }
			3 { return '3 [PowerPC]' }
			5 { return '5 [ARM32]' }
			6 { return '6 [ia64]' }
			9 { return '9 [x64]' }
			12 { return '12 [ARM64]' }
			default { return "$arch [Other]" }
		}
	}
}

function HasProperty {
	[OutputType([bool])]
	param(
		[Parameter(Mandatory=$true)] [object] $object,	# have to make it object here and cast to PSCustomObject below (e.g. Hasttable objects, maybe others, don't work otherwise...)
		[Parameter(Mandatory=$true)] [string] $propertyName
	)
	return ([PSCustomObject]$object).PSObject.Properties[$propertyName] -ne $null
}