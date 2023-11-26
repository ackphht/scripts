#!python3
# -*- coding: utf-8 -*-

import sys
if sys.platform == "win32":
	import ctypes
	from ctypes import wintypes, byref, POINTER

class LogHelper:
	"""
	helper class with some logging helpers. these started out ripped off from the colorama module (https://pypi.org/project/colorama/)
	so i don't have to have an external dependency for something so simple, but have since been
	'enhanced' a bit with my own stuff

	for each method, the message can be a string (including formatted string literals), or can be
	a str.format() style string with arguments passed in posargs and/or kwargs. Additionally, if
	the values of posargs and kwargs are callable objects (like a lambda), they will be called and
	the returned value used for the formatting. This allows for delayed evaluation, e.g. for the
	Verbose() method, if verbose logging is not enabled, the callable will not be invoked.
	"""
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
		Black = Red = Green = Yellow = Blue = Magenta = Cyan = White = Reset = \
			LightBlackEx = LightRedEx = LightGreenEx = LightYellowEx = LightBlueEx = \
			LightMagentaEx = LightCyanEx = LightWhiteEx = ""

	class NoAnsiBack:
		Black = Red = Green = Yellow = Blue = Magenta = Cyan = White = Reset = \
			LightBlackEx = LightRedEx = LightGreenEx = LightYellowEx = LightBlueEx = \
			LightMagentaEx = LightCyanEx = LightWhiteEx = ""

	class NoAnsiStyle:
		Bright = Dim = Normal = ResetAll = ""

	Fore   = AnsiFore()
	Back   = AnsiBack()
	Style  = AnsiStyle()
	_verboseEnabled = False

	@staticmethod
	def Init(verbose : bool = False) -> None:
		LogHelper._verboseEnabled = verbose
		if not LogHelper._isAnsiSupported():
			# if ansi escapes not supported:
			# TODO: this isn't the right way; need to see what colorama is doing...
			LogHelper.Fore = LogHelper.NoAnsiFore()
			LogHelper.Back = LogHelper.NoAnsiBack()
			LogHelper.Style = LogHelper.NoAnsiStyle()

	@staticmethod
	def Log(message : str, /, *posargs, **kwargs) -> None:
		"""prints a message to the console in light gray"""
		LogHelper._writeMessage(message, LogHelper.Style.Dim, LogHelper.Fore.White, "", *posargs, **kwargs)

	@staticmethod
	def Verbose(message : str, /, *posargs, **kwargs) -> None:
		"""if verbose logging is enbled, prints a VERBOSE message to the console in yellow"""
		if not LogHelper._verboseEnabled:
			return
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.Yellow, "VERBOSE", *posargs, **kwargs)

	@staticmethod
	def Info(message : str, /, *posargs, **kwargs) -> None:
		"""prints an INFO-level message to the console"""
		LogHelper.MessageWhite(message, *posargs, **kwargs)

	@staticmethod
	def Warning(message : str, /, *posargs, **kwargs) -> None:
		"""prints a WARNING message to the console in bright yellow"""
		LogHelper._writeMessage(message, LogHelper.Style.Bright, LogHelper.Fore.LightYellowEx, "WARNING", *posargs, **kwargs)

	@staticmethod
	def Warning2(message : str, /, *posargs, **kwargs) -> None:
		"""prints a WARNING message to the console in bright red; for more serious warnings (like, an error but not an error-error :|)"""
		LogHelper._writeMessage(message, LogHelper.Style.Bright, LogHelper.Fore.LightRedEx, "WARNING", *posargs, **kwargs)

	@staticmethod
	def Error(message : str, /, *posargs, **kwargs) -> None:
		"""prints an ERROR message to the console in red"""
		LogHelper._writeMessage(message, LogHelper.Style.Bright, LogHelper.Fore.Red, "ERROR", *posargs, **kwargs)

	@staticmethod
	def Message(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in cyan"""
		LogHelper.MessageCyan(message, *posargs, **kwargs)

	@staticmethod
	def Message2(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in magenta, like maybe for headers [OBSOLETE; use MessageMagenta()]"""
		LogHelper.MessageMagenta(message, *posargs, **kwargs)

	@staticmethod
	def Message3(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in yellow [OBSOLETE; use MessageYellow()]"""
		LogHelper.MessageYellow(message, *posargs, **kwargs)

	@staticmethod
	def MessageCyan(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in cyan"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.Cyan, "", *posargs, **kwargs)

	@staticmethod
	def MessageMagenta(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in magenta, like maybe for headers"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.Magenta, "", *posargs, **kwargs)

	@staticmethod
	def MessageYellow(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in yellow"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.Yellow, "", *posargs, **kwargs)

	@staticmethod
	def MessageGreen(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in green"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.Green, "", *posargs, **kwargs)

	@staticmethod
	def MessageGray(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in gray"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.LightBlackEx, "", *posargs, **kwargs)

	@staticmethod
	def MessageWhite(message : str, /, *posargs, **kwargs) -> None:
		"""prints a regular message to the console in white"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.White, "", *posargs, **kwargs)

	@staticmethod
	def WhatIf(message : str, /, *posargs, **kwargs) -> None:
		"""prints a test mode type message to the console, prefixed with 'WhatIf: ', in  white"""
		LogHelper._writeMessage(message, LogHelper.Style.Normal, LogHelper.Fore.White, "WhatIf", *posargs, **kwargs)

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

	@staticmethod
	def _writeMessage(message : str, style : str, color : str, prefix : str, /, *posargs, **kwargs) -> None:
		newPosArgs = [] if posargs else posargs
		for a in posargs:
			newPosArgs.append(a() if callable(a) else a)
		newKwArgs = {} if kwargs else kwargs
		for k in kwargs:
			val = kwargs[k]
			newKwArgs[k] = val() if callable(val) else val
		newMessage = message
		if newPosArgs or newKwArgs:
			newMessage = message.format(*newPosArgs, **newKwArgs)

		if prefix:
			print(f"{style}{color}{prefix}: {newMessage}{LogHelper.Style.ResetAll}")
		else:
			print(f"{style}{color}{newMessage}{LogHelper.Style.ResetAll}")
