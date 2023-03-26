@{
	PSVersion=$PSVersionTable.PSVersion.ToString();
	PSEdition=$PSVersionTable.PSEdition;
	PSPlatform=$PSVersionTable.Platform;
	PSOs=$PSVersionTable.OS
	IS64BitOS=[Environment]::Is64BitOperatingSystem
	Is64BitProcess=[Environment]::Is64BitProcess
	EnvVarProcessorArch=$env:PROCESSOR_ARCHITECTURE
	EnvVarProcessorId=$env:PROCESSOR_IDENTIFIER
	RIOSArch=[System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
	RIProcessArch=[System.Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture
	RIRuntimeId=[System.Runtime.InteropServices.RuntimeInformation]::RuntimeIdentifier
	RIOSDesc=[System.Runtime.InteropServices.RuntimeInformation]::OSDescription
	RIFrameworkDesc=[System.Runtime.InteropServices.RuntimeInformation]::FrameworkDescription
	IsLittleEndian=[BitConverter]::IsLittleEndian
}.GetEnumerator() | Sort-Object Name