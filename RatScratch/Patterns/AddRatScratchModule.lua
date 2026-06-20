local FilesystemService = require("RatScratch.Services.FilesystemService")
local MetaService = require("RatScratch.Services.MetaService")

local function AddRatScratchModule(outputDirectory, build)
	local moduleDestinationPath = ("%s/%s"):format(outputDirectory, "rat-scratch-module")
	FilesystemService.delete(moduleDestinationPath)

	if build then
		FilesystemService.copy("Data/Template/bootstrap", ("%s/bootstrap"):format(moduleDestinationPath))
		FilesystemService.copy(
			"rat-scratch-module/rat-scratch-module/Meta.lua",
			("%s/bootstrap/Meta.lua"):format(moduleDestinationPath)
		)
		FilesystemService.copy("Data/Template/init.lua", ("%s/init.lua"):format(moduleDestinationPath))

		FilesystemService.copy("rat-scratch-module/rat-scratch-module", ("%s/source"):format(moduleDestinationPath))
		FilesystemService.copy("rat-scratch-module/.rsmeta", ("%s/.rsmeta"):format(moduleDestinationPath))
	else
		FilesystemService.copy("rat-scratch-module/rat-scratch-module", moduleDestinationPath)

		local moduleMeta = MetaService.parseMeta("rat-scratch-module/.rsmeta")
		return moduleMeta[1]
	end
end

return AddRatScratchModule
