#!python3
# -*- coding: utf-8 -*-

import pathlib, csv
from typing import NamedTuple, Any
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

		def mapFromRawName(self, rawTagName: str) -> str:
			d = TagMapper._typedToTagNamesMap[self._getTagType()]
			u = rawTagName.upper()
			if u in d:
				return d[u]
			return ""

		def mapToRawName(self, tagName: str) -> list[str]:
			mapped = TagMapper._tagNamesToTypedMap[tagName] if tagName in TagMapper._tagNamesToTypedMap else None
			if mapped is None: return ""
			return self._getMappedTagProp(mapped)

		#region "abstract" methods
		def mapFromRawValue(self, rawValue: Any, tagName: str, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
			raise NotImplementedError()

		def _getTagType(self) -> str:
			raise NotImplementedError()

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			raise NotImplementedError()

		def _mapRawValue(self, rawValue: Any, tagName: str, rawTagName: str) -> list[str|int|bytes]:
			# we'll have already checked for lists, so incoming should just be a single value,
			# but some types (APE) store multi values in same tag object, so could be multiple outgoing
			raise NotImplementedError()
		#endregion

	class _mp4Mapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def mapFromRawValue(self, val: Any, tagName: str, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
			# we'll have already checked for lists, so incoming should just be a single value,
			# but some types (APE) store multi values in same tag object, so could be multiple outgoing
			if isinstance(val, mutagen.mp4.MP4FreeForm):
				if val.dataformat == mutagen.mp4.AtomDataType.INTEGER:
					# don't think we need to worry about parsing this: for standard tags,
					# mutagen just returns the simple value for you, for non-standard tags, they're always text
					pass
				else:
					if val.dataformat != mutagen.mp4.AtomDataType.UTF8:		# it looks like mutagen only ever supports utf-8, so ???
						raise NotImplementedError("MP4FreeForm contains unsupported data type: " + str(val.dataform))
					val = val.decode("utf-8")
			elif isinstance(val, mutagen.mp4.MP4Cover):
				val = bytes(val)
			return [val]

		def _getTagType(self) -> str:
			return TagMapper.MP4TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			return mappedTag.mp4

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

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			return mappedTag.vorbis

		# the vorbis tags are always just returned as strings (right?) so don't need to do this one (right?)
		#def _mapRawValue(self, rawValue: Any, tagName: str, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
		#	# we'll have already checked for lists, so incoming should just be a single value,
		#	# but some types (APE) store multi values in same tag object, so could be multiple outgoing
		#	raise NotImplementedError()

	class _asfMapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def mapFromRawValue(self, val: Any, tagName: str, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
			# we'll have already checked for lists, so incoming should just be a single value,
			# but some types (APE) store multi values in same tag object, so could be multiple outgoing
			# could be ASFUnicodeAttribute, ASFByteArrayAttribute, ASFBoolAttribute, ASFDWordAttribute, ASFQWordAttribute, ASFWordAttribute, ASFGUIDAttribute
			# but base class for all those is ASFBaseAttribute, we can just use its .value:
			if isinstance(val, mutagen.asf._attrs.ASFBaseAttribute):
				val = val.value
			return [val]

		def _getTagType(self) -> str:
			return TagMapper.AsfTagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			return mappedTag.asf

	class _apeV2Mapper(Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def mapFromRawValue(self, val: Any, tagName: str, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
			# we'll have already checked for lists, so incoming should just be a single value,
			# but some types (APE) store multi values in same tag object, so could be multiple outgoing
			result = []
			if isinstance(val, mutagen.apev2.APETextValue):
				# the value of APRTextValue types can contain multi values,
				# separated with null (b'\x00'), but it has an iterator:
				for v in val:
					result.append(v)
			elif isinstance(val, mutagen.apev2.APEBinaryValue):
				result.append(val.value)	# assume binary types are always single, since \x00 could be valid here ???
			return result

		def _getTagType(self) -> str:
			return TagMapper.ApeV2TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			return mappedTag.apev2

	class _id3Mapper(Mapper):	# abstract base class
		def __new__(cls):
			if cls.__name__ == "_id3Mapper":
				raise NotImplementedError("abstract class; use TagMapper.getTagMapper")
			return super().__new__(cls)

		def __init__(self):
			super().__init__()

		def mapFromRawValue(self, val: Any, tagName: str, rawTagName: str) -> list[str|int|bytes|list[str,str]]:
			# we'll have already checked for lists, so incoming should just be a single value,
			# but some types (APE) store multi values in same tag object, so could be multiple outgoing
			#
			# tags that will need special handling:
			# APIC (tag key tries to include description, which may or may not be there)
			# USLT/SYLT (tag key tries to include lang and description, which may or may not be there)
			# COMM (tag key tries to include lang and description, which may or may not be there)
			# track, disc, movement info
			# Producer, Engineer, Arranger, Mixer: may need to parse out of IPLS/TIPL, or they may be in separate tags
			# MusicianCredits: may be in IPLS(?) if id3v23, or in TMCL for id3v24; or could be in their own tag
			#
			result = []
			if isinstance(val, mutagen.id3.NumericPartTextFrame):	# TRCK, TPOS, MVIN; these will need special handling...
				# ?????
				for v in val:
					result.append(v)
			elif isinstance(val, mutagen.id3.NumericTextFrame):
				result.append(+val)
			elif isinstance(val, mutagen.id3.TextFrame):
				for v in val:
					result.append(v)
			elif isinstance(val, mutagen.id3.PairedTextFrame):	# TIPL, TMCL, IPLS
				for v in val.people:
					result.append(v)
			elif isinstance(val, mutagen.id3.USLT) or isinstance(val, mutagen.id3.SYLT):
				result.append(val.text)
			elif isinstance(val, mutagen.id3.UrlFrame):
				result.append(val.url)
			elif isinstance(val, mutagen.id3.BinaryFrame) or isinstance(val, mutagen.id3.APIC):
				result.append(val.data)
			elif isinstance(val, mutagen.id3.UFID):
				result.append(val.data.decode("ascii"))
			return result

	class _id3v24Mapper(_id3Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.Id3v24TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			return mappedTag.id3v24

	class _id3v23Mapper(_id3Mapper):
		_instance = None
		def __new__(cls):
			if cls._instance is None:
				cls._instance = super().__new__(cls)
			return cls._instance

		def __init__(self):
			super().__init__()

		def _getTagType(self) -> str:
			return TagMapper.Id3v23TagType

		def _getMappedTagProp(self, mappedTag: "TagMapper._mappedTags") -> list[str]:
			return mappedTag.id3v23
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
			if ver >= (2, 4, 0):
				return TagMapper._id3v24Mapper()
			if ver >= (2, 3, 0):
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
				mp4: list[str] = [x.replace("*:", Mp4TagNames.Mp4CustomPropertyPrefix) for x in TagMapper._splitTagName(row["MP4"])]
				vorbis: list[str] = TagMapper._splitTagName(row["Vorbis"])
				asf: list[str] = TagMapper._splitTagName(row["WMA"])
				id3v24: list[str] = TagMapper._splitTagName(row["ID3v24"])
				id3v23: list[str] = TagMapper._splitTagName(row["ID3v23"])
				ape: list[str] = TagMapper._splitTagName(row["APEv2"])

				TagMapper._tagNamesToTypedMap[tagName] = TagMapper._mappedTags(mp4=mp4, vorbis=vorbis, asf=asf, id3v24=id3v24, id3v23=id3v23, apev2=ape)

				TagMapper._addToTypedToTagNameDict(tagName, mp4, TagMapper.MP4TagType)
				TagMapper._addToTypedToTagNameDict(tagName, vorbis, TagMapper.VorbisTagType)
				TagMapper._addToTypedToTagNameDict(tagName, asf, TagMapper.AsfTagType)
				TagMapper._addToTypedToTagNameDict(tagName, id3v24, TagMapper.Id3v24TagType)
				TagMapper._addToTypedToTagNameDict(tagName, id3v23, TagMapper.Id3v23TagType)
				TagMapper._addToTypedToTagNameDict(tagName, ape, TagMapper.ApeV2TagType)

	@staticmethod
	def _splitTagName(tag: str) -> list[str]:
		return [x.strip() for x in tag.strip().split("|")] if tag else []

	@staticmethod
	def _addToTypedToTagNameDict(tagName: str, typedNames: list[str], tagType: str) -> list[str]:
		for t in typedNames:
			t = t.upper() if t else ""
			if t and t not in TagMapper._typedToTagNamesMap[tagType]:
				TagMapper._typedToTagNamesMap[tagType][t] = tagName
