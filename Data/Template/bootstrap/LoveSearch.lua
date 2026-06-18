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
		local localPath = ("%s/%s"):format(parentPath, sibling)
		local siblingInfo = love.filesystem.getInfo(localPath)
		local isRSLib = self:isRSLib(localPath)

		local localPackages = {
			path = localPath,
			isRSLib = isRSLib,
			type = siblingInfo.type,
		}

		if isRSLib then
			local metaFilename = ("%s/.rsmeta"):format(localPath)
			local metaFileData = love.filesystem.read(metaFilename)

			local meta = self.common:parseTOML(metaFileData)
			local childPackages = {}
			for _, m in ipairs(meta) do
				local r = {}
				for k, v in pairs(m) do
					r[k] = v
				end
				table.insert(childPackages, m)
			end

			childPackages[1].isRSLib = true
			localPackages.packages = childPackages
			localPackages.meta = meta

			local childrenPrefix = (childPackages[1]["directory.library"] or "./lib")
				:gsub("^%.?/*", "")
				:gsub("/*$", "")
				:gsub("/", ".")

			for i = 2, #localPackages.packages do
				local childPackage = childPackages[i]
				childPackage.path = ("%s/%s/%s"):format(localPath, childrenPrefix, childPackage.name)
				childPackage.isRSLib = self:isChildRSLib(childPackage.path)

				if childPackage.isRSLib then
					local childMetaFilename = ("%s/.rsmeta"):format(childPackage.path)
					local childMetaFileData = love.filesystem.read(childMetaFilename)
					childPackage.meta = childMetaFileData and self.common:parseTOML(metaFileData)
				end
			end
		end

		table.insert(packages, localPackages)
	end

	return packages
end

function LoveSearch:isChildRSLib(path)
	local metaFile = ("%s/.rsmeta"):format(path)

	local hasMetaFile = not not love.filesystem.getInfo(metaFile, "file")
	local isDirectory = not not love.filesystem.getInfo(path, "directory")

	return hasMetaFile and isDirectory
end

function LoveSearch:isRSLib(path)
	local metaFile = ("%s/.rsmeta"):format(path)
	local sourceDirectory = ("%s/source"):format(path)
	local bootstrapDirectory = ("%s/bootstrap"):format(path)

	local isDirectory = not not love.filesystem.getInfo(path, "directory")
	local hasMetaFile = not not love.filesystem.getInfo(metaFile, "file")
	local hasSourceDirectory = not not love.filesystem.getInfo(sourceDirectory, "directory")
	local hasBootstrapDirectory = not not love.filesystem.getInfo(bootstrapDirectory, "directory")

	return isDirectory and hasMetaFile and hasSourceDirectory and hasBootstrapDirectory
end

return LoveSearch
