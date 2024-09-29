"""
just some helper classes for my music files
"""

__author__ = "AckWare"
__version__ = "1.0.0"

__all__ = [ 'MusicFileProperties', 'TagNames', 'TagMapper', 'Mp4TagNames', ]

import sys

# The very first thing we do is give a useful error if someone is
# running this code under version of Python we don't want to support:
if sys.version_info < (3, 9):
	raise ImportError('This module only supports v3.9 and up of python.')

from .musicFileProperties import MusicFileProperties
from .tagMapper import TagMapper
from .tagNames import TagNames
from .mp4TagNames import Mp4TagNames