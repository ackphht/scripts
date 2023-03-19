$dividerColor = [System.ConsoleColor]::DarkCyan
$outputColor = [System.ConsoleColor]::Green
$dividerChar = '*'
$bigDivider = [string]::new($dividerChar, 80)

Write-Host $bigDivider -ForegroundColor $dividerColor
Write-Host ('{0}{0}{1} {2} {1}{0}{0}' -f $dividerChar,(' ' * 35),'Path') -ForegroundColor $dividerColor
Write-Host $bigDivider -ForegroundColor $dividerColor
Write-Host ($env:PATH -replace [System.IO.Path]::PathSeparator,[System.Environment]::NewLine) -ForegroundColor $outputColor

Write-Host $bigDivider -ForegroundColor $dividerColor
Write-Host ('{0}{0}{1} {2} {1}{0}{0}' -f $dividerChar,(' ' * 31),'PSModulePath') -ForegroundColor $dividerColor
Write-Host $bigDivider -ForegroundColor $dividerColor
Write-Host ($env:PSModulePath -replace [System.IO.Path]::PathSeparator,[System.Environment]::NewLine) -ForegroundColor $outputColor
