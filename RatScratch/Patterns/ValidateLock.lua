local MetaService = require("RatScratch.Services.MetaService")
local Console = require("RatScratch.Console")

local function ValidateLock(meta)
	for i = 2, #meta do
		Console.assert(
			meta[i].url and (not meta[i].url:match("https?://") or meta[i].hash),
			"Rat Scratch meta module meta missing values (hash and/or url): %s",
			MetaService.serialize(meta[i]):gsub("\n", ", ")
		)
	end
end

return ValidateLock
