local PackageService = require("RatScratch.Services.PackageService")
local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")
local FilesystemService = require("RatScratch.Services.FilesystemService")
local GetPackageMeta = require("RatScratch.Patterns.GetPackageMeta")

local function InstallPackage(meta)
	local packagePath = PackageService.getPackagePath(meta)
	local packageMetaPath = ("%s/.rsmeta"):format(packagePath)

	local packageMeta
	if love.filesystem.getInfo(packageMetaPath, "file") then
		packageMeta = MetaService.parseMeta(packageMetaPath)[1]
	else
		packageMeta = {
			name = meta.name,
			version = meta.version,
			source = meta.source,
		}
	end

	local destinationPath = ("staging/lib/%s"):format(packageMeta.name)
	Console.print('Installing package "%s@%s"...', packageMeta.name, packageMeta.version)

	if love.filesystem.getInfo(destinationPath, "directory") then
		Console.print('Removing old package "%s" from path "%s"...', meta.name, destinationPath)
		FilesystemService.delete(destinationPath)
	end

	local sourcePath = ("%s/%s"):format(packagePath, packageMeta.source)
	if love.filesystem.getInfo(sourcePath, "file") then
		destinationPath = ("%s/init.lua"):format(destinationPath)
	end

	Console.print('Copying new package "%s@%s" to path "%s"...', meta.name, meta.version, destinationPath)
	FilesystemService.copy(sourcePath, destinationPath)

	return meta
end

return InstallPackage
