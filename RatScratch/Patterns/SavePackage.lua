local PackageService = require("RatScratch.Services.PackageService")
local FilesystemService = require("RatScratch.Services.FilesystemService")
local MetaService = require("RatScratch.Services.MetaService")

local function SavePackage(inputMeta, blob)
	local hash = inputMeta.hash and inputMeta.hash:match(".+:(.+)")
	local packageMountPath = hash and PackageService.saveAndMountPackage(hash, blob)
		or PackageService.getPackagePath(inputMeta)

	local root = inputMeta.root
	if not root then
		root = FilesystemService.recurse(packageMountPath, function(path, recurse)
			if recurse then
				local probeFilenames = {
					"LICENSE",
					"LICENSE.md",
					"README",
					"README.md",
				}

				for _, probeFilename in ipairs(probeFilenames) do
					local fullProbeFilename = ("%s/%s"):format(path, probeFilename)

					if love.filesystem.getInfo(fullProbeFilename, "file") then
						return path
					end
				end

				recurse()
			end
		end)

		root = root and root:gsub("%-", "%%-")
	end

	local modifiedMeta = MetaService.clone(inputMeta)
	modifiedMeta.root = root

	local rootPath = PackageService.getRootPath(modifiedMeta, hash)
	local packageMetaFilename = ("%s/.rsmeta"):format(rootPath)
	if love.filesystem.getInfo(packageMetaFilename, "file") then
		local packageMeta = MetaService.parseMeta(packageMetaFilename)

		for key, value in pairs(packageMeta[1]) do
			if not modifiedMeta[key] then
				modifiedMeta[key] = value
			end
		end
	end

	PackageService.savePackageMeta(hash, MetaService.serialize(modifiedMeta))

	return modifiedMeta
end

return SavePackage
