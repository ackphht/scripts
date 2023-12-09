"""
just some helper classes for my stuff
"""

__author__ = "AckWare"
__version__ = "1.0.0"

__all__ = ['LogHelper', 'GithubRelease', 'FileHelpers', 'RunProcessHelper', 'Version', 'DateTimeHelpers']

import sys

# The very first thing we do is give a useful error if someone is
# running this code under version of Python we don't want to support:
if sys.version_info < (3, 9):
    raise ImportError('This module only supports v3.9 and up of python.')

from .loghelper import LogHelper
from .githubRelease import GithubRelease
from .fileHelpers import FileHelpers
from .runProcessHelper import RunProcessHelper
from .version import Version
from .datetimeHelpers import DateTimeHelpers
