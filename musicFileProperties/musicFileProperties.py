#!python3
# -*- coding: utf-8 -*-

import pathlib
from sqlite3 import NotSupportedError
from typing import Any, Iterable, Iterator
import mutagen					# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from ackPyHelpers import LogHelper
from .tagNames import TagNames
from .tagMapper import _tagMapper

class MusicFileProperties:
	_noPaddingArgOnSave: set[str] = { "APEv2", }

	def __init__(self, musicFilePath):
		if isinstance(musicFilePath, str):
			musicFilePath = pathlib.Path(musicFilePath)
		if not musicFilePath.is_file():
			raise FileNotFoundError(str(musicFilePath.absolute()))
		if not musicFilePath.is_absolute():
			musicFilePath = musicFilePath.absolute()
		self._musicFilePath = musicFilePath
		self._dirty = False
		self._mutagen: mutagen.FileType = mutagen.File(self._musicFilePath)
		self._mapper = _tagMapper.getTagMapper(self._mutagen.tags)
		self._tagtype = _tagMapper.getTagType(self._mutagen.tags)

	def save(self, removePadding = False) -> bool:
		if not self._dirty:
			return False
		if removePadding and self._tagtype not in MusicFileProperties._noPaddingArgOnSave:
			self._mutagen.save(padding = lambda x: 0)
		else:
			self._mutagen.save()
		self._dirty = False
		return True

	def getTagValues(self) -> Iterator[tuple[str, Any]]:
		#
		# TODO: this should just go through TagNames and try getting each one
		#
		yield ("AlbumArtist", self.AlbumArtist)
		yield ("AlbumTitle", self.AlbumTitle)
		yield ("TrackArtist", self.TrackArtist)
		yield ("TrackTitle", self.TrackTitle)
		yield ("Year", self.Year)
		yield ("Composer", self.Composer)
		yield ("Lyricist", self.Lyricist)
		yield ("Producer", self.Producer)
		yield ("TrackNumber", self.TrackNumber)
		yield ("TotalTracks", self.TotalTracks)
		yield ("DiscNumber", self.DiscNumber)
		yield ("TotalDiscs", self.TotalDiscs)
		yield ("Genre", self.Genre)
		yield ("Comments", self.Comments)

	def getNativeTagValues(self) -> Iterator[tuple[str, Any]]:
		yield ('$$TagType', self._mutagen.tags.__class__.__name__)
		for tag in self._mutagen.tags:
			# some tag types, the iterator returns a tuple(name,value), others it just returns the name
			if isinstance(tag, tuple):
				yield tag
			else:
				yield (tag, self._mutagen[tag])

	def getNativePropertyNames(self) -> Iterator[str]:
		for tag in self._mutagen.tags:
			# some tag types, the iterator returns a tuple(name,value), others it just returns the name
			if isinstance(tag, tuple):
				yield tag[0]
			else:
				yield tag

	def getTagValue(self, tagName: str) -> list[str|int|bytes|list[str,str]]:
		return self._getMutagenProperty(tagName)

	def setTagValue(self, tagName: str, value: Any) -> None:
		"""
		sets or removes the value of the specified tag.

		The value can be a string, an integer or a list of values. If the value is None or an empty string, the tag will be removed.
		"""
		if tagName == TagNames.Cover:
			raise NotSupportedError("setting the cover image is not supported (yet??)")
		return self._setMutagenProperty(tagName, value)

	def getNativeTagValue(self, rawTagName: str) -> list[str|int|Any]|str|Any|None:
		return self._mutagen.tags[rawTagName] if rawTagName in self._mutagen.tags else None

	def getTagValueFromNativeName(self, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
		val = self._mutagen.tags[rawTagName] if rawTagName in self._mutagen.tags else None
		if val is None: return []
		return list(self._mapMutagenProperty(val, self._mapper.mapFromRawName(rawTagName), rawTagName))

	def mapToNativeTagName(self, tagName: str) -> list[str]:
		return self._mapper.mapToRawName(tagName)

	def setNativeTagValue(self, rawTagName : str, value : Any) -> None:
		if self._mapper.mapFromRawName(rawTagName) == TagNames.Cover:
			raise NotSupportedError("setting the cover image is not supported (yet??)")
		#
		# TODO: name passed here is the "raw" tag name, but method expects mapped name, need to update this somehow; or remove it ???
		#
		self._setMutagenProperty(rawTagName, value)

	def deleteNativeTagValue(self, rawTagName : str) -> None:
		#
		# TODO: name passed here is the "raw" tag name, but method expects mapped name, need to update this somehow; or remove it ???
		#
		self._deleteMutagenProperty(rawTagName)

	def removeAllTags(self) -> None:
		self._mutagen.tags.clear()

	def _getMutagenProperty(self, tagName : str) -> list[str|int|bytes|list[str,str]]:
		if self._mapper.isSpecialHandlingTag(tagName):
			return self._mapper.getSpecialHandlingTagValues(tagName, self._mutagen.tags)

		rawTagNames = self._mapper.mapToRawName(tagName)
		tagValues: list[tuple[Any, str]] = []
		for n in rawTagNames:
			v = self._mutagen.tags[n] if n in self._mutagen.tags else None
			if v is not None: tagValues.append((v, n))
		if len(tagValues) == 0: return []
		# apparently mutagen gives us the same objects and lists of objects that it's caching underneath,
		# and if we modify those lists (like turning a complex type into a simple type), it's modifying
		# those cached values, which seems like a bad thing; also the list we return may get modified by caller;
		# so we always create a new list:
		results = []
		for rawTagValue,rawTagName in tagValues:
			for v in self._mapMutagenProperty(rawTagValue, tagName, rawTagName):
				results.append(v)
		return results

	def _setMutagenProperty(self, tagName : str, value : Any) -> None:
		rawTagNames = self._mapper.mapToRawName(tagName)
		if rawTagNames is None or len(rawTagNames) == 0:
			raise KeyError(f'tag name "{0}" is not mapped: do not know how to set it', tagName)

		LogHelper.Verbose('setting mutagen property "{0}" (raw tag name(s): "{1}")', tagName, rawTagNames)
		if not self._mapper.isSpecialHandlingTag(tagName):
			# if property is empty/None, delete the property:
			if value is None or (isinstance(value, str) or isinstance(value, list)) and len(value) == 0:
				LogHelper.Verbose('value for tag "{0}" is None or empty: removing raw tag(s) "{1}"', tagName, rawTagNames)
				for t in rawTagNames:
					if t in self._mutagen.tags:
						del self._mutagen.tags[t]
						self._dirty = True
				return

		# we're only going to set the first rawTagName from the mapping; if there are others, remove them:
		for idx in range(0, len(rawTagNames)):
			t = rawTagNames[idx]
			delete = True
			if idx == 0:
				LogHelper.Verbose('getting wrapped value for tag "{0}"', t)
				rawValues = self._mapper.prepareValueForSet(value, tagName, t, self._mutagen.tags)
				if rawValues is not None and ((not isinstance(rawValues, list) and not isinstance(rawValues, str)) or len(rawValues) > 0):
					LogHelper.Verbose('setting tag "{0}"', t)
					self._mutagen[t] = rawValues
					self._dirty = True
					delete = False
			if delete:
				if t in self._mutagen.tags:
					LogHelper.Verbose('deleting tag "{0}"', t)
					del self._mutagen.tags[t]
					self._dirty = True

	def _deleteMutagenProperty(self, tagName : str) -> None:
		self._setMutagenProperty(tagName, None)

	def _mapMutagenProperty(self, rawTagValue: Any, tagName: str, rawTagName: str) -> Iterable[str|int|bytes|list[str,str]]:
		if MusicFileProperties._isSimpleType(rawTagValue):
			yield rawTagValue
		elif isinstance(rawTagValue, list):
			if len(rawTagValue) > 0:
				# can we get a list of lists ???
				for v in rawTagValue:
					if v is None:
						continue
					elif MusicFileProperties._isSimpleType(v):
						yield v
					else:
						for v2 in self._mapper.mapFromRawValue(v, tagName, rawTagName):
							yield v2
		else:
			for v2 in self._mapper.mapFromRawValue(rawTagValue, tagName, rawTagName):
				yield v2

	@staticmethod
	def _isSimpleType(value: Any) -> bool:
		t = type(value)
		return t is str or t is int or t is bytes

	@property
	def TagType(self) -> pathlib.Path:
		return self._tagtype

	@property
	def HasChanges(self) -> pathlib.Path:
		return self._dirty

	@property
	def FilePath(self) -> pathlib.Path:
		return self._musicFilePath

	@property
	def DurationSeconds(self) -> float:
		return self._mutagen.info.length

	## region property LastWriteTime
	#@property
	#def LastWriteTime(self):
	#	raise NotImplementedError()
	#
	#@LastWriteTime.setter
	#def LastWriteTime(self, value : str):
	#	raise NotImplementedError()
	## endregion

	# region property AlbumTitle
	@property
	def AlbumTitle(self) -> list[str]:
		return self._getMutagenProperty(TagNames.AlbumTitle)

	@AlbumTitle.setter
	def AlbumTitle(self, value : str) -> None:
		self._setMutagenProperty(TagNames.AlbumTitle, value)

	@AlbumTitle.deleter
	def AlbumTitle(self) -> None:
		self._deleteMutagenProperty(TagNames.AlbumTitle)
	# endregion

	# region property TrackTitle
	@property
	def TrackTitle(self) -> list[str]:
		return self._getMutagenProperty(TagNames.TrackTitle)

	@TrackTitle.setter
	def TrackTitle(self, value : str) -> None:
		self._setMutagenProperty(TagNames.TrackTitle, value)

	@TrackTitle.deleter
	def TrackTitle(self) -> None:
		self._deleteMutagenProperty(TagNames.TrackTitle)
	# endregion

	# region property AlbumArtist
	@property
	def AlbumArtist(self) -> list[str]:
		return self._getMutagenProperty(TagNames.AlbumArtist)

	@AlbumArtist.setter
	def AlbumArtist(self, value : str) -> None:
		self._setMutagenProperty(TagNames.AlbumArtist, value)

	@AlbumArtist.deleter
	def AlbumArtist(self) -> None:
		self._deleteMutagenProperty(TagNames.AlbumArtist)
	# endregion

	# region property TrackArtist
	@property
	def TrackArtist(self) -> list[str]:
		return self._getMutagenProperty(TagNames.TrackArtist)

	@TrackArtist.setter
	def TrackArtist(self, value : str) -> None:
		self._setMutagenProperty(TagNames.TrackArtist, value)

	@TrackArtist.deleter
	def TrackArtist(self) -> None:
		self._deleteMutagenProperty(TagNames.TrackArtist)
	# endregion

	# region property Year
	@property
	def Year(self) -> list[int]:
		return self._getMutagenProperty(TagNames.YearReleased)

	@Year.setter
	def Year(self, value : int) -> None:
		self._setMutagenProperty(TagNames.YearReleased, value)

	@Year.deleter
	def Year(self) -> None:
		self._deleteMutagenProperty(TagNames.YearReleased)
	# endregion

	# region property Composer
	@property
	def Composer(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Composer)

	@Composer.setter
	def Composer(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Composer, value)

	@Composer.deleter
	def Composer(self) -> None:
		self._deleteMutagenProperty(TagNames.Composer)
	# endregion

	# region property Comments
	@property
	def Comments(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Comment)

	@Comments.setter
	def Comments(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Comment, value)

	@Comments.deleter
	def Comments(self) -> None:
		self._deleteMutagenProperty(TagNames.Comment)
	# endregion

	# region property Genre
	@property
	def Genre(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Genre)

	@Genre.setter
	def Genre(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Genre, value)

	@Genre.deleter
	def Genre(self) -> None:
		self._deleteMutagenProperty(TagNames.Genre)
	# endregion

	# region property TrackNumber
	@property
	def TrackNumber(self) -> list[int]:
		return self._getMutagenProperty(TagNames.TrackNumber)
		## if no track info at all, will not return anything; otherwise it always returns a tuple; if one value is missing, it will be 0 in the tuple
		#return trackInfo[0] if trackInfo and trackInfo[0] > 0 else None

	@TrackNumber.setter
	def TrackNumber(self, value : int) -> None:
		self._setMutagenProperty(TagNames.TrackNumber, value)

	@TrackNumber.deleter
	def TrackNumber(self) -> None:
		self._deleteMutagenProperty(TagNames.TrackNumber)
	# endregion

	# region property TotalTracks
	@property
	def TotalTracks(self) -> list[int]:
		return self._getMutagenProperty(TagNames.TrackCount)
		#return trackInfo[1] if trackInfo and trackInfo[1] > 0 else None

	@TotalTracks.setter
	def TotalTracks(self, value : int) -> None:
		self._setMutagenProperty(TagNames.TrackCount, value)

	@TotalTracks.deleter
	def TotalTracks(self) -> None:
		self._deleteMutagenProperty(TagNames.TrackCount)
	# endregion

	# region property DiscNumber
	@property
	def DiscNumber(self) -> list[int]:
		return self._getMutagenProperty(TagNames.DiscNumber)
		#return discInfo[0] if discInfo and discInfo[0] > 0 else None

	@DiscNumber.setter
	def DiscNumber(self, value : int) -> None:
		self._setMutagenProperty(TagNames.DiscNumber, value)

	@DiscNumber.deleter
	def DiscNumber(self) -> None:
		self._deleteMutagenProperty(TagNames.DiscNumber)
	# endregion

	# region property TotalDiscs
	@property
	def TotalDiscs(self) -> list[int]:
		return self._getMutagenProperty(TagNames.DiscCount)
		#return discInfo[1] if discInfo and discInfo[1] > 0 else None

	@TotalDiscs.setter
	def TotalDiscs(self, value : int) -> None:
		self._setMutagenProperty(TagNames.DiscCount, value)

	@TotalDiscs.deleter
	def TotalDiscs(self) -> None:
		self._deleteMutagenProperty(TagNames.DiscCount)
	# endregion

	# region property Producer
	@property
	def Producer(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Producer)

	@Producer.setter
	def Producer(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Producer, value)

	@Producer.deleter
	def Producer(self) -> None:
		self._deleteMutagenProperty(TagNames.Producer)
	# endregion

	# region property Conductor
	@property
	def Conductor(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Conductor)

	@Conductor.setter
	def Conductor(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Conductor, value)

	@Conductor.deleter
	def Conductor(self) -> None:
		self._deleteMutagenProperty(TagNames.Conductor)
	# endregion

	# region property Copyright
	@property
	def Copyright(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Copyright)

	@Copyright.setter
	def Copyright(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Copyright, value)

	@Copyright.deleter
	def Copyright(self) -> None:
		self._deleteMutagenProperty(TagNames.Copyright)
	# endregion

	# region property RecordLabel
	@property
	def RecordLabel(self) -> list[str]:
		return self._getMutagenProperty(TagNames.RecordLabel)

	@RecordLabel.setter
	def RecordLabel(self, value : str) -> None:
		self._setMutagenProperty(TagNames.RecordLabel, value)

	@RecordLabel.deleter
	def RecordLabel(self) -> None:
		self._deleteMutagenProperty(TagNames.RecordLabel)
	# endregion

	# region property Lyrics
	@property
	def Lyrics(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Lyrics)

	@Lyrics.setter
	def Lyrics(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Lyrics, value)

	@Lyrics.deleter
	def Lyrics(self) -> None:
		self._deleteMutagenProperty(TagNames.Lyrics)
	# endregion

	# region property Lyricist
	@property
	def Lyricist(self) -> list[str]:
		return self._getMutagenProperty(TagNames.Lyricist)

	@Lyricist.setter
	def Lyricist(self, value : str) -> None:
		self._setMutagenProperty(TagNames.Lyricist, value)

	@Lyricist.deleter
	def Lyricist(self) -> None:
		self._deleteMutagenProperty(TagNames.Lyricist)
	# endregion
