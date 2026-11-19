#!python3
# -*- coding: utf-8 -*-

import sys, os, pathlib
from platformdirs import PlatformDirs

def main():
	# even though they're in the docuimentation and using same version,
	# the properties sometimes throw an AttributeError, so ugly hack, yay
	def _safeCall(d: PlatformDirs, attr: str) -> str:
		return getattr(d, attr) if hasattr(d, attr) else 'N/A'

	# see https://platformdirs.readthedocs.io/en/latest/api.html
	app = "__app__"; company = "__company__"
	dirs = PlatformDirs(app, company)
	print("User folders:")
	print(f"        data: {_safeCall(dirs, 'user_data_dir')}")
	print(f"      config: {_safeCall(dirs, 'user_config_dir')}")
	print(f"  preference: {_safeCall(dirs, 'user_preference_dir')}")
	print(f"       state: {_safeCall(dirs, 'user_state_dir')}")
	print(f"       cache: {_safeCall(dirs, 'user_cache_dir')}")
	print(f"         log: {_safeCall(dirs, 'user_log_dir')}")
	print(f"     runtime: {_safeCall(dirs, 'user_runtime_dir')}")
	print(f"         bin: {_safeCall(dirs, 'user_bin_dir')}")
	print(f"     desktop: {_safeCall(dirs, 'user_desktop_dir')}")
	print(f"   documents: {_safeCall(dirs, 'user_documents_dir')}")
	print(f"   downloads: {_safeCall(dirs, 'user_downloads_dir')}")
	print(f"       music: {_safeCall(dirs, 'user_music_dir')}")
	print(f"    pictures: {_safeCall(dirs, 'user_pictures_dir')}")
	print(f"      videos: {_safeCall(dirs, 'user_videos_dir')}")
	print(f"   templates: {_safeCall(dirs, 'user_templates_dir')}")
	print(f"       fonts: {_safeCall(dirs, 'user_fonts_dir')}")
	print(f"applications: {_safeCall(dirs, 'user_applications_dir')}")	# start menu
	print()
	print("Site folders:")
	print(f"        data: {_safeCall(dirs, 'site_data_dir')}")
	print(f"      config: {_safeCall(dirs, 'site_config_dir')}")
	print(f"       state: {_safeCall(dirs, 'site_state_dir')}")
	print(f"       cache: {_safeCall(dirs, 'site_cache_dir')}")
	print(f"         log: {_safeCall(dirs, 'site_log_dir')}")
	print(f"     runtime: {_safeCall(dirs, 'site_runtime_dir')}")
	print(f"         bin: {_safeCall(dirs, 'site_bin_dir')}")
	print(f"applications: {_safeCall(dirs, 'site_applications_dir')}")	# start menu
if __name__ == "__main__":
	try:
		sys.exit(main())
	except KeyboardInterrupt:
		print('')
		print('')
		print(f"\033[22m\033[33m******** CANCELLED ********\033[0m")
		sys.exit(130) # See <http://www.tldp.org/LDP/abs/html/exitcodes.html>
