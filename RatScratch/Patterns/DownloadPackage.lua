local https = require("https")
local Console = require("RatScratch.Console")
local json = require("lib.json")
local MetaService = require("RatScratch.Services.MetaService")

local function isPackageWithHashDownloaded(hash)
	local inputHash = hash:match(".+:(.+)")
	local existingPackagePath = ("staging/lib/.tmp/%s.zip"):format(inputHash)
	local existingPackageMetaPath = ("staging/lib/.tmp/%s.rsmeta"):format(inputHash)
	if love.filesystem.getInfo(existingPackagePath, "file") then
		local hashAlgorithm = hash:match("(.+):")

		local fileData = love.filesystem.read(existingPackagePath)
		local fileHash = love.data.encode("string", "hex", love.data.hash("string", hashAlgorithm, fileData))

		if fileHash == inputHash then
			return true, MetaService.parseMeta(existingPackageMetaPath)[1]
		end
	end

	return false
end

local function isPackageDownloaded(inputMeta)
	if inputMeta.hash then
		return isPackageWithHashDownloaded(inputMeta.hash)
	end

	local meta = MetaService.parseMeta()
	for i = 2, #meta do
		local childMeta = meta[i]
		if childMeta.name == inputMeta.name and childMeta.version == inputMeta.version then
			return isPackageWithHashDownloaded(childMeta.hash), childMeta
		end
	end

	return false, nil
end

local function DownloadPackage(inputMeta, urls, headers)
	local isDownloaded, downloadedMeta = isPackageDownloaded(inputMeta)
	if isDownloaded and downloadedMeta then
		Console.print(
			'Package "%s@%s" cached from "%s"; not downloading again.',
			downloadedMeta.name,
			downloadedMeta.version,
			downloadedMeta.url
		)
		return true, downloadedMeta.hash, downloadedMeta.url
	end

	local blob, blobHash, blobURL
	for _, url in ipairs(urls) do
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
			if isHTTP or inputMeta.hash then
				Console.assert(not isHTTP or inputMeta.hash, "need to provide hash for HTTP URLs")

				local hashAlgorithm = inputMeta.hash:match("(.+):")
				local hash = love.data.encode("string", "hex", love.data.hash("string", hashAlgorithm, data))
				local inputHash = inputMeta.hash:match(".+:(.+)")

				Console.assert(
					hash == inputHash,
					"%s hash mismatch; got %s, expected %s",
					hashAlgorithm,
					hash,
					inputHash
				)

				blobHash = ("%s:%s"):format(hashAlgorithm, hash)
			else
				local hash = love.data.encode("string", "hex", love.data.hash("string", "sha512", data))
				blobHash = ("sha512:%s"):format(hash)
			end

			blob = data
			blobURL = url

			break
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

	return blob, blobHash, blobURL
end

return DownloadPackage
