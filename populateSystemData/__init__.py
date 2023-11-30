"""
Some helper stuff for getting system info
"""

__author__ = "AckWare"
__version__ = "1.0.0"

__all__ = ['OSDetails']

import sys

# The very first thing we do is give a useful error if someone is
# running this code under an older version of Python:
if sys.version_info < (3, 7):
	raise ImportError('This module only supports v3.7 and up of python.')

from .populateSystemData import OSDetails
