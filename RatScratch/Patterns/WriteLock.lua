local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")

local function getSpecificDependencies(meta, otherMeta)
	local result = { MetaService.clone(meta[1]) }

	for i = 2, #meta do
		Console.assert(
			meta[i].url and (not meta[i].url:match("https?://") or meta[i].hash),
			"Rat Scratch meta module meta missing values (hash and/or url): %s",
			MetaService.serialize(meta[i]):gsub("\n", ", ")
		)

		local hasDependency = false
		for j = 2, #otherMeta do
			if otherMeta[j].name == meta[i].name then
				hasDependency = true
				break
			end
		end

		if hasDependency then
			table.insert(result, MetaService.clone(meta[i]))
		end
	end

	return result
end

local function WriteLock(lock, packageMeta, filename)
	if packageMeta then
		MetaService.writeMeta(getSpecificDependencies(lock, packageMeta), filename)
	else
		MetaService.writeMeta(lock, filename)
	end
end

return WriteLock
