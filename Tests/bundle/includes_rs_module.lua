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
	"staging/test/main.lua",
	[[
		function love.errorhandler()
			os.exit(1)
		end

		local module = require "lib.rat-scratch-module"

		print("success!")

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
assert(file:read("*l") == "success!")
