local https = require("https")
local App = require("RatScratch.App")
local FilesystemService = require("RatScratch.Services.FilesystemService")
local Add = require("RatScratch.Commands.Add")
local Console = require("RatScratch.Console")
local MetaService = require("RatScratch.Services.MetaService")
local Build = require("RatScratch.Commands.Build")
local Bundle = require("RatScratch.Commands.Bundle")

local Test = {}

function Test.init(meta)
	App.init({ meta = meta or "rat-scratch-test/.rsmeta" })
end

function Test.deinit(meta)
	App.deinit({ meta = meta or "rat-scratch-test/.rsmeta" })
end

function Test.clear()
	FilesystemService.clear("staging/module")
end

local isReady = false

function Test.meta(meta)
	local metaRootNativePath = love.filesystem.canonicalizeRealPath("rat-scratch-test")
	assert(love.filesystem.mountFullPath(metaRootNativePath, "staging/test", "readwrite"))

	meta = meta or {
		{
			name = "rat-scratch-test",
			version = "1.0.0",
		},
	}

	MetaService.writeMeta(meta, "staging/test/.rsmeta")

	love.filesystem.unmountFullPath(metaRootNativePath)
end

function Test.start(meta)
	if not isReady then
		local metaRootNativePath = love.filesystem.canonicalizeRealPath("rat-scratch-test")
		love.filesystem.mountFullPath(metaRootNativePath, "staging/test", "readwrite")

		FilesystemService.clear("staging/test/fixtures")
		FilesystemService.clear("staging/test/lib")
	end

	if meta or not love.filesystem.getInfo("staging/test/.rsmeta") then
		meta = meta or {
			{
				name = "rat-scratch-test",
				version = "1.0.0",
			},
		}

		MetaService.writeMeta(meta, "staging/test/.rsmeta")
	end

	isReady = true
end

function Test.stop()
	if not isReady then
		return
	end

	local metaRootNativePath = love.filesystem.canonicalizeRealPath("rat-scratch-test")
	love.filesystem.unmountFullPath(metaRootNativePath)

	isReady = false
end

function Test.generateSource(dependencyName, dependency)
	local source = {}
	if dependency and dependency.libs then
		local meta = MetaService.parseMeta("staging/test/.rsmeta")
		local prefix = (meta[1]["directory.library"] or "./lib"):gsub("^%.?/*", ""):gsub("/*$", ""):gsub("/", ".")

		for _, child in ipairs(dependency.libs) do
			local childName = child:match("(.*)@.*")
			table.insert(source, ('require("%s.%s")'):format(prefix, childName))
		end

		table.insert(source, "")
	end

	table.insert(source, ('return function() print(("%%s: %%s"):format("hello from", %q)) end'):format(dependencyName))

	return table.concat(source, "\n")
end

local function _add(dependencies, dependency, e)
	local dependencyInfo = dependencies[dependency]

	local name, version = dependency:match("(.*)@(.*)")
	local filename = ("staging/test/fixtures/%s"):format(dependency)
	local metaFilename = ("%s/%s.rsmeta"):format(filename, dependencyInfo and dependencyInfo.mono and name or "")

	love.filesystem.createDirectory(filename)

	local sourceDirectory = ("%s/%s"):format(filename, name)
	love.filesystem.createDirectory(sourceDirectory)

	love.filesystem.write(("%s/init.lua"):format(sourceDirectory), Test.generateSource(dependency, dependencyInfo))

	local meta = ("name = %s\nversion = %s\nsource = %s\n"):format(name, version, name)
	love.filesystem.write(metaFilename, meta)

	love.filesystem.write(("%s/README.md"):format(filename), ("# %s\nThis is a README."):format(name))

	local nativeMetaFilename = ("rat-scratch-test/fixtures/%s/.rsmeta"):format(dependency)

	if dependencyInfo and dependencyInfo.libs and #dependencyInfo.libs >= 1 then
		for _, childDependency in ipairs(dependencyInfo.libs) do
			_add(dependencies, childDependency)
		end

		Test.init(nativeMetaFilename)
		for _, childDependency in ipairs(dependencyInfo.libs) do
			Test.addPackage({
				meta = metaFilename,
				root = childDependency:gsub("([%-%.])", "%%%1"),
			}, ("http://localhost:3000/fixtures/%s.zip"):format(childDependency))
		end
		Test.deinit(nativeMetaFilename)
	end
