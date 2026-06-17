local FilesystemService = require("RatScratch.Services.FilesystemService")
local Console = require("RatScratch.Console")
local clear = require("table.clear")
local PackageService = {}

PackageService.MOUNTED = {}
PackageService.REGISTERED = {}

function PackageService.saveAndMountPackage(hash, data)
	if type(data) == "string" then
		PackageService._savePackage(hash, data)
	end

	PackageService._mountPackage(hash)
	return ("staging/download/%s"):format(hash)
end

function PackageService.savePackageMeta(hash, meta)
	local filename = ("staging/lib/.tmp/%s.rsmeta"):format(hash)
	love.filesystem.write(filename, meta)
end

function PackageService.unmount()
	local items = love.filesystem.getDirectoryItems("staging/download")

	for _, item in ipairs(items) do
		local itemPath = ("staging/download/%s"):format(item)
		local nativePath = love.filesystem.getRealDirectory(itemPath)
		love.filesystem.unmountFullPath(nativePath)
	end

	clear(PackageService.MOUNTED)
	clear(PackageService.REGISTERED)
end

function PackageService._savePackage(hash, data)
	local filename = ("staging/lib/.tmp/%s.zip"):format(hash)
	love.filesystem.write(filename, data)
end

function PackageService._mountPackage(hash)
	local relativeFilename = (".tmp/%s.zip"):format(hash)
	local rootPath = love.filesystem.getRealDirectory("staging/lib")
	local filename = FilesystemService.buildPath(rootPath, relativeFilename)

	local mountPath = ("staging/download/%s"):format(hash)
	love.filesystem.mountFullPath(filename, mountPath)
end

function PackageService.getRootPath(meta, hash)
	local rootFolder = ("staging/download/%s"):format(hash)

	if meta.root then
		local currentFolder = rootFolder
		local nextFolder

		for folderPattern in meta.root:gmatch("(.*)/?") do
			if #folderPattern == 0 then
				break
			end

			local items = love.filesystem.getDirectoryItems(currentFolder)
			table.sort(items)

			local found = false
			for _, item in ipairs(items) do
				local itemPath = ("%s/%s"):format(currentFolder, item)
				if love.filesystem.getInfo(itemPath, "directory") and item:match(folderPattern) then
					found = true
					nextFolder = itemPath
					break
				end
			end

			if not found then
				break
			end

			currentFolder = nextFolder
		end

		rootFolder = currentFolder
	end

	return rootFolder
end

function PackageService.registerPackage(meta, root, hash)
	PackageService.MOUNTED[hash] = root

	local nameVersionKey = ("%s@%s"):format(meta.name, meta.version)
	PackageService.REGISTERED[nameVersionKey] = hash
end

function PackageService.isRegistered(meta)
	local nameVersionKey = ("%s@%s"):format(meta.name, meta.version)
	return PackageService.REGISTERED[nameVersionKey] ~= nil
end

function PackageService.getPackagePath(meta)
	Console.assert(PackageService.isRegistered(meta), 'package "%s@%s" is not registered', meta.name, meta.version)

	local nameVersionKey = ("%s@%s"):format(meta.name, meta.version)
	local hash = PackageService.REGISTERED[nameVersionKey]
	return PackageService.MOUNTED[hash]
end

return PackageService
