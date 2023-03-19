#Requires -Version 5.1
#Requires -Modules 'Microsoft.PowerShell.SecretManagement'
#Requires -Modules 'AckWare.AckLib'

[CmdletBinding(SupportsShouldProcess=$true, DefaultParameterSetName = 'LatLong')]
param(
	[Parameter(Mandatory=$false, ParameterSetName = 'LatLong')]
	[ValidateNotNullOrEmpty()]
	[Alias('lat')]
	[string] $latitude = '30.467073',
	[Parameter(Mandatory=$false, ParameterSetName = 'LatLong')]
	[ValidateNotNullOrEmpty()]
	[Alias('lon', 'long')]
	[string] $longitude = '-97.629882',

	[Parameter(Mandatory=$true, ParameterSetName = 'CityId')]
	[Alias('id')]
	[long] $cityId,

	[Parameter(Mandatory=$true, ParameterSetName = 'ZipCode')]
	[Alias('zip')]
	[string] $zipCode,
	[Parameter(Mandatory=$false, ParameterSetName = 'ZipCode')]
	[Parameter(Mandatory=$false, ParameterSetName = 'CityName')]
	[ValidateNotNullOrEmpty()]
	[Alias('country')]
	[string] $countryCode = 'US',

	[Parameter(Mandatory=$true, ParameterSetName = 'CityName')]
	[Alias('city')]
	[string] $cityName,
	[Parameter(Mandatory=$false, ParameterSetName = 'CityName')]
	[ValidateScript({ if ($countryCode -eq 'US' -and -not $_) { throw 'a state code is required for country = "US"' } return $true })]
	[Alias('state', 'st')]
	[string] $stateCode,

	[Parameter(Mandatory=$false)]
	[ValidateRange(0, 5)]		# 0 = no forecast
	[int] $forecastDays = 3,

	[Parameter(Mandatory=$false)]
	[ValidateSet('standard', 'metric', 'imperial')]
	[string] $units = 'imperial'
)

$ErrorActionPreference = 'Stop'
#Set-StrictMode -Version Latest

