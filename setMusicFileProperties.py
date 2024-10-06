#!python3
# -*- coding: utf-8 -*-

import os, sys, pathlib, datetime, re, argparse, stat, sqlite3
from typing import Any, List, Iterator
from tabulate import tabulate	# https://pypi.org/project/tabulate/
from operator import attrgetter

from ackPyHelpers import LogHelper, FileHelpers
from musicFileProperties import MusicFileProperties, TagNames

_musicAttributesDbPath = pathlib.Path(os.path.expandvars("%UserProfile%/Music/MyMusic/musicAttributes.sqlite"))#.resolve()
_defaultTableFormat = "presto"#"simple"

class DbRowHelper:
	def __init__(self, row : sqlite3.Row):
		self._row = row

	@staticmethod
	def EnumRows(rowList):
		for row in rowList:
			yield DbRowHelper(row)

	@property
	def DbId(self):
		return self._row["MusicFileAttributesId"]

	@property
	def FilePath(self):
		return f"{self.Folder}\\{self.Filename}{self.Extension}"

	@property
	def Folder(self):
		return self._row["Folder"]

	@property
	def Filename(self):
		return self._row["Filename"]

	@property
	def Extension(self):
		return self._row["Extension"]

	@property
	def ModifyTimeUTC(self):
		return self._row["ModifyTimeUTC"]

	@property
	def AlbumTitle(self):
		return self._row["AlbumTitle"]

	@property
	def AlbumArtist(self):
		return self._row["AlbumArtist"]

	@property
	def TrackArtist(self):
		return self._row["TrackArtist"]

	@property
	def TrackTitle(self):
		return self._row["TrackTitle"]

	@property
	def TrackNumber(self):
		return self._row["TrackNumber"]

	@property
	def Year(self):
		return self._row["Year"]

	@property
	def Composer(self):
		return self._row["Composer"]

	@property
	def Producer(self):
		return self._row["Producer"]

	@property
	def Conductor(self):
		return self._row["Conductor"]

	@property
	def Copyright(self):
		return self._row["Copyright"]

	@property
	def Publisher(self):
		return self._row["Publisher"]

	@property
	def Lyrics(self):
		return self._row["Lyrics"]

	@property
	def Comments(self):
		return self._row["Comments"]

	@property
	def OriginalArtist(self):
		return self._row["OriginalArtist"]

	@property
	def OriginalAlbum(self):
		return self._row["OriginalAlbum"]

	@property
	def OriginalYear(self):
		return self._row["OriginalYear"]

	@property
	def Genre(self):
		return self._row["Genre"]

class PlaylistEntry:
	def __init__(self, mf : MusicFileProperties, filename : str):
		tmp = mf.DiscNumber
		self.discNumber = tmp if tmp else 0
		tmp = mf.TrackNumber
		self.trackNumber = tmp if tmp else 0
		self.trackArtist = mf.TrackArtist
		self.trackTitle = mf.TrackTitle
		self.filename = filename
		self.duration = mf.DurationSeconds

class ApprovedTagsList:
	def __init__(self) -> None:
		self._tags = {
			TagNames.AlbumTitle.upper(): TagNames.AlbumTitle,
			TagNames.TrackTitle.upper(): TagNames.TrackTitle,
			TagNames.AlbumArtist.upper(): TagNames.AlbumArtist,
			TagNames.TrackArtist.upper(): TagNames.TrackArtist,
			TagNames.YearReleased.upper(): TagNames.YearReleased,
			TagNames.Composer.upper(): TagNames.Composer,
			TagNames.Comment.upper(): TagNames.Comment,
			TagNames.TrackNumber.upper(): TagNames.TrackNumber,
			TagNames.DiscNumber.upper(): TagNames.DiscNumber,
			TagNames.Copyright.upper(): TagNames.Copyright,
			TagNames.Conductor.upper(): TagNames.Conductor,
			TagNames.Lyrics.upper(): TagNames.Lyrics,
			TagNames.Writer.upper(): TagNames.Writer,
			TagNames.Producer.upper(): TagNames.Producer,
			TagNames.Engineer.upper(): TagNames.Engineer,
			TagNames.MixedBy.upper(): TagNames.MixedBy,
			TagNames.RemixedBy.upper(): TagNames.RemixedBy,
			TagNames.Arranger.upper(): TagNames.Arranger,
			TagNames.RecordLabel.upper(): TagNames.RecordLabel,
			TagNames.Lyricist.upper(): TagNames.Lyricist,
			TagNames.Language.upper(): TagNames.Language,
			TagNames.OriginalAlbumTitle.upper(): TagNames.OriginalAlbumTitle,
			TagNames.OriginalArtist.upper(): TagNames.OriginalArtist,
			TagNames.OriginalReleaseYear.upper(): TagNames.OriginalReleaseYear,
			TagNames.ReplayGainTrackGain.upper(): TagNames.ReplayGainTrackGain,
			TagNames.ReplayGainTrackPeak.upper(): TagNames.ReplayGainTrackPeak,
			TagNames.ReplayGainAlbumGain.upper(): TagNames.ReplayGainAlbumGain,
			TagNames.ReplayGainAlbumPeak.upper(): TagNames.ReplayGainAlbumPeak,
			TagNames.MusicBrainzDiscId.upper(): TagNames.MusicBrainzDiscId,
			TagNames.MusicBrainzAlbumId.upper(): TagNames.MusicBrainzAlbumId,
			TagNames.MusicBrainzTrackArtistId.upper(): TagNames.MusicBrainzTrackArtistId,
			TagNames.MusicBrainzAlbumArtistId.upper(): TagNames.MusicBrainzAlbumArtistId,
			TagNames.MusicBrainzTrackId.upper(): TagNames.MusicBrainzTrackId,
			TagNames.MusicBrainzTrackId.upper(): TagNames.MusicBrainzTrackId,
			TagNames.MusicBrainzAlbumReleaseCountry.upper(): TagNames.MusicBrainzAlbumReleaseCountry,
			TagNames.MusicBrainzReleaseGroupId.upper(): TagNames.MusicBrainzReleaseGroupId,
			TagNames.MusicBrainzReleaseType.upper(): TagNames.MusicBrainzReleaseType,
			TagNames.MusicBrainzReleaseStatus.upper(): TagNames.MusicBrainzReleaseStatus,
			TagNames.MediaType.upper(): TagNames.MediaType,
			TagNames.MusicBrainzWorkId.upper(): TagNames.MusicBrainzWorkId,
			TagNames.WorkTitle.upper(): TagNames.WorkTitle,
			TagNames.AcoustidId.upper(): TagNames.AcoustidId,
			TagNames.ISRC.upper(): TagNames.ISRC,
			TagNames.Barcode.upper(): TagNames.Barcode,
			TagNames.CatalogNumber.upper(): TagNames.CatalogNumber,
			TagNames.AmazonId.upper(): TagNames.AmazonId,
			TagNames.RecordLabel.upper(): TagNames.RecordLabel,
			TagNames.MusicianCredits.upper(): TagNames.MusicianCredits,
			TagNames.InvolvedPeople.upper(): TagNames.InvolvedPeople,
			TagNames.DigitalPurchaseFrom.upper(): TagNames.DigitalPurchaseFrom,
			TagNames.DigitalPurchaseDate.upper(): TagNames.DigitalPurchaseDate,
			TagNames.DigitalPurchaseId.upper(): TagNames.DigitalPurchaseId,
			TagNames.RecordedDate.upper(): TagNames.RecordedDate,
			TagNames.ReleasedDate.upper(): TagNames.ReleasedDate,
			TagNames.AllMusicArtistId.upper(): TagNames.AllMusicArtistId,
			TagNames.AllMusicAlbumId.upper(): TagNames.AllMusicAlbumId,
			TagNames.WikidataArtistId.upper(): TagNames.WikidataArtistId,
			TagNames.WikidataAlbumId.upper(): TagNames.WikidataAlbumId,
			TagNames.WikipediaArtistId.upper(): TagNames.WikipediaArtistId,
			TagNames.WikipediaAlbumId.upper(): TagNames.WikipediaAlbumId,
			TagNames.IMDbArtistId.upper(): TagNames.IMDbArtistId,
			# opus file's realplay gain names; don't think we need these in TagNames (??)
			"R128_ALBUM_GAIN": "R128_ALBUM_GAIN",
			"R128_TRACK_GAIN": "R128_TRACK_GAIN",
		}

	def __len__(self) -> int:
		return len(self._tags)

	def __contains__(self, key : str) -> bool:
		return key and key.upper() in self._tags

	def __iter__(self) -> Iterator[str]:
		for v in self._tags.values():	# should we just return the .values()?
			yield v

