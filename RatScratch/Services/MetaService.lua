local Console = require("RatScratch.Console")
local Meta = require("rat-scratch-module.rat-scratch-module.Meta")

local MetaService = {}

function MetaService.parseMeta(filename)
	filename = filename or "staging/module/.rsmeta"

	local data = love.filesystem.read(filename)
	Console.assert(
		love.filesystem.getInfo(filename, "file"),
		'Rat Scratch module meta does not exist at path "%s"',
		filename
	)

	return Meta.fromFile(filename, data)
end

function MetaService.isCompatible(currentMeta, pendingMeta)
	return Meta.isVersionExactMatch(currentMeta.version, pendingMeta.version)
end

function MetaService.isMaybeCompatible(currentMeta, pendingMeta)
	return Meta.isVersionMatch(currentMeta.version, pendingMeta.version)
end

function MetaService.isNewer(currentMeta, pendingMeta)
	return Meta.compareVersion(currentMeta.version, pendingMeta.version) < 0
end

function MetaService.clone(meta)
	if #meta == 0 then
		local result = {}

		for key, value in pairs(meta) do
			result[key] = value
		end

		return result
	end

	local results = {}
	for _, otherMeta in ipairs(meta) do
		local result = {}
		for key, value in pairs(otherMeta) do
			result[key] = value
		end
		table.insert(results, result)
	end

	return results
end

function MetaService.serialize(meta)
	return Meta.serialize(meta)
end

function MetaService.writeMeta(meta, filename)
	filename = filename or "staging/module/.rsmeta"
	love.filesystem.write(filename, Meta.serialize(meta))
end

function MetaService.buildRelativePath(meta, path)
	return Meta.buildPath(meta[1], path)
end

return MetaService
