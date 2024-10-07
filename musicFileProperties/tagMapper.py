#!python3
# -*- coding: utf-8 -*-

import pathlib, csv
from typing import NamedTuple, Any
import mutagen, mutagen.mp4, mutagen.asf, mutagen.apev2, mutagen.id3			# https://mutagen.readthedocs.io/en/latest/api/mp4.html
from .tagNames import TagNames
from .tagTypes import TagType

class _constants:
	MP4TagType = "mp4"
	VorbisTagType = "vorbis"
	AsfTagType = "asf"
	Id3v24TagType = "id3v24"
	Id3v23TagType = "id3v23"
	ApeV2TagType = "apev2"

	Mp4CustomPropertyPrefix = "----:com.apple.iTunes:"

class _tagMap:
	class _mappedTags(NamedTuple):
		mp4: list[str]
		vorbis: list[str]
		asf: list[str]
		id3v24: list[str]
		id3v23: list[str]
		apev2: list[str]

	_csvFilepath = pathlib.Path(__file__).absolute().parent / "musicTagsMap.csv"
	_tagNamesToNativeNamesMap: dict[str, "_tagMap._mappedTags"] = None
	_nativeNamesToTagNamesMap: dict[str, dict[str, str]] = None

	def __new__(cls):
		raise NotImplementedError("static class; use _tagMapper.getTagMapper() factory method to get the mapper you're probably looking for")

	_isInited = False;
	@staticmethod
	def _init():
		if _tagMap._isInited: return
		_tagMap._loadTagNames()
		_tagMap._isInited = True

	@staticmethod
	def _loadTagNames() -> None:
		_tagMap._tagNamesToNativeNamesMap = dict()
		_tagMap._nativeNamesToTagNamesMap = {
			_constants.MP4TagType: dict(),
			_constants.VorbisTagType: dict(),
			_constants.AsfTagType: dict(),
			_constants.Id3v24TagType: dict(),
			_constants.Id3v23TagType: dict(),
			_constants.ApeV2TagType: dict(),
		}
		with open(_tagMap._csvFilepath, mode="r", encoding="utf_8_sig", newline='') as f:
			for row in csv.DictReader(f, dialect=csv.excel):
				tagName: str = row["MusicTagName"].strip() if row["MusicTagName"] else ""
				if not tagName or tagName.startswith("#"): continue
				mp4: list[str] = [x.replace("*:", _constants.Mp4CustomPropertyPrefix) for x in _tagMap._splitTagName(row["MP4"])]
				vorbis: list[str] = _tagMap._splitTagName(row["Vorbis"])
				asf: list[str] = _tagMap._splitTagName(row["WMA"])
				id3v24: list[str] = _tagMap._splitTagName(row["ID3v24"])
				id3v23: list[str] = _tagMap._splitTagName(row["ID3v23"])
				ape: list[str] = _tagMap._splitTagName(row["APEv2"])

				_tagMap._tagNamesToNativeNamesMap[tagName] = _tagMap._mappedTags(mp4=mp4, vorbis=vorbis, asf=asf, id3v24=id3v24, id3v23=id3v23, apev2=ape)

				_tagMap._addNativeNamesToTagNameDict(tagName, mp4, _constants.MP4TagType)
				_tagMap._addNativeNamesToTagNameDict(tagName, vorbis, _constants.VorbisTagType)
				_tagMap._addNativeNamesToTagNameDict(tagName, asf, _constants.AsfTagType)
				_tagMap._addNativeNamesToTagNameDict(tagName, id3v24, _constants.Id3v24TagType)
				_tagMap._addNativeNamesToTagNameDict(tagName, id3v23, _constants.Id3v23TagType)
				_tagMap._addNativeNamesToTagNameDict(tagName, ape, _constants.ApeV2TagType)

	@staticmethod
	def _splitTagName(tag: str) -> list[str]:
		tag = tag.partition("#")[0].strip()
		return [x.strip() for x in tag.split("|")] if tag else []

	@staticmethod
	def _addNativeNamesToTagNameDict(tagName: str, nativeNames: list[str], tagType: str) -> list[str]:
		for t in nativeNames:
			t = t.upper() if t else ""
			if t and t not in _tagMap._nativeNamesToTagNamesMap[tagType]:
				_tagMap._nativeNamesToTagNamesMap[tagType][t] = tagName