class MusicFolderHandler:
	_supportedFileTypesGlob: list[str] = ["*.m4a", "*.wma", "*.flac", "*.ogg", "*.oga", "*.opus", "*.ape",]	# "*.mp3", "*.wav",]
	_disableWriteAccess = (stat.S_ISUID|stat.S_ISGID|stat.S_ISVTX|stat.S_IRWXU|stat.S_IRWXG|stat.S_IRWXO) ^ (stat.S_IWRITE|stat.S_IWGRP|stat.S_IWOTH)
	_commentsProducerRegex = re.compile(r"produce(r|d)", re.IGNORECASE)
	_composerRegex = re.compile(r"\s*(;|/)\s*")
	_badCharsRegex = re.compile(r"[‘’“”\u2014\u2013\u2010]")
	#_fancySingleQuotesRegex = re.compile(r"[‘’]")
	#_fancyDoubleQuotesRegex = re.compile(r"[“”]")
	_badQuotesRegex = re.compile(r"[‘’“”]")
	#_badDashesRegex = re.compile(r"[\—\–\‐]")	# m-dash, n-dash, hyphen
	_badDashesRegex = re.compile(r"[\u2014\u2013\u2010]")	# m-dash, n-dash, hyphen
	_badFilenameCharsRegex = re.compile(r"[<>\\/\|\*\?:\"]")
	_approvedTags = ApprovedTagsList()

	def __init__(self, folderPath : pathlib.Path = None, targetFolderPath : pathlib.Path = None, sourceFolderPath : pathlib.Path = None,
				createPlaylist : bool = False, onlyPlaylist : bool = False, playlistName : str = None, onlyTimestamp : bool = False, enableSimpleLookup : bool = False,
				whatIf : bool = False):
		self._folderPath = folderPath
		self._targetFolderPath = targetFolderPath
		self._sourceFolderPath = sourceFolderPath
		self._playlist = createPlaylist
		self._onlyPlaylist = onlyPlaylist
		self._playlistName = playlistName
		self._onlyTimestamp = onlyTimestamp
		self._enableSimpleLookup = enableSimpleLookup
		self._whatIf = whatIf

