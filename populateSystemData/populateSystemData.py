#!python3
# -*- coding: utf-8 -*-

from __future__ import annotations
from pydoc import describe
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

	PlatformWindows: str = "Windows"
	PlatformLinux: str = "Linux"
	PlatformMacOS: str = "MacOS"
	PlatformBSD: str = "BSD"
	_cachedOSDetails: "OSDetails" = None
	_cachedPlatform: str = None

	def __init__(self):
		self._platform: str = OSDetails._getPlatform()

	def __repr__(self) -> str:
		return f'<OSDetails: platform = "{self.platform}", id = "{self.id}", description = "{self.description}", release = "{self.release}", ' +\
				f'releaseVersion = "{self.releaseVersion}", kernelVersion = "{self.kernelVersion}", buildNumber = "{self.buildNumber}", ' +\
				f'updateRevision = "{self.updateRevision}", distributor = "{self.distributor}", codename = "{self.codename}", osType = "{self.osType}", ' +\
				f'edition = "{self.edition}", osArchitecture = "{self.osArchitecture}", is64BitOs = "{self.is64BitOs}">'

	@staticmethod
	def GetDetails() -> "OSDetails":
		if not OSDetails._cachedOSDetails:
			p = OSDetails._getPlatform()
			if p == OSDetails.PlatformWindows:
				OSDetails._cachedOSDetails = _OSDetailsWin()
			elif p in [OSDetails.PlatformLinux, OSDetails.PlatformBSD]:
				OSDetails._cachedOSDetails = _OSDetailsNix()
			elif p == OSDetails.PlatformMacOS:
				OSDetails._cachedOSDetails = _OSDetailsMac()
		return OSDetails._cachedOSDetails

	@staticmethod
	def _getPlatform() -> str:
		if not OSDetails._cachedPlatform:
			if sys.platform == "win32":
				OSDetails._cachedPlatform = OSDetails.PlatformWindows
			elif sys.platform == "linux":
				OSDetails._cachedPlatform = OSDetails.PlatformLinux
			elif sys.platform == "darwin":
				OSDetails._cachedPlatform = OSDetails.PlatformMacOS
			elif platform.system().upper().endswith("BSD") or platform.system() == "DragonFly":
				OSDetails._cachedPlatform = OSDetails.PlatformBSD
			else:
				raise NotImplementedError(f'unrecognized platform: sys.platform = "{sys.platform}", platform.system() = "{platform.system()}"')
		return OSDetails._cachedPlatform

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
			result = f"{major}.{minor}.{int(m.group('rev'))}"	# meh
		elif re.match(r"^\d+$", value):
			major = int(value)
			result = str(major)
		else:
			m = re.match(r"^(?P<maj>\d+)\.(?P<min>\d+)(?P<rest>\.[\d\.]+)?$", value)
			if m:
				major = int(m.group("maj"))
				minor = int(m.group("min"))
				rest = m.group("rest")
				result = f"{major}.{minor}{rest if rest else ''}"
		return result,major,minor

	# region methods to override
	def _getId(self) -> str:
		return None

	def _getDescription(self) -> str:
		return None

	def _getRelease(self) -> str:
		return None

	def _getReleaseVersion(self) -> str:
		return None

	def _getKernelVersion(self) -> str:
		return None

	def _getBuildNumber(self) -> str:
		return None

	def _getUpdateRevision(self) -> int:
		return None

	def _getDistributor(self) -> str:
		return None

	def _getCodename(self) -> str:
		return None

	def _getOsType(self) -> str:
		return None

	def _getEdition(self) -> str:
		return None

	def _getOsArchitecture(self) -> str:
		return None

	def _getIs64BitOS(self) -> bool:
		return None
	# endregion

	# region properties
	@property
	def platform(self) -> str:
		"what platform we're on; e.g. 'Windows' or 'Linux' or 'MacOS'"
		return self._platform

	@property
	def id(self) -> str:
		"a sorta parsable version string; e.g. 'win.10.21H2', 'win.8.1', 'linux.ubuntu'.23.04, 'mac.13', 'mac.10.15'"
		return self._getId()

	@property
	def description(self) -> str:
		"e.g. 'Microsoft Windows 10 Pro', 'Ubuntu 23.04', 'macOS 13.3.1 (22E261)'"
		return self._getDescription()

	@property
	def release(self) -> str:
		"e.g. 'Vista SP2', '7 SP1', '8.1', '10 1709', '11', '11 22H2'; for macOS, just the os version (13.3.1); for Linux, the distro version (e.g. for Ubuntu: '23.04')"
		return self._getRelease()

	@property
	def releaseVersion(self) -> str:
		"e.g. '10.0.16299.723'; Linux (for Ubuntu: '23.4'), MacOS (e.g. '13.3.1') have different versions for the OS itself and for the kernel"
		return self._getReleaseVersion()

	@property
	def kernelVersion(self) -> str:
		"e.g. '10.0.16299.723'; for macOS, this will be the Darwin version (e.g. '22.4.0'); Linux usually has complicated versions so this has to be a string"
		return self._getKernelVersion()

	@property
	def buildNumber(self) -> str:
		"the OS build number, if applicable"
		return self._getBuildNumber()

	@property
	def updateRevision(self) -> int:
		"for Windows, the UpdateBuildRevision (UBR), if available (Win10+)"
		return self._getUpdateRevision()

	@property
	def distributor(self) -> str:
		"e.g. 'Microsoft Corporation', 'Apple', 'Ubuntu', 'Fedora', etc"
		return self._getDistributor()

	@property
	def codename(self) -> str:
		"the OS release codename, if available"
		return self._getCodename()

	@property
	def osType(self) -> str:
		"for Windows: 'WorkStation' or 'Server'"
		return self._getOsType()

	@property
	def edition(self) -> str:
		"for Windows: e.g. 'Professional', 'Home', etc"
		return self._getEdition()

	@property
	def osArchitecture(self) -> str:
		"e.g. 'x86_64', 'Arm64'"
		return self._getOsArchitecture()

	@property
	def is64BitOS(self) -> bool:
		"whether or not the OS is 64 bit"
		return self._getIs64BitOS()
	# endregion