#region typed mapper classes
# these are sorta Singleton classes: can "new" up new ones, but they all return the same instance
# we could have a public class property Instance, like usual, but that still has to be inited somewhere
# but python doesn't really have static class initialization, so ???; this way seems ... okay, i think
class _tagMapper:	# abstract base class
	def __new__(cls):
		if cls.__name__ == "_tagMapper":
			raise NotImplementedError("abstract class; use _tagMapper.getTagMapper")
		return super().__new__(cls)

	def __init__(self):
		_tagMap._init()

	@staticmethod
	def getTagType(mgTags: mutagen.Tags) -> TagType:
		name = mgTags.__class__.__name__
		if name == "MP4Tags":
			return TagType.MP4
		if name == "VCFLACDict":
			return TagType.FLACVorbis
		if name == "OggOpusVComment" or name == "OggVCommentDict" or name == "OggFLACVComment" or name == "OggTheoraVComment" or name == "OggSpeexVComment":
			return TagType.OggVorbis
		if name == "ASFTags":
			return TagType.ASF
		if name == "APEv2":
			return TagType.APEv2
		if name == "ID3" or name == "_WaveID3":
			ver = mgTags.version
			if ver >= (2, 4, 0):
				return TagType.ID3v24
			if ver >= (2, 3, 0):
				return TagType.ID3v23
		raise TypeError(f'unrecognized mutagen tag type: "{mgTags.__class__.__module__}.{mgTags.__class__.__name__}"') #LookupError #NameError #TypeError

	@staticmethod
	def getTagMapper(mgTags: mutagen.Tags) -> "_tagMapper":
		name = _tagMapper.getTagType(mgTags)
		if name == TagType.MP4:
			return _mp4Mapper()
		if name == TagType.FLACVorbis or name == TagType.OggVorbis:
			return _vorbisMapper()
		if name == TagType.ASF:
			return _asfMapper()
		if name == TagType.APEv2:
			return _apeV2Mapper()
		if name == TagType.ID3v24:
			return _id3v24Mapper()
		if name == TagType.ID3v23:
			return _id3v23Mapper()

	def mapFromNativeName(self, nativeTagName: str) -> str:
		d = _tagMap._nativeNamesToTagNamesMap[self._getTagType()]
		u = nativeTagName.upper()
		if u in d:
			return d[u]
		return ""

	def mapToNativeName(self, tagName: str) -> list[str]:
		mapped = _tagMap._tagNamesToNativeNamesMap[tagName] if tagName in _tagMap._tagNamesToNativeNamesMap else None
		if mapped is None: return []
		return self._getMappedTagProp(mapped)

	def isSpecialHandlingTag(self, tagName: str) -> bool:
		return False

	def getSpecialHandlingTagValues(self, tagName: str, mgTags: mutagen.Tags) -> list[str|int|bytes|list[str,str]]:
		return []

	#region "abstract" methods
	def mapFromNativeValue(self, nativeValue: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes|list[str,str]]:
		raise NotImplementedError()

	def prepareValueForSet(self, nativeValue: Any, tagName: str, nativeTagName: str, mgTags: mutagen.Tags) -> list|Any|None:
		raise NotImplementedError()

	def _getTagType(self) -> str:
		raise NotImplementedError()

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
		raise NotImplementedError()

	def _mapNativeValue(self, nativeValue: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes]:
		# we'll have already checked for lists, so incoming should just be a single value,
		# but some types (APE) store multi values in same tag object, so could be multiple outgoing
		raise NotImplementedError()
	#endregion

	def _getWmaApePackedValueFirstPart(self, value: str|int) -> str|int|None:
		if isinstance(value, str) and len(value) > 0:
			v = self._getSplitPart(value, "/", 0)
			return v if len(v) > 0 else None
		elif isinstance(value, int):
			return value
		# no other types, right?
		return None

	def _getWmaApeMaybePackedValueSecondPart(self, maybeValue: str|int, fallbackCallable: callable) -> str|int|None:
		# try getting value from separate tag first:
		if isinstance(maybeValue, str) and len(maybeValue) > 0:
			maybeValue = maybeValue.strip()
			if len(maybeValue) > 0: return maybeValue
		elif isinstance(maybeValue, int):
			return maybeValue
		else:	# couldn't be some other type, right?
			# doesn't look like there's anything in maybeValue, see if it's packed in with fallback:
			fallback = fallbackCallable()
			if isinstance(fallback, str) and len(fallback) > 0:
				v = self._getSplitPart(fallback, "/", 1)
				if len(v) > 0: return v
			# for this one, don't care if it's an int, that would be the disc number
		return None

	def _getSplitPart(self, value: str, sep: str, index: int) -> str:
		if value is not None:
			split = value.partition(sep)
			return split[0].strip() if index == 0 else split[2].strip()
		return ""

