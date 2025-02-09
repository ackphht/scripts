#!python3
# -*- coding: utf-8 -*-

import sys
from typing import NamedTuple
from ackPyHelpers import LogHelper

def main() -> int:
	class ansi(NamedTuple):
		name: str
		val: str

	colors = [
		ansi("Black", LogHelper.Fore.Black), ansi("LightBlackEx", LogHelper.Fore.LightBlackEx),
		ansi("White", LogHelper.Fore.White), ansi("LightWhiteEx", LogHelper.Fore.LightWhiteEx),
		ansi("Blue", LogHelper.Fore.Blue), ansi("LightBlueEx", LogHelper.Fore.LightBlueEx),
		ansi("Cyan", LogHelper.Fore.Cyan), ansi("LightCyanEx", LogHelper.Fore.LightCyanEx),
		ansi("Green", LogHelper.Fore.Green), ansi("LightGreenEx", LogHelper.Fore.LightGreenEx),
		ansi("Red", LogHelper.Fore.Red), ansi("LightRedEx", LogHelper.Fore.LightRedEx),
		ansi("Magenta", LogHelper.Fore.Magenta), ansi("LightMagentaEx", LogHelper.Fore.LightMagentaEx),
		ansi("Yellow", LogHelper.Fore.Yellow), ansi("LightYellowEx", LogHelper.Fore.LightYellowEx),
	]
	styles = [ ansi("Normal", LogHelper.Style.Normal), ansi("Bright", LogHelper.Style.Bright), ansi("Dim", LogHelper.Style.Dim), ]

	for c in colors:
		for s in styles:
			# can use this on > 3.12, but adding a "if sys.version_info >= (3, 12):"
			# for older pythons isn't working and it still gets parsed and errors ???
			#msg = f"{f"{c.name} {s.name}":>21}: The quick brown fox jumps over the lazy dog. 1234567890"
			nm = f"{c.name} {s.name}"
			msg = f"{nm:>21}: The quick brown fox jumps over the lazy dog. 1234567890"
			LogHelper.MessageCustom(msg, c.val, s.val)

	return 0

if __name__ == "__main__":
	try:
		sys.exit(main())
	except KeyboardInterrupt:
		print('')
		print('')
		print(f"\033[22m\033[33m******** CANCELLED ********\033[0m")
