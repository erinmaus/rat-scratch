local PackageService = require("RatScratch.Services.PackageService")
local MetaService = require("RatScratch.Services.MetaService")

local function GetPackageMeta(inputMeta)
	local hash = inputMeta.hash and inputMeta.hash:match(".+:(.+)")
	local packageRootPath = PackageService.getRootPath(inputMeta, hash) or PackageService.getPackagePath(inputMeta)

	local metaFilename1 = ("%s/%s"):format(packageRootPath, ".rsmeta")
	local metaFilename2 = ("%s/%s.%s"):format(packageRootPath, inputMeta.name, ".rsmeta")
	if love.filesystem.getInfo(metaFilename1, "file") then
		return MetaService.parseMeta(metaFilename1)
	elseif love.filesystem.getInfo(metaFilename2, "file") then
		return MetaService.parseMeta(metaFilename2)
	else
		return {
			{
				name = inputMeta.name,
				version = inputMeta.version,
				source = inputMeta.source,
			},
		}
	end
end

return GetPackageMeta
