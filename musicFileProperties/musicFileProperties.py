#!python3
# -*- coding: utf-8 -*-

import pathlib
from typing import Any, Iterator
import mutagen					# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from ackPyHelpers import LogHelper
from .mp4TagNames import Mp4TagNames
from .tagNames import TagNames
from .tagMapper import TagMapper

class MusicFileProperties:
	def __init__(self, musicFilePath):
		if isinstance(musicFilePath, str):
			musicFilePath = pathlib.Path(musicFilePath)
		if not musicFilePath.is_file():
			raise FileNotFoundError(str(musicFilePath.absolute()))
		if not musicFilePath.is_absolute():
			musicFilePath = musicFilePath.absolute()
		self._musicFilePath = musicFilePath
		self._dirty = False
		self._mutagen = None
		self._tinytag = None
		self._mutagen = mutagen.File(self._musicFilePath)
		self._mapper = TagMapper.getTagMapper(self._mutagen.tags)

	def save(self, removePadding = False) -> bool:
		if not self._dirty:
			return False
		if removePadding:
			#
			# TODO: is this padding thing for other types than M4A ?? do we need to check for that ??
			#
			self._mutagen.save(padding = lambda x: 0)
		else:
			self._mutagen.save()
		self._dirty = False
		return True

	def getProperties(self) -> Iterator[tuple[str, Any]]:
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

	def getRawProperties(self) -> Iterator[tuple[str, Any]]:
		yield ('$$TagType', self._mutagen.tags.__class__.__name__)
		for tag in self._mutagen.tags:
			# some tag types, the iterator returns a tuple(name,value), others it just returns the name
			if isinstance(tag, tuple):
				yield tag
			else:
				yield (tag, self._mutagen[tag])

	def getRawPropertyNames(self) -> Iterator[str]:
		for tag in self._mutagen.tags:
			# some tag types, the iterator returns a tuple(name,value), others it just returns the name
			if isinstance(tag, tuple):
				yield tag[0]
			else:
				yield tag

	def getProperty(self, propertyName: str) -> list[str|int|bytes]:
		return self._getMutagenProperty(propertyName)

	def getRawProperty(self, propertyName: str) -> str|int|None:
		return self._mutagen[propertyName] if propertyName in self._mutagen else None

	def setRawProperty(self, propertyName : str, value : Any) -> None:
		self._setMutagenProperty(propertyName, value)

	def deleteRawProperty(self, propertyName : str) -> None:
		self._deleteMutagenProperty(propertyName)

	def _getMutagenProperty(self, tagName : str) -> list[str|int|bytes]:
		# TODO: mapToRawName needs to return all the names, not just first one
		rawTagName = self._mapper.mapToRawName(tagName)
		if not rawTagName: return []
		val = self._mutagen.tags[rawTagName] if rawTagName in self._mutagen.tags else None