class _mp4Mapper(_tagMapper):
	_specialTags: list[str] = [ TagNames.TrackNumber, TagNames.TrackCount, TagNames.DiscNumber, TagNames.DiscCount, ]

	_instance = None
	def __new__(cls):
		if cls._instance is None:
			cls._instance = super().__new__(cls)
		return cls._instance

	def __init__(self):
		super().__init__()

	def mapFromNativeValue(self, val: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes|list[str,str]]:
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

	def isSpecialHandlingTag(self, tagName: str) -> bool:
		return tagName in _mp4Mapper._specialTags

	def getSpecialHandlingTagValues(self, tagName: str, mgTags: mutagen.Tags) -> list[str|int|bytes|list[str,str]]:
		results = []
		# for track and disc: if no info at all, mg will not return anything;
		# otherwise it always returns a tuple, wrapped in a list;
		# if one total is missing, it will be 0 in the tuple; if number is missing, whole tag is left out
		if tagName == TagNames.TrackNumber or tagName == TagNames.TrackCount:
			mp4TagName = self._mapRequiredTagName(TagNames.TrackNumber)
			tag = mgTags[mp4TagName] if mp4TagName in mgTags else None
			if isinstance(tag, list) and len(tag) > 0:
				tag = tag[0]
				if tagName == TagNames.TrackNumber:
					if tag[0] > 0: results.append(tag[0])
				elif tagName == TagNames.TrackCount:
					if tag[1] > 0: results.append(tag[1])
		elif tagName == TagNames.DiscNumber or tagName == TagNames.DiscCount:
			mp4TagName = self._mapRequiredTagName(TagNames.DiscNumber)
			tag = mgTags[mp4TagName] if mp4TagName in mgTags else None
			if isinstance(tag, list) and len(tag) > 0:
				tag = tag[0]
				if tagName == TagNames.DiscNumber:
					if tag[0] > 0: results.append(tag[0])
				elif tagName == TagNames.DiscCount:
					if tag[1] > 0: results.append(tag[1])
		return results

	def prepareValueForSet(self, nativeValue: Any, tagName: str, nativeTagName: str, mgTags: mutagen.Tags) -> list|Any|None:
		# special case packed values:
		if tagName in [ TagNames.TrackNumber, TagNames.TrackCount, TagNames.DiscNumber, TagNames.DiscCount, ]:
			v = nativeValue
			if isinstance(v, list) and len(nativeValue) > 0: v = v[0]
			intVal = v if isinstance(v, int) else int(v) if v is not None else 0
			num = 0; ttl = 0;
			if tagName == TagNames.TrackNumber or tagName == TagNames.DiscNumber:
				num = intVal
				otherTagName = TagNames.TrackCount if tagName == TagNames.TrackNumber else TagNames.DiscCount
				otherVal = self.getSpecialHandlingTagValues(otherTagName, mgTags)
				ttl = otherVal[0] if isinstance(otherVal, list) and len(otherVal) > 0 else 0
			elif tagName == TagNames.TrackCount or tagName == TagNames.DiscCount:
				ttl = intVal
				otherTagName = TagNames.TrackNumber if tagName == TagNames.TrackCount else TagNames.DiscNumber
				otherVal = self.getSpecialHandlingTagValues(otherTagName, mgTags)
				num = otherVal[0] if isinstance(otherVal, list) and len(otherVal) > 0 else 0
			return [(num, ttl)] if num > 0 else None

		# for built-in tag names (the "FourCC" ones), mutagen will handle the mapping, so we don't have to wrap it:
		if not nativeTagName.startswith(_constants.Mp4CustomPropertyPrefix):
			if not isinstance(nativeValue, str) and not isinstance(nativeValue, list):
				return [nativeValue]		# but int's, others(?), have to be in a list or it blows up (???)
			return nativeValue
		# but for custom tags (the "----" ones), we have to create MP4FreeForm objects for mutagen to insert
		else:
			if isinstance(nativeValue, list):
				results = []
				for v in nativeValue:
					results.append(_mp4Mapper._wrapValue(v))
				return results
			return _mp4Mapper._wrapValue(nativeValue)

	def _getTagType(self) -> str:
		return _constants.MP4TagType

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
		return mappedTag.mp4

	def _mapRequiredTagName(self, tagName: str) -> str:
		n = self.mapToNativeName(tagName)
		if n is None or len(n) == 0:
			raise KeyError(f'no MP4 mapping found for tag "{tagName}"')
		return n[0]

	@staticmethod
	def _wrapValue(value: Any) -> mutagen.mp4.MP4FreeForm:
		if isinstance(value, mutagen.mp4.MP4FreeForm):
			return value	# already wrapped
		if not isinstance(value, str):
			value = str(value)	#custom Mp4 tags have to be strings (right ??)
		return mutagen.mp4.MP4FreeForm(value.encode("utf-8", errors="replace"), dataformat=mutagen.mp4.AtomDataType.UTF8)