if OSDetails._getPlatform() == OSDetails.PlatformWindows:
	import winreg
	class _OSDetailsWin(OSDetails):
		def __init__(self):
			super().__init__()
			self._buildNumber, self._displayVersion, self._editionId, self._installType, self._productName, self._releaseId, self._ubr = self._getWinRegData()
			self._cleanedUpProductName = self._cleanUpWinProductName(self._productName, self._buildNumber)
			self._osType = ""
			if self._installType is not None:
				self._osType = "WorkStation" if self._installType == "Client" else "Server"
			self._osArch, self._is64BitOs = self._getWinOsArch()
			osLookups = OSDetails._getOsInfoLookups()
			self._releaseVersion = self._getWinReleaseVersion(osLookups.windows.releaseVersions, self._buildNumber, self._ubr)
			self._release = self._getWinRelease(osLookups.windows.versions, self._buildNumber, self._osType, self._displayVersion, self._releaseId, self._ubr)
			self._codename = self._getWinCodename(osLookups.windows.codenames, self._buildNumber)
			self._id = self._getWinId(self._release, self._buildNumber, self._osType, self._cleanedUpProductName)
			self._kernelVersion = self._getWinKernelVersion(self._ubr)
			self._edition = self._getWinEdition(self._editionId, self._installType)

		# region overridden methods
		def _getId(self) -> str:
			return self._id

		def _getDescription(self) -> str:
			return self._cleanedUpProductName if self._cleanedUpProductName else ""

		def _getRelease(self) -> str:
			return self._release

		def _getReleaseVersion(self) -> str:
			return self._releaseVersion

		def _getKernelVersion(self) -> str:
			return self._kernelVersion

		def _getBuildNumber(self) -> str:
			return str(self._buildNumber) if self._buildNumber is not None else ""

		def _getUpdateRevision(self) -> int:
			return self._ubr if self._ubr is not None and self._ubr > 0 else None

		def _getDistributor(self) -> str:
			return "Microsoft Corporation"

		def _getCodename(self) -> str:
			return self._codename

		def _getOsType(self) -> str:
			return self._osType

		def _getEdition(self) -> str:
			return self._edition

		def _getOsArchitecture(self) -> str:
			return self._osArch

		def _getIs64BitOS(self) -> bool:
			return self._is64BitOs
		# endregion

		# region helper methods
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
		# endregion

