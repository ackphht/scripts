#!python3
# -*- coding: utf-8 -*-

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
	Writer = "----:com.apple.iTunes:WRITER"
	Producer = "----:com.apple.iTunes:PRODUCER"
	Engineer = "----:com.apple.iTunes:ENGINEER"
	Mixer = "----:com.apple.iTunes:MIXER"
	ReMixer = "----:com.apple.iTunes:MIXARTIST"
	Arranger = "----:com.apple.iTunes:ARRANGER"
	Publisher = "----:com.apple.iTunes:PUBLISHER"
	Lyricist = "----:com.apple.iTunes:LYRICIST"
	OriginalAlbum = "----:com.apple.iTunes:ORIGALBUM"
	OriginalArtist = "----:com.apple.iTunes:ORIGARTIST"
	OriginalYear = "----:com.apple.iTunes:ORIGYEAR"
	Codec = "----:com.apple.iTunes:cdec"
	iTunSMPB = "----:com.apple.iTunes:iTunSMPB"
	Isrc = "----:com.apple.iTunes:ISRC"		# "International Standard Recording Code"; https://musicbrainz.org/doc/ISRC
	EncodedBy = "----:com.apple.iTunes:encoded by"
	ReplayGainTrackGain = "----:com.apple.iTunes:replaygain_track_gain"
	ReplayGainTrackPeak = "----:com.apple.iTunes:replaygain_track_peak"
	ReplayGainAlbumGain = "----:com.apple.iTunes:replaygain_album_gain"
	ReplayGainAlbumPeak = "----:com.apple.iTunes:replaygain_album_peak"
	Source = "----:com.apple.iTunes:Source"
	RippingTool = "----:com.apple.iTunes:Ripping tool"
	RipDate = "----:com.apple.iTunes:Rip date"
	RelaseType = "----:com.apple.iTunes:Release type"
	Language = "----:com.apple.iTunes:LANGUAGE"
	Script = "----:com.apple.iTunes:SCRIPT"
	EncodingSettings = "----:com.apple.iTunes:encoding settings"
	# https://picard-docs.musicbrainz.org/en/appendices/tag_mapping.html
	# https://picard-docs.musicbrainz.org/en/variables/variables.html
	# https://musicbrainz.org/doc/MusicBrainz_Database
	MusicBrainzDiscId = "----:com.apple.iTunes:MusicBrainz Disc Id"
	MusicBrainzAlbumId = "----:com.apple.iTunes:MusicBrainz Album Id"
	MusicBrainzArtistId = "----:com.apple.iTunes:MusicBrainz Artist Id"
	MusicBrainzAlbumArtistId = "----:com.apple.iTunes:MusicBrainz Album Artist Id"
	MusicBrainzTrackId = "----:com.apple.iTunes:MusicBrainz Release Track Id"		# https://musicbrainz.org/doc/Recording - a "recording" is higher level than a track, at least one track per recording
	MusicBrainzRecordingId = "----:com.apple.iTunes:MusicBrainz Track Id"			# but Mp3tag uses this one ?? i'm confused on which of these tags is which
	MusicBrainzReleaseCountry = "----:com.apple.iTunes:MusicBrainz Album Release Country"
	MusicBrainzReleaseGroupId = "----:com.apple.iTunes:MusicBrainz Release Group Id"
	MusicBrainzReleaseType = "----:com.apple.iTunes:MusicBrainz Album Type"
	MusicBrainzReleaseStatus = "----:com.apple.iTunes:MusicBrainz Album Status"
	MusicBrainzWorkId = "----:com.apple.iTunes:MusicBrainz Work Id"
	WorkTitle = "©wrk"
	Mp3tagMediaType = "----:com.apple.iTunes:MEDIATYPE"
	MusicBrainzMediaType = "----:com.apple.iTunes:MEDIA"
	MusicBrainzMediaArtists = "----:com.apple.iTunes:ARTISTS"
	AcoustId = "----:com.apple.iTunes:Acoustid Id"
	Upc = "----:com.apple.iTunes:UPC"				# or BARCODE ??
	Barcode = "----:com.apple.iTunes:BARCODE"		# for CD rips
	CatalogNumber = "----:com.apple.iTunes:CATALOGNUMBER"
	Asin = "----:com.apple.iTunes:ASIN"				# for digital ones i bought from Amazon
	Rating = "----:com.apple.iTunes:RATING"
	Label = "----:com.apple.iTunes:LABEL"
	MusicianCredits = "----:com.apple.iTunes:MUSICIANCREDITS"
	InvolvedPeople = "----:com.apple.iTunes:INVOLVEDPEOPLE"
	DigitalPurchaseFrom = "----:com.apple.iTunes:DIGITALPURCHASEFROM"		# these are my own tags, so pascal case would be nice, but mp3tag uppercases everything; sigh
	DigitalPurchaseDate = "----:com.apple.iTunes:DIGITALPURCHASEDATE"
	DigitalPurchaseId = "----:com.apple.iTunes:DIGITALPURCHASEID"
	Recorded = "----:com.apple.iTunes:RECORDED"
	Released = "----:com.apple.iTunes:RELEASED"
	AllMusicArtistId = "----:com.apple.iTunes:ARTIST_ALLMUSIC_ID"
	AllMusicAlbumId = "----:com.apple.iTunes:ALBUM_ALLMUSIC_ID"
	WikidataArtistId = "----:com.apple.iTunes:ARTIST_WIKIDATA_ID"
	WikidataAlbumId = "----:com.apple.iTunes:ALBUM_WIKIDATA_ID"
	WikipediaArtistId = "----:com.apple.iTunes:ARTIST_WIKIPEDIA_ID"
	WikipediaAlbumId = "----:com.apple.iTunes:ALBUM_WIKIPEDIA_ID"
	ImdbArtistId = "----:com.apple.iTunes:ARTIST_IMDB_ID"
	# foobar2000 just blindly copies properties when it converts files, so if, e.g., we got from FLAC to M4A, we get FLAC property names:
	MusicBrainzOriginalYearFromConvert = "----:com.apple.iTunes:ORIGINALYEAR"
	MusicBrainzOriginalDateFromConvert = "----:com.apple.iTunes:ORIGINALDATE"
	MusicBrainzWorkIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_WORKID"
	MusicBrainzRecordingIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_TRACKID"
	MusicBrainzTrackIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_RELEASETRACKID"
	MusicBrainzReleaseGroupIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_RELEASEGROUPID"
	MusicBrainzDiscIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_DISCID"
	MusicBrainzArtistIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_ARTISTID"
	MusicBrainzAlbumIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_ALBUMID"
	MusicBrainzAlbumArtistIdFromConvert = "----:com.apple.iTunes:MUSICBRAINZ_ALBUMARTISTID"
	MusicBrainzPerformerFromConvert = "----:com.apple.iTunes:PERFORMER"
	MusicBrainzMediaReleaseTypeFromConvert = "----:com.apple.iTunes:RELEASETYPE"
	MusicBrainzReleaseStatusFromConvert = "----:com.apple.iTunes:RELEASESTATUS"
	MusicBrainzReleaseCountryFromConvert = "----:com.apple.iTunes:RELEASECOUNTRY"