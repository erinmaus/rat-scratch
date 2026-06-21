local FilesystemService = require("RatScratch.Services.FilesystemService")
local MetaService = require("RatScratch.Services.MetaService")
local Add = require("RatScratch.Commands.Add")
local Build = require("RatScratch.Commands.Build")
local Bundle = require("RatScratch.Commands.Bundle")
local Console = require("RatScratch.Console")
local Test = require("RatScratch.Commands.Test")
local PackageService = require("RatScratch.Services.PackageService")
local Help = require("RatScratch.Commands.Help")
local Get = require("RatScratch.Commands.Get")

local App = {}

App.COMMANDS = {
	{ name = "add", command = Add },
	{ name = "get", command = Get },
	{ name = "test", command = Test },
	{ name = "bundle", command = Bundle },
	{ name = "build", command = Build },
	{ name = "help", command = Help },
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
				command = possibleCommand
				break
			end
		end

		if not command then
			Console.error("command '%s' not recognized; use \"help\" for a list of commands", arguments[1])
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
			for _, possibleOption in ipairs(command.command.OPTIONS) do
				if possibleOption.option == option then
					if option.argument and not value then
						Console.error("option '%s' needs value %s", possibleOption.option, option.argument)
					end

					hasOption = true
				end
			end

			local isOptionDebug = option == "debug" and os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
			local isOptionHelp = option == "help"
			if not (hasOption or isOptionDebug or isOptionHelp) then
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
	local metaFilename = (options.meta or ".rsmeta"):match("/?([^/]*)$")

	local metaRootNativePath =
		love.filesystem.canonicalizeRealPath(FilesystemService.buildPath(options.meta or ".", ".."))
	Console.assert(
		metaRootNativePath ~= sourceNativePath,
		"source directory (%s) cannot be Rat Scratch module meta directory (%s)",
		sourceNativePath,
		metaRootNativePath
	)

	FilesystemService.mountModuleDirectory(metaRootNativePath)

	MetaService.setMetaFilename(metaFilename or ".rsmeta")
	local meta = MetaService.parseMeta()

	local libraryDirectory = MetaService.buildRelativePath(meta, meta[1]["directory.library"] or options.out or "./lib")
	local buildDirectory =
		MetaService.buildRelativePath(meta, meta[1]["directory.build"] or options.out or "./build/${name}-v${version}")

	FilesystemService.mountLibraryDirectory(libraryDirectory)
	FilesystemService.mountBuildDirectory(buildDirectory)

	PackageService.registerPackage(meta[1], "staging/module", ("local:%s@%s"):format(meta[1].name, meta[1].version))
end

function App.deinit(options)
	PackageService.unmount()
	FilesystemService.unmount()
	MetaService.setMetaFilename()
end

function App.help(command)
	local meta = MetaService.parseMeta(".rsmeta")[1]

	print(("%s - %s"):format(meta.name, meta.version))
	print("bundle libraries for distribution")
	print()
	print(("usage: %s <command> [options] [input1...]"):format(meta.name))
	print()

	if command.name == "help" then
		command.command.perform()
		return
	end

	local flag = love.system.getOS() == "Windows" and "/" or "--"
	for _, option in ipairs(command.command.OPTIONS) do
		if option.argument then
			print("", ("%s%s=<%s>"):format(flag, option.option, option.argument))
		else
			print("", ("%s%s"):format(flag, option.option))
		end

		print("", "", "", option.description)
	end
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
	if options["help"] or command.name == "help" then
		App.help(command)
		return
	end

	if options.meta then
		App.init(options)
	end

	command.command.perform(options, inputs)

	if options.meta then
		App.deinit(options)
	end
end

return App
