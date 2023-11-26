#!python3
# -*- coding: utf-8 -*-

# this uses the imagehash library: install it with e.g. py [-<python version>] -m pip install imagehash==4.0
#    this will also install the libraries that it depends on

import sys, os, pathlib, datetime, glob, csv, hashlib, argparse, time
from ackPyHelpers import LogHelper
from PIL import Image
import imagehash
from operator import itemgetter

PyScript = pathlib.Path(os.path.abspath(__file__))
PyScriptRoot = pathlib.Path(os.path.dirname(os.path.abspath(__file__)))

def main():
	args = initArgParser().parse_args()
	LogHelper.Init(args.verbose if "verbose" in args else False)
	if args.commandName == "ShowImportHashes":
		ShowImportHashes()
	elif args.commandName == "CheckForDupeImports":
		CheckForDupeImports()
	else:
		CheckImportsForDuplicates()

def initArgParser() -> argparse.ArgumentParser:
	parser = argparse.ArgumentParser()
	subparsers = parser.add_subparsers(dest="commandName", title="Commands")		# 'commandName' will be set to values passed to add_parser
	command01 = subparsers.add_parser("CheckImports", aliases=["c1"], help="check imports for duplicates against previous images (default command)")
	command01.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	command02 = subparsers.add_parser("ShowImportHashes", help="show hashes of files in the imports folder")
	command02.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	command02 = subparsers.add_parser("CheckForDupeImports", help="look for dupes in files in the imports folder")
	command02.add_argument("-v", "--verbose", action="store_true", help="enable verbose logging")
	return parser

class ImageHashInfo:
	@staticmethod
	def FromCsvRow(row):
#		return ImageHashInfo(row[0], imagehash.hex_to_hash(row[1]))
		return ImageHashInfo(row['Filename'], imagehash.hex_to_hash(row['PHash']), row['SHA256'], row['SHA1'], row['MD5'])

	@staticmethod
	def FromImageFile(imagePath, withAllHashes):
		hashes = ImageHashInfo._getImageHashes(imagePath, withAllHashes)
		if hashes:
			return ImageHashInfo(os.path.normcase(os.path.basename(imagePath)), hashes[0], hashes[1], hashes[2], hashes[3])
		else:
			return None

	@staticmethod
	def _getImageHashes(imgpath, withAllHashes):
		try:
			LogHelper.Verbose('_getImageHashes(): reading file "{0}" as image', imgpath)
			img = Image.open(imgpath)
		except OSError as ex:
			LogHelper.Warning('_getImageHashes(): could not read file "{0}" as image', imgpath)
			return None
		phash = imagehash.phash(img)
		if (withAllHashes):
			hMd5 = hashlib.md5()
			hSha1 = hashlib.sha1()
			hSha256 = hashlib.sha256()
			with open(imgpath, 'rb', buffering=0) as f:
				for chunk in iter(lambda : f.read(128*1024), b''):
					hMd5.update(chunk)
					hSha1.update(chunk)
					hSha256.update(chunk)
			sha256 = hSha256.hexdigest()
			sha1 = hSha1.hexdigest()
			md5 = hMd5.hexdigest()
		else:
			sha256 = sha1 = md5 = ''
		return [phash, sha256, sha1, md5]

	def __init__(self, name, phash, sha256, sha1, md5):
		self.Filename = name
		self.PHash = phash
		self.SHA256 = sha256
		self.SHA1 = sha1
		self.MD5 = md5

class SpotlightImageHashesDb:
	SpotlightFolder = os.path.expandvars('$UserProfile\\Pictures\\backgrounds & wallpaper\\Spotlight')
	SpotlightOneDriveFolder = os.path.expandvars('$OneDrive\\Pictures\\spotlight')
	SpotlightImportFolder = os.path.join(SpotlightFolder, 'import')
	ImageHashesDb = os.path.join(SpotlightOneDriveFolder, '$imagePHashes.csv')

	def __init__(self):
		self._imageHashes = self._loadDb()
		self._isDirty = False

	def _loadDb(self):
		imgFileHashes = []
		if os.path.exists(SpotlightImageHashesDb.ImageHashesDb):
			LogHelper.Verbose('_loadDb(): reading hashes from csv file "{0}"', SpotlightImageHashesDb.ImageHashesDb)
			with open(SpotlightImageHashesDb.ImageHashesDb, 'r', newline='') as f:
#				csvReader = csv.reader(f)
				csvReader = csv.DictReader(f)
				for row in csvReader:
					imgFileHashes.append(ImageHashInfo.FromCsvRow(row))
		else:
			LogHelper.Verbose('_loadDb(): hashes file "{0}" does not exist', SpotlightImageHashesDb.ImageHashesDb)
		LogHelper.Verbose('_loadDb(): read {0} hashes from file "{1}"', len(imgFileHashes), SpotlightImageHashesDb.ImageHashesDb)
		return imgFileHashes

	def _addImage(self, imagePath):
		hashInfo = ImageHashInfo.FromImageFile(imagePath, True)
		if (hashInfo):
			LogHelper.Info('_addImage(): adding new image "{0}" to hashes db list', hashInfo.Filename)
			self._imageHashes.append(hashInfo)
			self._isDirty = True

	def _containsImage(self, imagePath):
		#LogHelper.Verbose('_containsImage(): checking file "{0}"', imagePath)
		imgFilename = os.path.normcase(os.path.basename(imagePath))
		for hashInfo in self._imageHashes:
			#LogHelper.Verbose('_containsImage(): comparing imgFilename = "{0}" to hashInfo.Filename = "{1}"', imgFilename, hashInfo.Filename)
			if imgFilename == hashInfo.Filename:
				#LogHelper.Verbose('_containsImage(): returning True')
				return True
		#LogHelper.Verbose('_containsImage(): returning False')
		return False

	def SaveChanges(self):
		if self._isDirty:
			LogHelper.Info('SaveChanges(): writing hashes to csv file "{0}"', SpotlightImageHashesDb.ImageHashesDb)
			# TODO: should we make a backup first?
			with open(SpotlightImageHashesDb.ImageHashesDb, 'w', newline='') as f:
