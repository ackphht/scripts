#!python3
# -*- coding: utf-8 -*-

import os, pathlib, datetime, re, argparse, stat, sqlite3
from typing import Any, List, Iterator
from tabulate import tabulate	# https://pypi.org/project/tabulate/
from operator import attrgetter

from ackPyHelpers import LogHelper
from musicFileProperties import MusicFileProperties, Mp4TagNames

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
		self.discNumber = mf.DiscNumber if mf.DiscNumber else 0
		self.trackNumber = mf.TrackNumber if mf.TrackNumber else 0
		self.trackArtist = mf.TrackArtist
		self.trackTitle = mf.TrackTitle
		self.filename = filename
		self.duration = mf.DurationSeconds

class ApprovedTagsList:
	def __init__(self) -> None:
		self._tags = {
			Mp4TagNames.AlbumTitle.upper(): Mp4TagNames.AlbumTitle,
			Mp4TagNames.TrackTitle.upper(): Mp4TagNames.TrackTitle,
			Mp4TagNames.AlbumArtist.upper(): Mp4TagNames.AlbumArtist,
			Mp4TagNames.TrackArtist.upper(): Mp4TagNames.TrackArtist,
			Mp4TagNames.Year.upper(): Mp4TagNames.Year,
			Mp4TagNames.Composer.upper(): Mp4TagNames.Composer,
			Mp4TagNames.Comment.upper(): Mp4TagNames.Comment,
			Mp4TagNames.TrackNumber.upper(): Mp4TagNames.TrackNumber,
			Mp4TagNames.DiscNumber.upper(): Mp4TagNames.DiscNumber,
			Mp4TagNames.Copyright.upper(): Mp4TagNames.Copyright,
			Mp4TagNames.Conductor.upper(): Mp4TagNames.Conductor,
			Mp4TagNames.Lyrics.upper(): Mp4TagNames.Lyrics,
			Mp4TagNames.Writer.upper(): Mp4TagNames.Writer,
			Mp4TagNames.Producer.upper(): Mp4TagNames.Producer,
			Mp4TagNames.Engineer.upper(): Mp4TagNames.Engineer,
			Mp4TagNames.Mixer.upper(): Mp4TagNames.Mixer,
			Mp4TagNames.ReMixer.upper(): Mp4TagNames.ReMixer,
			Mp4TagNames.Arranger.upper(): Mp4TagNames.Arranger,
			Mp4TagNames.Publisher.upper(): Mp4TagNames.Publisher,
			Mp4TagNames.Lyricist.upper(): Mp4TagNames.Lyricist,
			Mp4TagNames.Language.upper(): Mp4TagNames.Language,
			Mp4TagNames.OriginalAlbum.upper(): Mp4TagNames.OriginalAlbum,
			Mp4TagNames.OriginalArtist.upper(): Mp4TagNames.OriginalArtist,
			Mp4TagNames.OriginalYear.upper(): Mp4TagNames.OriginalYear,
			Mp4TagNames.ReplayGainTrackGain.upper(): Mp4TagNames.ReplayGainTrackGain,
			Mp4TagNames.ReplayGainTrackPeak.upper(): Mp4TagNames.ReplayGainTrackPeak,
			Mp4TagNames.ReplayGainAlbumGain.upper(): Mp4TagNames.ReplayGainAlbumGain,
			Mp4TagNames.ReplayGainAlbumPeak.upper(): Mp4TagNames.ReplayGainAlbumPeak,
			Mp4TagNames.MusicBrainzDiscId.upper(): Mp4TagNames.MusicBrainzDiscId,
			Mp4TagNames.MusicBrainzAlbumId.upper(): Mp4TagNames.MusicBrainzAlbumId,
			Mp4TagNames.MusicBrainzArtistId.upper(): Mp4TagNames.MusicBrainzArtistId,
			Mp4TagNames.MusicBrainzAlbumArtistId.upper(): Mp4TagNames.MusicBrainzAlbumArtistId,
			Mp4TagNames.MusicBrainzTrackId.upper(): Mp4TagNames.MusicBrainzTrackId,
			Mp4TagNames.MusicBrainzRecordingId.upper(): Mp4TagNames.MusicBrainzRecordingId,
			Mp4TagNames.MusicBrainzReleaseCountry.upper(): Mp4TagNames.MusicBrainzReleaseCountry,
			Mp4TagNames.MusicBrainzReleaseGroupId.upper(): Mp4TagNames.MusicBrainzReleaseGroupId,
			Mp4TagNames.MusicBrainzReleaseType.upper(): Mp4TagNames.MusicBrainzReleaseType,
			Mp4TagNames.MusicBrainzReleaseStatus.upper(): Mp4TagNames.MusicBrainzReleaseStatus,
			Mp4TagNames.Mp3tagMediaType.upper(): Mp4TagNames.Mp3tagMediaType,
			Mp4TagNames.MusicBrainzMediaType.upper(): Mp4TagNames.MusicBrainzMediaType,
			Mp4TagNames.MusicBrainzWorkId.upper(): Mp4TagNames.MusicBrainzWorkId,
			Mp4TagNames.WorkTitle.upper(): Mp4TagNames.WorkTitle,
			Mp4TagNames.AcoustId.upper(): Mp4TagNames.AcoustId,
			Mp4TagNames.Isrc.upper(): Mp4TagNames.Isrc,
			Mp4TagNames.Barcode.upper(): Mp4TagNames.Barcode,
			Mp4TagNames.CatalogNumber.upper(): Mp4TagNames.CatalogNumber,
			Mp4TagNames.Asin.upper(): Mp4TagNames.Asin,
			Mp4TagNames.Label.upper(): Mp4TagNames.Label,
			Mp4TagNames.MusicianCredits.upper(): Mp4TagNames.MusicianCredits,
			Mp4TagNames.InvolvedPeople.upper(): Mp4TagNames.InvolvedPeople,
			Mp4TagNames.DigitalPurchaseFrom.upper(): Mp4TagNames.DigitalPurchaseFrom,
			Mp4TagNames.DigitalPurchaseDate.upper(): Mp4TagNames.DigitalPurchaseDate,
			Mp4TagNames.DigitalPurchaseId.upper(): Mp4TagNames.DigitalPurchaseId,
			Mp4TagNames.Recorded.upper(): Mp4TagNames.Recorded,
			Mp4TagNames.Released.upper(): Mp4TagNames.Released,
		}

	def __len__(self) -> int:
		return len(self._tags)

	def __contains__(self, key : str) -> bool:
		return key and key.upper() in self._tags

	def __iter__(self) -> Iterator[str]:
		for v in self._tags.values():	# should we just return the .values()?
			yield v