#
# https://mutagen.readthedocs.io/en/latest/user/vcomment.html
#
class _vorbisMapper(_tagMapper):
	_specialTags: list[str] = [ TagNames.TrackCount, TagNames.DiscCount, ]

	_instance = None
	def __new__(cls):
		if cls._instance is None:
			cls._instance = super().__new__(cls)
		return cls._instance

	def __init__(self):
		super().__init__()

	def _getTagType(self) -> str:
		return _constants.VorbisTagType

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
		return mappedTag.vorbis

	# the vorbis tags are always just returned as strings (right?) so don't need to do this one (right?)
	#def _mapNativeValue(self, nativeValue: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes|list[str,str]]:
	#	# we'll have already checked for lists, so incoming should just be a single value,
	#	# but some types (APE) store multi values in same tag object, so could be multiple outgoing
	#	raise NotImplementedError()

	def isSpecialHandlingTag(self, tagName: str) -> bool:
		return tagName in _vorbisMapper._specialTags

	def getSpecialHandlingTagValues(self, tagName: str, mgTags: mutagen.Tags) -> list[str|int|bytes|list[str,str]]:
		# for TrackCount: Picard writes both TOTALTRACKS and TRACKTOTAL, Mp3tag just writes TOTALTRACKS
		# for DiscCount: Picard writes both TOTALDISCS and DISCTOTAL, Mp3tag just writes TOTALDISCS
		# we're just going to return first one we find
		# TODO: when we set or delete one of these, need to make sure we clean up tags we don't want (i.e. Picard's duped ones)
		if tagName in _vorbisMapper._specialTags:
			vorbisName = self.mapToNativeName(tagName)
			if vorbisName is not None:
				for t in vorbisName:
					v = mgTags[t] if t in mgTags else None
					if isinstance(v, list) and len(v) > 0:
						return v
		return []

	def prepareValueForSet(self, nativeValue: Any, tagName: str, nativeTagName: str, mgTags: mutagen.Tags) -> list|Any|None:
		# everything just needs to be a string
		if nativeValue is None or isinstance(nativeValue, str): return nativeValue
		if isinstance(nativeValue, list):
			return [v if isinstance(v, str) else str(v) for v in nativeValue]
		return str(nativeValue)

