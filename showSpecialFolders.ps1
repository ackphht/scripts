$results = @([PSCustomObject]@{ Name = 'Path.GetTempPath()'; Path = [System.IO.Path]::GetTempPath(); })
$results += @([System.Enum]::GetValues([System.Environment+SpecialFolder]) |
				ForEach-Object { [PSCustomObject]@{ Name = "SpecialFolder.${_}"; Path = [System.Environment]::GetFolderPath($_); } } |
				Sort-Object Name
			)
$results | Format-Table