[TimeZoneInfo]::GetSystemTimeZones() |
	Sort-Object -Property BaseUtcOffset,Id |
	Format-Table -Property Id,@{Label="BaseOffset";Expression={$_.BaseUtcOffset}},@{Label="SupportsDst";Expression={$_.SupportsDaylightSavingTime}},StandardName,DaylightName,DisplayName