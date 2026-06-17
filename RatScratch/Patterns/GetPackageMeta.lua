local PackageService = require("RatScratch.Services.PackageService")
local MetaService = require("RatScratch.Services.MetaService")

local function GetPackageMeta(inputMeta)
	local hash = inputMeta.hash:match(".+:(.+)")
	local packageRootPath = PackageService.getRootPath(inputMeta, hash)

	local metaFilename = ("%s/%s"):format(packageRootPath, ".rsmeta")
	if love.filesystem.getInfo(metaFilename, "file") then
		return MetaService.parseMeta(metaFilename)
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
