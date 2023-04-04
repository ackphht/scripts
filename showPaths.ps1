$headerColor = [System.ConsoleColor]::DarkCyan
$outputColor = [System.ConsoleColor]::Green
$headerChar = '*'; $headerWidth = 80;
$bigDivider = [string]::new($headerChar, $headerWidth)

function showPath {
	param([string] $name, [string] $value)
	if ($value) {
		$totalSpaces = $headerWidth - 6 <# four '*'s, two spaces #> - $name.Length
		$halfSpaces = [int][Math]::Floor($totalSpaces / 2)
		if (($totalSpaces % 2) -eq 0) {
			$preSpaces = $postSpaces = [string]::new(' ', $halfSpaces)
		} else {
			$preSpaces = [string]::new(' ', $halfSpaces)
			$postSpaces = [string]::new(' ', $halfSpaces + 1)
		}
		Write-Host $bigDivider -ForegroundColor $headerColor
		Write-Host ('{0}{0}{1} {2} {3}{0}{0}' -f $headerChar,$preSpaces,$name,$postSpaces) -ForegroundColor $headerColor
		Write-Host $bigDivider -ForegroundColor $headerColor
		Write-Host ($value -replace [System.IO.Path]::PathSeparator,[System.Environment]::NewLine) -ForegroundColor $outputColor
	}
}

showPath -name 'Path' -value $env:PATH
showPath -name 'PSModulePath' -value $env:PSModulePath
showPath -name 'PythonPath' -value $env:PYTHONPATH