elif OSDetails._getPlatform() in [OSDetails.PlatformLinux, OSDetails.PlatformBSD]:
	from io import StringIO, TextIOBase
	from shlex import shlex
	import subprocess, shutil
	class _OSDetailsNix(OSDetails):
		def __init__(self):
			super().__init__()
			self._distId, self._description, self._release, self._codename = self._getReleaseProps()
			self._releaseLooksLikeVersion = OSDetails._looksLikeVersion(self._release)
			# # special case(s):
			if self._distId == "debian" and re.match(r"^\d+$", self._release):
				# Debian's os-release VERSION_ID is too simple, so let's try to get fuller debian_version:
				debianRelPath = pathlib.Path("/etc/debian_version")
				if debianRelPath.exists():
					self._release = debianRelPath.read_text()
					self._release = self._release.strip()
			self._distributor = (self._distId.title() if self.platform.find("BSD") < 0 else self._distId) if self._distId else ""
			self._finalDescription = f"{self._description} {self._release}" if self._releaseLooksLikeVersion and self._description.find(self._release) < 0 else self._description
			self._kernelVersion = self._getKernelVersion()
			if self._releaseLooksLikeVersion:
				self._id = f"{OSDetails._getPlatform().lower()}.{self._distId.lower()}.{self._release}"
				self._releaseVersion,major,minor = OSDetails._convertVersion(self._release)
			else:
				self._id = f"{OSDetails._getPlatform().lower()}.{self._distId.lower()}"
				self._releaseVersion = ""
			self._osArch, self._is64BitOs = OSDetails._normalizeArchitecture(platform.machine())	# apparently "platform.machine()"/"uname -m" is the OS arch, not the processor/"machine" arch

		# region overridden methods
		def _getId(self) -> str:
			return self._id

		def _getDescription(self) -> str:
			return self._finalDescription

		def _getRelease(self) -> str:
			return self._release

		def _getReleaseVersion(self) -> str:
			return self._releaseVersion

		def _getKernelVersion(self) -> str:
			return self._kernelVersion

		def _getDistributor(self) -> str:
			return self._distributor

		def _getCodename(self) -> str:
			return self._codename

		def _getOsArchitecture(self) -> str:
			return self._osArch

		def _getIs64BitOS(self) -> bool:
			return self._is64BitOs
		# endregion

		# region helper methods
		def _getReleaseProps(self) -> tuple[str, str, str, str]:
			distId = description = release = codename = ""
			# try getting data from reading files before shelling out to lsb_release:
			lsbReleasePath = pathlib.Path("/etc/lsb-release")
			if lsbReleasePath.is_file():
				logging.debug(f'reading lsb-release from file "{lsbReleasePath}"')
				with open(lsbReleasePath, "r", encoding="utf-8") as f:
					lsbrelease = _OSDetailsNix._parseLinesToDict(f)
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
					osrelease = _OSDetailsNix._parseLinesToDict(f)
				distIdName = "NAME" if OSDetails._getPlatform() == OSDetails.PlatformBSD else "ID"
				if not distId and distIdName in osrelease: distId = osrelease[distIdName]
				if not description and "NAME" in osrelease: description = osrelease["NAME"]
				if not release and "VERSION_ID" in osrelease: release = osrelease["VERSION_ID"]
				if not codename and "VERSION_CODENAME" in osrelease: codename = osrelease["VERSION_CODENAME"]
			else:
				logging.debug('no os-release file found at either "/etc/os-release" or "/usr/lib/os-release"')

			# some distros (e.g. fedora and opensuse tumbleweed) still don't have everything but it is returned by lsb_release (??), so let's try that:
			if not distId or not description or not release or not codename:
				lsbOutput = _OSDetailsNix._getLsbReleaseOutput()
				lsb = _OSDetailsNix._parseLinesToDict(lsbOutput, separator=":") if lsbOutput else {}
				if not distId and "Distributor ID" in lsb: distId = lsb["Distributor ID"]
				if not description and "Description" in lsb: description = lsb["Description"]
				if not release and "Release" in lsb: release = lsb["Release"]
				if not codename and "Codename" in lsb: codename = lsb["Codename"]

			if OSDetails._getPlatform() == OSDetails.PlatformBSD:
				# if no os-release, lsb_release, lsb-release; do what we can; so far for BSDs, these are close enough(??):
				if not distId:
					distId = platform.system()
				if not description:
					description = platform.system()
				if not release:
					release = platform.release()

			if codename.lower() == "n/a": codename = ""	# opensuse tumbleweed

			return distId, description, release, codename

		@staticmethod
		def _parseLinesToDict(lines: Union[TextIOBase, str], separator: str = "=") -> dict[str, str]:
			content = StringIO(lines) if isinstance(lines, str) else lines
			lx = shlex(content, posix=True)	# with posix=True, it strips quotes, too, which is nice, just not sure what else it might do, but so far, seems okay ??
			lx.whitespace_split = True				# with this and below, only splits on newlines, which wouldn't be any better tnan just iterating the lines,
			lx.whitespace = '\r\n'					# but shlex still does replace escapes, tries to handle comments (not very smartly but still...)
			results = {}
			for tk in lx:
				if separator in tk:
					k, v = tk.split(separator, 1)
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

		def _getKernelVersion(self) -> str:
			result = platform.release()
			if OSDetails._getPlatform() == OSDetails.PlatformLinux:
				# Debian, Kali, maybe others, are now apparently using a 'display' version that's above, but
				# then the real version has to be parsed out of below (haven't found a better way yet...)
				# want the fifth field if it starts with something dd.dd.d*:
				match = re.match(r"^[\S]+\s+[\S]+\s+[\S]+\s+[\S]+\s+(?P<ver>\d+\.\d+\.\d+[\S]*).*$", platform.version())
				if match:
					version = match.group("ver")
					if version and version != result:
						result = f"{result} [{version}]"
			return result
		# endregion