class _asfMapper(_tagMapper):
	# for WMA for Track info: Picard only ever writes track number and never writes total, while Mp3tag uses separate tags
	# for WMA for Disc info: Picard stores values together (e.g. "2/10")
	#     if either part is missing, whole tag gets left out 😲
	# while Mp3tag uses separate tags
	_specialTags: list[str] = [ TagNames.DiscNumber, TagNames.DiscCount, ]

	_instance = None
	def __new__(cls):
		if cls._instance is None:
			cls._instance = super().__new__(cls)
		return cls._instance

	def __init__(self):
		super().__init__()

	def mapFromNativeValue(self, val: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes|list[str,str]]:
		# we'll have already checked for lists, so incoming should just be a single value,
		# but some types (APE) store multi values in same tag object, so could be multiple outgoing
		# could be ASFUnicodeAttribute, ASFByteArrayAttribute, ASFBoolAttribute, ASFDWordAttribute, ASFQWordAttribute, ASFWordAttribute, ASFGUIDAttribute
		# but base class for all those is ASFBaseAttribute, we can just use its .value:
		if isinstance(val, mutagen.asf._attrs.ASFBaseAttribute):
			val = val.value
		return [val]

	def isSpecialHandlingTag(self, tagName: str) -> bool:
		return tagName in _asfMapper._specialTags

	def getSpecialHandlingTagValues(self, tagName: str, mgTags: mutagen.Tags) -> list[str|int|bytes|list[str,str]]:
		def _getWmaVal(tn: str) -> str:
			wmaTagName = self.mapToNativeName(tn)
			if wmaTagName is not None and len(wmaTagName) > 0:
				tag = mgTags[wmaTagName[0]] if wmaTagName[0] in mgTags else None
				if isinstance(tag, list) and len(tag) > 0 and isinstance(tag[0], mutagen.asf._attrs.ASFBaseAttribute):
					return tag[0].value
			return ""

		results = []
		if tagName == TagNames.DiscNumber:
			dnVal = self._getWmaApePackedValueFirstPart(_getWmaVal(TagNames.DiscNumber))
			if dnVal is not None: results.append(dnVal)
		elif tagName == TagNames.DiscCount:
			dcVal = self._getWmaApeMaybePackedValueSecondPart(_getWmaVal(TagNames.DiscCount), lambda: _getWmaVal(TagNames.DiscNumber))
			if dcVal is not None: results.append(dcVal)
		return results

	def prepareValueForSet(self, nativeValue: Any, tagName: str, nativeTagName: str, mgTags: mutagen.Tags) -> list|Any|None:
		# mutagen will actually write integer values as ASFDWordAttribute, which would be more correct,
		# but Mp3tag really only understands everything as string, so just do that:
		if nativeValue is None or isinstance(nativeValue, str): return nativeValue
		if isinstance(nativeValue, list):
			return [v if isinstance(v, str) else str(v) for v in nativeValue]
		return str(nativeValue)

	def _getTagType(self) -> str:
		return _constants.AsfTagType

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
		return mappedTag.asf

