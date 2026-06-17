local Test = require("RatScratch.Test")

Test.generate({
	["rs-common@1.0.0"] = {
		libs = { "rs-base@0.0.1" },
	},
})

Test.meta()
Test.init()
Test.fail(function()
	Test.addPackage({ hash = "sha256:notAValidHash" }, "http://localhost:3000/fixtures/rs-common@1.0.0.zip")
	Test.addPackage(
		{ force = true, hash = "sha256:notAValidHash" },
		"http://localhost:3000/fixtures/rs-common@1.0.0.zip"
	)
end)
Test.succeed(function()
	Test.addPackage({}, "http://localhost:3000/fixtures/rs-common@1.0.0.zip")
end)
