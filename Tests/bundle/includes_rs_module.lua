local Test = require("RatScratch.Test")

Test.meta({
	{
		name = "rat-scratch-test",
		version = "1.0.0",
		source = "source",
	},
})

Test.start()

love.filesystem.createDirectory("staging/test/source")
love.filesystem.write(
	"staging/test/source/init.lua",
	[[
		local PATH = ...
		local Module = require "lib.rat-scratch-module"

		return function()
			print(("path (no arg): %s"):format(Module.getSelfPath()))
			print(("path (arg): %s"):format(Module.getSelfPath(PATH)))
		end
	]]
)
love.filesystem.write(
	"staging/test/main.lua",
	[[
		function love.errorhandler()
			os.exit(1)
		end

		local printPath = require "source"
		printPath()

		love.event.quit()
	]]
)

Test.stop()

Test.init()
Test.bundle({})

love.filesystem.write(
	"staging/test/conf.lua",
	[[
		function love.conf(t)
			t.modules.graphics = false
			t.modules.window = false
			t.modules.audio = false
		end
	]]
)

local file = io.popen("love ./rat-scratch-test")
assert(file)
assert(file:read("*l") == "path (no arg): source")
assert(file:read("*l") == "path (arg): source")
