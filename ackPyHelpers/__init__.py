"""
just some helper classes for my stuff
"""

__author__ = "AckWare"
__version__ = "1.0.0"

__all__ = ['LogHelper', 'GithubRelease', 'FileHelpers', 'RunProcessHelper', 'Version', 'DateTimeHelpers', 'SqliteConnHelper', 'staticinit']

import sys

# The very first thing we do is give a useful error if someone is
# running this code under version of Python we don't want to support:
if sys.version_info < (3, 9):
	raise ImportError('This module only supports v3.9 and up of python.')

def staticinit(cls):
	"""
	a class decorator to call a static initializer method named '__static_init__', if the class defined one.

	NOTE: this gets called right away; there's no delayed initialization, waiting for the first usage of
	the class, like, e.g., .NET does it

	example:
	@staticinit
	class Foo:
		_someClassProp = None
		def __static_init__(cls):
			cls._someClassProp = 'FooFoo'
	"""
	if getattr(cls, "__static_init__", None):
		cls.__static_init__()
	return cls

from .loghelper import LogHelper
from .githubRelease import GithubRelease
from .fileHelpers import FileHelpers
from .runProcessHelper import RunProcessHelper
from .version import Version
from .datetimeHelpers import DateTimeHelpers
from .sqliteHelpers import SqliteConnHelper
