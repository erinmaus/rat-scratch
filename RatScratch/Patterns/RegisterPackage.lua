local MetaService = require("RatScratch.Services.MetaService")
local PackageService = require("RatScratch.Services.PackageService")

local function RegisterPackage(meta)
	if PackageService.isRegistered(meta) then
		return
	end

	local hash = meta.hash:match(".+:(.*)")
	local rootPath = PackageService.getRootPath(meta, hash)

	PackageService.registerPackage(meta, rootPath, hash)
end

return RegisterPackage
