local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")
local PackageService = require("RatScratch.Services.PackageService")

local function getSpecificDependencies(meta, otherMeta)
	local result = { MetaService.clone(meta[1]) }

	for i = 2, #meta do
		local localMeta = MetaService.clone(meta[i])
		if localMeta.url and localMeta.url:match(".*%.rsmeta$") then
			local localMetaFilename = ("staging/module/%s.rsmeta"):format(localMeta.name)
			if not love.filesystem.getInfo(localMetaFilename, "file") then
				local hash = PackageService.getPackageHash(meta[i])
				local rootMetaFilename = ("staging/lib/.tmp/%s.rsmeta"):format(hash)
				local rootMeta = MetaService.parseMeta(rootMetaFilename)

				localMeta.url = rootMeta.url
				localMeta.hash = rootMeta.hash
			end
		end

		local hasDependency = not otherMeta
		if otherMeta then
			for j = 2, #otherMeta do
				if otherMeta[j].name == localMeta.name then
					hasDependency = true
					break
				end
			end
		end

		if hasDependency then
			table.insert(result, localMeta)
		end
	end

	return result
end

local function WriteLock(lock, packageMeta, filename)
	MetaService.writeMeta(getSpecificDependencies(lock, packageMeta), filename)
end

return WriteLock
