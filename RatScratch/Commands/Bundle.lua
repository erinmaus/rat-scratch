local Options = require("RatScratch.Commands.Options")
local MetaService = require("RatScratch.Services.MetaService")
local ResolvePackageDependencies = require("RatScratch.Patterns.ResolvePackageDependencies")
local InstallPackage = require("RatScratch.Patterns.InstallPackage")
local WriteLock = require("RatScratch.Patterns.WriteLock")
local AddRatScratchModule = require("RatScratch.Patterns.AddRatScratchModule")
local Bundle = {}

Bundle.OPTIONS = {
	Options["common-meta"],
	Options["common-out"],
	Options["common-force"],
}

function Bundle.perform(arguments)
	local packageMeta = MetaService.parseMeta()
	local lock = ResolvePackageDependencies(packageMeta, arguments.force)

	for i = 2, #lock do
		InstallPackage(lock[i])
	end

	AddRatScratchModule("staging/lib", true)

	WriteLock(lock, packageMeta)
end

return Bundle
