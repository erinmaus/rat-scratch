local Test = require("RatScratch.Test")
local MetaService = require("RatScratch.Services.MetaService")

Test.generate({
	["rs-common@1.0.0"] = {
		mono = true,
	},
})

Test.meta()
Test.init()
Test.addPackage({ name = "rs-common" }, "http://localhost:3000/fixtures/rs-common@1.0.0.zip")

assert(Test.hasPackages(MetaService.parseMeta(), {
	"rs-common@1.0.0",
}))
