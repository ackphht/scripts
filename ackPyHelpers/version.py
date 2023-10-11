#!python3
# -*- coding: utf-8 -*-

class Version:
	"""
	represents a version with Major.Minor.Revision

	create one directly and pass in the major, minor and revision, or use the static method parseVersionString() to initialize a Version.
	"""

	def __init__(self, major: int, minor: int, revision: int):
		self._major: int = major
		self._minor: int = minor
		self._rev: int = revision

	def __repr__(self):
		return f"<Version: major={self.major}, minor={self.minor}, revision={self.revision}>"

	def __str__(self):
		return f"{self.major}.{self.minor}.{self.revision}"

	def __hash__(self):
		return hash(self.major, self.minor, self.revision)

	# docs (Library Reference > Built-in Types > Comparisons) say that __eq__ and __lt__ are enough
	def __eq__(self, other):
		return (self.major == other.major and self.minor == other.minor and self.revision == other.revision) if isinstance(other, Version) else NotImplemented

	def __lt__(self, other):
		return (self.major < other.major or self.minor < other.minor or self.revision < other.revision) if isinstance(other, Version) else NotImplemented

	@staticmethod
	def parseVersionString(ver: str):	# -> Self:
		if ver:
			major = minor = rev = 0
			sp = ver.split(".")
			# TODO: error handling for non-ints ??
			major = int(sp[0])
			if len(sp) >= 2:
				minor = int(sp[1])
			if len(sp) >= 3:
				rev = int(sp[2])
			return Version(major, minor, rev)
		else:
			return Version(0, 0, 0)

	@property
	def isZeroVersion(self):
		return self.major == 0 and self.minor == 0 and self.revision == 0

	@property
	def major(self):
		return self._major if self._major else 0

	@property
	def minor(self):
		return self._minor if self._minor else 0

	@property
	def revision(self):
		return self._rev if self._rev else 0
