@('Black', 'White', 'Gray', 'DarkGray', 'Blue', 'DarkBlue', 'Cyan', 'DarkCyan',
		'Green', 'DarkGreen', 'Red', 'DarkRed', 'Magenta', 'DarkMagenta', 'Yellow', 'DarkYellow') |
	ForEach-Object {
		Write-Host ('{0,11} : The quick brown fox jumps over the lazy dog. 1234567890' -f $_) -ForegroundColor $_
	}
