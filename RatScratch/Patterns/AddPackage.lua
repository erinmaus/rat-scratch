local MetaService = require("RatScratch.Services.MetaService")

local function AddPackage(packageMeta)
	local baseMeta = MetaService.parseMeta()

	local modifiedMeta = MetaService.clone(baseMeta)

	for i = 2, #baseMeta do
		local otherPackage = baseMeta[i]
		if otherPackage.name == packageMeta.name then
			modifiedMeta[i] = MetaService.clone(packageMeta)
			return modifiedMeta
		end
	end

	table.insert(modifiedMeta, packageMeta)
	return modifiedMeta
end

return AddPackage