#				csvWriter = csv.writer(f)
				csvWriter = csv.DictWriter(f, fieldnames=['Filename', 'PHash', 'SHA256', 'SHA1', 'MD5'], quoting=csv.QUOTE_ALL)
				csvWriter.writeheader()
				for hashInfo in sorted(self._imageHashes, key=lambda h: h.Filename):
#					csvWriter.writerow([hashInfo.Filename, hashInfo.PHash])
					csvWriter.writerow({'Filename': hashInfo.Filename, 'PHash': hashInfo.PHash, 'SHA256': hashInfo.SHA256, 'SHA1': hashInfo.SHA1, 'MD5': hashInfo.MD5})
		else:
			LogHelper.Verbose('SaveChanges(): _isDirty flag not set, not saving anything')

	def CheckForNewImages(self):
		LogHelper.Verbose('CheckForNewImages(): looking for new images in folder "{0}"', SpotlightImageHashesDb.SpotlightFolder)
		for img in glob.glob(os.path.join(SpotlightImageHashesDb.SpotlightFolder, '*.jpg')):
			if not self._containsImage(img):
				self._addImage(img)

	def FindMatchingImages(self, imagePathToCompare):
		toCompareHashInfo = ImageHashInfo.FromImageFile(imagePathToCompare, False)
		if toCompareHashInfo:
			LogHelper.Verbose('FindMatchingImages(): checking file "{0}": pHash = {1}', os.path.basename(imagePathToCompare), toCompareHashInfo.PHash)
			for existingHashInfo in self._imageHashes:
				phDiff = existingHashInfo.PHash - toCompareHashInfo.PHash
				if phDiff <=5:
					LogHelper.Verbose('FindMatchingImages(): probable match: existing file pHash = {0}, new file pHash = {1}', existingHashInfo.PHash, toCompareHashInfo.PHash)
					yield [existingHashInfo.Filename, phDiff]

def CheckImportsForDuplicates():
	imageHashes = SpotlightImageHashesDb()
	imageHashes.CheckForNewImages()
	imageHashes.SaveChanges()

	LogHelper.Info('comparing imported image hashes to previously saved images')
	for img in glob.glob(os.path.join(SpotlightImageHashesDb.SpotlightImportFolder, '_*.jpg')):
		for matchingImage in imageHashes.FindMatchingImages(img):
			phDiff = matchingImage[1]
			if phDiff == 0:
				LogHelper.Warning('==> import image "{0}" is same as image "{1}": phash diff = {2}', os.path.basename(img), matchingImage[0], phDiff)
				folder, filename = os.path.split(img)
				os.rename(img, os.path.join(folder, '!' + filename))
			elif phDiff <= 4:# and whDiff <= 5:
				LogHelper.Warning('??? import image "{0}" may be same as image "{1}": phash diff = {2}', os.path.basename(img), matchingImage[0], phDiff)
	LogHelper.Info('completed checking for duplicate images')

def ShowImportHashes():
	LogHelper.Info('')
	LogHelper.Info(f"{'Filename':<26}  {'PHash':<16}  {'SHA1':<40}  {'Modified':<19}")
	LogHelper.Info(f"{'='*26:<26}  {'='*16:<16}  {'='*40:<40}  {'='*19:<19}")
	imageInfos = []
	for img in glob.glob(os.path.join(SpotlightImageHashesDb.SpotlightImportFolder, '_*.jpg')):
		imgHashInfo = ImageHashInfo.FromImageFile(img, True)
		if imgHashInfo:
			modTime = datetime.datetime.fromtimestamp(os.path.getmtime(img)).strftime('%Y-%m-%d %H:%M:%S')
			imageInfos.append((os.path.basename(img), str(imgHashInfo.PHash), imgHashInfo.SHA1, modTime))
	for info in sorted(imageInfos, key=itemgetter(2,1,3)):	# sort by SHA1, then by PHash, then by modified time
		LogHelper.Info(f'{info[0]}  {info[1]}  {info[2]}  {info[3]}')

def CheckForDupeImports():
	hashes = dict()
	for img in glob.glob(os.path.join(SpotlightImageHashesDb.SpotlightImportFolder, '_*.jpg')):
		imgHashInfo = ImageHashInfo.FromImageFile(img, True)
		if imgHashInfo:
			modTime = datetime.datetime.fromtimestamp(os.path.getmtime(img)).strftime('%Y-%m-%d %H:%M:%S')
			if imgHashInfo.SHA256 in hashes:
				hashes[imgHashInfo.SHA256].append((img, imgHashInfo.Filename, modTime))
			else:
				hashes[imgHashInfo.SHA256] = [ (img, imgHashInfo.Filename, modTime) ]
	for k in hashes:
		files = hashes[k]
		if len(files) > 1:
			first = True
			LogHelper.Info(f"duplicates, will keep first: {', '.join(f[1] for f in files)}'")
			for f in sorted(files, key=itemgetter(2)):	# sort by mod time
				if first:
					first = False
				else:
					folder, filename = os.path.split(f[0])
					newName = os.path.join(folder, '@' + filename)
					LogHelper.Verbose("renaming '{0}' to '{1}'", f[0], newName)
					os.rename(f[0], newName)

if __name__ == '__main__':
	sys.exit(main())
