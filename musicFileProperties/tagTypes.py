#!python3
# -*- coding: utf-8 -*-

from enum import StrEnum

class TagType(StrEnum):
	MP4 = "MP4"
	FLACVorbis = "FLACVorbis"
	OggVorbis = "OggVorbis"
	ASF = "ASF"
	APEv2 = "APEv2"
	ID3v24 = "ID3v24"
	ID3v23 = "ID3v23"