end

function Test.clean()
	local metaRootNativePath = love.filesystem.canonicalizeRealPath("rat-scratch-test")
	assert(love.filesystem.mountFullPath(metaRootNativePath, "staging/test", "readwrite"))

	if love.filesystem.getInfo("staging/test/fixtures", "directory") then
		FilesystemService.delete("staging/test/fixtures")
	end

	if love.filesystem.getInfo("staging/test/lib", "directory") then
		FilesystemService.delete("staging/test/lib")
	end

	love.filesystem.unmountFullPath(metaRootNativePath)
end

function Test.fail(func, message, ...)
	local s, r = xpcall(func, debug.traceback)
	if not message then
		assert(not s)
	else
		Console.assert(not s, message, ...)
	end
end

function Test.succeed(func, message, ...)
	local s, r = xpcall(func, debug.traceback)
	if not s then
		Console.warn(r)
	end

	Console.assert(s, message, ...)
end

function Test.generate(dependencies)
	local result = {}

	for packageVersion in pairs(dependencies) do
		table.insert(result, packageVersion)
	end

	table.sort(result)

	Test.start()
	for _, packageVersion in ipairs(result) do
		_add(dependencies, packageVersion)
	end
	Test.stop()
end

function Test.addPackage(options, url)
	local newOptions = {}
	for key, value in pairs(options) do
		newOptions[key] = value
	end

	if not options.github and not options.hash and url:match("http://localhost") then
		local sha256URL = url:gsub("%.zip$", ".sha256")
		local response, hash = https.request(sha256URL)
		Console.assert(response == 200, "could not get ZIP hash from URL: %s", sha256URL)

		newOptions.hash = ("sha256:%s"):format(hash)

		if not newOptions.root then
			newOptions.root = ".*"
		end
	end

	if not options.meta then
		newOptions.meta = "rat-scratch-test/.rsmeta"
	end

	Add.perform(newOptions, { url })
end

function Test.build(options)
	local newOptions = {}
	for key, value in pairs(options) do
		newOptions[key] = value
	end

	if not options.meta then
		newOptions.meta = "rat-scratch-test/.rsmeta"
	end

	Build.perform(newOptions)
end

function Test.bundle(options)
	local newOptions = {}
	for key, value in pairs(options) do
		newOptions[key] = value
	end

	if not options.meta then
		newOptions.meta = "rat-scratch-test/.rsmeta"
	end

	Bundle.perform(newOptions)
end

function Test.hasPackages(meta, packages)
	local success = true

	for _, package in ipairs(packages) do
		local name, version = package:match("(.*)@(.*)")

		local hasPackage = false
		for i = 2, #meta do
			if meta[i].name == name then
				if meta[i].version == version then
					hasPackage = true
					break
				else
					Console.warn('Package "%s" version mismatch (got %s, expected %s).', name, meta[i].version, version)
				end
			end
		end

		if not hasPackage then
			success = false
			Console.warn('Missing package "%s@%s"', name, version)
		end
	end

	return success
end

function Test.hasOutput(lines)
	local file = io.popen("love ./rat-scratch-test", "r")
	assert(file, "could not run `love ./rat-scratch-test`")

	local outputLines = {}
	do
		local outputLine
		repeat
			outputLine = file:read("*l")
			table.insert(outputLines, outputLine)
		until not outputLine
	end

	for i, inputLine in ipairs(lines) do
		local outputLine = outputLines[i]

		Console.assert(
			inputLine == outputLine,
			'expected "%s", got: %s',
			inputLine,
			table.concat(outputLines, "\n", i, #outputLines)
		)
	end
end

return Test