#	@deprecated("we're not using this any more, right?")
	def SetFolderFilesFromDb(self):
		renamedFolder = self._cleanUpFolderName(self._folderPath)
		if renamedFolder:
			self._folderPath = renamedFolder
		self._cleanUpFilenames(self._folderPath)

		if not self._onlyPlaylist:
			with sqliteConnHelper(_musicAttributesDbPath) as conn:
				for f in self._folderPath.glob("*.m4a"):
					mf = MusicFileProperties(f)
					self._setMusicFileFromDb(mf, conn)

		if (self._playlist or self._onlyPlaylist) and not self._onlyTimestamp:
			self._createPlaylist()

	def CopyFolderProperties(self):
		renamedFolder = self._cleanUpFolderName(self._targetFolderPath)
		if renamedFolder:
			self._targetFolderPath = renamedFolder
		self._cleanUpFilenames(self._targetFolderPath)

		for tf in FileHelpers.MultiGlob(self._targetFolderPath, MusicFolderHandler._supportedFileTypesGlob):
			#
			# TODO: this needs updating to look for any supported types, not just same one as original...
			#
			sf = self._sourceFolderPath / tf.name
			if not sf.is_file():
				LogHelper.Warning(f"no source file found for file '{tf.name}'")
				continue
			trg = MusicFileProperties(tf)
			src = MusicFileProperties(sf)
			self._copyFileProperties(trg, src)

	def CleanFolderFiles(self):
		renamedFolder = self._cleanUpFolderName(self._folderPath)
		if renamedFolder:
			self._folderPath = renamedFolder
		self._cleanUpFilenames(self._folderPath)

		for f in FileHelpers.MultiGlob(self._folderPath, MusicFolderHandler._supportedFileTypesGlob):
			mf = MusicFileProperties(f)
			self._cleanFile(mf)

	def CleanFile(self, filePath : pathlib.Path):
		mf = MusicFileProperties(filePath)
		self._cleanFile(mf)

	def _saveFile(self, musicFile: MusicFileProperties, originalLastModTime: float, originalLastAccessTime: float, quiet: bool, ignoreOnlyTimestamp: bool):
		if self._whatIf:
			LogHelper.WhatIf(f'saving changes to file "{musicFile.FilePath.name}"')
		else:
			if quiet:
				LogHelper.Verbose(f'saving change to file "{musicFile.FilePath.name}"')
			else:
				LogHelper.Message(f'saving change to file "{musicFile.FilePath.name}"')
			musicFile.FilePath.chmod(musicFile.FilePath.stat().st_mode | stat.S_IWRITE)		# make sure it's NOT readonly
			if ignoreOnlyTimestamp or not self._onlyTimestamp:
				musicFile.save(True)
			os.utime(musicFile.FilePath, (originalLastAccessTime, originalLastModTime))
			musicFile.FilePath.chmod(musicFile.FilePath.stat().st_mode & MusicFolderHandler._disableWriteAccess)		# now make sure it IS readonly

	def _copyFileProperties(self, targetMusicFile : MusicFileProperties, sourceMusicFile : MusicFileProperties, forceOverwrite: bool = False):
		lastModTime = os.path.getmtime(sourceMusicFile.FilePath)
		currLastAccessTime = os.path.getatime(targetMusicFile.FilePath)
		self._cleanJunkProperties(targetMusicFile)

		self._copyTag(TagNames.AlbumTitle, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.TrackTitle, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.AlbumArtist, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.TrackArtist, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.YearReleased, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Conductor, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Copyright, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.RecordLabel, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Lyrics, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Composer, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Producer, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Comment, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.TrackNumber, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.TrackCount, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.DiscNumber, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.DiscCount, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.OriginalArtist, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.OriginalAlbumTitle, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.OriginalReleaseYear, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.RecordedDate, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.ReleasedDate, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.MusicianCredits, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Lyricist, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Engineer, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.MixedBy, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.Arranger, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.DigitalPurchaseFrom, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.DigitalPurchaseDate, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.DigitalPurchaseId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.AllMusicArtistId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.AllMusicAlbumId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.WikidataArtistId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.WikidataAlbumId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.WikipediaArtistId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.WikipediaAlbumId, sourceMusicFile, targetMusicFile)
		self._copyTag(TagNames.IMDbArtistId, sourceMusicFile, targetMusicFile)

		self._saveFile(targetMusicFile, lastModTime, currLastAccessTime, False, True)

#	@deprecated("we're not using this any more, right?")
	def _setMusicFileFromDb(self, musicFile : MusicFileProperties, sqliteConn : sqlite3.Connection):
		#
		# this should be updated, if we ever use it again...; or just get rid of it...
		___obsolete___
		#
		lastModTime = os.path.getmtime(musicFile.FilePath)
		currLastAccessTime = os.path.getatime(musicFile.FilePath)

		if not self._onlyTimestamp:
			self._cleanJunkProperties(musicFile)

		resultRows = []
		resultsCount = 0
		with sqliteCursorHelper(sqliteConn) as curs:
			LogHelper.Verbose(f"doing db query: AlbumArtist: '{musicFile.AlbumArtist}' / AlbumTitle: '{musicFile.AlbumTitle}' / TrackArtist: '{musicFile.TrackArtist}' / TrackTitle: '{musicFile.TrackTitle}'")
			queryHelper().doMusicFileDbQuery(curs, musicFile.TrackArtist, musicFile.AlbumArtist, musicFile.TrackTitle, musicFile.AlbumTitle)
			resultRows = curs.fetchall()
			resultsCount = len(resultRows)
			if resultsCount == 0 and self._enableSimpleLookup:
				LogHelper.Verbose(f"doing alt db query: TrackArtist: '{musicFile.TrackArtist}' / TrackTitle: '{musicFile.TrackTitle}'")
				queryHelper().doMusicFileDbQueryAlt(curs, musicFile.TrackArtist, musicFile.TrackTitle)
				resultRows = curs.fetchall()
				resultsCount = len(resultRows)

		if resultsCount == 0:
			LogHelper.Warning2(f"No DB record found for file '{musicFile.FilePath.name}'")
		elif resultsCount > 1:
			row = MusicFolderHandler._handleMultipleRows(resultRows, musicFile)
			if row:
				LogHelper.Message(f"Setting properties from record id {row.DbId} for file '{musicFile.FilePath.name}'")
				if not self._onlyTimestamp:
					self._setFileProperties(musicFile, row)
				if row.ModifyTimeUTC:
					lastModTime = MusicFolderHandler._dbModifyTimeToTimestamp(row.ModifyTimeUTC)
			else:
				LogHelper.Warning(f"skipping setting properties for file '{musicFile.FilePath.name}'")
		else:
			row = DbRowHelper(resultRows[0])
			LogHelper.Message(f"One DB record (id: {row.DbId}) found for file '{musicFile.FilePath.name}'")
			if not self._onlyTimestamp:
				self._setFileProperties(musicFile, row)
			if row.ModifyTimeUTC:
				lastModTime = MusicFolderHandler._dbModifyTimeToTimestamp(row.ModifyTimeUTC)

		self._saveFile(musicFile, lastModTime, currLastAccessTime, True, False)

