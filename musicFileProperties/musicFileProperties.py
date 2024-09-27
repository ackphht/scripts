#!python3
# -*- coding: utf-8 -*-

import pathlib
from typing import Any, Iterator
import mutagen					# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from ackPyHelpers import LogHelper
from .mp4TagNames import Mp4TagNames
from .musicTagNames import MusicTagNames
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

	def save(self, removePadding = False) -> bool:
		if not self._dirty:
			return False
		if removePadding:
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
		yield ("Genre", self.Genre)
		yield ("Comments", self.Comments)
		yield ("TrackNumber", self.TrackNumber)
		yield ("TotalTracks", self.TotalTracks)
		yield ("DiscNumber", self.DiscNumber)
		yield ("TotalDiscs", self.TotalDiscs)
		yield ("Producer", self.Producer)
		yield ("Conductor", self.Conductor)
		yield ("Copyright", self.Copyright)
		yield ("Publisher", self.Publisher)
		yield ("Lyrics", self.Lyrics)
		yield ("Lyricist", self.Lyricist)
		yield ("OriginalArtist", self.OriginalArtist)
		yield ("OriginalAlbum", self.OriginalAlbum)
		yield ("OriginalYear", self.OriginalYear)

	def getRawProperties(self) -> Iterator[tuple[str, Any]]:
		yield ('$$TagType', self._mutagen.tags.__class__.__name__)
		for tag in self._mutagen.tags:
			if isinstance(tag, tuple):
				yield tag
			else:
				yield (tag, self._mutagen[tag])

	def getRawPropertyNames(self) -> Iterator[str]:
		for tag in self._mutagen.tags:
			yield tag

	def getProperty(self, propertyName: str) -> str|int|None:
		return self._getMutagenProperty(propertyName)

	def getRawProperty(self, propertyName: str) -> str|int|None:
		return self._mutagen[propertyName] if propertyName in self._mutagen else None

	def setRawProperty(self, propertyName : str, value : Any) -> None:
		self._setMutagenProperty(propertyName, value)

	def deleteRawProperty(self, propertyName : str) -> None:
		self._deleteMutagenProperty(propertyName)

	def _getMutagenProperty(self, propertyName : str) -> str|int|None:
		val = self._mutagen[propertyName] if propertyName in self._mutagen else None
		if val and isinstance(val, list) and len(val) > 0:
			#
			# TODO: what if there's more than one? think MP4s do support it; Mp3tag, at least, does that sometimes
			#
			val = val[0]
		# TODO: this is all kinda specific to mp4 files; if we want this to work other types of files...
		if val and isinstance(val, mutagen.mp4.MP4FreeForm):
			if val.dataformat != mutagen.mp4.AtomDataType.UTF8:
				raise NotImplementedError("MP4FreeForm contains unsupported data type: " + str(val.dataform))
			val = val.decode("utf-8")
		return val

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

	@property
	def HasChanges(self) -> pathlib.Path:
		return self._dirty

	@property
	def FilePath(self) -> pathlib.Path:
		return self._musicFilePath

	@property
	def DurationSeconds(self) -> int:
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
	def AlbumTitle(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.AlbumTitle)

	@AlbumTitle.setter
	def AlbumTitle(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.AlbumTitle, value)

	@AlbumTitle.deleter
	def AlbumTitle(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.AlbumTitle)
	# endregion

	# region property TrackTitle
	@property
	def TrackTitle(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.TrackTitle)

	@TrackTitle.setter
	def TrackTitle(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.TrackTitle, value)

	@TrackTitle.deleter
	def TrackTitle(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.TrackTitle)
	# endregion

	# region property AlbumArtist
	@property
	def AlbumArtist(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.AlbumArtist)

	@AlbumArtist.setter
	def AlbumArtist(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.AlbumArtist, value)

	@AlbumArtist.deleter
	def AlbumArtist(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.AlbumArtist)
	# endregion

	# region property TrackArtist
	@property
	def TrackArtist(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.TrackArtist)

	@TrackArtist.setter
	def TrackArtist(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.TrackArtist, value)

	@TrackArtist.deleter
	def TrackArtist(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.TrackArtist)
	# endregion

	# region property Year
	@property
	def Year(self) -> int:
		return self._getMutagenProperty(Mp4TagNames.Year)

	@Year.setter
	def Year(self, value : int) -> None:
		self._setMutagenProperty(Mp4TagNames.Year, value)

	@Year.deleter
	def Year(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Year)
	# endregion

	# region property Composer
	@property
	def Composer(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Composer)

	@Composer.setter
	def Composer(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Composer, value)

	@Composer.deleter
	def Composer(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Composer)
	# endregion

	# region property Comments
	@property
	def Comments(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Comment)

	@Comments.setter
	def Comments(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Comment, value)

	@Comments.deleter
	def Comments(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Comment)
	# endregion

	# region property Genre
	@property
	def Genre(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Genre)

	@Genre.setter
	def Genre(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Genre, value)

	@Genre.deleter
	def Genre(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Genre)
	# endregion

	# region property TrackNumber
	@property
	def TrackNumber(self) -> int:
		trackInfo= self._getMutagenProperty(Mp4TagNames.TrackNumber)
		# if no track info at all, will not return anything; otherwise it always returns a tuple; if one value is missing, it will be 0 in the tuple
		return trackInfo[0] if trackInfo and trackInfo[0] > 0 else None

	@TrackNumber.setter
	def TrackNumber(self, value : int) -> None:
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, value, self.TotalTracks)

	@TrackNumber.deleter
	def TrackNumber(self) -> None:
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, 0, self.TotalTracks)
	# endregion

	# region property TotalTracks
	@property
	def TotalTracks(self) -> int:
		trackInfo= self._getMutagenProperty(Mp4TagNames.TrackNumber)
		return trackInfo[1] if trackInfo and trackInfo[1] > 0 else None

	@TotalTracks.setter
	def TotalTracks(self, value : int) -> None:
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, self.TrackNumber, value)

	@TotalTracks.deleter
	def TotalTracks(self) -> None:
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, self.TrackNumber, 0)
	# endregion

	# region property DiscNumber
	@property
	def DiscNumber(self) -> int:
		discInfo= self._getMutagenProperty(Mp4TagNames.DiscNumber)
		return discInfo[0] if discInfo and discInfo[0] > 0 else None

	@DiscNumber.setter
	def DiscNumber(self, value : int) -> None:
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, value, self.TotalDiscs)
		pass

	@DiscNumber.deleter
	def DiscNumber(self) -> None:
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, 0, self.TotalDiscs)
	# endregion

	# region property TotalDiscs
	@property
	def TotalDiscs(self) -> int:
		discInfo= self._getMutagenProperty(Mp4TagNames.DiscNumber)
		return discInfo[1] if discInfo and discInfo[1] > 0 else None

	@TotalDiscs.setter
	def TotalDiscs(self, value : int) -> None:
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, self.DiscNumber, value)
		pass

	@TotalDiscs.deleter
	def TotalDiscs(self) -> None:
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, self.DiscNumber, 0)
	# endregion

	# region property Producer
	@property
	def Producer(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Producer)

	@Producer.setter
	def Producer(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Producer, value)

	@Producer.deleter
	def Producer(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Producer)
	# endregion

	# region property Conductor
	@property
	def Conductor(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Conductor)

	@Conductor.setter
	def Conductor(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Conductor, value)

	@Conductor.deleter
	def Conductor(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Conductor)
	# endregion

	# region property Copyright
	@property
	def Copyright(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Copyright)

	@Copyright.setter
	def Copyright(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Copyright, value)

	@Copyright.deleter
	def Copyright(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Copyright)
	# endregion

	# region property Publisher
	@property
	def Publisher(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Publisher)

	@Publisher.setter
	def Publisher(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Publisher, value)

	@Publisher.deleter
	def Publisher(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Publisher)
	# endregion

	# region property Lyrics
	@property
	def Lyrics(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Lyrics)

	@Lyrics.setter
	def Lyrics(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Lyrics, value)

	@Lyrics.deleter
	def Lyrics(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Lyrics)
	# endregion

	# region property Lyricist
	@property
	def Lyricist(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.Lyricist)

	@Lyricist.setter
	def Lyricist(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.Lyricist, value)

	@Lyricist.deleter
	def Lyricist(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.Lyricist)
	# endregion

	# region property OriginalArtist
	@property
	def OriginalArtist(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.OriginalArtist)

	@OriginalArtist.setter
	def OriginalArtist(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.OriginalArtist, value)

	@OriginalArtist.deleter
	def OriginalArtist(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.OriginalArtist)
	# endregion

	# region property OriginalAlbum
	@property
	def OriginalAlbum(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.OriginalAlbum)

	@OriginalAlbum.setter
	def OriginalAlbum(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.OriginalAlbum, value)

	@OriginalAlbum.deleter
	def OriginalAlbum(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.OriginalAlbum)
	# endregion

	# region property OriginalYear
	@property
	def OriginalYear(self) -> str:
		return self._getMutagenProperty(Mp4TagNames.OriginalYear)

	@OriginalYear.setter
	def OriginalYear(self, value : str) -> None:
		self._setMutagenProperty(Mp4TagNames.OriginalYear, value)

	@OriginalYear.deleter
	def OriginalYear(self) -> None:
		self._deleteMutagenProperty(Mp4TagNames.OriginalYear)
	# endregion