function Main {
	[CmdletBinding(SupportsShouldProcess=$true)]
	param(
		[Parameter(Mandatory=$true)] [string] $paramSetName,
		[string] $latitude,
		[string] $longitude,
		[long] $cityId,
		[string] $zipCode,
		[string] $countryCode,
		[string] $cityName,
		[string] $stateCode,
		[Parameter(Mandatory=$true)] [int] $forecastDays,
		[Parameter(Mandatory=$true)] [string] $units
	)

	# https://openweathermap.org/current

	$hr = [string]::new('-', 80)

	$apiKey = Get-Secret -Name 'OpenWeatherMap_ApiKey' -AsPlainText -ErrorAction SilentlyContinue
	if (-not $apiKey) { Write-Error 'OpenWeatherMap API key not found in defult secret vault. Add your key with the name ''OpenWeatherMap_ApiKey'' to the default secrets vault.'; return; }

	$lookupBy = _getQueryParams -paramSetName $paramSetName -latitude $latitude -longitude $longitude -cityId $cityId `
								-zipCode $zipCode -countryCode $countryCode -cityName $cityName -stateCode $stateCode
	Write-Verbose "$($MyInvocation.InvocationName): paramSetName = |$paramSetName|, set lookupBy = |$lookupBy|"

	$currentConditions = _getCurrentConditions -apiKey $apiKey -queryBy $lookupBy -units $units
	Write-Host $hr -ForegroundColor Cyan
	Write-Host 'Current Conditions' -ForegroundColor Cyan
	Write-Host $hr -ForegroundColor Cyan
	$currentConditions | Format-List -Property *

	$forecastData = _getForecast -apiKey $apiKey -queryBy $lookupBy -units $units -forecastDays $forecastDays
	if ($forecastData) {
		Write-Host $hr -ForegroundColor Cyan
		Write-Host 'Forecast' -ForegroundColor Cyan
		Write-Host $hr -ForegroundColor Cyan
		$forecastData | Format-Table -Property *
	}
}

function _getCurrentConditions {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject])]
	param(
		[Parameter(Mandatory=$true)] [string] $apiKey,
		[Parameter(Mandatory=$true)] [string] $queryBy,
		[Parameter(Mandatory=$true)] [string] $units
	)
	$requestUrl = "https://api.openweathermap.org/data/2.5/weather?appid=${apiKey}&units=${units}&${queryBy}"
	Write-Verbose "$($MyInvocation.InvocationName): requestUrl = |$requestUrl|"

	$resp = Invoke-RestMethod -Method Get -Uri $requestUrl -ErrorAction Stop
	if ($resp -and $VerbosePreference -eq [System.Management.Automation.ActionPreference]::Continue) {
		#Write-Verbose "$($MyInvocation.InvocationName): response =`r`n$(ConvertTo-Json -InputObject $resp -Depth 100)"
		Write-Verbose "$($MyInvocation.InvocationName): response =`r`n$(ConvertTo-FormattedJson -value $resp -useSpaces <# ugh #>)"
	}

	$tempDesc = _getTemperatureDesc -units $units
	$velocityDesc = _getVelocityDesc -units $units
	$precipDesc = _getRainVolDesc -units $units
	$result = [PSCustomObject]::new()
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Timestamp' -Value (_convertToLocalTime -unixSeconds $resp.dt -offsetSeconds $resp.timezone).ToString('ddd, dd MMM yyyy, HH:mm:ssK')
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Description' -Value "$(@($resp.weather).description -join ', '), clouds: $($resp.clouds.all)%"
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Temperature' -Value "$($resp.main.temp)$tempDesc [area min/max: $($resp.main.temp_min)$tempDesc/$($resp.main.temp_max)$tempDesc]"
	if ($resp.wind.gust -and $resp.wind.gust -gt 0) {
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Wind' -Value "$($resp.wind.speed)$velocityDesc $(_getFriendlyWindDirection -degrees $resp.wind.deg), gusts: $($resp.wind.gust)$velocityDesc"
	} else {
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Wind' -Value "$($resp.wind.speed)$velocityDesc $(_getFriendlyWindDirection -degrees $resp.wind.deg)"
	}
	if ($resp.rain) {
		$val1 = _convertPrecipitation -units $units -value $f.rain.'1h'
		$val3 = _convertPrecipitation -units $units -value $f.rain.'3h'
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Rain' -Value "last hour: $val1$precipDesc, last 3 hours: $val3$precipDesc"
	}
	if ($resp.snow) {
		$val1 = _convertPrecipitation -units $units -value $f.snow.'1h'
		$val3 = _convertPrecipitation -units $units -value $f.snow.'3h'
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Snow' -Value "last hour: $val1$precipDesc, last 3 hours: $val3$precipDesc"
	}
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Humidity' -Value "$($resp.main.humidity)%"
	if ($resp.main.pressure -and $resp.main.pressure -gt 0) {
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Pressure' -Value "$($resp.main.pressure)hPa"
	} elseif ($resp.main.sea_level -and $resp.main.sea_level -gt 0) {
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Pressure' -Value "$($resp.main.sea_level)hPa [sea level pressure]"
	} elseif ($resp.main.grnd_level -and $resp.main.grnd_level -gt 0) {
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Pressure' -Value "$($resp.main.grnd_level)hPa [ground level pressure]"
	}
	if ([string]$resp.visibility) {
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Visibility' -Value "$($resp.visibility / 1000.0)km"
	}
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Sunrise' `
			-Value (_convertToLocalTime -unixSeconds $resp.sys.sunrise -offsetSeconds $resp.timezone).ToString('HH:mm:ssK')
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Sunset' `
			-Value (_convertToLocalTime -unixSeconds $resp.sys.sunset -offsetSeconds $resp.timezone).ToString('HH:mm:ssK')
	Add-Member -InputObject $result -MemberType NoteProperty -Name 'Location' -Value "$($resp.name) [$($resp.coord.lat),$($resp.coord.lon)]"

	return $result
}

