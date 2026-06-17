local REQUIRE_PACKAGE_NAME = ...
local ROOT_REQUIRE_PACKAGE_NAME = REQUIRE_PACKAGE_NAME:match("^(.-%.?)[^.]+$")

local RatScratchCommon = require(REQUIRE_PACKAGE_NAME .. ".bootstrap.Common")
local RatScratchLoveSearch = require(REQUIRE_PACKAGE_NAME .. ".bootstrap.LoveSearch")

local PATH = REQUIRE_PACKAGE_NAME:gsub("%.", "/")
local ROOT_PATH = ROOT_REQUIRE_PACKAGE_NAME:gsub("%.", "/"):gsub("/$", "")
local BASE_PACKAGE_PATTERN = ("^%s*([^.]+)"):format(ROOT_REQUIRE_PACKAGE_NAME:gsub("[%.%-]", "%%%1"))

local common = RatScratchCommon.new(ROOT_PATH)
local search = RatScratchLoveSearch.new(common)
assert(search:isRSLib(PATH), "not Rat Scratch module")

local packages = common:processPackages(search:collectRSLibs())

local function load()
	local function getBasePackage(level)
		local info = debug.getinfo(level + 1, "S")
		local parentRequirePath = (info.source:match("@(.*)/.*$") or ""):gsub("/", ".")
		local basePackage = parentRequirePath:match(BASE_PACKAGE_PATTERN)

		return basePackage
	end

	local require = require
	local xrequire = function(path)
		return common:require(require, getBasePackage(2), path, packages)
	end

	local patchedG = {
		__index = _G,
	}

	local g = { require = xrequire }
	g._G = g

	setfenv(0, setmetatable(g, patchedG))

	return common:require(require, getBasePackage(1), REQUIRE_PACKAGE_NAME .. ".source", packages)
end

local result
do
	local l = coroutine.create(load)
	repeat
		local s, r = coroutine.resume(l)
		if not s then
			error(debug.traceback(l, r))
		end

		result = r
	until coroutine.status(l) == "dead"
end

--- @module "Template.bootstrap.Common"
local module = result

return module
