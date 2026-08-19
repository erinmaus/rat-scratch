local ARGS = ...
local THREAD_FILENAME = ARGS.filename
local REQUIRE_PACKAGE_NAME = ARGS.path
local ROOT_REQUIRE_PACKAGE_NAME = REQUIRE_PACKAGE_NAME:match("^(.-%.?)[^.]+$")

local RatScratchCommon = require(REQUIRE_PACKAGE_NAME .. ".bootstrap.Common")
local RatScratchLoveSearch = require(REQUIRE_PACKAGE_NAME .. ".bootstrap.LoveSearch")
local RatScratchMeta = require(REQUIRE_PACKAGE_NAME .. ".bootstrap.Meta")

local PATH = REQUIRE_PACKAGE_NAME:gsub("%.", "/")
local ROOT_PATH = ROOT_REQUIRE_PACKAGE_NAME:gsub("%.", "/"):gsub("/$", "")
local BASE_PACKAGE_PATTERN = ("^%s*([^.]+)"):format(ROOT_REQUIRE_PACKAGE_NAME:gsub("[%.%-]", "%%%1"))

local common = RatScratchCommon.new(ROOT_PATH, RatScratchMeta)
local search = RatScratchLoveSearch.new(common)
assert(search:isRSLib(PATH), "not Rat Scratch module")

local function load()
	local rsModule

	local function getBasePackage(level)
		local info = debug.getinfo(level + 1, "S")
		local parentRequirePath = (info.source:match("@(.*)/.*$") or ""):gsub("/", ".")
		local basePackage = parentRequirePath:match(BASE_PACKAGE_PATTERN)

		return basePackage
	end

	local function registerPackage(path, module, package)
		if rsModule then
			rsModule.register(package.meta, path, module)

			if not package.bundled and package.isRSLib then
				rsModule.addRequireScope(path, ("%s.source"):format(package.require), package.meta)
			else
				rsModule.addRequireScope(path, package.require, package.meta)
			end

			rsModule.addWarnings(package.meta, common:getWarnings())
		end
	end

	local require = require
	local xrequire = function(path)
		local result, resolvedPath, package = common:require(require, getBasePackage(1), path, packages)
		if package then
			assert(not resolvedPath:match("/"))
			registerPackage(resolvedPath or path, result, package)
		end

		return result
	end

	local patchedG = {
		__index = _G,
	}

	local g = { require = xrequire }
	g._G = g

	setfenv(0, setmetatable(g, patchedG))

	rsModule = common:require(require, getBasePackage(1), REQUIRE_PACKAGE_NAME, packages)
	rsModule.initialize()

	local chunk, e = love.filesystem.load(THREAD_FILENAME)
	if not chunk then
		error(e)
	end

	chunk(unpack(ARGS.args, 1, ARGS.n))
end

require("love.data")
require("love.event")
require("love.image")
require("love.math")
require("love.system")
require("love.thread")
require("love.timer")

do
	local l = coroutine.create(load)
	repeat
		local s, r = coroutine.resume(l)
		if not s then
			error(debug.traceback(l, r))
		end
	until coroutine.status(l) == "dead"
end
