local PackageService = require("RatScratch.Services.PackageService")
local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")
local DownloadAllPackages = require("RatScratch.Patterns.DownloadAllPackages")

local function tryAddPackage(completeMeta, meta, force)
	if meta and meta.url then
		DownloadAllPackages(meta, { meta.url })
	end

	for i = 2, #completeMeta do
		local otherMeta = completeMeta[i]
		if otherMeta.name == meta.name then
			if MetaService.isNewer(meta, otherMeta) then
				if not MetaService.isCompatible(meta, otherMeta) then
					if force then
						Console.warn(
							'package "%s@%s" is being upgraded to new major version "%s", but there might be breaking changes',
							meta.name,
							meta.version,
							otherMeta.version
						)
					else
						Console.error(
							'package "%s@%s" cannot be upgraded to new major version "%s", there might be breaking changes',
							meta.name,
							meta.version,
							otherMeta.version
						)
					end
				end

				completeMeta[i] = MetaService.clone(meta)
			end

			return
		end
	end

	table.insert(completeMeta, MetaService.clone(meta))
end

local function resolveChildDependency(completeMeta, meta, force, e)
	Console.assert(not e[meta.name], 'package "%s" is dependent on self', meta.name)
	e[meta.name] = true

	tryAddPackage(completeMeta, meta, force)

	local packagePath = PackageService.getPackagePath(meta)
	local packageMetaPath = ("%s/.rsmeta"):format(packagePath)
	if love.filesystem.getInfo(packageMetaPath) then
		local packageMeta = MetaService.parseMeta(packageMetaPath)
		for i = 2, #packageMeta do
			resolveChildDependency(completeMeta, packageMeta[i], force, e)
		end
	end

	e[meta.name] = false
end

local function ResolvePackageDependencies(meta, force)
	local completeMeta = {}

	meta = meta or MetaService.parseMeta()
	table.insert(completeMeta, meta[1])

	local e = { meta[1].name }
	for i = 2, #meta do
		resolveChildDependency(completeMeta, meta[i], force, e)
	end

	return completeMeta
end

return ResolvePackageDependencies