elif OSDetails._getPlatform() == OSDetails.PlatformMacOS:
	import subprocess, shutil
	class _OSDetailsMac(OSDetails):
		def __init__(self):
			super().__init__()
			self._description = self._getMacDescription()
			self._release = self._getMacReleaseVersion()
			self._releaseVersion,self._major,self._minor = OSDetails._convertVersion(self._release)
			self._id = self._getMacId(self._major, self._minor)
			kern = self._getMacKernelVersion()
			self._kernelVersion = kern if kern else ""
			osLookups = OSDetails._getOsInfoLookups()
			self._codename = self._getMacCodename(osLookups.macos.codenames, self._major, self._minor)
			self._buildNumber = self._getMacBuildNumber()
			self._updateRevision = self._getMacRevision()
			self._osArch, self._is64BitOs = self._getMacOSArch()

		# region overridden methods
		def _getId(self) -> str:
			return self._id

		def _getDescription(self) -> str:
			return self._description

		def _getRelease(self) -> str:
			return self._release

		def _getReleaseVersion(self) -> str:
			return self._releaseVersion

		def _getKernelVersion(self) -> str:
			return self._kernelVersion

		def _getBuildNumber(self) -> str:
			return self._buildNumber

		def _getUpdateRevision(self) -> int:
			return self._updateRevision

		def _getDistributor(self) -> str:
			return "Apple"

		def _getCodename(self) -> str:
			return self._codename

		def _getOsArchitecture(self) -> str:
			return self._osArch

		def _getIs64BitOS(self) -> bool:
			return self._is64BitOs
		# endregion

		# region helper methods
		def _getMacDescription(self) -> str:
			tmp = _OSDetailsMac._getCommandOutput(["system_profiler", "-json", "SPSoftwareDataType"])
			jsonDict = json.loads(tmp)
			#$osDetails.Description = $sysProfData.SPSoftwareDataType.os_version
			return jsonDict["SPSoftwareDataType"][0]["os_version"]

		def _getMacReleaseVersion(self) -> str:
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osproductversion"])
			if not tmp:
				pass	# anywhere else to look ???
			return tmp

		def _getMacKernelVersion(self) -> str:
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osrelease"])
			if not tmp:
				pass	# anywhere else to look ???
			return tmp

		def _getMacId(self, verMajor: int, verMinor: int) -> str:
			result = ""
			#if verMajor > 10:
			#	result = f"mac.{verMajor}"
			#elif verMajor == 10:
			result = f"mac.{verMajor}.{verMinor}"
			return result

		def _getMacCodename(self, osCodenames: list["OSDetails._osCodename"], verMajor: int, verMinor: int) -> str:
			for ver in osCodenames:
				if verMajor == ver.major and (verMinor == ver.minor or ver.minor < 0):
					return ver.codename
			return ""

		def _getMacBuildNumber(self) -> str:
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osversion"])
			if not tmp:
				pass	# anywhere else to look ???
			return tmp

		def _getMacRevision(self) -> int:
			result = -1
			tmp = _OSDetailsMac._getCommandOutput(["sysctl", "-hin", "kern.osrevision"])
			if not tmp:
				pass	# anywhere else to look ???
			if tmp:
				result = int(tmp.replace(',', ''))
			return result

		def _getMacOSArch(self) -> tuple[str, int]:
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
		# endregion

else:
	raise NotImplementedError(f'unrecognized platform: "{sys.platform}"')
