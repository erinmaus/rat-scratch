local Test = require("RatScratch.Test")
local MetaService = require("RatScratch.Services.MetaService")

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
		local slick = require("lib.slick")
		local bump = require("lib.bump")

		local function main()
			print(("slick: %s"):format(slick._VERSION))
			print(("bump: %s"):format(bump._VERSION))
		end

		return {
			main = main
		}
	]]
)

love.filesystem.write(
	"staging/test/main.lua",
	[[
		function love.errorhandler()
			os.exit(1)
		end

  		local test = require "build.rat-scratch-test"
		local module = require "build.rat-scratch-test.lib.rat-scratch-module"

		local versions = module.getVersions("rat-scratch-test")
		print(("rat-scratch-test: %s (%d)"):format(versions[1], #versions))

		test.main()
		love.event.quit()
	]]
)

Test.stop()

Test.init()
Test.addPackage({ github = true, source = "slick" }, "erinmaus/slick@slick-v4.0.8")
Test.addPackage({ github = true, source = "bump.lua" }, "kikito/bump.lua@v3.1.7")
Test.build({})

local file = io.popen("love ./rat-scratch-test")
assert(file:read("*l") == "rat-scratch-test: 1.0.0 (1)")
assert(file:read("*l") == "slick: 4.0.8")
assert(file:read("*l") == "bump: bump v3.1.7")
