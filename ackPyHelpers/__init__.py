"""
just some helper classes for my stuff
"""

__author__ = "AckWare"
__version__ = "1.0.0"

__all__ = ['LogHelper', 'GithubRelease', 'FileHelpers', 'RunProcessHelper', 'Version']

import sys

# The very first thing we do is give a useful error if someone is
# running this code under Python 2.
if sys.version_info.major < 3 or sys.version_info.minor < 9:
    raise ImportError('This module only supports v3.9 and up of python.')

from .loghelper import LogHelper
from .githubRelease import GithubRelease
from .fileHelpers import FileHelpers
from .runProcessHelper import RunProcessHelper
from .version import Version
