#!python3
# -*- coding: utf-8 -*-

import sys, os, platform, pathlib, re, json
import logging
from typing import Union

PyScript = pathlib.Path(os.path.abspath(__file__))
PyScriptRoot = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))

class OSDetails:
	# region helper classes
	class _osName:
		@staticmethod
		def deserialize(json: dict) -> "OSDetails._osName":
			result = OSDetails._osName()
			result.build: int = json["build"] if "build" in json else 0
			result.name: str = json["name"] if "name" in json else ""
			result.addRegRelease: bool = json["addRegRelease"] if "addRegRelease" in json else False
			result.addBuildNumber: bool = json["addBuildNumber"] if "addBuildNumber" in json else False
			result.addBuildLab: bool = json["addBuildLab"] if "addBuildLab" in json else False
			result.addUbr: bool = json["addUbr"] if "addUbr" in json else False
			return result

	class _osCodename:
		@staticmethod
		def deserialize(json: dict) -> "OSDetails._osCodename":
			result = OSDetails._osCodename()
			result.major: int = json["major"] if "major" in json else 0
			result.minor: int = json["minor"] if "minor" in json else 0
			result.build: int = json["build"] if "build" in json else 0
			result.codename: str = json["codename"] if "codename" in json else ""
			return result

	class _osVersion:
		@staticmethod
		def deserialize(json: dict) -> "OSDetails._osVersion":
			result = OSDetails._osVersion()
			result.major: int = json["major"] if "major" in json else 0
			result.minor: int = json["minor"] if "minor" in json else 0
			result.build: int = json["build"] if "build" in json else 0
			result.includeUbr: bool = json["includeUbr"] if "includeUbr" in json else False
			return result

	class _osInfo:
		@staticmethod
		def deserialize(json: dict) -> "OSDetails._osInfo":
			result = OSDetails._osInfo()
			result.versions: dict[str, list[OSDetails._osName]] = {}
			if "names" in json:
				for key in json["names"].keys():
					result.versions[key] = []
					for x in json["names"][key]:
						result.versions[key].append(OSDetails._osName.deserialize(x))
			result.codenames: list[OSDetails._osCodename] = []
			if "codenames" in json:
				for x in json["codenames"]:
					result.codenames.append(OSDetails._osCodename.deserialize(x))
			result.releaseVersions: list[OSDetails._osVersion] = []
			if "versions" in json:
				for x in json["versions"]:
					result.releaseVersions.append(OSDetails._osVersion.deserialize(x))
			return result

	class _osInfos:
		@staticmethod
		def deserialize(json: dict) -> "OSDetails._osInfos":
			result = OSDetails._osInfos()
			for key in json.keys():
				result.__setattr__(key, OSDetails._osInfo.deserialize(json[key]))
			return result
	# endregion

	_cachedOSDetails: "OSDetails" = None

	def __init__(self):
		self._platform: str = OSDetails._getPlatform()
		self._id: str = ""
		self._description: str = ""
		self._release: str = ""
		self._releaseVersion: str = ""
		self._kernelVersion: str = "0.0.0"
		self._buildNumber: str = "0"
		self._updateRevision: int = 0
		self._distributor: str = ""
		self._codename: str = ""
		self._osType: str = ""
		self._edition: str = ""
		self._osArchitecture: str = ""
		self._is64BitOs: bool = True

	def __repr__(self) -> str:
		return f'<OSDetails: platform = "{self._platform}", id = "{self._id}", description = "{self._description}", release = "{self._release}", ' +\
				f'releaseVersion = "{self._releaseVersion}", kernelVersion = "{self._kernelVersion}", buildNumber = "{self._buildNumber}", ' +\
				f'updateRevision = "{self._updateRevision}", distributor = "{self._distributor}", codename = "{self._codename}", osType = "{self._osType}", ' +\
				f'edition = "{self._edition}", osArchitecture = "{self._osArchitecture}", is64BitOs = "{self._is64BitOs}">'

	def _setfield(self, propName: str, propValue) -> None:
		# subclasses can't set field values ???
		self.__setattr__(propName, propValue)

	@staticmethod
	def GetDetails() -> "OSDetails":
		if not OSDetails._cachedOSDetails:
			if sys.platform == "win32":
				OSDetails._cachedOSDetails = _OSDetailsWin()
			elif sys.platform == "linux":
				OSDetails._cachedOSDetails = _OSDetailsLinux()
			elif sys.platform == "darwin":
				OSDetails._cachedOSDetails = _OSDetailsMac()
		return OSDetails._cachedOSDetails

	@staticmethod
	def _getPlatform() -> str:
		if sys.platform == "win32":
			return "Windows"
		elif sys.platform == "linux":
			return "Linux"
		elif sys.platform == "darwin":
			return "MacOS"
		else:
			raise NotImplementedError(f'unrecognized platform: "{sys.platform}"')

	@staticmethod
	def _getOsInfoLookups() -> "OSDetails._osInfos":
		jsonPath = PyScriptRoot / "osInfoLookups.jsonc"
		logging.debug(f'trying to read osInfoLookups data from file "{jsonPath}"')
		with open(jsonPath, "r", encoding="utf-8") as file:
			s = file.read()
		# the python json parser can't handle comments 😖 so strip them out
		# (these regexes will break things if there's '//' or '/*' inside a string in the json but that's okay for this file because i didn't do that):
		s = re.sub(r"//.*[\r\n]+", "", s)	# line comments
		s = re.sub(r"/\*[\s\S]+?\*/", "", s)	# block comments
		jsonDict = json.loads(s)
		comma = ','
		logging.debug(f'osInfoLookups data: OSes = "{comma.join(jsonDict.keys())}"')
		return OSDetails._osInfos.deserialize(jsonDict)

	@staticmethod
	def _normalizeArchitecture(arch: str) -> tuple[str, bool]:
		is64BitOs = True
		arch = arch.lower()
		if arch in ["x64", "amd64", "em64t", "x86_64h"]:
			arch = "x86_64"
		elif arch in ["x86", "i386", "i686"]:
			arch = "x86_32"
			is64BitOs = False
		elif arch in ["aarch64", "arm64e"]:
			arch = "arm64"
		elif arch.startswith("armv"):
			arch = "arm"
			is64BitOs = False
		elif arch == "arm":
			is64BitOs = False
		# any others just use name as-is
		return arch,is64BitOs

	@staticmethod
	def _looksLikeVersion(value: str) -> bool:
		return value and re.match(r"^[\d\.]+$", value)

	@staticmethod
	def _convertVersion(value: str) -> tuple[str,int,int]:
		result = "0.0"; major: int = 0; minor: int = 0;
		m = re.match(r"^(?P<maj>\d\d\d\d)(?P<min>\d\d)(?P<rev>\d\d)$", value)	# for opensuse tumbleweed
		if m:
			major = int(m.group("maj"))
			minor = int(m.group("min"))
			result = f"{major}.{minor}.{m.group('rev')}"	# meh
		elif re.match(r"^\d+$", value):
			major = int(value)
			result = int(value)
		else:
			m = re.match(r"^(?P<maj>\d+)\.(?P<min>\d+)(\.[\d\.]+)?$", value)
			if m:
				major = int(m.group("maj"))
				minor = int(m.group("min"))
				result = value
		return result,major,minor

	# region properties
	@property
	def platform(self) -> str:
		"what platform we're on; e.g. 'Windows' or 'Linux' or 'MacOS'"
		return self._platform

	@property
	def id(self) -> str:
		"a sorta parsable version string; e.g. 'win.10.21H2', 'win.8.1', 'linux.ubuntu'.23.04, 'mac.13', 'mac.10.15'"
		return self._id

	@property
	def description(self) -> str:
		"e.g. 'Microsoft Windows 10 Pro', 'Ubuntu 23.04', 'macOS 13.3.1 (22E261)'"
		return self._description

	@property
	def release(self) -> str:
		"e.g. 'Vista SP2', '7 SP1', '8.1', '10 1709', '11', '11 22H2'; for macOS, just the os version (13.3.1); for Linux, the distro version (e.g. for Ubuntu: '23.04')"
		return self._release

	@property
	def releaseVersion(self) -> str:
		"e.g. '10.0.16299.723'; Linux (for Ubuntu: '23.4'), MacOS (e.g. '13.3.1') have different versions for the OS itself and for the kernel"
		return self._releaseVersion

	@property
	def kernelVersion(self) -> str:
		"e.g. '10.0.16299.723'; for macOS, this will be the Darwin version (e.g. '22.4.0'); Linux usually has complicated versions so this has to be a string"
		return self._kernelVersion

	@property
	def buildNumber(self) -> str:
		"the OS build number, if applicable"
		return self._buildNumber

	@property
	def updateRevision(self) -> int:
		"for Windows, the UpdateBuildRevision (UBR), if available (Win10+)"
		return self._updateRevision

	@property
	def distributor(self) -> str:
		"e.g. 'Microsoft Corporation', 'Apple', 'Ubuntu', 'Fedora', etc"
		return self._distributor

	@property
	def codename(self) -> str:
		"the OS release codename, if available"
		return self._codename

	@property
	def osType(self) -> str:
		"for Windows: 'WorkStation' or 'Server'"
		return self._osType

	@property
	def edition(self) -> str:
		"for Windows: e.g. 'Professional', 'Home', etc"
		return self._edition

	@property
	def osArchitecture(self) -> str:
		"e.g. 'x86_64', 'Arm64'"
		return self._osArchitecture

	@property
	def is64BitOS(self) -> bool:
		"whether or not the OS is 64 bit"
		return self._is64BitOs
	# endregion

