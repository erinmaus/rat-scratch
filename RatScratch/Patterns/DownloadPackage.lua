local https = require("https")
local Console = require("RatScratch.Console")
local json = require("lib.json")
local MetaService = require("RatScratch.Services.MetaService")
local PackageService = require("RatScratch.Services.PackageService")

local function isPackageWithHashDownloaded(inputMeta)
	local inputHash = inputMeta.hash and inputMeta.hash:match(".+:(.+)")
		or PackageService.isRegistered(inputMeta) and PackageService.getPackageHash(inputMeta)
	if not inputHash then
		return false, nil
	end

	if not PackageService.isRegistered(inputHash) then
		return false, nil
	end

	local existingPackagePath = ("staging/lib/.tmp/%s.zip"):format(inputHash)

	if not love.filesystem.getInfo(existingPackagePath, "file") then
		return false, inputMeta
	end

	local rootPath = PackageService.getPackagePath(inputHash)
	local metaFilename1 = ("%s/%s.rsmeta"):format(rootPath, inputMeta.name)
	local metaFilename2 = ("staging/lib/.tmp/%s.rsmeta"):format(inputHash)

	local resultMeta
	if love.filesystem.getInfo(metaFilename1, "file") then
		resultMeta = MetaService.parseMeta(metaFilename1)[1]
		resultMeta.url = inputMeta.url
		resultMeta.hash = inputMeta.hash

		PackageService.registerPackage(resultMeta, rootPath, inputHash)
	end

	if love.filesystem.getInfo(metaFilename2, "file") then
		local baseMeta = MetaService.parseMeta(metaFilename2)[1]
		resultMeta = resultMeta or baseMeta
		resultMeta.url = baseMeta.url
	end

	return not not resultMeta, resultMeta
end

local function isPackageDownloaded(inputMeta)
	local success, resultMeta = isPackageWithHashDownloaded(inputMeta)
	if success then
		return resultMeta
	end

	local meta = MetaService.parseMeta()
	for i = 2, #meta do
		local childMeta = meta[i]
		if childMeta.name == inputMeta.name and childMeta.version == inputMeta.version and childMeta.hash then
			return isPackageWithHashDownloaded(childMeta)
		end
	end

	return false, nil
end

local function downloadPackage(inputMeta, url, headers)
	Console.print("Trying to download package from URL '%s'...", url)

	local before = love.timer.getTime()

	local response, data
	if headers and next(headers) then
		response, data = https.request(url, headers and {
			method = "GET",
			headers = headers,
		})
	else
		response, data = https.request(url)
	end
	local after = love.timer.getTime()

	local timeInMS = (after - before) * 1000
	if response and data and response >= 200 and response <= 299 then
		Console.print("Successfully downloaded package in %.2f ms.", timeInMS)

		local isHTTP = url:match("^http://")
		local blobHash
		if isHTTP or inputMeta.hash then
			Console.assert(not isHTTP or inputMeta.hash, "need to provide hash for HTTP URLs")

			local hashAlgorithm = inputMeta.hash:match("(.+):")
			local hash = love.data.encode("string", "hex", love.data.hash("string", hashAlgorithm, data))
			local inputHash = inputMeta.hash:match(".+:(.+)")

			Console.assert(hash == inputHash, "%s hash mismatch; got %s, expected %s", hashAlgorithm, hash, inputHash)

			blobHash = ("%s:%s"):format(hashAlgorithm, hash)
		else
			local hash = love.data.encode("string", "hex", love.data.hash("string", "sha512", data))
			blobHash = ("sha512:%s"):format(hash)
		end

		return data, blobHash, url
	else
		Console.warn("Failed to download package in %.2f ms.", timeInMS)

		if data and response and response >= 100 then
			local isJSON, json = pcall(json.decode, data)
			local minifiedJSON = isJSON and json.encode(json)
			local isPlainText = data:match("^[\x21-\x7e]+$")

			if minifiedJSON then
				Console.warn("Received response code %d from URL with JSON response: %s", response, minifiedJSON)
			elseif isPlainText then
				Console.warn("Recieved response code %d from URL with plain-text response: %s", response, data)
			end
		elseif response then
			if data then
				Console.warn("Recieved underlying error code %d from URL with message: %s", response, data)
			else
				Console.warn("Recieved underlying error code %d from URL with no message.", response)
			end
		else
			Console.warn("Recieved unknown error while trying to download package.")
		end
	end
end

local function DownloadPackage(inputMeta, urls, parentMeta, headers)
	local isDownloaded, downloadedMeta = isPackageDownloaded(inputMeta)
	if isDownloaded and downloadedMeta then
		Console.print(
			'Package "%s@%s" cached from "%s"; not downloading again.',
			downloadedMeta.name,
			downloadedMeta.version,
			downloadedMeta.url
		)

		return true, downloadedMeta.hash, downloadedMeta.url, downloadedMeta
	end

	local blob, blobHash, blobURL, blobMeta
	for _, url in ipairs(urls) do
		if not url:match("https?://") and url:match("(.*)%.rsmeta") and parentMeta then
			local rootPath = PackageService.getPackagePath(parentMeta)
			local hash = PackageService.getPackageHash(parentMeta)

			local downloadedMeta
			local downloadedMetaFilename = ("staging/lib/.tmp/%s.rsmeta"):format(hash)
			if love.filesystem.getInfo(downloadedMetaFilename, "file") then
				downloadedMeta = MetaService.parseMeta(downloadedMetaFilename)[1]
			end

			Console.assert(
				rootPath,
				"could not find path for parent package %s@%s",
				parentMeta.name,
				parentMeta.version
			)

			blobMeta = MetaService.clone(inputMeta)
			blobMeta.url = downloadedMeta and downloadedMeta.url or parentMeta.url or url
			blobMeta.hash = downloadedMeta and downloadedMeta.hash or hash
			blobMeta.root = downloadedMeta and downloadedMeta.root or parentMeta.root

			local rootMetaPath = ("%s/%s"):format(rootPath, url)
			local childMeta = MetaService.parseMeta(rootMetaPath)[1]
			blobMeta.name = childMeta.name
			blobMeta.version = childMeta.version
			blobMeta.source = childMeta.source

			blob = true
			blobHash = parentMeta.hash
			blobURL = url

			PackageService.registerPackage(blobMeta, rootPath, hash)
			break
		else
			blob, blobHash, blobURL = downloadPackage(inputMeta, url, headers)
			if blob and blobHash and blobURL then
				blobMeta = MetaService.clone(inputMeta)
				blobMeta.url = blobURL
				blobMeta.hash = blobHash
				break
			end
		end
	end

	return blob, blobHash, blobURL, blobMeta or MetaService.clone(inputMeta)
end

return DownloadPackage
