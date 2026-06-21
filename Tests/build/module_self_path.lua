local Test = require("RatScratch.Test")

Test.meta({
	{
		name = "rat-scratch-test",
		version = "1.0.0",
		source = "source",
		["directory.build"] = "build/rat-scratch-test",
	},
})

Test.start()
love.filesystem.createDirectory("staging/test/source")
love.filesystem.write(
	"staging/test/source/init.lua",
	[[
		local main = require("rat-scratch-test.main")

		return {
			main = main.main
		}
	]]
)

love.filesystem.write(
	"staging/test/source/main.lua",
	[[
		local PATH = ... 
		local RatScratchModule = require("rat-scratch-module")

		local function main()
			assert(RatScratchModule.getSelfPath() == RatScratchModule.getSelfPath(PATH))
			print(("module path: %s"):format(RatScratchModule.getSelfPath()))
		end

		return {
			main = main
		}
	]]
)

love.filesystem.write(
	"staging/test/main.lua",
	[[
		function love.errorhandler(e)
			print(e)
			os.exit(1)
		end

  		local test = require "build.rat-scratch-test"

		test.main()
		love.event.quit()
	]]
)

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

Test.stop()

Test.init()
Test.build({})

Test.hasOutput({
	"module path: build/rat-scratch-test/source",
})
