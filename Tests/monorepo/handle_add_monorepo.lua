local Test = require("RatScratch.Test")
local MetaService = require("RatScratch.Services.MetaService")
local FilesystemService = require("RatScratch.Services.FilesystemService")

local function generateMonoRepoPackage(name, version, dependency)
	local filename = ("staging/test/fixtures/rs-test-mono/%s"):format(name)
	love.filesystem.createDirectory(filename)

	local metaFilename = ("%s.rsmeta"):format(filename, name)

	local meta = {
		{
			name = name,
			version = version,
			source = name,
		},
	}

	if dependency and dependency.libs then
		for _, nameVersion in ipairs(dependency.libs) do
			local name, version = nameVersion:match("(.*)@(.*)")

			table.insert(meta, {
				name = name,
				url = ("%s.rsmeta"):format(name),
				version = "*",
			})
		end
	end

	love.filesystem.write(metaFilename, MetaService.serialize(meta))

	love.filesystem.write(
		("%s/init.lua"):format(filename),
		Test.generateSource(("%s@%s"):format(name, version), dependency)
	)
end

Test.start()
FilesystemService.delete("staging/test/fixtures")

love.filesystem.createDirectory("staging/test/source")
love.filesystem.write(
	"staging/test/source/init.lua",
	[[
		local gltf = require("lib.rs-gltf")
		local common = require("lib.rs-common")
		local module = require("lib.rat-scratch-module")

		local function main()
			for _, meta in module.iterate() do
				print(("%s (%s)"):format(meta.name, meta.version))
			end

			gltf()
			common()
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

  		local test = require "build.rat-scratch-test-mono"

		test.main()
		love.event.quit()
	]]
)

generateMonoRepoPackage(
	"rs-gltf",
	"1.2.3",
	{ libs = { "rs-common@1.1.2", "rs-math@1.0.0", "rs-graphics@0.1.0", "slick@4.0.8" } }
)
generateMonoRepoPackage("rs-graphics", "0.1.0", { libs = { "rs-common@1.1.2", "rs-math@1.0.0" } })
generateMonoRepoPackage("rs-math", "1.0.0", { libs = { "rs-common@1.1.2" } })
generateMonoRepoPackage("rs-common", "1.1.2")
Test.stop()

Test.init("rat-scratch-test/fixtures/rs-test-mono/rs-gltf.rsmeta")
Test.addPackage({ github = true, source = "slick" }, "erinmaus/slick@slick-v4.0.8")
Test.deinit()

Test.meta({
	{
		name = "rat-scratch-test",
		version = "1.0.0",
		source = "source",
		["directory.build"] = "build/rat-scratch-test-mono",
	},
})
Test.init()
Test.addPackage({ name = "rs-gltf" }, "http://localhost:3000/fixtures/rs-test-mono.zip")
Test.addPackage({ name = "rs-common" }, "http://localhost:3000/fixtures/rs-test-mono.zip")
Test.build({})

Test.hasOutput({
	"rat-scratch-module (1.0.1)",
	"rat-scratch-test (1.0.0)",
	"rs-common (1.1.2)",
	"rs-gltf (1.2.3)",
	"rs-graphics (0.1.0)",
	"rs-math (1.0.0)",
	"slick (4.0.8)",
	"hello from: rs-gltf@1.2.3",
	"hello from: rs-common@1.1.2",
})
