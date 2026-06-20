local MetaService = require("RatScratch.Services.MetaService")
local GetPackageMeta = require("RatScratch.Patterns.GetPackageMeta")
local DownloadPackage = require("RatScratch.Patterns.DownloadPackage")
local SavePackage = require("RatScratch.Patterns.SavePackage")
local RegisterPackage = require("RatScratch.Patterns.RegisterPackage")

local function DownloadAllPackages(meta, urls, parentMeta, e)
	e = e or {}

	for _, m in ipairs(e) do
		if m.name == meta.name and m.version == meta.version then
			return m
		end
	end

	local modifiedMeta = MetaService.clone(meta)
	table.insert(e, modifiedMeta)

	local blob, blobHash, blobURL, blobMeta = DownloadPackage(modifiedMeta, urls, parentMeta)
	blobMeta = SavePackage(blobMeta, blob)

	local packageMeta = GetPackageMeta(blobMeta)

	blobMeta.name = packageMeta[1].name
	blobMeta.version = packageMeta[1].version
	RegisterPackage(blobMeta)

	for i = 2, #packageMeta do
		local childPackageMeta = packageMeta[i]
		DownloadAllPackages(childPackageMeta, { childPackageMeta.url }, packageMeta[1], e)
	end

	return blobMeta
end

return DownloadAllPackages