if sys.platform == "win32":
	import winreg
	class _OSDetailsWin(OSDetails):
		def __init__(self):
			base = super()
			base.__init__()
			base._setfield("_distributor", "Microsoft Corporation")	# super() can only call methods, can't set fields/properties (and can't call __setattr__) ???
			buildNumber, displayVersion, editionId, installType, productName, releaseId, ubr = self._getWinRegData()
			if buildNumber is not None:
				base._setfield("_buildNumber", str(buildNumber))
			cleanedUpProductName = self._cleanUpWinProductName(productName, buildNumber)
			if cleanedUpProductName:
				base._setfield("_description", cleanedUpProductName)
			osType = ""
			if installType is not None:
				osType = "WorkStation" if installType == "Client" else "Server"
				base._setfield("_osType", osType)
			if ubr is not None and ubr > 0:
				base._setfield("_updateRevision", ubr)
			base._setfield("_kernelVersion", self._getWinKernelVersion(ubr))
			osArch, is64BitOs = self._getWinOsArch()
			base._setfield("_osArchitecture", osArch)
			base._setfield("_is64BitOs", is64BitOs)
			osLookups = OSDetails._getOsInfoLookups()
			base._setfield("_releaseVersion", self._getWinReleaseVersion(osLookups.windows.releaseVersions, buildNumber, ubr))
			release = self._getWinRelease(osLookups.windows.versions, buildNumber, osType, displayVersion, releaseId, ubr)
			base._setfield("_release", release)
			base._setfield("_id", self._getWinId(release, buildNumber, osType, cleanedUpProductName))
			base._setfield("_codename", self._getWinCodename(osLookups.windows.codenames, buildNumber))
			base._setfield("_edition", self._getWinEdition(editionId, installType))

		def _getWinRegData(self) -> tuple[int, str, str, str, str, str, int]:
			logging.debug(r"reading data from registry HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion")
			buildNumber: int = 0; displayVersion: str = None; editionId: str = None; installType: str = None; productName: str = None; releaseId: str = None; ubr: int = 0;
			with winreg.OpenKeyEx(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion") as key:
				bld = self._readRegValue(key, "CurrentBuild")
				if bld: bld = int(bld)
				buildNumber = bld
				displayVersion = self._readRegValue(key, "DisplayVersion")
				editionId = self._readRegValue(key, "EditionID")
				installType = self._readRegValue(key, "InstallationType")
				productName = self._readRegValue(key, "ProductName")
				releaseId = self._readRegValue(key, "ReleaseId")
				ubr = self._readRegValue(key, "UBR")
			logging.debug(f'returning registry data: buildNumber="{buildNumber}", editionId="{editionId}", displayVersion="{displayVersion}", releaseId="{releaseId}", ubr="{ubr}"')
			return buildNumber, displayVersion, editionId, installType, productName, releaseId, ubr

		def _getWinBuildLab(self) -> str:
			buildLab: str = None
			with winreg.OpenKeyEx(winreg.HKEY_LOCAL_MACHINE, r"SOFTWARE\Microsoft\Windows NT\CurrentVersion") as key:
				buildLab = self._readRegValue(key, "BuildLab")
			return buildLab

		def _readRegValue(self, key: winreg.HKEYType, valueName: str) -> Union[str, int]:
			try:
				return winreg.QueryValueEx(key, valueName)[0]
			except OSError:
				return None

		def _cleanUpWinProductName(self, rawName: str, buildNumber: int) -> str:
			logging.debug(f'cleaning up product name "{rawName}"')
			if not rawName: return ""
			if buildNumber > 22000:
				rawName = rawName.replace(" 10 ", " 11 ")	# they didn't change it in the registry ???
			rawName = rawName.replace("™", "").replace(" (TM)", "").replace("®", "").replace(" (R)", "")
			if not rawName.startswith("Microsoft"):
				rawName = ("Microsoft " + rawName)
			logging.debug(f'returning cleaned up product name "{rawName}"')
			return rawName

		def _getWinKernelVersion(self, ubr: int) -> str:
			return f"{platform.version()}.{ubr if ubr is not None else 0}"

		def _getWinReleaseVersion(self, osReleaseVersions: list["OSDetails._osVersion"], buildNumber: int, ubr: int) -> str:
			for ver in sorted(osReleaseVersions, key=lambda v: v.build, reverse=True):
				if buildNumber >= ver.build:
					return f"{ver.major}.{ver.minor}.{buildNumber}.{ubr if ver.includeUbr and ubr is not None else 0}"
			return f"{buildNumber}"

		def _getWinOsArch(self) -> tuple[str, bool]:
			# can't use platform.machine() (or platform.uname()) -> that's the processor architecture;
			# and can't use platform.architecture() because it does nothing on windows, just always returns
			# whatever bitness the python executable is, which is not necessarily what we're looking for for this
			# and don't see anything in os or sys that would help, either
			# ==> so we're going to have to play with the environment vars:
			# 1) as far as i can tell, the PROCESSOR_ARCHITECTURE env var is sorta misnamed; it's really OS_ARCHITECTURE
			# 2) if you're running a 32-bit app on a 64-bit OS, then the PROCESSOR_ARCHITEW6432 env var will exist and contain the correct OS architecture
			# 3) else you're running a 64-bit app on a 64-bit os or a 32-bit app on a 32-bit OS, and only PROCESSOR_ARCHITECTURE will exist and contain the correct OS architecture
			is64BitOs = True
			arch = os.environ["PROCESSOR_ARCHITECTURE"]
			if "PROCESSOR_ARCHITEW6432" in os.environ:
				arch = os.environ["PROCESSOR_ARCHITEW6432"]
			return OSDetails._normalizeArchitecture(arch)

		def _getWinRelease(self, osVersions: dict[str, list["OSDetails._osName"]], buildNumber: int, osType: str, displayVersion: str, releaseId: str, ubr: int) -> str:
			logging.debug(f'mapping win release: build = "{buildNumber}", type = "{osType}"')
			result = "<unknown>"
			key = "server" if osType.lower() == "server" else "client"
			verList: list[OSDetails._osName] = None
			if key in osVersions:
				verList: list[OSDetails._osName] = osVersions[key]
			if not verList or len(verList) == 0:
				logging.warn(f"could not find matching versionList for osType '{osType}' or it is empty")
				return result
			for ver in sorted(verList, key=lambda v: v.build, reverse=True):
				if buildNumber >= ver.build:
					result = ver.name
					if ver.addRegRelease:
						result += f".{displayVersion if displayVersion else releaseId}"
					if ver.addBuildNumber:
						result += f".{buildNumber}"
					if ver.addUbr:
						result += f".{ubr}"
					if ver.addBuildLab:
						bldLab = self._getWinBuildLab()
						if bldLab:
							result += f".{bldLab}"
					break
			logging.debug(f'mapping win release: result = "{result}"')
			return result

		def _getWinId(self, release: str, buildNumber: int, osType: str, productName: str) -> str:
			logging.debug(f'mapping win id: release = "{release}", build = "{buildNumber}", type = "{osType}"')
			result = "<unknown>"
			if osType.lower() != "server":
				if buildNumber >= 6000:
					result = f"win.{release}"
				else:
					result = f"win.{buildNumber}"
			else:
				# #
				# #TODO: this needs to be updated; have not kept up with Server versions
				# #
				if buildNumber >= 17763:
					if productName.index("2019") > 0:		# can't find any other way to distinguish these...
						result = "srvr.2019"
					else:
						result = "srvr"
				elif buildNumber >= 16299:
					result = "srvr."	# TODO: think there was supposed to be something else in here...
				elif buildNumber >= 10240:
					result = "srvr.2016"
				elif buildNumber >= 9600:
					result = "srvr.2012R2"
				elif buildNumber >= 9200:
					result = "srvr.2012"
				elif buildNumber >= 7600:
					result = "srvr.2008R2"
				elif buildNumber >= 6000:
					result = "srvr.2008"
				else:
					result = f"srvr.{buildNumber}"
			logging.debug(f'mapping win id: result = "{result}"')
			return result

		def _getWinCodename(self, osCodenames: list["OSDetails._osCodename"], buildNumber: int) -> str:
			for ver in sorted(osCodenames, key=lambda v: v.build, reverse=True):
				if buildNumber >= ver.build:
					return ver.codename
			return ""

		def _getWinEdition(self, editionId: str, installType: str) -> str:
			if editionId.startswith("Core"):
				return editionId.replace("Core", "Home")
			editionIdLower = editionId.lower()
			if editionIdLower == "serverstandard" or editionIdLower == "serverdatacenter" or editionIdLower == "serverenterprise" or editionIdLower == "serverweb":
				if installType == "Server Core":
					return f"{editionId}Core"
				if not installType:
					# for original versions of Server 2008 they weren't populating InstallationType yet, but the EditionId doesn't
					# distinguish between regular and core; for this case; only way i can find to tell is to call the Win32 API
					# GetProductionInfo() because that will tell you the difference between regular and core on Server 2008 and its R2
					# but that does not distinguish between regular and core on Windows 2012 and up 😖 you're supposed to look in a
					# different registry key that only exists on those versions (?) and interpret those values; ffs
					# but we can tell the difference between them from the registry data alone so that's what we're going to do
					# up above and only resort to calling the API method here for this specific case, which should be good enough
					# TODO:
					pass
			# probably others to map, but this is all i have data for
			# for everything else, just use what the registry had:
			return editionId

elif sys.platform == "linux":
	from io import StringIO, TextIOBase
	from shlex import shlex
	import subprocess, shutil
	class _OSDetailsLinux(OSDetails):
		def __init__(self):
			base = super()
			base.__init__()
			distId, description, release, codename = _OSDetailsLinux._getLinuxReleaseProps()
			releaseLooksLikeVersion = OSDetails._looksLikeVersion(release)
			# # special case(s):
			if distId == "debian" and re.match(r"^\d+$", release):
				# Debian's os-release VERSION_ID is too simple, so let's try to get fuller debian_version:
				debianRelPath = pathlib.Path("/etc/debian_version")
				if debianRelPath.exists():
					release = debianRelPath.read_text()
					release = release.strip()
			if distId:
				base._setfield("_distributor", distId.title())
			base._setfield("_description", (f"{description} {release}" if releaseLooksLikeVersion and description.find(release) < 0 else description))
			base._setfield("_release", release)
			base._setfield("_codename", codename)
			if releaseLooksLikeVersion:
				base._setfield("_id", f"linux.{distId.lower()}.{release}")
				releaseVersion,major,minor = OSDetails._convertVersion(release)
				base._setfield("_releaseVersion", releaseVersion)
				pass
			else:
				base._setfield("_id", f"linux.{distId.lower()}")
			base._setfield("_kernelVersion", _OSDetailsLinux._getLinuxKernelVersion())
			osArch, is64BitOs = OSDetails._normalizeArchitecture(platform.machine())	# apparently "platform.machine()"/"uname -m" is the OS arch, not the processor/"machine" arch
			base._setfield("_osArchitecture", osArch)
			base._setfield("_is64BitOs", is64BitOs)

		@staticmethod
		def _getLinuxReleaseProps() -> tuple[str, str, str, str]:
			distId = description = release = codename = ""
			# try getting data from reading files before shelling out to lsb_release:
			lsbReleasePath = pathlib.Path("/etc/lsb-release")
			if lsbReleasePath.is_file():
				logging.debug(f'reading lsb-release from file "{lsbReleasePath}"')
				with open(lsbReleasePath, "r", encoding="utf-8") as f:
					lsbrelease = _OSDetailsLinux._parseLinesToDict(f)
				if "DISTRIB_ID" in lsbrelease: distId = lsbrelease["DISTRIB_ID"]
				if "DISTRIB_DESCRIPTION" in lsbrelease: description = lsbrelease["DISTRIB_DESCRIPTION"]
				if "DISTRIB_RELEASE" in lsbrelease: release = lsbrelease["DISTRIB_RELEASE"]
				if "DISTRIB_CODENAME" in lsbrelease: codename = lsbrelease["DISTRIB_CODENAME"]
			else:
				logging.debug(f'no lsb-release file found at "{lsbReleasePath}"')

			osReleasePath = pathlib.Path("/etc/os-release")
			if not osReleasePath.is_file():
				osReleasePath = pathlib.Path("/usr/lib/os-release")
			if (not distId or not description or not release or not codename) and osReleasePath.is_file():
				logging.debug(f'reading os-release from file "{osReleasePath}"')
				with open(osReleasePath, "r", encoding="utf-8") as f:
					osrelease = _OSDetailsLinux._parseLinesToDict(f)
				if not distId and "ID" in osrelease: distId = osrelease["ID"]
				if not description and "NAME" in osrelease: description = osrelease["NAME"]
				if not release and "VERSION_ID" in osrelease: release = osrelease["VERSION_ID"]
				if not codename and "VERSION_CODENAME" in osrelease: codename = osrelease["VERSION_CODENAME"]
			else:
				logging.debug('no os-release file found at either "/etc/os-release" or "/usr/lib/os-release"')

			# some distros (e.g. fedora and opensuse tumbleweed) still don't have everything but it is returned by lsb_release (??), so let's try that:
			if not distId or not description or not release or not codename:
				lsbOutput = _OSDetailsLinux._getLsbReleaseOutput()
				lsb = _OSDetailsLinux._parseLinesToDict(lsbOutput) if lsbOutput else {}
				if not distId and "Distributor ID" in lsb: distId = lsb["Distributor ID"]
				if not description and "Description" in lsb: description = lsb["Description"]
				if not release and "Release" in lsb: release = lsb["Release"]
				if not codename and "Codename" in lsb: codename = lsb["Codename"]

			if codename.lower() == "n/a": codename = ""	# opensuse tumbleweed

			return distId, description, release, codename

		@staticmethod
		def _parseLinesToDict(lines: Union[TextIOBase, str]) -> dict[str, str]:
			content = StringIO(lines) if isinstance(lines, str) else lines
			lx = shlex(content, posix=True)	# with posix=True, it strips quotes, too, which is nice, just not sure what else it might do, but so far, seems okay ??
			lx.whitespace_split = True				# with this and below, only splits on newlines, which wouldn't be any better tnan just iterating the lines,
			lx.whitespace = '\r\n'					# but shlex still does replace escapes, tries to handle comments (not very smartly but still...)
			results = {}
			for tk in lx:
				if "=" in tk:
					k, v = tk.split("=", 1)
					results[k.strip()] = v.strip()
			return results

		@staticmethod
		def _getLsbReleaseOutput() -> str:
			lsbReleasePath = shutil.which("lsb_release")
			result = ""
			if lsbReleasePath:
				logging.debug(f'lsb_release found at "{lsbReleasePath}"')
				# "file" output is locale dependent: force the usage of the C locale to get deterministic behavior. (from platform.py...)
				env = dict(os.environ, LC_ALL="C")
				try:
					output = subprocess.check_output([lsbReleasePath, "-a"], stderr=subprocess.DEVNULL, env=env)
				except (OSError, subprocess.CalledProcessError):
					output = ""
				if output:
					# With the C locale, the output should be mostly ASCII-compatible. (from platform.py...)
					# Decode from Latin-1 to prevent Unicode decode error. (because it's returning a byte string...)
					result = output.decode('latin-1')
			else:
				logging.debug("no lsb_release found")
			return result

		@staticmethod
		def _getLinuxKernelVersion() -> str:
			result = platform.release()
			# Debian, Kali, maybe others, are now apparently using a 'display' version that's above, but
			# then the real version has to be parsed out of below (haven't found a better way yet...)
			# want the fifth field if it starts with something dd.dd.d*:
			match = re.match(r"^[\S]+\s+[\S]+\s+[\S]+\s+[\S]+\s+(?P<ver>\d+\.\d+\.\d+[\S]*).*$", platform.version())
			if match:
				version = match.group("ver")
				if version and version != result:
					result = f"{result} [{version}]"
			return result

elif sys.platform == "darwin":
	import subprocess, shutil
	class _OSDetailsMac(OSDetails):
		def __init__(self):
			base = super()
			base.__init__()
			base._setfield("_distributor", "Apple")	# super() can only call methods, can't set fields/properties (and can't call __setattr__) ???
			base._setfield("_description", _OSDetailsMac._getMacDescription())
			base._setfield("_release", _OSDetailsMac._getMacReleaseVersion())
			releaseVersion,major,minor = OSDetails._convertVersion(base.release)
			base._setfield("_releaseVersion", releaseVersion)
			kern = _OSDetailsMac._getMacKernelVersion()
			if kern:
				base._setfield("_kernelVersion", kern)
			base._setfield("_id", _OSDetailsMac._getMacId(major, minor))
			osLookups = OSDetails._getOsInfoLookups()
			base._setfield("_codename", _OSDetailsMac._getMacCodename(osLookups.macos.codenames, major, minor))
			base._setfield("_buildNumber", _OSDetailsMac._getMacBuildNumber())
			base._setfield("_updateRevision", _OSDetailsMac._getMacRevision())
			osArch, is64BitOs = _OSDetailsMac._getMacOSArch()
			base._setfield("_osArchitecture", osArch)
			base._setfield("_is64BitOs", is64BitOs)

		@staticmethod
		def _getMacDescription() -> str:
			tmp = _OSDetailsMac._getCommandOutput(["system_profiler", "-json", "SPSoftwareDataType"])
			jsonDict = json.loads(tmp)
			#$osDetails.Description = $sysProfData.SPSoftwareDataType.os_version
			return jsonDict["SPSoftwareDataType"][0]["os_version"]

		@staticmethod
		def _getMacReleaseVersion() -> str:
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osproductversion"])
			if not tmp:
				pass	# anywhere else to look ???
			return tmp

		@staticmethod
		def _getMacKernelVersion() -> str:
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osrelease"])
			if not tmp:
				pass	# anywhere else to look ???
			return tmp

		@staticmethod
		def _getMacId(verMajor: int, verMinor: int) -> str:
			result = ""
			#if verMajor > 10:
			#	result = f"mac.{verMajor}"
			#elif verMajor == 10:
			result = f"mac.{verMajor}.{verMinor}"
			return result

		@staticmethod
		def _getMacCodename(osCodenames: list["OSDetails._osCodename"], verMajor: int, verMinor: int) -> str:
			for ver in osCodenames:
				if verMajor == ver.major and verMinor == ver.minor:
					return ver.codename
			return ""

		@staticmethod
		def _getMacBuildNumber() -> str:
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osversion"])
			if not tmp:
				pass	# anywhere else to look ???
			return tmp

		@staticmethod
		def _getMacRevision() -> int:
			result = -1
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osrevision"])
			if not tmp:
				pass	# anywhere else to look ???
			if tmp:
				result = int(tmp)
			return result

		@staticmethod
		def _getMacOSArch() -> tuple[str, int]:
			archPath = shutil.which("arch")
			if archPath:
				tmpArch = _OSDetailsMac._getCommandOutput([archPath])
			else:
				# macOs 10.7+ only come in 64bit, and 10.15+ only support 64bit apps,  but that doesn't tell us the architecture
				tmpArch = platform.machine()	# still not clear if this is processor arch or os arch...
			if tmpArch:
				return OSDetails._normalizeArchitecture(tmpArch)
			return "",True

		@staticmethod
		def _getCommandOutput(args: list[str]) -> str:
			tmp = subprocess.check_output(args, stderr=subprocess.DEVNULL)
			return tmp.decode().strip()

else:
	raise NotImplementedError(f'unrecognized platform: "{sys.platform}"')