#	@deprecated("we're not using this any more, right?")
	def _setFileProperties(self, musicFile : MusicFileProperties, dbRow : DbRowHelper):
		#
		# this should be updated, if we ever use it again...; or just get rid of it...
		___obsolete___
		#
		LogHelper.Verbose(f"setting properties on file '{musicFile.FilePath.stem}'")
		if dbRow.AlbumTitle:
			at = MusicFolderHandler._addFancyChars(dbRow.AlbumTitle)
			self._logSetProperty("AlbumTitle", at)
			musicFile.AlbumTitle = at
		if dbRow.TrackTitle:
			tt = MusicFolderHandler._addFancyChars(dbRow.TrackTitle)
			self._logSetProperty("TrackTitle", tt)
			musicFile.TrackTitle = tt
		albumArtist = dbRow.AlbumArtist if dbRow.AlbumArtist else dbRow.TrackArtist
		if albumArtist:
			aa = MusicFolderHandler._addFancyChars(albumArtist)
			self._logSetProperty("AlbumArtist", aa)
			musicFile.AlbumArtist = aa
		trackArtist = dbRow.TrackArtist if dbRow.TrackArtist else dbRow.AlbumArtist
		if trackArtist:
			ta = MusicFolderHandler._addFancyChars(trackArtist)
			self._logSetProperty("TrackArtist", ta)
			musicFile.TrackArtist = ta
		if dbRow.Year:
			year = int(dbRow.Year)
			if year > 0:
				self._logSetProperty("Year", dbRow.Year)
				musicFile.Year = str(year)
		if dbRow.Conductor:
			self._logSetProperty("Conductor", dbRow.Conductor)
			musicFile.Conductor = dbRow.Conductor
		copyright = dbRow.Copyright
		if copyright:
			copyright = copyright.replace("(c)", "©").replace("(C)", "©").replace("(p)", "℗").replace("(P)", "℗")
			self._logSetProperty("Copyright", copyright)
			musicFile.Copyright = copyright
		if dbRow.Publisher:
			self._logSetProperty("Publisher", dbRow.Publisher)
			musicFile.Publisher = dbRow.Publisher
		if dbRow.OriginalArtist:
			self._logSetProperty("OriginalArtist", dbRow.OriginalArtist)
			musicFile.OriginalArtist = dbRow.OriginalArtist
		if dbRow.OriginalAlbum:
			self._logSetProperty("OriginalAlbum", dbRow.OriginalAlbum)
			musicFile.OriginalAlbum = dbRow.OriginalAlbum
		if dbRow.OriginalYear:
			self._logSetProperty("OriginalYear", dbRow.OriginalYear)
			musicFile.OriginalYear = dbRow.OriginalYear
		# for lyrics & comments, i normalized the line endins to *nix style in DB, so maybe need to put that back?
		# nothing in db has "\r\n", so can do simple replace:
		lyrics = dbRow.Lyrics
		if lyrics:
			lyrics = lyrics.replace("\\n", "\r\n")
			self._logSetProperty("Lyrics", lyrics)
			musicFile.Lyrics = lyrics
		# normalize Composer, Producer, any other multi-value lists: replace '\s*/\s*', '\s*;\s*', '\s*&\s*', '\s*and\s*', '\s*,\s*' (except what about e.g.', Jr.' ??), etc(?) with just '/'
		#    --> on second thought, just leave these alone; there's too much variability and the way they're formatted usually matches what the albums say, so should just keep that
		composer = dbRow.Composer
		if composer:
			#composer = MusicFolderHandler._composerRegex.sub("/", composer)	# don't think i need to do this; already did it for db??
			self._logSetProperty("Composer", composer)
			musicFile.Composer = composer
		producer = dbRow.Producer
		if producer:
			self._logSetProperty("Producer", producer)
			musicFile.Producer = producer
		# handle Producer: if we got one from source file/DB, in addition to setting tag, add it to Comments if not already in there (search for 'Producer' or 'Produced' ??)
		comments = dbRow.Comments
		if comments:
			comments = comments.replace("\\n", "\r\n")
			if producer and not MusicFolderHandler._commentsProducerRegex.search(comments):
				LogHelper.Verbose(f"adding producer '{producer}' to comments")
				comments = f"Produced by: {producer}\r\n\r\n{comments}"
			self._logSetProperty("Comments", comments)
			musicFile.Comments = comments
		elif producer:
			comments = f"Produced by: {producer}"
			self._logSetProperty("Comments", comments)
			musicFile.Comments = comments
		# if target file already has track number, leave it alone (?); same for disc number; and if we don't have a TotalDiscs in target file, set to '1'(?)
		# also, some of the track numbers in the DB are like '2/8', so have to parse those; but with those, i have the TotalTracks, so...
		dbTrackNum = dbRow.TrackNumber
		if dbTrackNum:
			trackPieces = dbTrackNum.partition("/")
			trackNum = int(trackPieces[0]) if trackPieces[0] and trackPieces[0].strip() else 0
			ttlTracks = int(trackPieces[2]) if trackPieces[2] and trackPieces[2].strip() else 0
			#if not musicFile.TrackNumber and trackNum > 0:
			if trackNum > 0:
				self._logSetProperty("TrackNumber", str(trackNum))
				musicFile.TrackNumber = trackNum
			#if not musicFile.TotalTracks and ttlTracks > 0:
			if ttlTracks > 0:
				self._logSetProperty("TotalTracks", str(ttlTracks))
				musicFile.TotalTracks = ttlTracks
		## no Disc info in db (oversight?), so just default them to 1 if not already set:
		#if not musicFile.DiscNumber:
		#	self._logSetProperty("DiscNumber", "1")
		#	musicFile.DiscNumber = 1
		#if not musicFile.TotalDiscs:
		#	self._logSetProperty("TotalDiscs", "1")
		#	musicFile.TotalDiscs = 1

	def _cleanFile(self, musicFile : MusicFileProperties):
		lastModTime = os.path.getmtime(musicFile.FilePath)
		currLastAccessTime = os.path.getatime(musicFile.FilePath)

		self._cleanJunkProperties(musicFile)

		self._saveFile(musicFile, lastModTime, currLastAccessTime, False, True)

	def _cleanJunkProperties(self, musicFile : MusicFileProperties):
		musicFile.deleteTag(TagNames.iTunSMPB)
		musicFile.deleteTag(TagNames.Genre)
		musicFile.deleteTag(TagNames.Cover)
		musicFile.deleteTag(TagNames.Encoder)
		musicFile.deleteTag(TagNames.Codec)
		musicFile.deleteTag(TagNames.EncodedBy)
		musicFile.deleteTag(TagNames.Source)
		musicFile.deleteTag(TagNames.RippingTool)
		musicFile.deleteTag(TagNames.RipDate)
		musicFile.deleteTag(TagNames.MusicBrainzReleaseType)
		musicFile.deleteTag(TagNames.EncodingSettings)
		musicFile.deleteTag(TagNames.UPC)
		musicFile.deleteTag(TagNames.Rating)
		musicFile.deleteTag(TagNames.Script)
		musicFile.deleteTag(TagNames.Artists)
		musicFile.deleteTag(TagNames.Performer)
		#musicFile.deleteTag(TagNames.OriginalReleaseDate)		# think we've got a conflict with names from Picard and what i'm adding in Mp3tag ??
		#musicFile.deleteTag(TagNames.OriginalReleaseYear)
		musicFile.deleteTag(TagNames.AlbumTitleSort)
		musicFile.deleteTag(TagNames.TrackTitleSort)
		musicFile.deleteTag(TagNames.AlbumArtistSort)
		musicFile.deleteTag(TagNames.TrackArtistSort)
		musicFile.deleteTag(TagNames.ComposerSort)

		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzReleaseType, musicFile)	# we're deleting this one above ???
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzReleaseStatus, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzAlbumReleaseCountry, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzWorkId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzTrackId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzReleaseTrackId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzReleaseGroupId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzDiscId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzTrackArtistId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzAlbumId, musicFile)
		MusicFolderHandler._cleanUpTagName(TagNames.MusicBrainzAlbumArtistId, musicFile)

		unexpectedTags = []
		for t,v in musicFile.getNativeTagValues():
			if t.startswith('$$'): continue
			if t not in MusicFolderHandler._approvedTags:
				strV = str(v)
				if len(strV) > 120:
					strV = strV[:117] + "..."
				unexpectedTags.append((t, strV))
		if unexpectedTags:
			msg = f"unexpected tag(s) in file '{musicFile.FilePath.name}':"
			for tup in unexpectedTags:
				msg += f"{os.linesep}      tag: {tup[0]}{os.linesep}    value: {tup[1]}"
			LogHelper.Warning(msg)

	def _cleanUpFolderName(self, folderPath : pathlib.Path):
		# check that folder name doesn't contain any funky characters and rename it if so (like fancy quotes etc)
		folderName = folderPath.name
		if MusicFolderHandler._hasBadChars(folderName):
			folderName = MusicFolderHandler._fixBadChars(folderName)
			LogHelper.Message2(f"renaming folder |{folderPath.name}| to |{folderName}|")
			if self._whatIf:
				LogHelper.WhatIf(f"renaming folder |{folderPath.name}| to |{folderName}|")
			else:
				return folderPath.rename((folderPath.parent / folderName))

	def _cleanUpFilenames(self, folderPath : pathlib.Path):
		# check all the file names for funky characters and rename them
		for f in FileHelpers.MultiGlob(folderPath, MusicFolderHandler._supportedFileTypesGlob):
			filename = f.name
			if MusicFolderHandler._hasBadChars(filename):
				filename = MusicFolderHandler._fixBadChars(filename)
				LogHelper.Message2(f"renaming file |{f.name}| to |{filename}|")
				if self._whatIf:
					LogHelper.WhatIf(f"renaming file |{f.name}| to |{filename}|")
				else:
					f = f.rename((f.parent / filename))

	def _createPlaylist(self):
		entries = []; isFirst = True; albumTitle = ''; albumArtist = ''
		for f in FileHelpers.MultiGlob(self._folderPath, MusicFolderHandler._supportedFileTypesGlob):
			mf = MusicFileProperties(f)
			if isFirst:
				albumTitle = self._playlistName if self._playlistName else mf.AlbumTitle
				albumArtist = mf.AlbumArtist if mf.AlbumArtist else mf.TrackArtist
				isFirst = False
			entries.append(PlaylistEntry(mf, f.name))

		albumArtistForFile = albumArtist
		if (albumArtistForFile.lower().startswith("the ")):
			albumArtistForFile = albumArtistForFile[4:] + ", The"
		elif (albumArtistForFile.lower().startswith("a ")):
			albumArtistForFile = albumArtistForFile[2:] + ", A"
		elif (albumArtistForFile.lower().startswith("an ")):
			albumArtistForFile = albumArtistForFile[3:] + ", An"
		#filename = f"{albumArtistForFile} - {albumTitle}.m3u8"
		filename = f"{albumArtistForFile} - {albumTitle}.m3u"
		filename = MusicFolderHandler._fixBadChars(filename)
		filename = MusicFolderHandler._badFilenameCharsRegex.sub("_", filename)
		playlist = pathlib.Path((self._folderPath / filename))

		LogHelper.Message(f"creating playlist '{str(playlist)}'")
		if self._whatIf:
			LogHelper.WhatIf(f"creating playlist file '{playlist.name}'")
		else:
			if playlist.is_file():
				# make sure it's not readonly:
				playlist.chmod(playlist.stat().st_mode | stat.S_IWRITE)
			#with playlist.open(mode='wt', encoding='utf-8') as pl:
			with playlist.open(mode='wt', encoding='utf-8-sig') as pl:
				pl.write("#EXTM3U\n")
				if albumTitle:
					pl.write(f"#EXTALB:{albumTitle}\n")
				if albumArtist:
					pl.write(f"#EXTART:{albumArtist}\n")
				for e in sorted(entries, key=attrgetter('discNumber', 'trackNumber')):
					pl.write(f"#EXTINF:{round(e.duration)},{e.trackArtist} - {e.trackTitle}\n")
					pl.write(f"{e.filename}\n")
			playlist.chmod(playlist.stat().st_mode & MusicFolderHandler._disableWriteAccess)

	def _logSetProperty(self, propertyName : str, value : str):
		LogHelper.Verbose('    setting "{propertyName}" to "{value}"', propertyName = propertyName, value = lambda: MusicFolderHandler._ellipsify(value))

	@staticmethod
	def _ellipsify(value : str):
		if value and len(value) > 64:
			value = value[:61] + "..."
		return value

	@staticmethod
	def _dbModifyTimeToTimestamp(value : str):
		# for ModifyTimeUTC, i didn't use ISO format, so will need to do a ParseExtact kind of thing and make sure it's UTC:
		return datetime.datetime.strptime(value, "%Y-%m-%d %H:%M:%S").replace(tzinfo=datetime.timezone.utc).timestamp()

	@staticmethod
	def _handleMultipleRows(dbRows : List, musicFile : MusicFileProperties):
		LogHelper.Warning(f"Multiple DB record found for file '{musicFile.FilePath.name}':")
		headers = ["Id", "FilePath", "AlbumArtist", "AlbumTitle", "TrackArtist", "TrackTitle"]
		outputRows = []
		ids = []
		idsMap = dict()
		for row in DbRowHelper.EnumRows(dbRows):
			idStr = str(row.DbId)
			ids.append(idStr)
			idsMap[idStr] = row
			outputRows.append([idStr, row.FilePath, row.AlbumArtist, row.AlbumTitle, row.TrackArtist, row.TrackTitle])
		print(tabulate(outputRows, headers=headers, tablefmt=_defaultTableFormat))
		print("")
		prompt = f"Which song do you want to use? {', '.join(ids)}, or S to skip: "
		while True:
			choice = input(prompt)
			if choice.upper() == 'S':
				return None
			if choice in idsMap:
				return idsMap[choice]
			print("please enter a value from the list")

	@staticmethod
	def _hasBadChars(value : str):
		return bool(MusicFolderHandler._badCharsRegex.search(value))

	@staticmethod
	def _fixBadChars(value : str):
		#value = MusicFolderHandler._fancySingleQuotesRegex.sub("'", value)
		#value = MusicFolderHandler._fancyDoubleQuotesRegex.sub("'", value)
		value = MusicFolderHandler._badQuotesRegex.sub("'", value)
		value = MusicFolderHandler._badDashesRegex.sub("-", value)
		return value

	@staticmethod
	def _addFancyChars(value : str):
		return value.replace("'", "’").replace("...", "…")

	@staticmethod
	def _copyTag(tagName: str, source: MusicFileProperties, target: MusicFileProperties):
		val = source.getTagValue(tagName)
		if val:
			target.setTagValue(tagName, val)

	@staticmethod
	def _cleanUpTagName(tagName: str, target: MusicFileProperties):
		# we're handling old tag names mapped to new names in the mapping file and in how we're saving the tags,
		# so all we have to do is get and re-save the property, if it's there:
		val = target.getTagValue(tagName)
		if not val: return
		target.setTagValue(tagName, val)

