#!python3
# -*- coding: utf-8 -*-

import sys
import os
import pathlib
from typing import Any, List
import mutagen					# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from tinytag import TinyTag		# mutagen doesn't support WMA files

class MusicFileProperties:
	Mp4CustomPropertyPrefix = "----:com.apple.iTunes:"
	MGAlbumTitle = "©alb"
	MGTrackTitle = "©nam"
	MGAlbumArtist = "aART"
	MGTrackArtist = "©ART"
	MGYear = "©day"
	MGComposer = "©wrt"
	MGComment = "©cmt"
	MGGenre = "©gen"
	MGTrackNumber = "trkn"
	MGDiscNumber = "disk"
	MGCopyright = "cprt"
	MGConductor = "©con"
	MGLyrics = "©lyr"
	MGEncoder = "©too"
	MGCover = "covr"
	MGAlbumTitleSort = "soal"
	MGTrackTitleSort = "sonm"
	MGAlbumArtistSort = "soaa"
	MGTrackArtistSort = "soar"
	MGComposerSort = "soco"
	MGProducer = Mp4CustomPropertyPrefix + "PRODUCER"
	MGPublisher = Mp4CustomPropertyPrefix + "PUBLISHER"
	MGLyricist = Mp4CustomPropertyPrefix + "LYRICIST"
	MGOriginalAlbum = Mp4CustomPropertyPrefix + "ORIGALBUM"
	MGOriginalArtist = Mp4CustomPropertyPrefix + "ORIGARTIST"
	MGOriginalYear = Mp4CustomPropertyPrefix + "ORIGYEAR"
	MGCodec = Mp4CustomPropertyPrefix + "cdec"
	MGiTunSMPB = Mp4CustomPropertyPrefix + "iTunSMPB"
	MGisrc = Mp4CustomPropertyPrefix + "isrc"		# "International Standard Recording Code"; https://musicbrainz.org/doc/ISRC
	MGEncodedBy = Mp4CustomPropertyPrefix + "encoded by"
	MGReplayGainTrackGain = Mp4CustomPropertyPrefix + "replaygain_track_gain"
	MGReplayGainTrackPeak = Mp4CustomPropertyPrefix + "replaygain_track_peak"
	MGReplayGainAlbumGain = Mp4CustomPropertyPrefix + "replaygain_album_gain"
	MGReplayGainAlbumPeak = Mp4CustomPropertyPrefix + "replaygain_album_peak"
	MGSource = Mp4CustomPropertyPrefix + "Source"
	MGRippingTool = Mp4CustomPropertyPrefix + "Ripping tool"
	MGRipDate = Mp4CustomPropertyPrefix + "Rip date"
	MGRelaseType = Mp4CustomPropertyPrefix + "Release type"
	MGLanguage = Mp4CustomPropertyPrefix + "language"
	MGEncodingSettings = Mp4CustomPropertyPrefix + "encoding settings"
	# https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html
	# https://picard-docs.musicbrainz.org/en/variables/variables.html
	# https://musicbrainz.org/doc/MusicBrainz_Database
	MGMusicBrainzAlbumId = Mp4CustomPropertyPrefix + "MusicBrainz Album Id"
	MGMusicBrainzArtistId = Mp4CustomPropertyPrefix + "MusicBrainz Artist Id"
	MGMusicBrainzAlbumArtistId = Mp4CustomPropertyPrefix + "MusicBrainz Album Artist Id"
	MGMusicBrainzTrackId = Mp4CustomPropertyPrefix + "MusicBrainz Release Track Id"		# https://musicbrainz.org/doc/Recording - a "recording" is higher level than a track, at least one track per recording
	MGMusicBrainzRecordingId = Mp4CustomPropertyPrefix + "MusicBrainz Track Id"			# but Mp3tag uses this one ?? i'm confused on which of these tags is which
	MGMusicBrainzReleaseCountry = Mp4CustomPropertyPrefix + "MusicBrainz Album Release Country"
	MGMusicBrainzReleaseGroupId = Mp4CustomPropertyPrefix + "MusicBrainz Release Group Id"
	MGUpc = Mp4CustomPropertyPrefix + "UPC"		# or BARCODE ??
	MGBarcode = Mp4CustomPropertyPrefix + "BARCODE"
	MGRating = Mp4CustomPropertyPrefix + "RATING"
	MGLabel = Mp4CustomPropertyPrefix + "LABEL"
	MGMusicianCredits = Mp4CustomPropertyPrefix + "MUSICIANCREDITS"
	MGDigitalPurchaseFrom = Mp4CustomPropertyPrefix + "DIGITALPURCHASEFROM"		# these are my own tags, so pascal case would be nice, but mp3tag uppercases everything; sigh
	MGDigitalPurchaseDate = Mp4CustomPropertyPrefix + "DIGITALPURCHASEDATE"
	MGDigitalPurchaseId = Mp4CustomPropertyPrefix + "DIGITALPURCHASEID"
	MGRecorded = Mp4CustomPropertyPrefix + "RECORDED"
	MGReleased = Mp4CustomPropertyPrefix + "RELEASED"

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
		if not propertyName.startswith(MusicFileProperties.Mp4CustomPropertyPrefix):
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
			return self._getMutagenProperty(MusicFileProperties.MGAlbumTitle)

	@AlbumTitle.setter
	def AlbumTitle(self, value : str):
		self._verifyCanSet('AlbumTitle')
		self._setMutagenProperty(MusicFileProperties.MGAlbumTitle, value)

	@AlbumTitle.deleter
	def AlbumTitle(self):
		self._verifyCanDelete('AlbumTitle')
		self._deleteMutagenProperty(MusicFileProperties.MGAlbumTitle)
	# endregion

	# region property TrackTitle
	@property
	def TrackTitle(self):
		if self._tinytag:
			return self._tinytag.title
		else:
			return self._getMutagenProperty(MusicFileProperties.MGTrackTitle)

	@TrackTitle.setter
	def TrackTitle(self, value : str):
		self._verifyCanSet('TrackTitle')
		self._setMutagenProperty(MusicFileProperties.MGTrackTitle, value)

	@TrackTitle.deleter
	def TrackTitle(self):
		self._verifyCanDelete('TrackTitle')
		self._deleteMutagenProperty(MusicFileProperties.MGTrackTitle)
	# endregion

	# region property AlbumArtist
	@property
	def AlbumArtist(self):
		if self._tinytag:
			return self._tinytag.albumartist
		else:
			return self._getMutagenProperty(MusicFileProperties.MGAlbumArtist)

	@AlbumArtist.setter
	def AlbumArtist(self, value : str):
		self._verifyCanSet('AlbumArtist')
		self._setMutagenProperty(MusicFileProperties.MGAlbumArtist, value)

	@AlbumArtist.deleter
	def AlbumArtist(self):
		self._verifyCanDelete('AlbumArtist')
		self._deleteMutagenProperty(MusicFileProperties.MGAlbumArtist)
	# endregion

	# region property TrackArtist
	@property
	def TrackArtist(self):
		if self._tinytag:
			return self._tinytag.artist
		else:
			return self._getMutagenProperty(MusicFileProperties.MGTrackArtist)

	@TrackArtist.setter
	def TrackArtist(self, value : str):
		self._verifyCanSet('TrackArtist')
		self._setMutagenProperty(MusicFileProperties.MGTrackArtist, value)

	@TrackArtist.deleter
	def TrackArtist(self):
		self._verifyCanDelete('TrackArtist')
		self._deleteMutagenProperty(MusicFileProperties.MGTrackArtist)
	# endregion

	# region property Year
	@property
	def Year(self):
		if self._tinytag:
			return self._tinytag.year
		else:
			return self._getMutagenProperty(MusicFileProperties.MGYear)

	@Year.setter
	def Year(self, value : int):
		self._verifyCanSet('Year')
		self._setMutagenProperty(MusicFileProperties.MGYear, value)

	@Year.deleter
	def Year(self):
		self._verifyCanDelete('Year')
		self._deleteMutagenProperty(MusicFileProperties.MGYear)
	# endregion

	# region property Composer
	@property
	def Composer(self):
		if self._tinytag:
			return self._tinytag.composer
		else:
			return self._getMutagenProperty(MusicFileProperties.MGComposer)

	@Composer.setter
	def Composer(self, value : str):
		self._verifyCanSet('Composer')
		self._setMutagenProperty(MusicFileProperties.MGComposer, value)

	@Composer.deleter
	def Composer(self):
		self._verifyCanDelete('Composer')
		self._deleteMutagenProperty(MusicFileProperties.MGComposer)
	# endregion

	# region property Comments
	@property
	def Comments(self):
		if self._tinytag:
			return self._tinytag.comment
		else:
			return self._getMutagenProperty(MusicFileProperties.MGComment)

	@Comments.setter
	def Comments(self, value : str):
		self._verifyCanSet('Comments')
		self._setMutagenProperty(MusicFileProperties.MGComment, value)

	@Comments.deleter
	def Comments(self):
		self._verifyCanDelete('Comments')
		self._deleteMutagenProperty(MusicFileProperties.MGComment)
	# endregion

	# region property Genre
	@property
	def Genre(self):
		if self._tinytag:
			return self._tinytag.genre
		else:
			return self._getMutagenProperty(MusicFileProperties.MGGenre)

	@Genre.setter
	def Genre(self, value : str):
		self._verifyCanSet('Genre')
		self._setMutagenProperty(MusicFileProperties.MGGenre, value)

	@Genre.deleter
	def Genre(self):
		self._verifyCanDelete('Genre')
		self._deleteMutagenProperty(MusicFileProperties.MGGenre)
	# endregion

	# region property TrackNumber
	@property
	def TrackNumber(self):
		if self._tinytag:
			return self._tinytag.track
		else:
			trackInfo= self._getMutagenProperty(MusicFileProperties.MGTrackNumber)
			# if no track info at all, will not return anything; otherwise it always returns a tuple; if one value is missing, it will be 0 in the tuple
			return trackInfo[0] if trackInfo and trackInfo[0] > 0 else None

	@TrackNumber.setter
	def TrackNumber(self, value : int):
		self._verifyCanSet('TrackNumber')
		self._setTrackOrDisc(MusicFileProperties.MGTrackNumber, value, self.TotalTracks)

	@TrackNumber.deleter
	def TrackNumber(self):
		self._verifyCanDelete('TrackNumber')
		self._setTrackOrDisc(MusicFileProperties.MGTrackNumber, 0, self.TotalTracks)
	# endregion

	# region property TotalTracks
	@property
	def TotalTracks(self):
		if self._tinytag:
			return self._tinytag.track_total
		else:
			trackInfo= self._getMutagenProperty(MusicFileProperties.MGTrackNumber)
			return trackInfo[1] if trackInfo and trackInfo[1] > 0 else None

	@TotalTracks.setter
	def TotalTracks(self, value : int):
		self._verifyCanSet('TotalTracks')
		self._setTrackOrDisc(MusicFileProperties.MGTrackNumber, self.TrackNumber, value)

	@TotalTracks.deleter
	def TotalTracks(self):
		self._verifyCanDelete('TotalTracks')
		self._setTrackOrDisc(MusicFileProperties.MGTrackNumber, self.TrackNumber, 0)
	# endregion

	# region property DiscNumber
	@property
	def DiscNumber(self):
		if self._tinytag:
			return self._tinytag.disc
		else:
			discInfo= self._getMutagenProperty(MusicFileProperties.MGDiscNumber)
			return discInfo[0] if discInfo and discInfo[0] > 0 else None

	@DiscNumber.setter
	def DiscNumber(self, value : int):
		self._verifyCanSet('DiscNumber')
		self._setTrackOrDisc(MusicFileProperties.MGDiscNumber, value, self.TotalDiscs)
		pass

	@DiscNumber.deleter
	def DiscNumber(self):
		self._verifyCanDelete('DiscNumber')
		self._setTrackOrDisc(MusicFileProperties.MGDiscNumber, 0, self.TotalDiscs)
	# endregion

	# region property TotalDiscs
	@property
	def TotalDiscs(self):
		if self._tinytag:
			return self._tinytag.disc_total
		else:
			discInfo= self._getMutagenProperty(MusicFileProperties.MGDiscNumber)
			return discInfo[1] if discInfo and discInfo[1] > 0 else None

	@TotalDiscs.setter
	def TotalDiscs(self, value : int):
		self._verifyCanSet('TotalDiscs')
		self._setTrackOrDisc(MusicFileProperties.MGDiscNumber, self.DiscNumber, value)
		pass

	@TotalDiscs.deleter
	def TotalDiscs(self):
		self._verifyCanDelete('TotalDiscs')
		self._setTrackOrDisc(MusicFileProperties.MGDiscNumber, self.DiscNumber, 0)
	# endregion

	# region property Producer
	@property
	def Producer(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGProducer)

	@Producer.setter
	def Producer(self, value : str):
		self._verifyCanSet('Producer')
		self._setMutagenProperty(MusicFileProperties.MGProducer, value)

	@Producer.deleter
	def Producer(self):
		self._verifyCanDelete('Producer')
		self._deleteMutagenProperty(MusicFileProperties.MGProducer)
	# endregion

	# region property Conductor
	@property
	def Conductor(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGConductor)

	@Conductor.setter
	def Conductor(self, value : str):
		self._verifyCanSet('Conductor')
		self._setMutagenProperty(MusicFileProperties.MGConductor, value)

	@Conductor.deleter
	def Conductor(self):
		self._verifyCanDelete('Conductor')
		self._deleteMutagenProperty(MusicFileProperties.MGConductor)
	# endregion

	# region property Copyright
	@property
	def Copyright(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGCopyright)

	@Copyright.setter
	def Copyright(self, value : str):
		self._verifyCanSet('Copyright')
		self._setMutagenProperty(MusicFileProperties.MGCopyright, value)

	@Copyright.deleter
	def Copyright(self):
		self._verifyCanDelete('Copyright')
		self._deleteMutagenProperty(MusicFileProperties.MGCopyright)
	# endregion

	# region property Publisher
	@property
	def Publisher(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGPublisher)

	@Publisher.setter
	def Publisher(self, value : str):
		self._verifyCanSet('Publisher')
		self._setMutagenProperty(MusicFileProperties.MGPublisher, value)

	@Publisher.deleter
	def Publisher(self):
		self._verifyCanDelete('Publisher')
		self._deleteMutagenProperty(MusicFileProperties.MGPublisher)
	# endregion

	# region property Lyrics
	@property
	def Lyrics(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGLyrics)

	@Lyrics.setter
	def Lyrics(self, value : str):
		self._verifyCanSet('Lyrics')
		self._setMutagenProperty(MusicFileProperties.MGLyrics, value)

	@Lyrics.deleter
	def Lyrics(self):
		self._verifyCanDelete('Lyrics')
		self._deleteMutagenProperty(MusicFileProperties.MGLyrics)
	# endregion

	# region property Lyricist
	@property
	def Lyricist(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGLyricist)

	@Lyricist.setter
	def Lyricist(self, value : str):
		self._verifyCanSet('Lyricist')
		self._setMutagenProperty(MusicFileProperties.MGLyricist, value)

	@Lyricist.deleter
	def Lyricist(self):
		self._verifyCanDelete('Lyricist')
		self._deleteMutagenProperty(MusicFileProperties.MGLyricist)
	# endregion

	# region property OriginalArtist
	@property
	def OriginalArtist(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGOriginalArtist)

	@OriginalArtist.setter
	def OriginalArtist(self, value : str):
		self._verifyCanSet('OriginalArtist')
		self._setMutagenProperty(MusicFileProperties.MGOriginalArtist, value)

	@OriginalArtist.deleter
	def OriginalArtist(self):
		self._verifyCanDelete('OriginalArtist')
		self._deleteMutagenProperty(MusicFileProperties.MGOriginalArtist)
	# endregion

	# region property OriginalAlbum
	@property
	def OriginalAlbum(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGOriginalAlbum)

	@OriginalAlbum.setter
	def OriginalAlbum(self, value : str):
		self._verifyCanSet('OriginalAlbum')
		self._setMutagenProperty(MusicFileProperties.MGOriginalAlbum, value)

	@OriginalAlbum.deleter
	def OriginalAlbum(self):
		self._verifyCanDelete('OriginalAlbum')
		self._deleteMutagenProperty(MusicFileProperties.MGOriginalAlbum)
	# endregion

	# region property OriginalYear
	@property
	def OriginalYear(self):
		if self._tinytag:
			return None
		else:
			return self._getMutagenProperty(MusicFileProperties.MGOriginalYear)

	@OriginalYear.setter
	def OriginalYear(self, value : str):
		self._verifyCanSet('OriginalYear')
		self._setMutagenProperty(MusicFileProperties.MGOriginalYear, value)

	@OriginalYear.deleter
	def OriginalYear(self):
		self._verifyCanDelete('OriginalYear')
		self._deleteMutagenProperty(MusicFileProperties.MGOriginalYear)
	# endregion
