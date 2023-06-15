#!python3
# -*- coding: utf-8 -*-
import sys
if sys.platform == "win32":
	import ctypes
	from ctypes import wintypes, byref, POINTER

class LogHelper:
	# these are ripped off from colorama module (https://pypi.org/project/colorama/) so i don't have to have an external dependency for something so simple
	class AnsiFore():
		Black = "\033[30m"
		Red = "\033[31m"
		Green = "\033[32m"
		Yellow = "\033[33m"
		Blue = "\033[34m"
		Magenta = "\033[35m"
		Cyan = "\033[36m"
		White = "\033[37m"
		Reset = "\033[39m"
		# These are fairly well supported, but not part of the standard.
		LightBlackEx = "\033[90m"
		LightRedEx = "\033[91m"
		LightGreenEx = "\033[92m"
		LightYellowEx = "\033[93m"
		LightBlueEx = "\033[94m"
		LightMagentaEx = "\033[95m"
		LightCyanEx = "\033[96m"
		LightWhiteEx = "\033[97m"

	class AnsiBack():
		Black = "\033[40m"
		Red = "\033[41m"
		Green = "\033[42m"
		Yellow = "\033[43m"
		Blue = "\033[44m"
		Magenta = "\033[45m"
		Cyan = "\033[46m"
		White = "\033[47m"
		Reset = "\033[49m"
		# These are fairly well supported, but not part of the standard.
		LightBlackEx = "\033[100m"
		LightRedEx = "\033[101m"
		LightGreenEx = "\033[102m"
		LightYellowEx = "\033[103m"
		LightBlueEx = "\033[104m"
		LightMagentaEx = "\033[105m"
		LightCyanEx = "\033[106m"
		LightWhiteEx = "\033[107m"

	class AnsiStyle():
		Bright = "\033[1m"
		Dim = "\033[2m"
		Normal = "\033[22m"
		ResetAll = "\033[0m"

	class NoAnsiFore:
		Black = Red = Green = Yellow = Blue = Magenta = Cyan = Whute = Reset = \
			LightBlackEx = LightRedEx = LightGreenEx = LightYellowEx = LightBlueEx = \
			LightMagentaEx = LightCyanEx = LightWhiteEx = ""

	class NoAnsiBack:
		Black = Red = Green = Yellow = Blue = Magenta = Cyan = Whute = Reset = \
			LightBlackEx = LightRedEx = LightGreenEx = LightYellowEx = LightBlueEx = \
			LightMagentaEx = LightCyanEx = LightWhiteEx = ""

	class NoAnsiStyle:
		Bright = Dim = Normal = ResetAll = ""

	Fore   = AnsiFore()
	Back   = AnsiBack()
	Style  = AnsiStyle()
	_verboseEnabled = False

	@staticmethod
	def Init(verbose : bool = False):
		LogHelper._verboseEnabled = verbose
		if not LogHelper._isAnsiSupported():
			# if ansi escapes not supported:
			# TODO: this isn't the right way; need to see what colorama is doing...
			LogHelper.Fore = LogHelper.NoAnsiFore()
			LogHelper.Back = LogHelper.NoAnsiBack()
			LogHelper.Style = LogHelper.NoAnsiStyle()

	@staticmethod
	def Log(message : str):
		"""prints a message to the console in light gray"""
		print(f"{LogHelper.Style.Dim}{LogHelper.Fore.White}{message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Verbose(message : str):
		"""if verbose logging is enbled, prints a VERBOSE message to the console in yellow"""
		if LogHelper._verboseEnabled:
			print(f"{LogHelper.Style.Normal}{LogHelper.Fore.Yellow}VERBOSE: {message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Warning(message : str):
		"""prints a WARNING message to the console in bright yellow"""
		print(f"{LogHelper.Style.Bright}{LogHelper.Fore.LightYellowEx}WARNING: {message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Warning2(message : str):
		"""prints a WARNING message to the console in bright red; for more serious warnings (like, an error but not an error-error :|)"""
		print(f"{LogHelper.Style.Bright}{LogHelper.Fore.LightRedEx}WARNING: {message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Error(message : str):
		"""prints an ERROR message to the console in red"""
		print(f"{LogHelper.Style.Bright}{LogHelper.Fore.Red}ERROR: {message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Message(message : str):
		"""prints a regular message to the console in cyan"""
		print(f"{LogHelper.Style.Normal}{LogHelper.Fore.Cyan}{message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Message2(message : str):
		"""prints a regular message to the console in magenta, like maybe for headers"""
		print(f"{LogHelper.Style.Normal}{LogHelper.Fore.Magenta}{message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def Message3(message : str):
		"""prints a regular message to the console in yellow"""
		print(f"{LogHelper.Style.Normal}{LogHelper.Fore.Yellow}{message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def WhatIf(message : str):
		"""prints a test mode type message to the console, prefixed with 'WhatIf: ', in  white"""
		print(f"{LogHelper.Style.Normal}{LogHelper.Fore.White}WhatIf: {message}{LogHelper.Style.ResetAll}")

	@staticmethod
	def _isAnsiSupported() -> bool:
		if sys.platform != "win32": return True	# assume yes
		# newer windows consoles and the Terminal app should support it, but check:
		getStdHandle = ctypes.windll.kernel32.GetStdHandle
		getStdHandle.restype = wintypes.HANDLE
		getStdHandle.argtypes = [ wintypes.DWORD, ]
		getConsoleMode = ctypes.windll.kernel32.GetConsoleMode
		getConsoleMode.restype = wintypes.BOOL
		getConsoleMode.argtypes = [ wintypes.HANDLE, POINTER(wintypes.DWORD) ]
		setConsoleMode = ctypes.windll.kernel32.SetConsoleMode
		setConsoleMode.argtypes = [ wintypes.HANDLE, wintypes.DWORD ]
		setConsoleMode.restype = wintypes.BOOL
		h = getStdHandle(-11)	# STDOUT
		mode = wintypes.DWORD()
		getConsoleMode(h, byref(mode))
		if not mode.value & 0x0004:		# ENABLE_VIRTUAL_TERMINAL_PROCESSING
			# if not already turned on, try turning it on and see if it sticks:
			setConsoleMode(h, mode.value | 0x0004)
			getConsoleMode(h, byref(mode))
		return bool(mode.value & 0x0004)