class sqliteConnHelper:
	def __init__(self, sqliteFilename : str):
		self._filename = sqliteFilename

	def __enter__(self):
		self._conn = sqlite3.connect(self._filename)
		self._conn.row_factory = sqlite3.Row	# have to use this to get rows with column names; default just returns plain tuples of the values;
		return self._conn

	def __exit__(self, exc_type, exc_value, traceback):
		if self._conn:
			self._conn.close()
			self._conn = None

class sqliteCursorHelper:
	def __init__(self, sqliteConn : sqlite3.Connection):
		self._conn = sqliteConn

	def __enter__(self):
		self._cursor = self._conn.cursor()
		return self._cursor

	def __exit__(self, exc_type, exc_value, traceback):
		if self._cursor:
			self._cursor.close()
			self._cursor = None
		self._conn = None

class queryHelper:
	@staticmethod
	def _normalizeString(value : str):
		if value is None:
			return None
		value = value.strip()
		if value == '':
			return None
		value = value.replace("‘", "'").replace("’", "'").replace('”', '"').replace('“', '"').replace("—", "-").replace("–", "-").replace("‐", "-")
		return value

	def doSimpleDbQuery(self, sqliteCursor : sqlite3.Cursor, trackArtist : str, albumArtist : str, trackTitle : str, albumTitle : str):
		trackArtist = queryHelper._normalizeString(trackArtist)
		albumArtist = queryHelper._normalizeString(albumArtist)
		trackTitle = queryHelper._normalizeString(trackTitle)
		albumTitle = queryHelper._normalizeString(albumTitle)
		query = """SELECT MusicFileAttributesId, Folder, Filename, Extension
					FROM MusicFiles
					WHERE (@trackArtist IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(TrackArtist, '’', ''''), '‘', ''''), '“', '"'), '”', '"') = @trackArtist COLLATE NOCASE) AND
						(@albumArtist IS NULL OR AlbumArtist IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(AlbumArtist, '’', ''''), '‘', ''''), '“', '"'), '”', '"') = @albumArtist COLLATE NOCASE) AND
						(@trackTitle IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TrackTitle, '’', ''''), '‘', ''''), '“', '"'), '”', '"'), '—', '-'), '–', '-'), '‐', '-') = @trackTitle COLLATE NOCASE) AND
						(@albumTitle IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(AlbumTitle, '’', ''''), '‘', ''''), '“', '"'), '”', '"'), '—', '-'), '–', '-'), '‐', '-') = @albumTitle COLLATE NOCASE)"""
		#			WHERE (@trackArtist IS NULL OR TrackArtistNormed = @trackArtist) AND
		#				(@albumArtist IS NULL OR AlbumArtistNormed IS NULL OR AlbumArtistNormed = @albumArtist) AND
		#				(@trackTitle IS NULL OR TrackTitleNormed = @trackTitle) AND
		#				(@albumTitle IS NULL OR AlbumTitleNormed = @albumTitle)"""
		params = {
			"trackArtist": trackArtist,
			"albumArtist": albumArtist,
			"trackTitle": trackTitle,
			"albumTitle": albumTitle,
		}
		sqliteCursor.execute(query, params)

	def doMusicFileDbQuery(self, sqliteCursor : sqlite3.Cursor, trackArtist : str, albumArtist : str, trackTitle : str, albumTitle : str):
		trackArtist = queryHelper._normalizeString(trackArtist)
		albumArtist = queryHelper._normalizeString(albumArtist)
		trackTitle = queryHelper._normalizeString(trackTitle)
		albumTitle = queryHelper._normalizeString(albumTitle)
		# don't have any db records where AlbumArtis is not null and TrackArtist is null,
		# but about 1/4 have it the other way, so allow AlbumArtist to be NULL:
		query = """SELECT MusicFileAttributesId, Folder, Filename, Extension, ModifyTimeUTC,
						AlbumTitle, AlbumArtist, TrackArtist, TrackTitle, TrackNumber, Year,
						Composer, Producer, Conductor, Copyright, Publisher, Lyrics, Comments,
						OriginalArtist, OriginalAlbum, OriginalYear, Genre
					FROM MusicFiles
					WHERE (@trackArtist IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(TrackArtist, '’', ''''), '‘', ''''), '“', '"'), '”', '"') = @trackArtist COLLATE NOCASE) AND
						(@albumArtist IS NULL OR AlbumArtist IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(AlbumArtist, '’', ''''), '‘', ''''), '“', '"'), '”', '"') = @albumArtist COLLATE NOCASE) AND
						(@trackTitle IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TrackTitle, '’', ''''), '‘', ''''), '“', '"'), '”', '"'), '—', '-'), '–', '-'), '‐', '-') = @trackTitle COLLATE NOCASE) AND
						(@albumTitle IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(AlbumTitle, '’', ''''), '‘', ''''), '“', '"'), '”', '"'), '—', '-'), '–', '-'), '‐', '-') = @albumTitle COLLATE NOCASE)"""
		# sqlite doesn't have FUNCTIONs, so have to do all the REPLACES in the query; ick
		# but looks like the REPLACEs turn off the COLLATE NOCASEs, so i have to put them back in in the query; again, ick
		# also, it has computed columns for tables, which i tried, but sqlite does not have DROP COLUMN (???), so if i have to change the computed column,
		#     there's no way to do that, so went back to just using to doing it inline
		params = {
			"trackArtist": trackArtist,
			"albumArtist": albumArtist,
			"trackTitle": trackTitle,
			"albumTitle": albumTitle,
		}
		sqliteCursor.execute(query, params)

	def doMusicFileDbQueryAlt(self, sqliteCursor : sqlite3.Cursor, trackArtist : str, trackTitle : str):
		trackArtist = queryHelper._normalizeString(trackArtist)
		trackTitle = queryHelper._normalizeString(trackTitle)
		# don't have any db records where AlbumArtis is not null and TrackArtist is null,
		# but about 1/4 have it the other way, so allow AlbumArtist to be NULL:
		query = """SELECT MusicFileAttributesId, Folder, Filename, Extension, ModifyTimeUTC,
						AlbumTitle, AlbumArtist, TrackArtist, TrackTitle, TrackNumber, Year,
						Composer, Producer, Conductor, Copyright, Publisher, Lyrics, Comments,
						OriginalArtist, OriginalAlbum, OriginalYear, Genre
					FROM MusicFiles
					WHERE (@trackArtist IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(TrackArtist, '’', ''''), '‘', ''''), '“', '"'), '”', '"') = @trackArtist COLLATE NOCASE)  AND
						(@trackTitle IS NULL OR REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(TrackTitle, '’', ''''), '‘', ''''), '“', '"'), '”', '"'), '—', '-'), '–', '-'), '‐', '-') = @trackTitle COLLATE NOCASE)"""
		# sqlite doesn't have FUNCTIONs, so have to do all the REPLACES in the query; ick
		# but looks like the REPLACEs turn off the COLLATE NOCASEs, so i have to put them back in in the query; again, ick
		# also, it has computed columns for tables, which i tried, but sqlite does not have DROP COLUMN (???), so if i have to change the computed column,
		#     there's no way to do that, so went back to just using to doing it inline
		params = {
			"trackArtist": trackArtist,
			"trackTitle": trackTitle,
		}
		sqliteCursor.execute(query, params)