#
# https://mutagen.readthedocs.io/en/latest/user/apev2.html
#
class _apeV2Mapper(_tagMapper):
	# for Apev2: Picard stores Track and Disc info together (e.g. "2/10")
	#     if no Total, then you just get the Track/Disc Number; if Total but no Number, info doesn't get written at all
	# while Mp3tag uses separate tags
	_specialTags: list[str] = [ TagNames.TrackNumber, TagNames.TrackCount, TagNames.DiscNumber, TagNames.DiscCount, ]

	_instance = None
	def __new__(cls):
		if cls._instance is None:
			cls._instance = super().__new__(cls)
		return cls._instance

	def __init__(self):
		super().__init__()

	def mapFromNativeValue(self, val: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes|list[str,str]]:
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

	def isSpecialHandlingTag(self, tagName: str) -> bool:
		return tagName in _apeV2Mapper._specialTags

	def getSpecialHandlingTagValues(self, tagName: str, mgTags: mutagen.Tags) -> list[str|int|bytes|list[str,str]]:
		def _getApeVal(tn: str) -> str:
			apeTagName = self.mapToNativeName(tn)
			if apeTagName is not None and len(apeTagName) > 0:
				for t in apeTagName:
					tag = mgTags[t] if t in mgTags else None
					if isinstance(tag, mutagen.apev2.APETextValue):
						return tag.value	# we'll assume there's only one value in there ???
			return ""

		results = []
		if tagName == TagNames.TrackNumber:
			tnVal = self._getWmaApePackedValueFirstPart(_getApeVal(TagNames.TrackNumber))
			if tnVal is not None: results.append(tnVal)
		elif tagName == TagNames.TrackCount:
			tcVal = self._getWmaApeMaybePackedValueSecondPart(_getApeVal(TagNames.TrackCount), lambda: _getApeVal(TagNames.TrackNumber))
			if tcVal is not None: results.append(tcVal)
		elif tagName == TagNames.DiscNumber:
			dnVal = self._getWmaApePackedValueFirstPart(_getApeVal(TagNames.DiscNumber))
			if dnVal is not None: results.append(dnVal)
		elif tagName == TagNames.DiscCount:
			dcVal = self._getWmaApeMaybePackedValueSecondPart(_getApeVal(TagNames.DiscCount), lambda: _getApeVal(TagNames.DiscNumber))
			if dcVal is not None: results.append(dcVal)
		return results

	def prepareValueForSet(self, nativeValue: Any, tagName: str, nativeTagName: str, mgTags: mutagen.Tags) -> list|Any|None:
		# everything just needs to be a string
		if nativeValue is None or isinstance(nativeValue, str): return nativeValue
		if isinstance(nativeValue, list):
			return [v if isinstance(v, str) else str(v) for v in nativeValue]
		return str(nativeValue)

	def _getTagType(self) -> str:
		return _constants.ApeV2TagType

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
		return mappedTag.apev2

