local LoveFilesystem = {}

function LoveFilesystem.write(filename, data)
	local success = love.filesystem.write(filename, data)
	return success
end

function LoveFilesystem.read(filename)
	local data = love.filesystem.read(filename)
	return data
end

function LoveFilesystem.getDirectoryItems(path)
	local result = love.filesystem.getDirectoryItems(path)
	table.sort(result)

	return result
end

function LoveFilesystem.createDirectory(path)
	local success = love.filesystem.createDirectory(path)
	return success
end

function LoveFilesystem.remove(path)
	local success = love.filesystem.remove(path)
	return success
end

function LoveFilesystem.exists(path, type)
	if type == "file" or type == "directory" then
		return love.filesystem.getInfo(path, type) ~= nil
	end

	return love.filesystem.getInfo(path) ~= nil
end

return LoveFilesystem