def queryDbCommand(args : argparse.Namespace):
	LogHelper.Init()
	headers = ["Id", "Filename"]
	results = []
	with sqliteConnHelper(_musicAttributesDbPath) as conn, sqliteCursorHelper(conn) as curs:
		queryHelper().doSimpleDbQuery(curs, args.trackArtist, args.albumArtist, args.trackTitle, args.albumTitle)
		for row in DbRowHelper.EnumRows(curs.fetchall()):
			results.append([row.DbId, row.FilePath])
	print(tabulate(results, headers=headers, tablefmt=_defaultTableFormat))

def setFolderPropertiesFromDbCommand(args):
	LogHelper.Init(verbose=args.verbose)
	folder = pathlib.Path(args.folderPath)#.resolve()
	if not folder.is_dir():
		print(f'folder "{args.folderPath}" does not exist, is not a folder or could not be accessed')
		return

	MusicFolderHandler(folderPath = folder, createPlaylist = args.playlist, onlyPlaylist = args.onlyPlaylist, playlistName = args.playlistName,
						onlyTimestamp = args.timestamp, enableSimpleLookup = args.simpleLookup, whatIf = args.whatIf)\
		.SetFolderFilesFromDb()

def copyFolderPropertiesCommand(args):
	LogHelper.Init(verbose=args.verbose)
	targetFolder = pathlib.Path(args.targetFolderPath)#.resolve()
	if not targetFolder.is_dir():
		print(f'folder "{args.targetFolderPath}" does not exist, is not a folder or could not be accessed')
		return
	sourceFolder = pathlib.Path(args.sourceFolderPath)#.resolve()
	if not sourceFolder.is_dir():
		print(f'folder "{args.sourceFolderPath}" does not exist, is not a folder or could not be accessed')
		return

	MusicFolderHandler(targetFolderPath = targetFolder, sourceFolderPath = sourceFolder, whatIf = args.whatIf)\
		.CopyFolderProperties()

