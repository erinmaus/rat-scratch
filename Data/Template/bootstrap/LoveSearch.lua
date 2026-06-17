local LoveSearch = {}
local LoveSearchMetatable = { __index = LoveSearch }

function LoveSearch.new(common)
	return setmetatable({
		common = common,
		libs = {},
	}, LoveSearchMetatable)
end

function LoveSearch:isFile(path)
	return love.filesystem.getInfo(path, "file") ~= nil
end

function LoveSearch:collectRSLibs(path)
	local parentPath = path or self.common:getPath()

	local siblings = love.filesystem.getDirectoryItems(parentPath)

	local packages = {}
	for _, sibling in ipairs(siblings) do
		local localPath = string.format("%s/%s", parentPath, sibling)
		local siblingInfo = love.filesystem.getInfo(localPath)
		local isRSLib = self:isRSLib(localPath)

		local localPackages = {
			path = localPath,
			isRSLib = isRSLib,
			type = siblingInfo.type,
		}

		if isRSLib then
			local metaFilename = string.format("%s/.rsmeta", localPath)
			local metaFileData = love.filesystem.read(metaFilename)

			local childPackages = self.common:parseTOML(metaFileData)
			childPackages[1].isRSLib = true

			localPackages.packages = childPackages
			for i = 2, #localPackages.packages do
				local childPackage = childPackages[i]
				childPackage.path = string.format("%s/lib/%s", localPath, childPackage.name)
				childPackage.isRSLib = self:isChildRSLib(childPackage.path)
			end
		end

		table.insert(packages, localPackages)
	end

	return packages
end

function LoveSearch:isChildRSLib(path)
	local metaFile = string.format("%s/.rsmeta", path)

	local hasMetaFile = not not love.filesystem.getInfo(metaFile, "file")
	local isDirectory = not not love.filesystem.getInfo(path, "directory")

	return hasMetaFile and isDirectory
end

function LoveSearch:isRSLib(path)
	local metaFile = string.format("%s/.rsmeta", path)
	local sourceDirectory = string.format("%s/source", path)
	local bootstrapDirectory = string.format("%s/bootstrap", path)

	local isDirectory = not not love.filesystem.getInfo(path, "directory")
	local hasMetaFile = not not love.filesystem.getInfo(metaFile, "file")
	local hasSourceDirectory = not not love.filesystem.getInfo(sourceDirectory, "directory")
	local hasBootstrapDirectory = not not love.filesystem.getInfo(bootstrapDirectory, "directory")

	return isDirectory and hasMetaFile and hasSourceDirectory and hasBootstrapDirectory
end

return LoveSearch
