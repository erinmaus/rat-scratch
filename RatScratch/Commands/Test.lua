local FilesystemService = require("RatScratch.Services.FilesystemService")
local Options = require("RatScratch.Commands.Options")

local Test = {}

Test.OPTIONS = {
	Options["common-meta"],
}

function Test.perform(options, inputs)
	local failedTests = {}
	local passedTests = {}

	FilesystemService.recurse(inputs[1], function(path, func)
		if func then
			func()
			return
		end

		if not path:match("%.lua$") then
			return
		end

		if #inputs >= 2 then
			local runTest = false
			for i = 2, #inputs do
				local input = inputs[i]
				if path:match("Tests/(.*)"):match(input) then
					runTest = true
					break
				end
			end

			if not runTest then
				return
			end
		end

		local chunk = love.filesystem.load(path)

		require("RatScratch.Test").clean()
		local s, r = xpcall(chunk, debug.traceback)
		if not s then
			print(("%s: failure!"):format(path))
			print(r)
			table.insert(failedTests, { test = path, message = r })
		else
			print(("%s: success!"):format(path))
			table.insert(passedTests, { test = path })
		end

		pcall(require("RatScratch.Test").deinit)
	end)

	print(("%d tests passed"):format(#passedTests))
	for i = 1, #passedTests do
		print("-", passedTests[i].test)
	end

	print(("%d tests failed"):format(#failedTests))
	for i = 1, #failedTests do
		print("-", failedTests[i].test)
		print(failedTests[i].message)
	end

	love.event.quit((#failedTests == 0 and #passedTests > 0 and 0) or 1)
end

return Test
