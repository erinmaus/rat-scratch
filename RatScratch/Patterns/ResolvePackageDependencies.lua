local PackageService = require("RatScratch.Services.PackageService")
local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")
local DownloadAllPackages = require("RatScratch.Patterns.DownloadAllPackages")

local function tryAddPackage(completeMeta, meta, parentMeta, force)
	if meta.url then
		meta = DownloadAllPackages(meta, { meta.url }, parentMeta)
	end

	for i = 2, #completeMeta do
		local otherMeta = completeMeta[i]
		if otherMeta.name == meta.name then
			if otherMeta.version == "*" or MetaService.isNewer(meta, otherMeta) then
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

			return meta
		end
	end

	table.insert(completeMeta, MetaService.clone(meta))
	return meta
end

local function resolveChildDependency(completeMeta, meta, parentMeta, force, e)
	Console.assert(not e[meta.name], 'package "%s" is dependent on self', meta.name)
	e[meta.name] = true

	meta = tryAddPackage(completeMeta, meta, parentMeta, force) or meta

	local packagePath = PackageService.getPackagePath(meta)
	local packageMetaPath1 = ("%s/%s.rsmeta"):format(packagePath, meta.name)
	local packageMetaPath2 = ("%s/.rsmeta"):format(packagePath)

	local packageMeta
	if love.filesystem.getInfo(packageMetaPath1, "file") then
		packageMeta = MetaService.parseMeta(packageMetaPath1)
	elseif love.filesystem.getInfo(packageMetaPath2, "file") then
		packageMeta = MetaService.parseMeta(packageMetaPath2)
	end

	if packageMeta then
		for i = 2, #packageMeta do
			resolveChildDependency(completeMeta, packageMeta[i], packageMeta[1], force, e)
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
		resolveChildDependency(completeMeta, meta[i], meta[1], force, e)
	end

	return completeMeta
end

return ResolvePackageDependencies