def cleanFilesCommand(args):
	LogHelper.Init(verbose=args.verbose)
	p = pathlib.Path(args.path)#.resolve()
	if p.is_dir():
		MusicFolderHandler(folderPath = p, whatIf = args.whatIf).CleanFolderFiles()
	elif p.is_file():
		MusicFolderHandler(whatIf = args.whatIf).CleanFile(p)
	else:
		print(f'path "{args.path}" does not exist, is not a folder or could not be accessed')

def showFolderPropertiesCommand(args : argparse.Namespace):
	LogHelper.Init()
	folder = pathlib.Path(args.folderPath)#.resolve()
	if not folder.is_dir():
		print(f'folder "{args.folderPath}" does not exist, is not a folder or could not be accessed')
		return
	headers = ['Filename', 'AlbumTitle', 'TrackArtist', 'TrackTitle', 'Year']
	results = []
	for f in FileHelpers.MultiGlob(folder, MusicFolderHandler._supportedFileTypesGlob):
		props = MusicFileProperties(f)
		results.append([f.name, props.AlbumTitle, props.TrackArtist, props.TrackTitle, props.Year])
		props = None
	print(tabulate(sorted(results, key=lambda r: r[0]), headers=headers, tablefmt=_defaultTableFormat))

def showFilePropertiesCommand(args : argparse.Namespace):
	LogHelper.Init()
	file = pathlib.Path(args.filePath)#.resolve()
	if not file.is_file():
		print(f'file "{args.filePath}" does not exist, is not a folder or could not be accessed')
		return
	props = MusicFileProperties(file)
	printData = []
	if args.raw:
		for p,v in (sorted(props.getNativeTagValues(), key=lambda p: p[0].upper()) if args.sort else props.getNativeTagValues()):
			# 'APIC' if MP3 (no idea why mutagen is putting ':' in there); 'Cover Art XXX' for APE; 'METADATA_BLOCK_PICTURE' for Vorbis; 'WM/Picture' is WMA;
			if p == "covr" or p == 'APIC:' or p.startswith('Cover Art') or p == 'METADATA_BLOCK_PICTURE' or p == 'WM/Picture':
				printData.append([p,'<binary (cover)>'])
			elif p == "©lyr" or p.startswith('USLT::') or p.upper() == 'LYRICS' or p.upper() == 'UNSYNCEDLYRICS' or p == 'WM/Lyrics':
				printData.append([p,'<lyrics>'])
			else:
				printData.append([p,v])
	else:
		for p,v in props.getTagValues():
			printData.append([p,v])
	#print(tabulate(printData, headers=['Property','Value'], tablefmt='fancy_grid'))
	print(tabulate(printData, headers=['Property','Value'], tablefmt=_defaultTableFormat))
	props = None

