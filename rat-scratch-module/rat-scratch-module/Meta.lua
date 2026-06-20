local Meta = {}

local function _validateVersionPart(value)
	if not (value and (value:match("%d+") or value == "~")) then
		return false
	end

	return true
end

local function _validateVersion(major, minor, patch)
	return _validateVersionPart(major) and _validateVersionPart(minor) and _validateVersionPart(patch)
end

local function _splitVersion(version)
	if version == "*" then
		-- "~" will always be "greater" in a string comparison than a string of numbers
		-- we could use string.char(127) (DEL) or something but that's not always printable
		-- needs to be UTF-8 compatible, so >127 is not possible
		return "~", "~", "~"
	end

	return version:gsub("*", "~"):match("([%d~]+)%.([%d~]+)%.([%d~]+)")
end

local function _compareVersionPart(a, b)
	if a == b then
		return 0
	elseif a < b then
		return 1
	elseif a > b then
		return -1
	end
end

function Meta.compareVersion(a, b)
	local aMajor, aMinor, aPatch = _splitVersion(a)
	local bMajor, bMinor, bPatch = _splitVersion(b)

	local major = _compareVersionPart(aMajor, bMajor)
	local minor = _compareVersionPart(aMinor, bMinor)
	local patch = _compareVersionPart(aPatch, bPatch)

	if major == 0 then
		if minor == 0 then
			return patch
		end

		return minor
	end

	return major
end

function Meta.versionLess(a, b)
	return Meta.compareVersion(a, b) < 0
end

local function _isVersionPartEqual(current, required)
	if required == "~" or current == "~" then
		return true
	end

	return current == required
end

local function _isVersionPartGreater(current, required)
	if required == "~" or current == "~" then
		return true
	end

	return current > required
end

local function _isVersionPartGreaterThanEqual(current, required)
	return _isVersionPartGreater(current, required) or _isVersionPartEqual(current, required)
end

function Meta.isVersionExactMatch(packageVersion, requiredVersion)
	local packageMajor, packageMinor, packagePatch = _splitVersion(packageVersion)
	local requiredMajor, requiredMinor, requiredPatch = _splitVersion(requiredVersion)

	return _isVersionPartEqual(packageMajor, requiredMajor)
		and (
			_isVersionPartGreater(packageMinor, requiredMinor)
			or (
				_isVersionPartEqual(packageMinor, requiredMinor)
				or _isVersionPartGreaterThanEqual(packagePatch, requiredPatch)
			)
		)
end

function Meta.isVersionMatch(packageVersion, requiredVersion)
	local packageMajor, packageMinor, packagePatch = _splitVersion(packageVersion)
	local requiredMajor, requiredMinor, requiredPatch = _splitVersion(requiredVersion)

	return _isVersionPartGreaterThanEqual(packageMajor, requiredMajor)
		and (
			_isVersionPartGreater(packageMinor, requiredMinor)
			or (
				_isVersionPartEqual(packageMinor, requiredMinor)
				or _isVersionPartGreaterThanEqual(packagePatch, requiredPatch)
			)
		)
end

local function _validatePackage(packages, package, lineNumber)
	if not package.version and package.name then
		error(("%d: expected current package to have version and name"):format(lineNumber - 1))
	end

	if not _validateVersion(_splitVersion(package.version)) then
		error(("%d: package version malformed: %s"):format(lineNumber, package.version))
	end

	for _, otherPackage in ipairs(packages) do
		if otherPackage.name == package.name then
			error(('%d: duplicate package "%s"'):format(lineNumber, package.name))
		end
	end
end

function Meta.parse(data)
	local packages = {}
	local currentPackage = {}

	local packageLineNumber = 1
	local lineNumber = 0

	for line in data:gmatch("([^\r\n]*)\r?\n?") do
		lineNumber = lineNumber + 1

		line = line:gsub("^%s*(.*)%s$", "%1"):gsub("(.-)#.*$", "%1")
		local key, value = line:match("%s*(.-)%s*=%s*(.*)%s*")
		local nextPackageName = line:match("%[%s*([%w][%w%d+-]*)%s*]")

		if key and value then
			currentPackage[key] = value
		elseif nextPackageName then
			_validatePackage(packages, currentPackage, packageLineNumber)
			packageLineNumber = lineNumber

			table.insert(packages, currentPackage)
			currentPackage = { name = nextPackageName }
		elseif line ~= "" then
			error("%d: malformed Rat Scrach meta TOML line, could not parse; expected key/value on package name")
		end
	end

	_validatePackage(packages, currentPackage)
	table.insert(packages, currentPackage)

	return packages
end

function Meta.fromFile(filename, data)
	if not data then
		error(("Rat Scratch module meta not found at path: %s"):format(filename))
	end

	local success, result = pcall(Meta.parse, data)
	if not success then
		error(("%s:%s"):format(filename, result))
	end

	return result
end

local _keysByIndex = {
	"name",
	"version",
	"license",
	"source",
	"url",
	"hash",
	"root",
	"directory.build",
	"directory.library",
	"lls.module",
}

local function _getKeyIndex(key)
	for index, otherKey in ipairs(_keysByIndex) do
		if otherKey == key then
			return index
		end
	end

	return nil
end

local function _lessKey(a, b)
	local aIndex = _getKeyIndex(a[1])
	local bIndex = _getKeyIndex(b[1])

	if aIndex and bIndex then
		return aIndex < bIndex
	elseif aIndex then
		return true
	elseif bIndex then
		return false
	end

	return a < b
end

local function _stringify(package, excludedKeys)
	local keyValues = {}

	for key, value in pairs(package) do
		if not (excludedKeys and excludedKeys[key]) then
			table.insert(keyValues, { key, value })
		end
	end

	table.sort(keyValues, _lessKey)

	local result = {}
	for _, keyValuePair in ipairs(keyValues) do
		local key, value = unpack(keyValuePair)
		table.insert(result, ("%s = %s"):format(key, value))
	end

	return table.concat(result, "\n")
end

local _dependencyPackageExcludedKeys = {
	name = true,
}

local function _serialize(packages)
	local result = {}
	table.insert(result, _stringify(packages[1]))

	if #packages > 1 then
		table.insert(result, "")
	end

	for i = 2, #packages do
		table.insert(result, ("[%s]"):format(packages[i].name))
		table.insert(result, _stringify(packages[i], _dependencyPackageExcludedKeys))

		if i < #packages then
			table.insert(result, "")
		end
	end

	return table.concat(result, "\n")
end

function Meta.serialize(meta)
	if #meta == 0 then
		return _stringify(meta)
	end

	return _serialize(meta)
end

function Meta.buildPath(package, path)
	local result = path:gsub("%$%{(.-)%}", function(value)
		return package[value]
	end)

	return result
end

return Meta
