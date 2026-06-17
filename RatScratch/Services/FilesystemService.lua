local ffi = require("ffi")
local jit = require("jit")
local Console = require("RatScratch.Console")

local FilesystemService = {}
FilesystemService.MAX_PATH = 4096

FilesystemService.PATH_SEPARATOR = "[/\\]"

local currentPathPattern = "%." .. FilesystemService.PATH_SEPARATOR
local relativePathPattern = "^(.*)" .. FilesystemService.PATH_SEPARATOR .. ".+$"
local relativePathSubstitution = "%1/"

function FilesystemService.makeAbsolutePath(path)
	local oldPath
	local newPath = path

	repeat
		oldPath = newPath

		local i, j = oldPath:find("..", 1, true)
		if i and j then
			local prefix = oldPath:sub(1, i - 1):gsub(relativePathPattern, relativePathSubstitution)
			local suffix = oldPath:sub(j + 2)

			newPath = prefix .. suffix
		else
			newPath = oldPath
		end
	until oldPath == newPath

	local result = newPath:gsub(currentPathPattern, ""):gsub("\\", "/")
	return result
end

function FilesystemService.buildPath(rootPath, ...)
	local result = { rootPath or love.filesystem.getWorkingDirectory(), ... }
	local path = table.concat(result, "/")
	return FilesystemService.makeAbsolutePath(path)
end

function FilesystemService.mountModuleDirectory(path)
	love.filesystem.mountFullPath(path, "staging/module", "readwrite", false)
end

function FilesystemService.mountLibraryDirectory(relativePath)
	local path = FilesystemService.buildPath("staging/module", relativePath)
	love.filesystem.createDirectory(path)

	local tmpPath = FilesystemService.buildPath(path, ".tmp")
	love.filesystem.createDirectory(tmpPath)

	local nativePath = FilesystemService.buildPath(love.filesystem.getRealDirectory("staging/module"), relativePath)
	love.filesystem.mountFullPath(nativePath, "staging/lib", "readwrite", false)
end

function FilesystemService.recurse(path, func)
	local items = love.filesystem.getDirectoryItems(path)
	table.sort(items)

	for _, item in ipairs(items) do
		local itemPath = ("%s/%s"):format(path, item)

		local info = love.filesystem.getInfo(itemPath)

		local result
		if info.type == "directory" then
			result = func(itemPath, function()
				return FilesystemService.recurse(itemPath, func)
			end)
		else
			result = func(itemPath)
		end

		if result ~= nil then
			return result
		end
	end

	return nil
end

function FilesystemService.delete(rootPath)
	FilesystemService.recurse(rootPath, function(path, recurse)
		if recurse then
			recurse()
		end

		Console.assert(love.filesystem.remove(path), 'could not remove file or directory at path "%s"', path)
	end)

	Console.assert(love.filesystem.remove(rootPath), 'could not remove file or directory at path "%s"', rootPath)
end

function FilesystemService.clear(rootPath)
	local items = love.filesystem.getDirectoryItems(rootPath)
	table.sort(items)

	for _, item in ipairs(items) do
		local itemPath = ("%s/%s"):format(rootPath, item)

		FilesystemService.delete(itemPath)
	end
end

function FilesystemService.copy(from, to)
	Console.assert(
		love.filesystem.getInfo(to) == nil,
		'cannot copy source "%s" to destination "%s": destination exists',
		from,
		to
	)

	if love.filesystem.getInfo(from, "file") then
		local folderPath = FilesystemService.buildPath(to, "..")

		love.filesystem.createDirectory(folderPath)
		love.filesystem.write(to, love.filesystem.read(from))
	else
		FilesystemService.recurse(from, function(path, recurse)
			if recurse then
				recurse()
			else
				local _, j = path:find(from, 1, true)
				local relativePath = path:sub((j or 0) + 1):gsub("^/", "")

				local destinationPath = ("%s/%s"):format(to, relativePath)
				local folderPath = FilesystemService.buildPath(destinationPath, "..")

				love.filesystem.createDirectory(folderPath)
				love.filesystem.write(destinationPath, love.filesystem.read(path))
			end
		end)
	end
end

function FilesystemService.mountBuildDirectory(relativePath)
	local path = FilesystemService.buildPath("staging/module", relativePath)
	love.filesystem.createDirectory(path)

	local nativePath = FilesystemService.buildPath(love.filesystem.getRealDirectory("staging/module"), relativePath)
	love.filesystem.mountFullPath(nativePath, "staging/build", "readwrite", false)
end

function FilesystemService.unmount()
	local libPath = love.filesystem.getRealDirectory("staging/lib")
	local buildPath = love.filesystem.getRealDirectory("staging/build")
	local modulePath = love.filesystem.getRealDirectory("staging/module")

	love.filesystem.unmountFullPath(libPath)
	love.filesystem.unmountFullPath(buildPath)
	love.filesystem.unmountFullPath(modulePath)
end

return FilesystemService
