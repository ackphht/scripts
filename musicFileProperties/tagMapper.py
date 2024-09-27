#!python3
# -*- coding: utf-8 -*-

import pathlib, csv
from typing import NamedTuple
import mutagen					# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from .mp4TagNames import Mp4TagNames

class TagMapper:
	class _mappedTags(NamedTuple):
		mp4: list[str]
		vorbis: list[str]
		asf: list[str]
		id3v24: list[str]
		id3v23: list[str]
		apev2: list[str]

	_csvFilepath = pathlib.Path(__file__).absolute().parent / "musicTagsMap.csv"
	_tagNamesToTypedMap: dict[str, "TagMapper._mappedTags"] = None
	_typedToTagNamesMap: dict[str, dict[str, str]] = None

	MP4TagType = "mp4"
	VorbisTagType = "vorbis"
	AsfTagType = "asf"
	Id3v24TagType = "id3v24"
	Id3v23TagType = "id3v23"
	ApeV2TagType = "apev2"

	#region typed mapper classes
	# these are sorta Singleton classes: can "new" up new ones, but they all return the same instance
	# we could have a public class property Instance, like usual, but that still has to be inited somewhere
	# but python doesn't really have static class initialization, so ???; this way seems ... okay, i think
	class Mapper:	# abstract base class
		def __new__(cls):
			if cls.__name__ == "Mapper":
				raise NotImplementedError("abstract class; use TagMapper.getTagMapper")
			return super().__new__(cls)

		def __init__(self):
			TagMapper._init()

		def mapTypedNameToTagName(self, typedName: str) -> str:
			d = TagMapper._typedToTagNamesMap[self._getTagType()]
			u = typedName.upper()
			if u in d:
				return d[u]
			return ""

		def mapTagNameToTypedName(self, tagName: str) -> str:
			mapped = TagMapper._tagNamesToTypedMap[tagName] if tagName in TagMapper._tagNamesToTypedMap else None
			if mapped is None: return ""
			return self._getMappedTagProp(mapped)

		def _getTagType(self) -> str:
			raise NotImplementedError()

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			raise NotImplementedError()

	class _mp4Mapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.MP4TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			return mappedTag.mp4[0] if len(mappedTag.mp4) > 0 else ""

	class _vorbisMapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.VorbisTagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			return mappedTag.vorbis[0] if len(mappedTag.vorbis) > 0 else ""

	class _asfMapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.AsfTagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			return mappedTag.asf[0] if len(mappedTag.asf) > 0 else ""

	class _apeV2Mapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.ApeV2TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			return mappedTag.apev2[0] if len(mappedTag.apev2) > 0 else ""

	class _id3v24Mapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.Id3v24TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			return mappedTag.id3v24[0] if len(mappedTag.id3v24) > 0 else ""

	class _id3v23Mapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.Id3v23TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> str:
			return mappedTag.id3v23[0] if len(mappedTag.id3v23) > 0 else ""
	#endregion

	def __new__(cls):
		raise NotImplementedError("static class; use TagMapper.getTagMapper() factory method")

	_isInited = False;
	@staticmethod
	def _init():
		if TagMapper._isInited: return
		TagMapper._loadTagNames()
		TagMapper._isInited = True

	@staticmethod
	def getTagMapper(mgTags:  mutagen.Tags) -> "TagMapper.Mapper":
		name = mgTags.__class__.__name__
		if name == "MP4Tags":
			return TagMapper._mp4Mapper()
		if name == "VCFLACDict" or name == "OggOpusVComment" or name == "OggVCommentDict":
			return TagMapper._vorbisMapper()
		if name == "ASFTags":
			return TagMapper._asfMapper()
		if name == "APEv2":
			return TagMapper._apeV2Mapper()
		if name == "ID3" or name == "_WaveID3":
			ver = mgTags.version
			if ver > (2, 4, 0):
				return TagMapper._id3v24Mapper()
			if ver > (2, 3, 0):
				return TagMapper._id3v23Mapper()
		raise TypeError(f'unrecognized mutagen tag type: "{mgTags.__class__.__module__}.{mgTags.__class__.__name__}"') #LookupError #NameError #TypeError

	@staticmethod
	def _loadTagNames() -> None:
		TagMapper._tagNamesToTypedMap = dict()
		TagMapper._typedToTagNamesMap = {
			TagMapper.MP4TagType: dict(),
			TagMapper.VorbisTagType: dict(),
			TagMapper.AsfTagType: dict(),
			TagMapper.Id3v24TagType: dict(),
			TagMapper.Id3v23TagType: dict(),
			TagMapper.ApeV2TagType: dict(),
		}
		with open(TagMapper._csvFilepath, mode="r", encoding="utf_8_sig", newline='') as f:
			for row in csv.DictReader(f, dialect=csv.excel):
				tagName: str = row["MusicTagName"].strip() if row["MusicTagName"] else ""
				if not tagName or tagName.startswith("#"): continue
				mp4: list[str] = [x.replace("*", Mp4TagNames.Mp4CustomPropertyPrefix) for x in TagMapper._splitTagName(row["MP4"])]
				vorbis: list[str] = TagMapper._splitTagName(row["Vorbis"])
				asf: list[str] = TagMapper._splitTagName(row["WMA"])
				id3v24: list[str] = TagMapper._splitTagName(row["ID3v24"])
				id3v23: list[str] = TagMapper._splitTagName(row["ID3v23"])
				ape: list[str] = TagMapper._splitTagName(row["APEv2"])

				TagMapper._tagNamesToTypedMap[tagName] = TagMapper._mappedTags(mp4=mp4, vorbis=vorbis, id3v24=id3v24, id3v23=id3v23, apev2=ape)

				for t in mp4:
					t = t.upper() if t else ""
					if t and t not in TagMapper._typedToTagNamesMap[TagMapper.MP4TagType]:
						TagMapper._typedToTagNamesMap[TagMapper.MP4TagType][t] = tagName
				for t in vorbis:
					t = t.upper() if t else ""
					if t and t not in TagMapper._typedToTagNamesMap[TagMapper.VorbisTagType]:
						TagMapper._typedToTagNamesMap[TagMapper.VorbisTagType][t] = tagName
				for t in asf:
					t = t.upper() if t else ""
					if t and t not in TagMapper._typedToTagNamesMap[TagMapper.AsfTagType]:
						TagMapper._typedToTagNamesMap[TagMapper.AsfTagType][t] = tagName
				for t in id3v24:
					t = t.upper() if t else ""
					if t and t not in TagMapper._typedToTagNamesMap[TagMapper.Id3v24TagType]:
						TagMapper._typedToTagNamesMap[TagMapper.Id3v24TagType][t] = tagName
				for t in id3v23:
					t = t.upper() if t else ""
					if t and t not in TagMapper._typedToTagNamesMap[TagMapper.Id3v23TagType]:
						TagMapper._typedToTagNamesMap[TagMapper.Id3v23TagType][t] = tagName
				for t in ape:
					t = t.upper() if t else ""
					if t and t not in TagMapper._typedToTagNamesMap[TagMapper.ApeV2TagType]:
						TagMapper._typedToTagNamesMap[TagMapper.ApeV2TagType][t] = tagName

	@staticmethod
	def _splitTagName(tag: str) -> list[str]:
		return [x.strip() for x in tag.strip().split("|")] if tag else []
