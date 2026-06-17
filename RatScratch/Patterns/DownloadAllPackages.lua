local MetaService = require("RatScratch.Services.MetaService")
local GetPackageMeta = require("RatScratch.Patterns.GetPackageMeta")
local DownloadPackage = require("RatScratch.Patterns.DownloadPackage")
local SavePackage = require("RatScratch.Patterns.SavePackage")
local RegisterPackage = require("RatScratch.Patterns.RegisterPackage")

local function DownloadAllPackages(meta, urls, e)
	e = e or {}

	for _, m in ipairs(e) do
		if m.name == meta.name and m.version == meta.version then
			return m
		end
	end

	local modifiedMeta = MetaService.clone(meta)
	table.insert(e, modifiedMeta)

	local blob, blobHash, blobURL = DownloadPackage(modifiedMeta, urls)

	modifiedMeta.url = blobURL
	modifiedMeta.hash = blobHash
	assert(modifiedMeta.hash)

	modifiedMeta = SavePackage(modifiedMeta, blob)

	local packageMeta = GetPackageMeta(modifiedMeta)

	modifiedMeta.name = packageMeta[1].name
	modifiedMeta.version = packageMeta[1].version
	RegisterPackage(modifiedMeta)

	for i = 2, #packageMeta do
		local childPackageMeta = packageMeta[i]
		DownloadAllPackages(childPackageMeta, { childPackageMeta.url }, e)
	end

	return modifiedMeta
end

return DownloadAllPackages