function _getForecast {
	[CmdletBinding(SupportsShouldProcess=$true)]
	[OutputType([PSObject[]])]
	param(
		[Parameter(Mandatory=$true)] [string] $apiKey,
		[Parameter(Mandatory=$true)] [string] $queryBy,
		[Parameter(Mandatory=$true)] [int] $forecastDays,
		[Parameter(Mandatory=$true)] [string] $units
	)
	if ($forecastDays -le 0) { return $null }
	if ($forecastDays -gt 5) { $forecastDays = 5 }

	# https://openweathermap.org/forecast5

	$returnCount = $forecastDays * 8
	$requestUrl = "https://api.openweathermap.org/data/2.5/forecast?appid=${apiKey}&units=${units}&cnt=${returnCount}&${queryBy}"
	Write-Verbose "$($MyInvocation.InvocationName): requestUrl = |$requestUrl|"

	$resp = Invoke-RestMethod -Method Get -Uri $requestUrl -ErrorAction Stop
	if ($resp -and $VerbosePreference -eq [System.Management.Automation.ActionPreference]::Continue) {
		#Write-Verbose "$($MyInvocation.InvocationName): response =`r`n$(ConvertTo-Json -InputObject $resp -Depth 100)"
		Write-Verbose "$($MyInvocation.InvocationName): response =`r`n$(ConvertTo-FormattedJson -value $resp -useSpaces <# ugh #>)"
	}

	$offset = $resp.city.timezone #ugh
	$tempDesc = _getTemperatureDesc -units $units
	$velocityDesc = _getVelocityDesc -units $units
	$precipDesc = _getRainVolDesc -units $units
	# if no forecast objects have rain and/or snow data, don't need to add those columns
	$hasRain = $false; $hasSnow = $false;
	foreach ($f in $resp.list) {
		if ($f.rain) { $hasRain = $true }
		if ($f.snow) { $hasSnow = $true }
	}
	foreach ($f in $resp.list) {
		$result = [PSCustomObject]::new()
		$ts = _convertToLocalTime -unixSeconds $f.dt -offsetSeconds $offset
		$tsHour = $ts.Hour % 12
		$tsFormat = if ($tsHour -gt 0 -and $tsHour -lt 10) { 'ddd  h tt' } else { 'ddd h tt' }
		#Write-Verbose "ts: |$($ts.ToString('yyyy-MM-dd HH:mm:ss'))| / ts.Hour % 12 = |$($ts.Hour % 12)| / tsFormat = |$tsFormat|"
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Time' -Value $ts.ToString($tsFormat)
		# TODO: map their icon (https://openweathermap.org/weather-conditions#How-to-get-icon-URL) to nerdfont icons
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Description' -Value "$(@($f.weather).description -join ', ')"
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Temperature' -Value "$([System.Math]::Round(($f.main.temp), 0))$tempDesc"
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Humidity' -Value "$($f.main.humidity)%"
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Clouds' -Value "$($f.clouds.all)%"
		Add-Member -InputObject $result -MemberType NoteProperty -Name 'Precip' -Value "$($f.pop * 100)%"
		if ($f.rain) {
			$val = _convertPrecipitation -units $units -value $f.rain.'3h'
			Add-Member -InputObject $result -MemberType NoteProperty -Name 'Rainfall' -Value "$val$precipDesc"
		} elseif ($hasRain) {
			Add-Member -InputObject $result -MemberType NoteProperty -Name 'Rainfall' -Value ''
		}
		if ($f.snow) {
			$val = _convertPrecipitation -units $units -value $f.snow.'3h'
			Add-Member -InputObject $result -MemberType NoteProperty -Name 'Snowfall' -Value "$val$precipDesc"
		} elseif ($hasSnow) {
			Add-Member -InputObject $result -MemberType NoteProperty -Name 'Snowfall' -Value ''
		}
		if ($f.wind.gust -and $f.wind.gust -gt 0) {
			Add-Member -InputObject $result -MemberType NoteProperty -Name 'Wind' -Value "$($f.wind.speed)$velocityDesc $(_getFriendlyWindDirection -degrees $f.wind.deg), gusts: $($f.wind.gust)$velocityDesc"
		} else {
			Add-Member -InputObject $result -MemberType NoteProperty -Name 'Wind' -Value "$($f.wind.speed)$velocityDesc $(_getFriendlyWindDirection -degrees $f.wind.deg)"
		}
		Write-Output $result
	}
}

