local clear = require("table.clear")
local RatScratchModule = {}

RatScratchModule.REGISTRY = {}
RatScratchModule.PATHS = {}

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
	end
end

function RatScratchModule.addRequireScope(localRequire, moduleRequire, meta)
	if RatScratchModule.PATHS[localRequire] then
		local path = RatScratchModule.PATHS[localRequire]
		assert(path.require == moduleRequire, "import mis-match")
		assert(path.meta.name == meta.name and path.meta.version == meta.version, "import mis-match")

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

function RatScratchModule.getSelfRequire(path)
	if not path then
		local info = debug.getinfo(2, "S")
		path = info and (info.source:match("@(.-)%..*$") or ""):gsub("/", ".")
	end

	if not path then
		return ""
	end

	local pathInfo = RatScratchModule.PATHS[path]
	if not pathInfo then
		return ""
	end

	return pathInfo.require
end

function RatScratchModule.getSelfPath(path)
	if not path then
		local info = debug.getinfo(2, "S")
		path = info and (info.source:match("@(.-)%..*$") or ""):gsub("/", ".")
	end

	if not path then
		return ""
	end

	local pathInfo = RatScratchModule.PATHS[path]
	if not pathInfo then
		return ""
	end

	return pathInfo.path
end

return RatScratchModule
