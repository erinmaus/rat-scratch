local Test = require("RatScratch.Test")
local MetaService = require("RatScratch.Services.MetaService")

Test.meta()
Test.init()

Test.addPackage({ github = true, source = "slick" }, "erinmaus/slick@slick-v4.0.8")
Test.addPackage({ github = true, source = "json.lua" }, "rxi/json.lua@v0.1.2")
Test.addPackage({ github = true, source = "bump.lua" }, "kikito/bump.lua@v3.1.7")

assert(Test.hasPackages(MetaService.parseMeta(), {
	"slick@4.0.8",
	"bump@3.1.7",
	"json@0.1.2",
}))
