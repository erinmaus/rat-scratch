local Test = require("RatScratch.Test")
local MetaService = require("RatScratch.Services.MetaService")

Test.generate({
	["rs-gltf@1.2.3"] = {
		libs = { "rs-math@1.0.0", "rs-common@0.1.5", "rs-graphics-3d@4.4.0" },
	},

	["rs-gltf@1.0.0"] = {
		libs = { "rs-math@1.1.0", "rs-common@0.1.3", "rs-graphics-3d@4.4.0" },
	},

	["rs-math@1.0.0"] = {
		libs = { "rs-common@0.4.0" },
	},

	["rs-graphics-3d@4.4.0"] = {
		libs = { "rs-common@0.4.0", "rs-graphics-common@1.0.0" },
	},

	["rs-graphics-3d@4.5.0"] = {
		libs = { "rs-common@0.4.1", "rs-graphics-common@1.0.0" },
	},

	["rs-graphics-common@1.0.0"] = {
		libs = { "rs-common@0.0.1" },
	},

	["rs-book@3.4.0"] = {
		libs = { "rs-gltf@1.0.0", "rs-common@0.4.0", "rs-graphics-3d@4.5.0" },
	},
})

Test.meta()
Test.init()
Test.addPackage({}, "http://localhost:3000/fixtures/rs-book@3.4.0.zip")
Test.addPackage({}, "http://localhost:3000/fixtures/rs-graphics-3d@4.4.0.zip")
Test.build({})

assert(Test.hasPackages(MetaService.parseMeta(), {
	"rs-book@3.4.0",
	"rs-graphics-3d@4.5.0",
}))

assert(Test.hasPackages(MetaService.parseMeta("staging/build/.rsmeta"), {
	"rs-book@3.4.0",
	"rs-gltf@1.0.0",
	"rs-math@1.1.0",
	"rs-common@0.4.1",
	"rs-graphics-3d@4.5.0",
	"rs-graphics-common@1.0.0",
}))