class MusicFolderHandler:
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

		for tf in self._targetFolderPath.glob("*.m4a"):
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

		for f in self._folderPath.glob("*.m4a"):
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
			os.chmod(musicFile.FilePath, stat.S_IWRITE)		# make sure it's NOT readonly
			if ignoreOnlyTimestamp or not self._onlyTimestamp:
				musicFile.save(True)
			os.utime(musicFile.FilePath, (originalLastAccessTime, originalLastModTime))
			os.chmod(musicFile.FilePath, stat.S_IREAD)		# now make sure it IS readonly

	def _copyFileProperties(self, targetMusicFile : MusicFileProperties, sourceMusicFile : MusicFileProperties, forceOverwrite: bool = False):
		lastModTime = os.path.getmtime(sourceMusicFile.FilePath)
		currLastAccessTime = os.path.getatime(targetMusicFile.FilePath)
		self._cleanJunkProperties(targetMusicFile)

		targetMusicFile.AlbumTitle = sourceMusicFile.AlbumTitle
		targetMusicFile.TrackTitle = sourceMusicFile.TrackTitle
		targetMusicFile.AlbumArtist = sourceMusicFile.AlbumArtist
		targetMusicFile.TrackArtist = sourceMusicFile.TrackArtist
		targetMusicFile.Year = sourceMusicFile.Year
		targetMusicFile.Conductor = sourceMusicFile.Conductor
		targetMusicFile.Copyright = sourceMusicFile.Copyright
		targetMusicFile.Publisher = sourceMusicFile.Publisher
		targetMusicFile.OriginalArtist = sourceMusicFile.OriginalArtist
		targetMusicFile.OriginalAlbum = sourceMusicFile.OriginalAlbum
		targetMusicFile.OriginalYear = sourceMusicFile.OriginalYear
		targetMusicFile.Lyrics = sourceMusicFile.Lyrics
		targetMusicFile.Composer = sourceMusicFile.Composer
		targetMusicFile.Producer = sourceMusicFile.Producer
		targetMusicFile.Comments = sourceMusicFile.Comments
		targetMusicFile.TrackNumber = sourceMusicFile.TrackNumber
		targetMusicFile.TotalTracks = sourceMusicFile.TotalTracks
		targetMusicFile.DiscNumber = sourceMusicFile.DiscNumber
		targetMusicFile.TotalDiscs = sourceMusicFile.TotalDiscs
		# tags i haven't or don't want to make properties for:
		self._copyTag(Mp4TagNames.Recorded, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.Released, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.MusicianCredits, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.Lyricist, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.Engineer, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.Mixer, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.Arranger, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.DigitalPurchaseFrom, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.DigitalPurchaseDate, sourceMusicFile, targetMusicFile)
		self._copyTag(Mp4TagNames.DigitalPurchaseId, sourceMusicFile, targetMusicFile)

		self._saveFile(targetMusicFile, lastModTime, currLastAccessTime, False, True)

	def _setMusicFileFromDb(self, musicFile : MusicFileProperties, sqliteConn : sqlite3.Connection):
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

	def _setFileProperties(self, musicFile : MusicFileProperties, dbRow : DbRowHelper):
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
		musicFile.deleteRawProperty(Mp4TagNames.iTunSMPB)
		musicFile.deleteRawProperty(Mp4TagNames.Genre)
		musicFile.deleteRawProperty(Mp4TagNames.Cover)
		musicFile.deleteRawProperty(Mp4TagNames.Encoder)
		musicFile.deleteRawProperty(Mp4TagNames.Codec)
		musicFile.deleteRawProperty(Mp4TagNames.EncodedBy)
		musicFile.deleteRawProperty(Mp4TagNames.Source)
		musicFile.deleteRawProperty(Mp4TagNames.RippingTool)
		musicFile.deleteRawProperty(Mp4TagNames.RipDate)
		musicFile.deleteRawProperty(Mp4TagNames.RelaseType)
		musicFile.deleteRawProperty(Mp4TagNames.EncodingSettings)
		musicFile.deleteRawProperty(Mp4TagNames.Upc)
		musicFile.deleteRawProperty(Mp4TagNames.Rating)
		musicFile.deleteRawProperty(Mp4TagNames.Script)
		musicFile.deleteRawProperty(Mp4TagNames.MusicBrainzMediaArtists)
		musicFile.deleteRawProperty(Mp4TagNames.MusicBrainzPerformerFromConvert)
		musicFile.deleteRawProperty(Mp4TagNames.MusicBrainzOriginalYearFromConvert)
		musicFile.deleteRawProperty(Mp4TagNames.MusicBrainzOriginalDateFromConvert)
		musicFile.deleteRawProperty(Mp4TagNames.AlbumTitleSort)
		musicFile.deleteRawProperty(Mp4TagNames.TrackTitleSort)
		musicFile.deleteRawProperty(Mp4TagNames.AlbumArtistSort)
		musicFile.deleteRawProperty(Mp4TagNames.TrackArtistSort)
		musicFile.deleteRawProperty(Mp4TagNames.ComposerSort)

		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzMediaReleaseTypeFromConvert, Mp4TagNames.MusicBrainzReleaseType, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzReleaseStatusFromConvert, Mp4TagNames.MusicBrainzReleaseStatus, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzReleaseCountryFromConvert, Mp4TagNames.MusicBrainzReleaseCountry, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzWorkIdFromConvert, Mp4TagNames.MusicBrainzWorkId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzRecordingIdFromConvert, Mp4TagNames.MusicBrainzRecordingId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzTrackIdFromConvert, Mp4TagNames.MusicBrainzTrackId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzReleaseGroupIdFromConvert, Mp4TagNames.MusicBrainzReleaseGroupId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzDiscIdFromConvert, Mp4TagNames.MusicBrainzDiscId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzArtistIdFromConvert, Mp4TagNames.MusicBrainzArtistId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzAlbumIdFromConvert, Mp4TagNames.MusicBrainzAlbumId, musicFile)
		MusicFolderHandler._renameTag(Mp4TagNames.MusicBrainzAlbumArtistIdFromConvert, Mp4TagNames.MusicBrainzAlbumArtistId, musicFile)

		unexpectedTags = []
		for t,v in musicFile.getRawProperties():
			if t.startswith('$$'): continue
			if t not in MusicFolderHandler._approvedTags:
				strV = str(v)
				if len(strV) > 120:
					strV = strV[:117] + "..."
				unexpectedTags.append((t, strV))
		if unexpectedTags:
			LogHelper.Warning(f"unexpected tag(s) in file '{musicFile.FilePath.name}':")
			for tup in unexpectedTags:
				LogHelper.Warning(f"      tag: {tup[0]}{os.linesep}    value: {tup[1]}")

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
		for f in folderPath.glob("*.m4a"):
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
		for f in self._folderPath.glob("*.m4a"):
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
				os.chmod(playlist, stat.S_IWRITE)
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
			os.chmod(playlist, stat.S_IREAD)

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
		val = source.getRawProperty(tagName)
		if val:
			target.setRawProperty(tagName, val)

	@staticmethod
	def _renameTag(oldTagName: str, newTagName: str, target: MusicFileProperties):
		val = target.getRawProperty(oldTagName)
		if not val: return
		if target.getRawProperty(newTagName):
			LogHelper.Warning('for file = "{0}", cannot rename tag "{1}" to "{2}": new name already exists', target.FilePath.name, oldTagName, newTagName)
		target.setRawProperty(newTagName, val)
		target.deleteRawProperty(oldTagName)

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
	for f in folder.glob('*.m4a'):
		props = MusicFileProperties(f)
		results.append([f.name, props.AlbumTitle, props.TrackArtist, props.TrackTitle, props.Year])
		props = None
	for f in folder.glob('*.wma'):
		props = MusicFileProperties(f)
		results.append([f.name, props.AlbumTitle, props.TrackArtist, props.TrackTitle, props.Year])
		props = None
	print(tabulate(results, headers=headers, tablefmt=_defaultTableFormat))

