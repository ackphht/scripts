@{
	RootModule = 'ackWingetHelpers.psm1'
	ModuleVersion = '1.0.0'
	GUID = '986a2402-e66f-40c4-8bdd-e70ed172308f'
	Author = 'AckWare'
	CompanyName = 'AckWare'
	Copyright = '© All rights reserved.'
	Description = 'Some helping wrappers and aliases for winget'
	# Minimum version of the Windows PowerShell engine required by this module
	PowerShellVersion = '5.1'
	CompatiblePSEditions = 'Desktop', 'Core'
	# Functions to export from this module
	#FunctionsToExport = '*'
	FunctionsToExport = @(
		'Search-AckWingetPackages'
		'Get-AckWingetInstalledPackages'
		'Get-AckWingetPackageDetails'
		'Install-AckWingetPackage'
		'Uninstall-AckWinGetPackage'
		'Get-AckWingetOutdatedPackages'
		'Update-AckWingetPackage'
		'Show-AckWingetPackageRepository'
	)
	# Cmdlets to export from this module
	CmdletsToExport = ''	# setting this to empty string to keep Microsoft.WinGet.Client cmdlets from getting exported from here
	# Variables to export from this module
	#VariablesToExport = '*'
	# Aliases to export from this module
	AliasesToExport = '*'
	# Private data to pass to the module specified in RootModule/ModuleToProcess
	# PrivateData = ''
}