#		return self._mapper.mapFromRawValue(val, propertyName, rawTagName)
		if val is None: return []
		# apparently mutagen gives us the same objects and lists of objects that it's caching underneath,
		# and if we modify those lists (like turning a complex type into a simple type), it's modifying
		# those cached values, which seems like a bad thing; also the list we return may get modified by caller;
		# so we always create a new list:
		results = []
		if MusicFileProperties._isSimpleType(val):
			results.append(val)
		elif isinstance(val, list):
			if len(val) > 0:
				# can we get a list of lists ???
				for v in val:
					if v is None:
						continue
					elif MusicFileProperties._isSimpleType(v):
						results.append(v)
					else:
						for v2 in self._mapper.mapFromRawValue(v, tagName, rawTagName):
							results.append(v2)
		else:
			for v2 in self._mapper.mapFromRawValue(val, tagName, rawTagName):
				results.append(v2)
		return results




	def _setMutagenProperty(self, propertyName : str, value : Any) -> None:
		LogHelper.Verbose('setting mutagen property named "{0}"', propertyName)
		if value == None or (isinstance(value, str) and len(value) == 0):
			if propertyName in self._mutagen:
				del self._mutagen[propertyName]
				self._dirty = True
			return
		# TODO: this is all kinda specific to mp4 files; if we want this to work other types of files...
		if not propertyName.startswith(Mp4TagNames.Mp4CustomPropertyPrefix):
			self._mutagen[propertyName] = value
		else:
			if type(value) is list and len(value) == 1 and type(value[0]) is mutagen.mp4.MP4FreeForm:
				self._mutagen[propertyName] = value[0]		# probably should check that the file is actually an mp4...
			else:
				if not isinstance(value, str):
					raise NotImplementedError("only currently know how to set string values")
				self._mutagen[propertyName] = mutagen.mp4.MP4FreeForm(value.encode(), dataformat=mutagen.mp4.AtomDataType.UTF8)
		self._dirty = True

	def _deleteMutagenProperty(self, propertyName : str) -> None:
		if propertyName in self._mutagen:
			del self._mutagen[propertyName]
			self._dirty = True

	def _setTrackOrDisc(self, propertyName : str, val : int, ttl : int) -> None:
		val = 0 if val is None or val < 0 else val
		ttl = 0 if ttl is None or ttl < 0 else ttl
		if val == 0 and ttl == 0:
			self._deleteMutagenProperty(propertyName)
		else:
			self._setMutagenProperty(propertyName, [(val, ttl)])

	@staticmethod
	def _isSimpleType(value: Any) -> bool:
		t = type(value)
		return t is str or t is int or t is bytes

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
		#
		# TODO
		#
		trackInfo= self._getMutagenProperty(TagNames.TrackNumber)
		# if no track info at all, will not return anything; otherwise it always returns a tuple; if one value is missing, it will be 0 in the tuple
		return trackInfo[0] if trackInfo and trackInfo[0] > 0 else None

	@TrackNumber.setter
	def TrackNumber(self, value : int) -> None:
		self._setTrackOrDisc(TagNames.TrackNumber, value, self.TotalTracks)

	@TrackNumber.deleter
	def TrackNumber(self) -> None:
		self._setTrackOrDisc(TagNames.TrackNumber, 0, self.TotalTracks)
	# endregion

	# region property TotalTracks
	@property
	def TotalTracks(self) -> list[int]:
		#
		# TODO
		#
		trackInfo= self._getMutagenProperty(TagNames.TrackNumber)
		return trackInfo[1] if trackInfo and trackInfo[1] > 0 else None

	@TotalTracks.setter
	def TotalTracks(self, value : int) -> None:
		self._setTrackOrDisc(TagNames.TrackNumber, self.TrackNumber, value)

	@TotalTracks.deleter
	def TotalTracks(self) -> None:
		self._setTrackOrDisc(TagNames.TrackNumber, self.TrackNumber, 0)
	# endregion

	# region property DiscNumber
	@property
	def DiscNumber(self) -> list[int]:
		#
		# TODO
		#
		discInfo= self._getMutagenProperty(TagNames.DiscNumber)
		return discInfo[0] if discInfo and discInfo[0] > 0 else None

	@DiscNumber.setter
	def DiscNumber(self, value : int) -> None:
		self._setTrackOrDisc(TagNames.DiscNumber, value, self.TotalDiscs)
		pass

	@DiscNumber.deleter
	def DiscNumber(self) -> None:
		self._setTrackOrDisc(TagNames.DiscNumber, 0, self.TotalDiscs)
	# endregion

	# region property TotalDiscs
	@property
	def TotalDiscs(self) -> list[int]:
		#
		# TODO
		#
		discInfo= self._getMutagenProperty(TagNames.DiscNumber)
		return discInfo[1] if discInfo and discInfo[1] > 0 else None

	@TotalDiscs.setter
	def TotalDiscs(self, value : int) -> None:
		self._setTrackOrDisc(TagNames.DiscNumber, self.DiscNumber, value)
		pass

	@TotalDiscs.deleter
	def TotalDiscs(self) -> None:
		self._setTrackOrDisc(TagNames.DiscNumber, self.DiscNumber, 0)
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
