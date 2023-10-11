#!python3
# -*- coding: utf-8 -*-

import sys, urllib.request, json
if sys.platform == "win32":
	import ctypes
	from ctypes import wintypes, byref, POINTER

class GithubRelease:
	"""
	a helper class for getting Github release infomation.

	Use the static methods GetLatestRelease and/or GetReleaseForTag to retrieve info.

	e.g.:
	from githubHelper import GithubRelease
	latest = GithubRelease.GetLatestRelease("microsoft", "vscode")
	release = GithubRelease.GetReleaseForTag("microsoft", "vscode", "1.82.0")
	"""

	_latestReleaseUrlTemplate: str = "https://api.github.com/repos/{0}/{1}/releases/latest"
	_releaseUrlTemplate: str = "https://api.github.com/repos/{0}/{1}/releases/tags/{2}"

	class GithubReleaseAsset:
		"contains information about a release asset (i.e. a file)"

		def __init__(self, assetDict: dict):
			if not assetDict:
				raise ValueError("must provide some asset data retrieved from a Github release")
			self._id: int = assetDict['id']
			self._name: str = assetDict['name']
			self._label: str = assetDict['label']
			self._contentType: str = assetDict['content_type']
			self._size: int = assetDict['size']
			self._createdAt: str = assetDict['created_at']
			self._updatedAt: str = assetDict['updated_at']
			self._downloadUrl: str = assetDict['browser_download_url']

		def __repr__(self):
			return f'<GithubReleaseAsset: name="{self.name}", label="{self.label}", download="{self.downloadUrl}">'

		@property
		def id(self) -> int:
			"returns the Github ID for this asset"
			return self._id

		@property
		def name(self) -> str:
			"returns the name specified for this asset"
			return self._name if self._name else ""

		@property
		def label(self) -> str:
			"returns the label specified for this asset"
			return self._label if self._label else ""

		@property
		def contentType(self) -> str:
			"returns the content type/mime type specified for this asset"
			return self._contentType if self._contentType else ""

		@property
		def size(self) -> int:
			"returns the size in bytes of this asset"
			return self._size

		@property
		def created(self) -> str:
			"returns the timestamp at which this asset was created"
			return self._createdAt if self._createdAt else ""

		@property
		def updated(self) -> str:
			"returns the timestamp at which this asset was updated"
			return self._updatedAt if self._updatedAt else ""

		@property
		def downloadUrl(self) -> str:
			"returns the download URL for this asset"
			return self._downloadUrl if self._downloadUrl else ""

	def __init__(self, releaseJson: str):
		if not releaseJson:
			raise ValueError("must provide some json retrieved from a Github release")
		j = json.loads(releaseJson)
		self._id: int = j['id']
		self._releaseUrl: str = j['html_url']
		self._tag: str = j['tag_name']
		self._name: str = j['name']
		self._createdAt: str = j['created_at']
		self._publishedAt: str = j['published_at']
		self._assets = []
		for asset in j['assets']:
			self._assets.append(GithubRelease.GithubReleaseAsset(asset))

	def __repr__(self):
		return f'<GithubRelease: tag="{self.tag}", name="{self.name}", asset count={len(self.assets)}, url="{self.url}">'

	@staticmethod
	def GetLatestRelease(owner: str, repo: str):# -> Self:	#only for 3.11+ ?? so not yet...
		"retrieves the latest release information for the specified owner and repository"
		url = GithubRelease._latestReleaseUrlTemplate.format(owner, repo)
		logging.debug(f"getting url |{url}|")
		with urllib.request.urlopen(url) as resp:
			return GithubRelease(resp.read())

	@staticmethod
	def GetReleaseForTag(owner: str, repo: str, tag: str):# -> Self:	#only for 3.11+ ?? so not yet...
		"retrieves the release information for the specified owner, repository and tag"
		url = GithubRelease._releaseUrlTemplate.format(owner, repo, tag)
		logging.debug(f"getting url |{url}|")
		with urllib.request.urlopen(url) as resp:
			return GithubRelease(resp.read())

	@property
	def id(self) -> int:
		"returns the Github ID of this release"
		return self._id

	@property
	def url(self) -> str:
		"returns the web url for this release"
		return self._releaseUrl if self._releaseUrl else ""

	@property
	def tag(self) -> str:
		"returns the tag for this release"
		return self._tag if self._tag else ""

	@property
	def name(self) -> str:
		"returns the name of this release"
		return self._name if self._name else ""

	@property
	def created(self) -> str:
		"returns the timestamp at which this release was created"
		return self._createdAt if self._createdAt else ""

	@property
	def published(self) -> str:
		"returns the timestamp at which this release was published"
		return self._publishedAt if self._publishedAt else ""

	@property
	def assets(self) -> list[GithubReleaseAsset]:
		"returns the list of assets (files) for this release"
		return self._assets
