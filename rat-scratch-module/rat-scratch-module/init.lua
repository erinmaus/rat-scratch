local clear = require("table.clear")
local Filesystem = require("rat-scratch-module.Filesystem")
local Meta = require("rat-scratch-module.Meta")

local RatScratchModule = {}
RatScratchModule.Meta = require("rat-scratch-module.Meta")

RatScratchModule.REGISTRY = {}
RatScratchModule.PATHS = {}
RatScratchModule.LIBRARIES = {}
RatScratchModule.IS_INTIALIZED = true

function RatScratchModule.initialize()
	RatScratchModule.IS_INTIALIZED = true
end

local function _compareMeta(a, b)
	if a.name == b.name then
		return Meta.versionLess(a.version, b.version)
	end

	return a.name < b.name
end

function RatScratchModule.register(meta, moduleRequire, module)
	local registeredModule = RatScratchModule.REGISTRY[meta.name]
	if not registeredModule then
		registeredModule = {
			versions = {},
			modulesByVersion = {},
			warnings = {},
		}

		RatScratchModule.REGISTRY[meta.name] = registeredModule
	end

	if not registeredModule.modulesByVersion[meta.version] then
		table.insert(registeredModule.versions, meta.version)
		table.sort(registeredModule.versions)

		registeredModule.modulesByVersion[meta.version] = {
			module = module,
			require = moduleRequire,
			path = moduleRequire:gsub("%.", "/"),
			warnings = {},
		}

		table.insert(RatScratchModule.LIBRARIES, meta)
		table.sort(RatScratchModule.LIBRARIES, _compareMeta)
	end
end

function RatScratchModule.addRequireScope(localRequire, moduleRequire, meta)
	if RatScratchModule.PATHS[localRequire] then
		local path = RatScratchModule.PATHS[localRequire]
		assert(path.require == moduleRequire, "import mismatch")
		assert(path.meta.name == meta.name and path.meta.version == meta.version, "import mismatch")

		return
	end

	RatScratchModule.PATHS[localRequire] = {
		require = moduleRequire,
		path = moduleRequire:gsub("%.", "/"),
		meta = meta,
	}
end

function RatScratchModule.addWarnings(meta, warnings)
	local registeredModule = RatScratchModule.REGISTRY[meta.name]
	if not registeredModule then
		return
	end

	local module = registeredModule.modulesByVersion[meta.version]
	for _, warning in ipairs(warnings) do
		table.insert(registeredModule, warning)

		if module then
			table.insert(module.warnings, warning)
		end
	end
end

function RatScratchModule.iterate()
	return ipairs(RatScratchModule.LIBRARIES)
end

function RatScratchModule.getWarnings(name, version, result)
	result = result or {}
	clear(result)

	local registeredModule = RatScratchModule.REGISTRY[name]
	if not registeredModule then
		return result
	end

	local warnings = version
		and registeredModule.modulesByVersion[version]
		and registeredModule.modulesByVersion[version].warnings
	warnings = warnings or registeredModule.warnings

	for _, warning in ipairs(warnings) do
		table.insert(result, warning)
	end

	return result
end

function RatScratchModule.getVersions(name, result)
	result = result or {}
	clear(result)

	local registeredModule = RatScratchModule.REGISTRY[name]
	if not registeredModule then
		return result
	end

	for _, version in ipairs(registeredModule.versions) do
		table.insert(result, version)
	end

	return result
end

function RatScratchModule.getModule(name, version)
	local registeredModule = RatScratchModule.REGISTRY[name]
	local module = registeredModule and registeredModule.modulesByVersion[version]
	return module and module.module
end

function RatScratchModule.getPath(name, version)
	local registeredModule = RatScratchModule.REGISTRY[name]
	local module = registeredModule and registeredModule.modulesByVersion[version]
	return module and module.path
end

function RatScratchModule.getRequire(name, version)
	local registeredModule = RatScratchModule.REGISTRY[name]
	local module = registeredModule and registeredModule.modulesByVersion[version]
	return module and module.require
end

local function _findPath(path)
	if RatScratchModule.PATHS[path] ~= nil then
		return RatScratchModule.PATHS[path]
	end

	local filename = path:gsub("%.", "/")
	local possibleMeta = { { filename = ".rsmeta", directory = "" } }

	local currentPath
	for localPath in filename:gmatch("([^/]+)/?") do
		local nextPath = currentPath and ("%s/%s"):format(currentPath, localPath) or localPath

		table.insert(possibleMeta, 1, {
			filename = ("%s/.rsmeta"):format(nextPath),
			directory = nextPath,
		})

		table.insert(possibleMeta, 1, {
			filename = currentPath and ("%s/%s.rsmeta"):format(currentPath, localPath)
				or ("%s.rsmeta"):format(localPath),
			directory = currentPath or localPath,
		})

		currentPath = nextPath
	end

	local rootSelfPath, meta
	for _, possibleMeta in ipairs(possibleMeta) do
		if love.filesystem.getInfo(possibleMeta.filename, "file") then
			local packages = Meta.fromFile(possibleMeta.filename, Filesystem.read(possibleMeta.filename))
			local package = packages and packages[1]

			if package then
				rootSelfPath = possibleMeta.directory
				meta = packages
				break
			end
		end
	end

	if not (rootSelfPath and meta) then
		RatScratchModule.PATHS[path] = false
		return nil
	end

	local selfPath = rootSelfPath

	local requirePath = selfPath:gsub("/", ".")
	local targetMeta
	do
		local lib = meta[1]["directory.library"] or "./lib"
		lib = lib:gsub("^%./", ""):gsub("/", ".")

		local libRequirePath = ("%s.%s"):format(requirePath, lib)
		do
			local _, j = path:find(libRequirePath, 1, true)

			if j then
				local packageName = path:sub(j + 1):match("%.?([^%.]*)")

				requirePath = ("%s.%s"):format(libRequirePath, packageName)

				for i = 2, #meta do
					if meta[i].name == packageName then
						targetMeta = meta[i]
						break
					end
				end
			else
				local possibleSelfPath = rootSelfPath ~= ""
						and ("%s/%s"):format(rootSelfPath, meta[1].source or "source")
					or meta[1].source
				if possibleSelfPath and love.filesystem.getInfo(possibleSelfPath, "directory") then
					requirePath = possibleSelfPath:gsub("/", ".")
					selfPath = possibleSelfPath
					targetMeta = meta[1]
				end
			end
		end

		if not targetMeta then
			local _, j = path:find(requirePath, 1, true)
			if j then
				requirePath = ("%s%s"):format(selfPath:gsub("/", "."), path:sub(j + 1))
			end
		end
	end

	targetMeta = targetMeta or meta[1]
	RatScratchModule.PATHS[path] = {
		require = requirePath,
		path = selfPath,
		meta = {
			name = targetMeta.name,
			version = targetMeta.version,
		},
	}

	return RatScratchModule.PATHS[path]
end

function RatScratchModule.getSelfRequire(path)
	if not path then
		local info = debug.getinfo(2, "S")
		path = info and (info.source:match("@(.-)%..*$") or ""):gsub("/", ".")
	end

	if not path then
		return ""
	end

	local pathInfo = _findPath(path)
	return pathInfo and pathInfo.require or ""
end

function RatScratchModule.getSelfPath(path)
	if not path then
		local info = debug.getinfo(2, "S")
		path = info and (info.source:match("@(.-)%..*$") or ""):gsub("/", ".")
	end

	if not path then
		return ""
	end

	if not path then
		return ""
	end

	local pathInfo = _findPath(path)
	return pathInfo and pathInfo.path or ""
end

return RatScratchModule
