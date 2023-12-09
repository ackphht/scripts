#!python3
# -*- coding: utf-8 -*-

from datetime import datetime, timezone, date, time, tzinfo
from .loghelper import LogHelper

class DateTimeHelpers:
	"""
	class to help with some datetime conversions
	"""

	@staticmethod
	def Now() -> datetime:
		"""gets a datetime for the current local time"""
		return datetime.now().astimezone()

	@staticmethod
	def UtcNow() -> datetime:
		"""gets a datetime for the current UTC time"""
		# datetime.utcnow() returns a datetime with no timezone info; don't use that
		return datetime.now(timezone.utc)

	@staticmethod
	def HasValidTimezone(value: datetime|time) -> bool:
		"""checks if the given datetime or time object has valid, usable timezone info"""
		return bool(value.tzinfo) and value.tzinfo.utcoffset((value if isinstance(value, datetime) else None)) is not None

	@staticmethod
	def CurrentLocalTimeZone() -> timezone:
		"""
		returns the local 'timezone' as of this moment

		don't forget: this "timezone" object is not a timezone like .NET's: it's simply an offset with a name
		"""
		return datetime.now(timezone.utc).astimezone().tzinfo	# ffs

	@staticmethod
	def GetLocalTimeZoneFor(dt: datetime) -> timezone:
		"""
		returns the local 'timezone' as of the datetime, if the datetime does not already have a timezone specified. If it does, that is returned.

		don't forget: this "timezone" object is not a timezone like .NET's: it's simply an offset with a name
		"""
		return dt.tzinfo if dt.tzinfo else datetime.astimezone().tzinfo

	@staticmethod
	def FromTimestamp(timestamp: float, targetTimezone: timezone = None) -> datetime:
		"""
		parses a timestamp (like returned for a file's modified time) and returns a datetime object

		if targetTimezone is None, timestamp will be assumed to be local time (which is what the stat() methods return).
		if targetTimezone is not None, timestamp will still be assumed to be local, but will then be adjusted to the specified timezone.
		"""
		dt = datetime.fromtimestamp(timestamp, targetTimezone)
		return dt if DateTimeHelpers.HasValidTimezone(dt) else dt.astimezone()

	@staticmethod
	def FromTimestampUtc(timestamp: float) -> datetime:
		"""
		parses a timestamp (like returned for a file's modified time) and returns a datetime object

		timestamp is assumed to be local time (which is what the stat() methods return), and converted to UTC.
		"""
		return DateTimeHelpers.FromTimestamp(timestamp, timezone.utc)
