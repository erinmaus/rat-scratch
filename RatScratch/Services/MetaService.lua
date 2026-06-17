local Common = require("Data.Template.bootstrap.Common")
local Console = require("RatScratch.Console")
local MetaService = {}

function MetaService.parseMeta(filename)
	filename = filename or "staging/module/.rsmeta"
	Console.assert(
		love.filesystem.getInfo(filename, "file"),
		'Rat Scratch module meta does not exist at path "%s"',
		filename
	)

	local metaFile = love.filesystem.read(filename)
	return Common.new("staging/module"):parseTOML(metaFile)
end

function MetaService.isCompatible(currentMeta, pendingMeta)
	return Common.new("staging/module"):isVersionMatch(currentMeta.version, pendingMeta.version)
end

function MetaService.isMaybeCompatible(currentMeta, pendingMeta)
	return Common.new("staging/module"):isVersionMaybeMatch(currentMeta.version, pendingMeta.version)
end

function MetaService.isNewer(currentMeta, pendingMeta)
	return Common.new("staging/module"):compareVersion(currentMeta.version, pendingMeta.version)
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

function MetaService.stringifyPackageMeta(package, excludedKeys)
	local keyValues = {}

	for key, value in pairs(package) do
		if not (excludedKeys and excludedKeys[key]) then
			table.insert(keyValues, { key, value })
		end
	end

	table.sort(keyValues, function(a, b)
		return a[1] < b[1]
	end)

	local result = {}
	for _, keyValuePair in ipairs(keyValues) do
		local key, value = unpack(keyValuePair)
		table.insert(result, ("%s = %s"):format(key, value))
	end

	return table.concat(result, "\n")
end

function MetaService.writeMeta(meta, filename)
	filename = filename or "staging/module/.rsmeta"

	local result = {}
	table.insert(result, MetaService.stringifyPackageMeta(meta[1]))
	table.insert(result, "")

	for i = 2, #meta do
		table.insert(result, ("[%s]"):format(meta[i].name))
		table.insert(result, MetaService.stringifyPackageMeta(meta[i], { name = true }))
		table.insert(result, "")
	end

	local stringifiedMeta = table.concat(result, "\n")
	love.filesystem.write(filename, stringifiedMeta)
end

function MetaService.buildRelativePath(meta, path)
	local result = path:gsub("%$%{(.-)%}", function(value)
		return meta[1][value]
	end)

	return result
end

return MetaService