def showFilePropertiesCommand(args : argparse.Namespace):
	LogHelper.Init()
	file = pathlib.Path(args.filePath)#.resolve()
	if not file.is_file():
		print(f'file "{args.filePath}" does not exist, is not a folder or could not be accessed')
		return
	props = MusicFileProperties(file)
	printData = []
	if args.raw:
		for p,v in (sorted(props.getRawProperties(), key=lambda p: p[0].upper()) if args.sort else props.getRawProperties()):
			# 'APIC' if MP3 (no idea why mutagen is putting ':' in there); 'Cover Art XXX' for APE; 'METADATA_BLOCK_PICTURE' for Vorbis; 'WM/Picture' is WMA;
			if p == Mp4TagNames.Cover or p == 'APIC:' or p.startswith('Cover Art') or p == 'METADATA_BLOCK_PICTURE' or p == 'WM/Picture':
				printData.append([p,'<binary (cover)>'])
			elif p == Mp4TagNames.Lyrics or p.startswith('USLT::') or p.upper() == 'LYRICS' or p.upper() == 'UNSYNCEDLYRICS' or p == 'WM/Lyrics':
				printData.append([p,'<lyrics>'])
			else:
				printData.append([p,v])
	else:
		for p,v in props.getProperties():
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
	setFolderCmd.add_argument("targetFolderPath")
	setFolderCmd.add_argument("sourceFolderPath")
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
