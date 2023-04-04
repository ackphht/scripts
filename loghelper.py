#!python3
# -*- coding: utf-8 -*-

import colorama					# https://pypi.org/project/colorama/

class LogHelper:
	@staticmethod
	def Init():		# seems like there would be a way to do this automatically or something when the module is imported ??
		colorama.init(strip=False, convert=None)

	@staticmethod
	def Log(message : str):
		print(f"{colorama.Style.DIM}{colorama.Fore.WHITE}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Verbose(message : str):
		print(f"{colorama.Style.NORMAL}{colorama.Fore.YELLOW}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Warning(message : str):
		print(f"{colorama.Style.BRIGHT}{colorama.Fore.LIGHTYELLOW_EX}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Warning2(message : str):
		print(f"{colorama.Style.BRIGHT}{colorama.Fore.LIGHTRED_EX}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Error(message : str):
		print(f"{colorama.Style.BRIGHT}{colorama.Fore.RED}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Message(message : str):
		print(f"{colorama.Style.NORMAL}{colorama.Fore.CYAN}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Message2(message : str):
		print(f"{colorama.Style.NORMAL}{colorama.Fore.MAGENTA}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def Message3(message : str):
		print(f"{colorama.Style.NORMAL}{colorama.Fore.YELLOW}{message}{colorama.Style.RESET_ALL}")

	@staticmethod
	def WhatIf(message : str):
		print(f"{colorama.Style.NORMAL}{colorama.Fore.WHITE}WhatIf: {message}{colorama.Style.RESET_ALL}")
