﻿@{
RootModule = 'ackPoshHelpers.psm1'
ModuleVersion = '1.0.0'
GUID = 'ded707d6-74e8-4196-a635-3efa89573d43'
Author = 'AckWare'
CompanyName = 'AckWare'
Copyright = '© All rights reserved.'
Description = 'Some helper functions'
# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '4.0'
CompatiblePSEditions = 'Desktop', 'Core'
# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''
# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''
# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''
# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = '4.0'
# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''
# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()
# Assemblies that must be loaded prior to importing this module
# RequiredAssemblies = @()
# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# ScriptsToProcess = @()
# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()
# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()
# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()
# Functions to export from this module
#FunctionsToExport = '*'
FunctionsToExport = @('Write*', 'Get*', 'Convert*', 'Parse*', 'Map*', 'Has*', 'Coalesce', 'VerifyFolderExists')
# Cmdlets to export from this module
#CmdletsToExport = '*'
# Variables to export from this module
#VariablesToExport = '*'
# Aliases to export from this module
#AliasesToExport = '*'
# List of all modules packaged with this module
# ModuleList = @()
# List of all files packaged with this module
# FileList = @()
# Private data to pass to the module specified in RootModule/ModuleToProcess
# PrivateData = ''
# HelpInfo URI of this module
# HelpInfoURI = ''
# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = ''
}