#
# https://mutagen.readthedocs.io/en/latest/user/id3.html
#
class _id3Mapper(_tagMapper):	# abstract base class
	_specialTags: list[str] = [ TagNames.Comment, TagNames.Lyrics, TagNames.TrackNumber, TagNames.TrackCount,
								TagNames.DiscNumber, TagNames.DiscCount, TagNames.MovementNumber, TagNames.MovementCount,
								TagNames.Producer, TagNames.Engineer, TagNames.MixedBy, TagNames.Arranger,
								TagNames.MusicianCredits, TagNames.Cover, ]

	def __new__(cls):
		if cls.__name__ == "_id3Mapper":
			raise NotImplementedError("abstract class; use _tagMapper.getTagMapper")
		return super().__new__(cls)

	def __init__(self):
		super().__init__()

	def mapFromNativeValue(self, val: Any, tagName: str, nativeTagName: str) -> list[str|int|bytes|list[str,str]]:
		# we'll have already checked for lists, so incoming should just be a single value,
		# but some types (APE) store multi values in same tag object, so could be multiple outgoing
		#
		# tags that will need special handling:
		# APIC (tag key tries to include description, which may or may not be there)
		# USLT/SYLT (tag key tries to include lang and description, which may or may not be there)
		# COMM (tag key tries to include lang and description, which may or may not be there)
		# track, disc, movement info
		# Producer, Engineer, Arranger, Mixer: may need to parse out of IPLS (v2.3)/TIPL (v2.4), or they may be in separate tags
		# MusicianCredits: may be in IPLS if id3v23, or in TMCL for id3v24; or could be in their own tag
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
		elif isinstance(val, mutagen.id3.APIC) or isinstance(val, mutagen.id3.BinaryFrame):
			result.append(val.data)
		elif isinstance(val, mutagen.id3.UFID):
			result.append(val.data.decode("ascii"))
		return result

	def isSpecialHandlingTag(self, tagName: str) -> bool:
		return tagName in _id3Mapper._specialTags

	def getSpecialHandlingTagValues(self, tagName: str, mgTags: mutagen.Tags) -> list[str|int|bytes|list[str,str]]:
		#
		# TODO: these need to actually get the values and return list[str|int|bytes|list[str,str]],
		# rather than "list[tuple[Any,str]]" like i originally did it
		#
		if tagName == TagNames.Comment:
			results = []
			for t in self.mapToNativeName(tagName):
				tags = sorted(_id3Mapper._findTagsStartingWith(t, mgTags), key=_id3Mapper._sortByLang)
				for tag in tags:
					results.append((tag, tag.HashKey))
			xxxxxxxx
			return results
		elif tagName == TagNames.Lyrics:
			results = []
			for t in self.mapToNativeName(tagName):
				if t in ["USLT", "SYLT"]:
					possibles = sorted(_id3Mapper._findTagsStartingWith(t, mgTags), key=_id3Mapper._sortByLang)
					for p in possibles:
						results.append((p, p.HashKey))
				else:
					tag = mgTags[t] if t in mgTags else None
					if tag is not None:
						results.append((tag, t))
			xxxxxxxx
			return results
		elif tagName == TagNames.TrackNumber or tagName == TagNames.TrackCount:
			results = []
			for t in self.mapToNativeName(TagNames.TrackNumber):
				tag = mgTags[t] if t in mgTags else None
				if tag is not None: results.append((tag, t))
				break
			if tagName == TagNames.TrackCount:
				for t in self.mapToNativeName(TagNames.TrackCount):
					tag = mgTags[t] if t in mgTags else None
					if tag is not None: results.append((tag, t))
					break
			xxxxxxxx
			return results
		elif tagName == TagNames.DiscNumber or tagName == TagNames.DiscCount:
			results = []
			for t in self.mapToNativeName(TagNames.DiscNumber):
				tag = mgTags[t] if t in mgTags else None
				if tag is not None: results.append((tag, t))
				break
			if tagName == TagNames.DiscCount:
				for t in self.mapToNativeName(TagNames.DiscCount):
					tag = mgTags[t] if t in mgTags else None
					if tag is not None: results.append((tag, t))
					break
			xxxxxxxx
			return results
		elif tagName == TagNames.MovementNumber or tagName == TagNames.MovementCount:
			results = []
			for t in self.mapToNativeName(TagNames.MovementNumber):
				tag = mgTags[t] if t in mgTags else None
				if tag is not None: results.append((tag, t))
				break
			if tagName == TagNames.MovementCount:
				for t in self.mapToNativeName(TagNames.MovementCount):
					tag = mgTags[t] if t in mgTags else None
					if tag is not None: results.append((tag, t))
					break
			xxxxxxxx
			return results
		elif tagName == TagNames.Producer:
			# need to check in IPLS or TIPL, and also look for TXXX:PRODUCER
			pass
		elif tagName == TagNames.Engineer:
			# need to check in IPLS or TIPL, and also look for TXXX:ENGINEER
			pass
		elif tagName == TagNames.MixedBy:
			# need to check in IPLS or TIPL, and also look for TXXX:MIXER(?)
			pass
		elif tagName == TagNames.Arranger:
			# need to check in IPLS or TIPL, and also look for TXXX:ARRANGER
			pass
		elif tagName == TagNames.MusicianCredits:
			# need to check in IPLS, filtering out any of the ones above, or in TMCL; and also look for TXXX:MUSICIANCREDITS
			pass
		elif tagName == TagNames.Cover:
			possibles = sorted(_id3Mapper._findTagsStartingWith("APIC", mgTags), key=lambda c: 1 if c.type == mutagen.id3._specs.PictureType.COVER_FRONT else 2)
			if len(possibles) > 0:
				xxxxxxxx
				return [(possibles[0], possibles[0].HashKey)]
		return None

	@staticmethod
	def _findTagsStartingWith(tagPrefix: str, mgTags: mutagen.id3.ID3) -> list[mutagen.id3.Frame]:
		results: list[mutagen.id3.Frame] = []
		for t in mgTags:
			if t.startswith(tagPrefix):
				results.append(mgTags[t])
		return results

	@staticmethod
	def _sortByLang(tagWithLang: mutagen.id3.TextFrame) -> int:
		if tagWithLang.lang == "eng": return 1
		if tagWithLang.lang == "XXX": return 2
		return 3

class _id3v24Mapper(_id3Mapper):
	_instance = None
	def __new__(cls):
		if cls._instance is None:
			cls._instance = super().__new__(cls)
		return cls._instance

	def __init__(self):
		super().__init__()

	def _getTagType(self) -> str:
		return _constants.Id3v24TagType

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
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
		return _constants.Id3v23TagType

	def _getMappedTagProp(self, mappedTag: "_tagMap._mappedTags") -> list[str]:
		return mappedTag.id3v23
#endregion
