local Options = require("RatScratch.Commands.Options")
local Console = require("RatScratch.Console")
local GitHubService = require("RatScratch.Services.GitHubService")
local DownloadAllPackages = require("RatScratch.Patterns.DownloadAllPackages")
local ResolvePackageDependencies = require("RatScratch.Patterns.ResolvePackageDependencies")
local AddPackage = require("RatScratch.Patterns.AddPackage")
local InstallPackage = require("RatScratch.Patterns.InstallPackage")
local WriteLock = require("RatScratch.Patterns.WriteLock")
local ValidateLock = require("RatScratch.Patterns.ValidateLock")
local MetaService = require("RatScratch.Services.MetaService")
local PrepareBundleLock = require("RatScratch.Patterns.PrepareBundleLock")

local Add = {}

Add.OPTIONS = {
	Options["common-force"],
	Options["common-meta"],
	Options["add-github"],
	Options["add-hash"],
	Options["add-name"],
	Options["add-root"],
	Options["add-source"],
	Options["add-version"],
}

function Add.perform(options, inputs)
	Console.assert(#inputs == 1, "expected input URL of package")

	local url = inputs[1]
	local version = options.version or url:match("(%d+%.%d+%.%d+)")

	Console.assert(
		options.github or not (url:match("^http://") and not options.hash),
		"hash not provided and using insecure 'http' protocol; must provide hash manually"
	)

	local hashAlgorithm = options.hash and options.hash:match("(sha%d+):") or "sha512"

	Console.assert(
		not hashAlgorithm or hashAlgorithm == "sha512" or hashAlgorithm == "sha256",
		"specified hash algorithm unsupported: %s",
		hashAlgorithm
	)

	local name = options.name

	local urls
	local root = options.root
	if options.github then
		local organization, project, identifierType, identifier = url:match("(.-)/(.*)([#@])(.*)")
		if identifierType == "#" then
			urls = { GitHubService.buildHashDownloadURL(organization, project, identifier) }
			root = root or ("^%s-%s([%w%a]*)$"):format(project, identifier):gsub("%-", "%%-")
		else
			urls = {
				GitHubService.buildTagDownloadURL(organization, project, identifier),
				GitHubService.buildBranchDownloadURL(organization, project, identifier),
			}

			if identifier:match("^%w%d+%.%d+%.%d+") then
				-- GitHub drops the "v" from tags in the form "v1.0.0"... Let's be a bit cautious and make the entire letter optional.
				root = root
					or ("^%s-%s$")
						:format(project, identifier:gsub("^(%w)(%d+%.%d+%.%d+)", "%1?%2"))
						:gsub("([%-%.])", "%%%1")
			else
				root = root or ("^%s-%s$"):format(project, identifier):gsub("([%-%.])", "%%%1")
			end
		end

		name = name or project:gsub("%.lua$", "") -- 'bump.lua' -> bump, 'json.lua' -> json
	else
		urls = { url }
	end

	local pendingMeta = {
		name = name,
		version = version,
		root = root,
		hash = options.hash,
		source = options.source,
	}

	local parentMeta = MetaService.parseMeta()
	local modifiedMeta = DownloadAllPackages(pendingMeta, urls, parentMeta[1])

	Console.assert(modifiedMeta.name, "could not determine package name: %s", url)
	Console.assert(modifiedMeta.version, "could not determine package version: %s", url)

	local packageMeta = AddPackage(modifiedMeta)
	local lock = ResolvePackageDependencies(packageMeta, options.force)

	for i = 2, #lock do
		InstallPackage(lock[i])
	end

	local finalLock = PrepareBundleLock(lock, packageMeta)
	ValidateLock(finalLock)
	WriteLock(finalLock, packageMeta)
end

return Add