function _getQueryParams {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)] [string] $paramSetName,
		[string] $latitude,
		[string] $longitude,
		[long] $cityId,
		[string] $zipCode,
		[string] $countryCode,
		[string] $cityName,
		[string] $stateCode
	)
	$result = ''
	switch ($paramSetName) {
		'LatLong' {
			$result = "lat=${latitude}&lon=${longitude}"
			break
		}
		'CityId' {
			$result = "id=${cityId}"
			break
		}
		'CityName' {
			$result = "q=${cityName}"
			if ($stateCode) {
				$result += ",${stateCode}"
			}
			if ($countryCode) {
				$result += ",${countryCode}"
			}
			break
		}
		'ZipCode' {
			$result = "zip=${zipCode}"
			if ($countryCode) {
				$result += ",${countryCode}"
			}
			break
		}
		default { throw 'unrecognized parameter set name: "$paramSetName"' }
	}
	return $result
}

$script:arcDegrees = 360.0 / 16.0					# 22.5
$script:halfArcDegrees = $script:arcDegrees / 2.0	# 11.25
function _getFriendlyWindDirection {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)]
		[long] $degrees
	)
#	$arc = 360.0 / 16.0
#	$halfArc = $arc / 2.0
	# this seems kinda inefficient, but ... meh, good enough:
	if ($degrees -ge (360.0 - $script:halfArcDegrees) -or $degrees -lt $script:halfArcDegrees) { return 'N' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 0) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 1)) { return 'NNE' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 1) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 2)) { return 'NE' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 2) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 3)) { return 'ENE' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 3) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 4)) { return 'E' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 4) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 5)) { return 'ESE' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 5) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 6)) { return 'SE' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 6) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 7)) { return 'SSE' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 7) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 8)) { return 'S' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 8) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 9)) { return 'SSW' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 9) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 10)) { return 'SW' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 10) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 11)) { return 'WSW' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 11) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 12)) { return 'W' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 12) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 13)) { return 'WNW' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 13) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 14)) { return 'NW' }
	if ($degrees -ge ($script:halfArcDegrees + $script:arcDegrees * 14) -and $degrees -lt ($script:halfArcDegrees + $script:arcDegrees * 15)) { return 'NNW' }
}

function _getTemperatureDesc {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)]
		[string] $units
	)
	if ($units -eq 'imperial') { return <# '℉' doesn't look very good #> '°F' }
	if ($units -eq 'metric') { return <# '℃' doesn't look very good #> '°C' }
	return 'K' <# 'K' #>
}

function _getVelocityDesc {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)]
		[string] $units
	)
	if ($units -eq 'imperial') { return 'mph' }
	return 'm/s'
}

function _getRainVolDesc {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)]
		[string] $units
	)
	if ($units -eq 'imperial') { return 'in' }
	return 'mm'
}

function _convertPrecipitation {
	[OutputType([float])]
	param(
		[Parameter(Mandatory=$true)]
		[float] $value,
		[Parameter(Mandatory=$true)]
		[string] $units
	)
	# they always return precipitation in mm, regardless of what units we ask for:
	if ($units -eq 'imperial') {
		return [System.Math]::Round(($value / 25.4), 2)
	}
	return $value
}

function _convertToLocalTime {
	[OutputType([string])]
	param(
		[Parameter(Mandatory=$true)]
		[long] $unixSeconds,
		[Parameter(Mandatory=$true)]
		[long] $offsetSeconds
	)
	$dtutc = [System.DateTimeOffset]::FromUnixTimeSeconds($unixSeconds)
	return [System.DateTimeOffset]::new($dtutc.AddSeconds($offsetSeconds).DateTime, [timespan]::FromSeconds($offsetSeconds))
}

#==============================
Main -paramSetName $PSCmdlet.ParameterSetName -latitude $latitude -longitude $longitude -cityId $cityId `
		-zipCode $zipCode -countryCode $countryCode -cityName $cityName -stateCode $stateCode `
		-forecastDays $forecastDays -units $units
#==============================
