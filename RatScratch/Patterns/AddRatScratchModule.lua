local FilesystemService = require("RatScratch.Services.FilesystemService")
local MetaService = require("RatScratch.Services.MetaService")

local function AddRatScratchModule(outputDirectory)
	local moduleDestinationPath = ("%s/%s"):format(outputDirectory, "rat-scratch-module")
	FilesystemService.copy("rat-scratch-module/source/init.lua", ("%s/init.lua"):format(moduleDestinationPath))

	local moduleMeta = MetaService.parseMeta("rat-scratch-module/.rsmeta")
	return moduleMeta[1]
end

return AddRatScratchModule