def buildArguments():
	parser = argparse.ArgumentParser()
	subparsers = parser.add_subparsers(dest="commandName", title="subcommands")		# 'commandName' will be set to values passed to add_parser

	queryDbCmd = subparsers.add_parser("queryDb", help="queries the music properties sqlite db and prints out results")					# can add aliases
	queryDbCmd.add_argument("-ta", "--trackArtist")
	queryDbCmd.add_argument("-aa", "--albumArtist")
	queryDbCmd.add_argument("-tt", "--trackTitle")
	queryDbCmd.add_argument("-at", "--albumTitle")
	queryDbCmd.set_defaults(func=queryDbCommand)

	setFolderCmd = subparsers.add_parser("setFolderPropertiesFromDb", aliases=["set"], help="enumerates music files in a folder, queries the music property db for each and sets their properties")
	setFolderCmd.add_argument("folderPath")
	setFolderCmd.add_argument("-pl", "--playlist", action="store_true", help="also create a M3U8 playlist")
	setFolderCmd.add_argument("-op", "--onlyPlaylist", action="store_true", help="only create a M3U8 playlist")
	setFolderCmd.add_argument("-pn", "--playlistName", help="override playlist name")
	setFolderCmd.add_argument("-ts", "--timestamp", action="store_true", help="only set timestamps from the DB")
	setFolderCmd.add_argument("-sl", "--simpleLookup", action="store_true", help="enable simpler lookup if no record found with longer lookup")
	setFolderCmd.add_argument("-w", "--whatIf", action="store_true", help="do the lookups, but don't actually save anything")
	setFolderCmd.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	setFolderCmd.set_defaults(func=setFolderPropertiesFromDbCommand)

	setFolderCmd = subparsers.add_parser("copyFolderProperties", aliases=["copy", "cp"], help="enumerates music files in the target folder, looks for a matching file in source folder, and copies properties from source to target")
	setFolderCmd.add_argument("sourceFolderPath", help="folder to copy file tags FROM")
	setFolderCmd.add_argument("targetFolderPath", help="folder to copy file tags TO")
	setFolderCmd.add_argument("-w", "--whatIf", action="store_true", help="look up properties, but don't actually save anything")
	setFolderCmd.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	setFolderCmd.set_defaults(func=copyFolderPropertiesCommand)

	setFolderCmd = subparsers.add_parser("cleanFiles", aliases=["clean", "cl", "cf"], help="cleans out junk properties from the music files in the target folder")
	setFolderCmd.add_argument("path")
	setFolderCmd.add_argument("-w", "--whatIf", action="store_true", help="go thru cleaning properties, but don't actually save anything")
	setFolderCmd.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	setFolderCmd.set_defaults(func=cleanFilesCommand)

	setFolderCmd = subparsers.add_parser("showFolderProperties", aliases=["folder", "fld"], help="enumerates music files in the folder and shows properties for each")
	setFolderCmd.add_argument("folderPath")
	setFolderCmd.set_defaults(func=showFolderPropertiesCommand)

	setFolderCmd = subparsers.add_parser("showFileProperties", aliases=["file", "fil"], help="show music properties for the given file")
	setFolderCmd.add_argument("filePath")
	setFolderCmd.add_argument("-r", "--raw", action="store_true", help="show raw properties without mapping to friendly names")
	setFolderCmd.add_argument("-s", "--sort", action="store_true", help="if --raw, also sort the names")
	setFolderCmd.set_defaults(func=showFilePropertiesCommand)

	return parser

if __name__ == "__main__":
	parser = buildArguments()
	args = parser.parse_args()
	args.func(args)
