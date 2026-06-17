local FilesystemService = require("RatScratch.Services.FilesystemService")
local MetaService = require("RatScratch.Services.MetaService")
local Add = require("RatScratch.Commands.Add")
local Build = require("RatScratch.Commands.Build")
local Bundle = require("RatScratch.Commands.Bundle")
local Console = require("RatScratch.Console")
local Test = require("RatScratch.Commands.Test")
local PackageService = require("RatScratch.Services.PackageService")

local App = {}

App.COMMANDS = {
	{ name = "add", command = Add },
	{ name = "test", command = Test },
	{ name = "bundle", command = Bundle },
	{ name = "build", command = Build },
}

function App.getOptionAndValue(argument)
	if argument:match("^--") or argument:match("^/") then
		return argument:match("^%-%-([^=]*)=?(.*)")
	end

	return nil, nil
end

function App.processArguments(arguments)
	local command
	do
		for _, possibleCommand in ipairs(App.COMMANDS) do
			if possibleCommand.name == arguments[1] then
				command = possibleCommand.command
				break
			end
		end

		if not command then
			Console.error("command '%s' not recognized; use \"help\" for a list of commands")
		end
	end

	local options = {}
	local inputs = {}

	for i = 2, #arguments do
		local argument = arguments[i]

		if argument == "--" then
			for j = i + 1, #arguments do
				table.insert(inputs, arguments[j])
			end

			break
		end

		local option, value = App.getOptionAndValue(argument)
		if option then
			local hasOption = false
			for _, possibleOption in ipairs(command.OPTIONS) do
				if possibleOption.option == option then
					if option.argument and not value then
						Console.error("option '%s' needs value %s", possibleOption.option, option.argument)
					end

					hasOption = true
				end
			end

			local isOptionDebug = option == "debug" and os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
			if not (hasOption or isOptionDebug) then
				Console.error("option '%s' not valid for command '%s'", option, arguments[1])
			end

			options[option] = value or true
		else
			table.insert(inputs, argument)
		end
	end

	return command, options, inputs
end

function App.init(options)
	local sourceNativePath = love.filesystem.getRealDirectory("main.lua")
	local metaRootNativePath =
		love.filesystem.canonicalizeRealPath(FilesystemService.buildPath(options.meta or ".", ".."))
	Console.assert(
		metaRootNativePath ~= sourceNativePath,
		"source directory (%s) cannot be Rat Scratch module meta directory (%s)",
		sourceNativePath,
		metaRootNativePath
	)

	FilesystemService.mountModuleDirectory(metaRootNativePath)

	local meta = MetaService.parseMeta()

	local libraryDirectory = MetaService.buildRelativePath(meta, meta[1]["directory.library"] or options.out or "./lib")
	local buildDirectory =
		MetaService.buildRelativePath(meta, meta[1]["directory.build"] or options.out or "./build/${name}-v${version}")

	FilesystemService.mountLibraryDirectory(libraryDirectory)
	FilesystemService.mountBuildDirectory(buildDirectory)
end

function App.deinit(options)
	PackageService.unmount()
	FilesystemService.unmount()
end

function App.run(args)
	if love.filesystem.getInfo(".args", "file") then
		local argsFile = love.filesystem.read(".args")

		args = {}
		for line in argsFile:gmatch("([^\r\n]*)\r?\n?") do
			line = line:gsub("^%s*(.*)%s$", "%1"):gsub("(.-)#.*$", "%1")
			table.insert(args, line)
		end
	end

	local command, options, inputs = App.processArguments(args)
	if options.meta then
		App.init(options)
	end

	command.perform(options, inputs)

	if options.meta then
		App.deinit(options)
	end
end

return App
