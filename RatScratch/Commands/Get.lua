local Options = require("RatScratch.Commands.Options")
local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")
local Get = {}

Get.OPTIONS = {
	Options["inspect-package"],
	Options["common-meta"],
}

local DEFAULT_VALUES = {
	["directory.library"] = "./lib",
	["directory.build"] = "./build/${name}-${version}",
}

function Get.perform(options, values)
	local meta = MetaService.parseMeta()

	Console.assert(#values == 1, "can only get one key from Rat Scratch meta")

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

	local value = targetMeta[values[1]] or DEFAULT_VALUES[values[1]]
	Console.assert(value, '"%s" does not have key "%s"', targetMeta.name, values[1])

	if values[1]:match("^directory%.") then
		value = MetaService.buildRelativePath(meta, value)
	end

	io.stdout:write(value)
end

return Get
