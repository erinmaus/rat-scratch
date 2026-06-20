local Options = require("RatScratch.Commands.Options")
local MetaService = require("RatScratch.Services.MetaService")
local ResolvePackageDependencies = require("RatScratch.Patterns.ResolvePackageDependencies")
local InstallPackage = require("RatScratch.Patterns.InstallPackage")
local WriteLock = require("RatScratch.Patterns.WriteLock")
local FilesystemService = require("RatScratch.Services.FilesystemService")
local AddRatScratchModule = require("RatScratch.Patterns.AddRatScratchModule")
local Build = {}

Build.OPTIONS = {
	Options["common-meta"],
	Options["common-out"],
	Options["common-force"],
}

function Build.perform(options)
	local packageMeta = MetaService.parseMeta()
	local lock = ResolvePackageDependencies(packageMeta, options.force)

	for i = 2, #lock do
		InstallPackage(lock[i])
	end

	FilesystemService.clear("staging/build")

	local outputLibraryDirectory = FilesystemService.buildPath(
		"staging/build",
		MetaService.buildRelativePath(lock[1], lock[1]["directory.library"] or "./lib")
	)
	for i = 2, #lock do
		local meta = lock[i]
		local librarySourcePath = ("staging/lib/%s"):format(meta.name)
		local libraryDestinationPath = ("%s/%s"):format(outputLibraryDirectory, meta.name)

		FilesystemService.copy(librarySourcePath, libraryDestinationPath)
	end

	local ratScratchModuleMeta = AddRatScratchModule(outputLibraryDirectory)
	table.insert(lock, ratScratchModuleMeta)

	if lock[1].source then
		local sourcePath = ("staging/module/%s"):format(lock[1].source)
		if love.filesystem.getInfo(sourcePath, "file") then
			FilesystemService.copy(sourcePath, "staging/build/source/init.lua")
		else
			FilesystemService.copy(sourcePath, "staging/build/source")
		end
	end

	FilesystemService.copy("Data/Template/bootstrap", "staging/build/bootstrap")
	FilesystemService.copy("rat-scratch-module/rat-scratch-module/Meta.lua", "staging/build/bootstrap/Meta.lua")

	local initSource = love.filesystem.read("Data/Template/init.lua")
	local moduleName = lock[1]["lls.module"] or ("%s.source"):format(lock[1].name)
	initSource = initSource:gsub('@module "(.*)"', ('@module "%s"'):format(moduleName))
	love.filesystem.write("staging/build/init.lua", initSource)

	local cleanLock = {}
	for index, lockMeta in ipairs(lock) do
		cleanLock[index] = {
			name = lockMeta.name,
			version = lockMeta.version,
			license = lockMeta.license,
			["directory.library"] = lockMeta["directory.library"]
				and MetaService.buildRelativePath(lockMeta, lockMeta["directory.library"]),
		}
	end

	WriteLock(cleanLock, nil, "staging/build/.rsmeta")
end

return Build
