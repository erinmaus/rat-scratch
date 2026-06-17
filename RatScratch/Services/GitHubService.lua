local https = require("https")
local Console = require("RatScratch.Console")

local GitHubService = {}

function GitHubService.buildTagDownloadURL(organization, project, tag)
	return ("https://github.com/%s/%s/archive/refs/tags/%s.zip"):format(organization, project, tag)
end

function GitHubService.buildBranchDownloadURL(organization, project, branch)
	return ("https://github.com/%s/%s/archive/refs/head/%s.zip"):format(organization, project, branch)
end

function GitHubService.buildHashDownloadURL(organization, project, hash)
	return ("https://github.com/%s/%s/archive/%s.zip"):format(organization, project, hash)
end

function GitHubService.downloadTagOrBranch(organization, project, tagOrBranch)
	local tagURL = GitHubService.buildTagDownloadURL(organization, project, tagOrBranch)
	local branchURL = GitHubService.buildBranchDownloadURL(organization, project, tagOrBranch)

	Console.print("Trying download URL '%s'...", tagURL)
	local tagCode, tagResult = https.request(tagURL)
	if tagCode == 200 and tagResult then
		Console.print("Success.")
		return tagResult
	end

	Console.print("Got %d response, trying download URL '%s'...", tagCode, branchURL)
	local branchCode, branchResult = https.request(branchURL)
	if branchCode == 200 and branchResult then
		Console.print("Success.")
		return branchResult
	end

	Console.warn("Got %d response; failed!", branchCode)
	return nil
end

function GitHubService.downloadHash(organization, project, hash)
	local hashURL = GitHubService.buildHashDownloadURL(organization, project, hash)

	Console.print("Trying download URL '%s'...", hashURL)
	local code, result = https.request(hashURL)
	if code == 200 and result then
		Console.print("Success.")
		return result
	end

	Console.warb("Got %d response; failed!", code)
	return nil
end

return GitHubService
