#Requires -Version 5.1
#Requires -Modules 'Pscx'

[CmdletBinding(DefaultParameterSetName = 'Path', SupportsShouldProcess=$false)]
param(
	#[Parameter(Mandatory = $true, ValueFromPipeline = $true)]
	#[PSObject] $input,
	[Parameter(ParameterSetName = "Path", Position = 0, Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[Pscx.PscxPath(Tag = "PathCommand.Path")]
	[Pscx.IO.PscxPathInfo[]] $path,

	[Parameter(ParameterSetName = "LiteralPath", Position = 0, Mandatory = $true, ValueFromPipeline = $false, ValueFromPipelineByPropertyName = $true)]
	[Pscx.PscxPath(NoGlobbing = $true, Tag = "PathCommand.LiteralPath")]
	[Pscx.IO.PscxPathInfo[]] $literalPath,

	[Parameter(ParameterSetName = "Object", Mandatory = $true, ValueFromPipeline = $true)]
	[PSObject] $inputObject,

	[switch] $toClipboard
)

$ErrorActionPreference = 'Stop'	#'Continue'
Set-StrictMode -Version Latest

switch ($PSCmdlet.ParameterSetName) {
	'Path' { $b64 = ConvertTo-Base64 -Path $path -NoLineBreak }
	'LiteralPath' { $b64 = ConvertTo-Base64 -LiteralPath $literalPath -NoLineBreak }
	'Object' { $b64 = ConvertTo-Base64 -InputObject $inputObject -NoLineBreak }
}

if ($toClipboard) {
	$b64 | Microsoft.PowerShell.Management\Set-Clipboard
} else {
	Write-Output $b64
}