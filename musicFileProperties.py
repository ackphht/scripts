#!python3
# -*- coding: utf-8 -*-

import pathlib
from typing import Any, List
import mutagen					# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from tinytag import TinyTag		# mutagen doesn't support WMA files

class Mp4TagNames:
	Mp4CustomPropertyPrefix = "----:com.apple.iTunes:"
	AlbumTitle = "©alb"
	TrackTitle = "©nam"
	AlbumArtist = "aART"
	TrackArtist = "©ART"
	Year = "©day"
	Composer = "©wrt"
	Comment = "©cmt"
	Genre = "©gen"
	TrackNumber = "trkn"
	DiscNumber = "disk"
	Copyright = "cprt"
	Conductor = "©con"
	Lyrics = "©lyr"
	Encoder = "©too"
	Cover = "covr"
	AlbumTitleSort = "soal"
	TrackTitleSort = "sonm"
	AlbumArtistSort = "soaa"
	TrackArtistSort = "soar"
	ComposerSort = "soco"
	Producer = Mp4CustomPropertyPrefix + "PRODUCER"
	Publisher = Mp4CustomPropertyPrefix + "PUBLISHER"
	Lyricist = Mp4CustomPropertyPrefix + "LYRICIST"
	OriginalAlbum = Mp4CustomPropertyPrefix + "ORIGALBUM"
	OriginalArtist = Mp4CustomPropertyPrefix + "ORIGARTIST"
	OriginalYear = Mp4CustomPropertyPrefix + "ORIGYEAR"
	Codec = Mp4CustomPropertyPrefix + "cdec"
	iTunSMPB = Mp4CustomPropertyPrefix + "iTunSMPB"
	Isrc = Mp4CustomPropertyPrefix + "ISRC"		# "International Standard Recording Code"; https://musicbrainz.org/doc/ISRC
	EncodedBy = Mp4CustomPropertyPrefix + "encoded by"
	ReplayGainTrackGain = Mp4CustomPropertyPrefix + "replaygain_track_gain"
	ReplayGainTrackPeak = Mp4CustomPropertyPrefix + "replaygain_track_peak"
	ReplayGainAlbumGain = Mp4CustomPropertyPrefix + "replaygain_album_gain"
	ReplayGainAlbumPeak = Mp4CustomPropertyPrefix + "replaygain_album_peak"
	Source = Mp4CustomPropertyPrefix + "Source"
	RippingTool = Mp4CustomPropertyPrefix + "Ripping tool"
	RipDate = Mp4CustomPropertyPrefix + "Rip date"
	RelaseType = Mp4CustomPropertyPrefix + "Release type"
	Language = Mp4CustomPropertyPrefix + "language"
	EncodingSettings = Mp4CustomPropertyPrefix + "encoding settings"
	# https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html
	# https://picard-docs.musicbrainz.org/en/variables/variables.html
	# https://musicbrainz.org/doc/MusicBrainz_Database
	MusicBrainzAlbumId = Mp4CustomPropertyPrefix + "MusicBrainz Album Id"
	MusicBrainzArtistId = Mp4CustomPropertyPrefix + "MusicBrainz Artist Id"
	MusicBrainzAlbumArtistId = Mp4CustomPropertyPrefix + "MusicBrainz Album Artist Id"
	MusicBrainzTrackId = Mp4CustomPropertyPrefix + "MusicBrainz Release Track Id"		# https://musicbrainz.org/doc/Recording - a "recording" is higher level than a track, at least one track per recording
	MusicBrainzRecordingId = Mp4CustomPropertyPrefix + "MusicBrainz Track Id"			# but Mp3tag uses this one ?? i'm confused on which of these tags is which
	MusicBrainzReleaseCountry = Mp4CustomPropertyPrefix + "MusicBrainz Album Release Country"
	MusicBrainzReleaseGroupId = Mp4CustomPropertyPrefix + "MusicBrainz Release Group Id"
	Upc = Mp4CustomPropertyPrefix + "UPC"		# or BARCODE ??
	Barcode = Mp4CustomPropertyPrefix + "BARCODE"		# for CD rips
	Asin = Mp4CustomPropertyPrefix + "ASIN"			# for digital ones i bought from Amazon
	Rating = Mp4CustomPropertyPrefix + "RATING"
	Label = Mp4CustomPropertyPrefix + "LABEL"
	MusicianCredits = Mp4CustomPropertyPrefix + "MUSICIANCREDITS"
	DigitalPurchaseFrom = Mp4CustomPropertyPrefix + "DIGITALPURCHASEFROM"		# these are my own tags, so pascal case would be nice, but mp3tag uppercases everything; sigh
	DigitalPurchaseDate = Mp4CustomPropertyPrefix + "DIGITALPURCHASEDATE"
	DigitalPurchaseId = Mp4CustomPropertyPrefix + "DIGITALPURCHASEID"
	Recorded = Mp4CustomPropertyPrefix + "RECORDED"
	Released = Mp4CustomPropertyPrefix + "RELEASED"

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
		if self._musicFilePath.suffix == '.wma':
			self._tinytag = TinyTag.get(self._musicFilePath)
		else:
			self._mutagen = mutagen.File(self._musicFilePath)

	def save(self, removePadding = False) -> bool:
		if self._tinytag:
			raise NotImplementedError("save() not supported for files using tinytag (e.g. WMA files)")
		if not self._dirty:
			return False
		if removePadding:
			self._mutagen.save(padding = lambda x: 0)
		else:
			self._mutagen.save()
		self._dirty = False
		return True

	def getProperties(self):
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

	def getRawProperties(self):
		if self._tinytag:
			d = self._tinytag.as_dict()
			for t in d:
				yield (t, d[t])
		else :
			for tag in self._mutagen.tags:
				yield (tag, self._mutagen[tag])

	def setRawProperty(self, propertyName : str, value : Any):
		if self._tinytag:
			raise NotImplementedError("modifying files using tinytag (e.g. WMA files) is not supported")
		self._setMutagenProperty(propertyName, value)

	def deleteRawProperty(self, propertyName : str):
		if self._tinytag:
			raise NotImplementedError("modifying files using tinytag (e.g. WMA files) is not supported")
		self._deleteMutagenProperty(propertyName)

	def _getMutagenProperty(self, propertyName : str):
		val = self._mutagen[propertyName] if propertyName in self._mutagen else None
		if val and isinstance(val, list) and len(val) > 0:
			val = val[0]
		if val and isinstance(val, mutagen.mp4.MP4FreeForm):
			if val.dataformat != mutagen.mp4.AtomDataType.UTF8:
				raise NotImplementedError("MP4FreeForm contains unsupported data type: " + str(val.dataform))
			val = val.decode("utf-8")
		return val

	def _verifyCanSet(self, property : str):
		if self._tinytag:
			raise NotImplementedError("modifying files using tinytag (e.g. WMA files) is not supported. Property = " + property)

	def _verifyCanDelete(self, property : str):
		if self._tinytag:
			raise NotImplementedError("deleting properties in files using tinytag (e.g. WMA files) is not supported. Property = " + property)

	def _setMutagenProperty(self, propertyName : str, value : Any):
		if value == None or (isinstance(value, str) and len(value) == 0):
			if propertyName in self._mutagen:
				del self._mutagen[propertyName]
				self._dirty = True
			return
		if not propertyName.startswith(Mp4TagNames.Mp4CustomPropertyPrefix):
			self._mutagen[propertyName] = value
		else:
			if not isinstance(value, str):
				raise NotImplementedError("only currently know how to set string values")
			self._mutagen[propertyName] = mutagen.mp4.MP4FreeForm(value.encode(), dataformat=mutagen.mp4.AtomDataType.UTF8)
		self._dirty = True
		return

	def _deleteMutagenProperty(self, propertyName : str):
		if propertyName in self._mutagen:
			del self._mutagen[propertyName]
			self._dirty = True

	def _setTrackOrDisc(self, propertyName : str, val : int, ttl : int):
		val = 0 if val is None or val < 0 else val
		ttl = 0 if ttl is None or ttl < 0 else ttl
		if val == 0 and ttl == 0:
			self._deleteMutagenProperty(propertyName)
		else:
			self._setMutagenProperty(propertyName, [(val, ttl)])

	@property
	def FilePath(self):
		return self._musicFilePath

	@property
	def DurationSeconds(self):
		if self._tinytag:
			return self._tinytag.duration
		else:
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
	def AlbumTitle(self):
		if self._tinytag:
			return self._tinytag.album
		else:
			return self._getMutagenProperty(Mp4TagNames.AlbumTitle)

	@AlbumTitle.setter
	def AlbumTitle(self, value : str):
		self._verifyCanSet('AlbumTitle')
		self._setMutagenProperty(Mp4TagNames.AlbumTitle, value)

	@AlbumTitle.deleter
	def AlbumTitle(self):
		self._verifyCanDelete('AlbumTitle')
		self._deleteMutagenProperty(Mp4TagNames.AlbumTitle)
	# endregion

	# region property TrackTitle
	@property
	def TrackTitle(self):
		if self._tinytag:
			return self._tinytag.title
		else:
			return self._getMutagenProperty(Mp4TagNames.TrackTitle)

	@TrackTitle.setter
	def TrackTitle(self, value : str):
		self._verifyCanSet('TrackTitle')
		self._setMutagenProperty(Mp4TagNames.TrackTitle, value)

	@TrackTitle.deleter
	def TrackTitle(self):
		self._verifyCanDelete('TrackTitle')
		self._deleteMutagenProperty(Mp4TagNames.TrackTitle)
	# endregion

	# region property AlbumArtist
	@property
	def AlbumArtist(self):
		if self._tinytag:
			return self._tinytag.albumartist
		else:
			return self._getMutagenProperty(Mp4TagNames.AlbumArtist)

	@AlbumArtist.setter
	def AlbumArtist(self, value : str):
		self._verifyCanSet('AlbumArtist')
		self._setMutagenProperty(Mp4TagNames.AlbumArtist, value)

	@AlbumArtist.deleter
	def AlbumArtist(self):
		self._verifyCanDelete('AlbumArtist')
		self._deleteMutagenProperty(Mp4TagNames.AlbumArtist)
	# endregion

	# region property TrackArtist
	@property
	def TrackArtist(self):
		if self._tinytag:
			return self._tinytag.artist
		else:
			return self._getMutagenProperty(Mp4TagNames.TrackArtist)

	@TrackArtist.setter
	def TrackArtist(self, value : str):
		self._verifyCanSet('TrackArtist')
		self._setMutagenProperty(Mp4TagNames.TrackArtist, value)

	@TrackArtist.deleter
	def TrackArtist(self):
		self._verifyCanDelete('TrackArtist')
		self._deleteMutagenProperty(Mp4TagNames.TrackArtist)
	# endregion

	# region property Year
	@property
	def Year(self):
		if self._tinytag:
			return self._tinytag.year
		else:
			return self._getMutagenProperty(Mp4TagNames.Year)

	@Year.setter
	def Year(self, value : int):
		self._verifyCanSet('Year')
		self._setMutagenProperty(Mp4TagNames.Year, value)

	@Year.deleter
	def Year(self):
		self._verifyCanDelete('Year')
		self._deleteMutagenProperty(Mp4TagNames.Year)
	# endregion

	# region property Composer
	@property
	def Composer(self):
		if self._tinytag:
			return self._tinytag.composer
		else:
			return self._getMutagenProperty(Mp4TagNames.Composer)

	@Composer.setter
	def Composer(self, value : str):
		self._verifyCanSet('Composer')
		self._setMutagenProperty(Mp4TagNames.Composer, value)

	@Composer.deleter
	def Composer(self):
		self._verifyCanDelete('Composer')
		self._deleteMutagenProperty(Mp4TagNames.Composer)
	# endregion

	# region property Comments
	@property
	def Comments(self):
		if self._tinytag:
			return self._tinytag.comment
		else:
			return self._getMutagenProperty(Mp4TagNames.Comment)

	@Comments.setter
	def Comments(self, value : str):
		self._verifyCanSet('Comments')
		self._setMutagenProperty(Mp4TagNames.Comment, value)

	@Comments.deleter
	def Comments(self):
		self._verifyCanDelete('Comments')
		self._deleteMutagenProperty(Mp4TagNames.Comment)
	# endregion

	# region property Genre
	@property
	def Genre(self):
		if self._tinytag:
			return self._tinytag.genre
		else:
			return self._getMutagenProperty(Mp4TagNames.Genre)

	@Genre.setter
	def Genre(self, value : str):
		self._verifyCanSet('Genre')
		self._setMutagenProperty(Mp4TagNames.Genre, value)

	@Genre.deleter
	def Genre(self):
		self._verifyCanDelete('Genre')
		self._deleteMutagenProperty(Mp4TagNames.Genre)
	# endregion

	# region property TrackNumber
	@property
	def TrackNumber(self):
		if self._tinytag:
			return self._tinytag.track
		else:
			trackInfo= self._getMutagenProperty(Mp4TagNames.TrackNumber)
			# if no track info at all, will not return anything; otherwise it always returns a tuple; if one value is missing, it will be 0 in the tuple
			return trackInfo[0] if trackInfo and trackInfo[0] > 0 else None

	@TrackNumber.setter
	def TrackNumber(self, value : int):
		self._verifyCanSet('TrackNumber')
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, value, self.TotalTracks)

	@TrackNumber.deleter
	def TrackNumber(self):
		self._verifyCanDelete('TrackNumber')
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, 0, self.TotalTracks)
	# endregion

	# region property TotalTracks
	@property
	def TotalTracks(self):
		if self._tinytag:
			return self._tinytag.track_total
		else:
			trackInfo= self._getMutagenProperty(Mp4TagNames.TrackNumber)
			return trackInfo[1] if trackInfo and trackInfo[1] > 0 else None

	@TotalTracks.setter
	def TotalTracks(self, value : int):
		self._verifyCanSet('TotalTracks')
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, self.TrackNumber, value)

	@TotalTracks.deleter
	def TotalTracks(self):
		self._verifyCanDelete('TotalTracks')
		self._setTrackOrDisc(Mp4TagNames.TrackNumber, self.TrackNumber, 0)
	# endregion

	# region property DiscNumber
	@property
	def DiscNumber(self):
		if self._tinytag:
			return self._tinytag.disc
		else:
			discInfo= self._getMutagenProperty(Mp4TagNames.DiscNumber)
			return discInfo[0] if discInfo and discInfo[0] > 0 else None

	@DiscNumber.setter
	def DiscNumber(self, value : int):
		self._verifyCanSet('DiscNumber')
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, value, self.TotalDiscs)
		pass

	@DiscNumber.deleter
	def DiscNumber(self):
		self._verifyCanDelete('DiscNumber')
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, 0, self.TotalDiscs)
	# endregion

	# region property TotalDiscs
	@property
	def TotalDiscs(self):
		if self._tinytag:
			return self._tinytag.disc_total
		else:
			discInfo= self._getMutagenProperty(Mp4TagNames.DiscNumber)
			return discInfo[1] if discInfo and discInfo[1] > 0 else None

	@TotalDiscs.setter
	def TotalDiscs(self, value : int):
		self._verifyCanSet('TotalDiscs')
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, self.DiscNumber, value)
		pass

	@TotalDiscs.deleter
	def TotalDiscs(self):
		self._verifyCanDelete('TotalDiscs')
		self._setTrackOrDisc(Mp4TagNames.DiscNumber, self.DiscNumber, 0)
	# endregion

	# region property Producer
	@property
	def Producer(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.Producer)

	@Producer.setter
	def Producer(self, value : str):
		self._verifyCanSet('Producer')
		self._setMutagenProperty(Mp4TagNames.Producer, value)

	@Producer.deleter
	def Producer(self):
		self._verifyCanDelete('Producer')
		self._deleteMutagenProperty(Mp4TagNames.Producer)
	# endregion

	# region property Conductor
	@property
	def Conductor(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.Conductor)

	@Conductor.setter
	def Conductor(self, value : str):
		self._verifyCanSet('Conductor')
		self._setMutagenProperty(Mp4TagNames.Conductor, value)

	@Conductor.deleter
	def Conductor(self):
		self._verifyCanDelete('Conductor')
		self._deleteMutagenProperty(Mp4TagNames.Conductor)
	# endregion

	# region property Copyright
	@property
	def Copyright(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.Copyright)

	@Copyright.setter
	def Copyright(self, value : str):
		self._verifyCanSet('Copyright')
		self._setMutagenProperty(Mp4TagNames.Copyright, value)

	@Copyright.deleter
	def Copyright(self):
		self._verifyCanDelete('Copyright')
		self._deleteMutagenProperty(Mp4TagNames.Copyright)
	# endregion

	# region property Publisher
	@property
	def Publisher(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.Publisher)

	@Publisher.setter
	def Publisher(self, value : str):
		self._verifyCanSet('Publisher')
		self._setMutagenProperty(Mp4TagNames.Publisher, value)

	@Publisher.deleter
	def Publisher(self):
		self._verifyCanDelete('Publisher')
		self._deleteMutagenProperty(Mp4TagNames.Publisher)
	# endregion

	# region property Lyrics
	@property
	def Lyrics(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.Lyrics)

	@Lyrics.setter
	def Lyrics(self, value : str):
		self._verifyCanSet('Lyrics')
		self._setMutagenProperty(Mp4TagNames.Lyrics, value)

	@Lyrics.deleter
	def Lyrics(self):
		self._verifyCanDelete('Lyrics')
		self._deleteMutagenProperty(Mp4TagNames.Lyrics)
	# endregion

	# region property Lyricist
	@property
	def Lyricist(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.Lyricist)

	@Lyricist.setter
	def Lyricist(self, value : str):
		self._verifyCanSet('Lyricist')
		self._setMutagenProperty(Mp4TagNames.Lyricist, value)

	@Lyricist.deleter
	def Lyricist(self):
		self._verifyCanDelete('Lyricist')
		self._deleteMutagenProperty(Mp4TagNames.Lyricist)
	# endregion

	# region property OriginalArtist
	@property
	def OriginalArtist(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.OriginalArtist)

	@OriginalArtist.setter
	def OriginalArtist(self, value : str):
		self._verifyCanSet('OriginalArtist')
		self._setMutagenProperty(Mp4TagNames.OriginalArtist, value)

	@OriginalArtist.deleter
	def OriginalArtist(self):
		self._verifyCanDelete('OriginalArtist')
		self._deleteMutagenProperty(Mp4TagNames.OriginalArtist)
	# endregion

	# region property OriginalAlbum
	@property
	def OriginalAlbum(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.OriginalAlbum)

	@OriginalAlbum.setter
	def OriginalAlbum(self, value : str):
		self._verifyCanSet('OriginalAlbum')
		self._setMutagenProperty(Mp4TagNames.OriginalAlbum, value)

	@OriginalAlbum.deleter
	def OriginalAlbum(self):
		self._verifyCanDelete('OriginalAlbum')
		self._deleteMutagenProperty(Mp4TagNames.OriginalAlbum)
	# endregion

	# region property OriginalYear
	@property
	def OriginalYear(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(Mp4TagNames.OriginalYear)

	@OriginalYear.setter
	def OriginalYear(self, value : str):
		self._verifyCanSet('OriginalYear')
		self._setMutagenProperty(Mp4TagNames.OriginalYear, value)

	@OriginalYear.deleter
	def OriginalYear(self):
		self._verifyCanDelete('OriginalYear')
		self._deleteMutagenProperty(Mp4TagNames.OriginalYear)
	# endregion
