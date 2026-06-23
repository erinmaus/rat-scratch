local Options = require("RatScratch.Commands.Options")
local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")
local Set = {}

Set.OPTIONS = {
	Options["inspect-package"],
	Options["common-meta"],
}

local DEFAULT_VALUES = {
	["directory.library"] = "./lib",
	["directory.build"] = "./build/${name}-${version}",
}

function Set.perform(options, values)
	local meta = MetaService.parseMeta()

	Console.assert(#values == 2, "can only set get one key-value pair in Rat Scratch meta")

	local targetMeta
	if options.package then
		for i = 1, #meta do
			if meta[i].name == options.package then
				targetMeta = meta[i]
				break
			end
		end

		Console.assert(targetMeta, 'could not find module "%s" in Rat Scratch meta', options.package)
	else
		targetMeta = meta[1]
	end

	local key = (values[1] or ""):match("%s*(.*)%s*")
	local value = (values[2] or ""):match("%s*(.*)%s*")

	Console.assert(key ~= "", "key is empty")
	Console.assert(value ~= "", "value for key '%s' is empty", key)

	targetMeta[key] = value

	MetaService.writeMeta(meta)
end

return Set
