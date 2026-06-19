local RatScratchCommon = {}
local RatScratchCommonMetatable = { __index = RatScratchCommon }

function RatScratchCommon.new(path)
	return setmetatable({
		path = path,
		packages = {},
		warnings = {},
		resolved = {},
	}, RatScratchCommonMetatable)
end

function RatScratchCommon:getPath()
	return self.path
end

function RatScratchCommon:getWarnings()
	return self.warnings
end

function RatScratchCommon:assert(value, format, ...)
	if not value then
		local message = self:print(io.stderr, "[Rat Scratch error]: %s\n", format, ...)
		error(message)
	end
end

function RatScratchCommon:debug(format, ...)
	--- @diagnostic disable-next-line: undefined-field
	if _G._RSM_DEBUG then
		self:print(io.stdout, "[Rat Scratch debug]: %s\n", format, ...)
	end
end

function RatScratchCommon:warn(format, ...)
	local message = self:print(io.stderr, "[Rat Scratch warning]: %s\n", format, ...)
	table.insert(self.warnings, message)
end

function RatScratchCommon:print(stream, wrapper, format, ...)
	local message
	if select("#", ...) == 0 then
		message = format
	else
		message = format:format(...)
	end

	stream:write(wrapper:format(message))
	return message
end

local function _matchPackagePath(path, pattern, currentPackageName, currentPackageRequire)
	if currentPackageName and currentPackageRequire then
		return currentPackageName, currentPackageRequire
	end

	return path:match(pattern)
end

function RatScratchCommon:require(require, basePackageName, path, packages)
	local basePackageWithName = basePackageName and packages[basePackageName] and packages[basePackageName].base
	if not basePackageWithName or not basePackageWithName.isRSLib then
		return package.loaded[path] or require(path)
	end

	local packageName, packageRequire
	if path == basePackageWithName.require then
		packageName = basePackageName
	else
		packageName, packageRequire = _matchPackagePath(
			path,
			("^%s%%.%s%%.([^.]+)%%.?(.*)"):format(
				basePackageWithName.pattern,
				basePackageWithName.childrenPrefixPattern or "lib"
			),
			packageName,
			packageRequire
		)
		packageName, packageRequire = _matchPackagePath(
			path,
			("^%s%%.([^.]+)%%.?(.*)"):format(basePackageWithName.childrenPrefixPattern or "lib"),
			packageName,
			packageRequire
		)
		packageName, packageRequire = _matchPackagePath(path, "^([^.]+)%.?(.*)", packageName, packageRequire)
	end

	local packagesWithName = packages[packageName]
	local targetPackageWithName = packagesWithName and basePackageWithName.packages[packageName]

	if not targetPackageWithName and basePackageWithName and not basePackageWithName.bundled then
		local newPath
		if not packageRequire then
			newPath = ("%s.source"):format(basePackageWithName.require)
		else
			newPath = ("%s.source.%s"):format(basePackageWithName.require, packageRequire)
		end

		return package.loaded[newPath] or require(newPath), newPath, basePackageWithName
	end

	if not targetPackageWithName or (packageName and packageRequire and packageRequire ~= "") then
		return package.loaded[path] or require(path), path, targetPackageWithName or basePackageWithName
	end

	local basePackageResolutions = self.resolved[basePackageName]
	if not basePackageResolutions then
		basePackageResolutions = {}
	end

	local bestPackageWithName, closestPackageWithName

	-- Try existing loaded package.
	do
		local currentPackageWithName = self.packages[packageName]
		if
			currentPackageWithName
			and self:isVersionMatch(currentPackageWithName.version, targetPackageWithName.version)
		then
			bestPackageWithName = currentPackageWithName
		end
	end

	-- Try exact match.
	if not bestPackageWithName then
		for _, namedPackage in ipairs(packagesWithName.packages) do
			if self:isVersionMatch(namedPackage.version, targetPackageWithName.version) then
				bestPackageWithName = namedPackage
				break
			elseif
				not closestPackageWithName
				and self:isVersionMaybeMatch(namedPackage.version, targetPackageWithName.version)
			then
				closestPackageWithName = closestPackageWithName
			end
		end
	end

	local result, package
	if bestPackageWithName then
		local currentPackageWithName = self.packages[packageName]
		if currentPackageWithName and bestPackageWithName.version ~= currentPackageWithName.version then
			self:warn(
				'module "%s@%s" (path = "%s") imported package "%s@%s" (path = "%s"), but already loaded package "%s@%s" (path = "%s"); there might be runtime compatibility isssues',
				basePackageWithName.name,
				basePackageWithName.version,
				basePackageWithName.path,
				bestPackageWithName.name,
				bestPackageWithName.version,
				bestPackageWithName.path,
				currentPackageWithName.name,
				currentPackageWithName.version,
				currentPackageWithName.path
			)
		else
			self.packages[packageName] = bestPackageWithName
		end

		result = require(bestPackageWithName.require)
		package = bestPackageWithName
	elseif closestPackageWithName then
		self:warn(
			'module "%s@%s" (path = "%s") required package "%s@%s" (path = "%s"), but closest package was "%s@%s" (path = "%s"); there might be runtime compatibility isssues',
			basePackageWithName.name,
			basePackageWithName.version,
			basePackageWithName.path,
			targetPackageWithName.name,
			targetPackageWithName.version,
			targetPackageWithName.path,
			closestPackageWithName.name,
			closestPackageWithName.version,
			closestPackageWithName.path
		)

		local currentPackageWithName = self.packages[packageName]
		if currentPackageWithName and closestPackageWithName.version ~= currentPackageWithName.version then
			self:warn(
				'module "%s@%s" (path = "%s") imported package "%s@%s" (path = "%s"), but already loaded package "%s@%s" (path = "%s"); there might be runtime compatibility isssues',
				basePackageWithName.name,
				basePackageWithName.version,
				basePackageWithName.path,
				bestPackageWithName.name,
				bestPackageWithName.version,
				bestPackageWithName.path,
				currentPackageWithName.name,
				currentPackageWithName.version,
				currentPackageWithName.path
			)
		else
			self.packages[packageName] = closestPackageWithName
		end

		result = require(closestPackageWithName.require)
		package = closestPackageWithName
	end

	if result == nil then
		self:warn(
			'module "%s@%s" (path = "%s") required package "%s@%s" (path = "%s"), but no matching package found; probably a bug in Rat Scratch',
			basePackageWithName.name,
			basePackageWithName.version,
			basePackageWithName.path,
			targetPackageWithName.name,
			targetPackageWithName.version,
			targetPackageWithName.path
		)

		if not self.packages[packageName] then
			self.packages[packageName] = targetPackageWithName
		end

		result = require(targetPackageWithName.require)
		package = targetPackageWithName
	end

	return result, package.require, package
end

function RatScratchCommon:splitVersion(version)
	if version == "*" then
		-- "~" will always be "greater" in a string comparison than a string of numbers
		-- we could use string.char(127) (DEL) or something but that's not always printable
		-- needs to be UTF-8 compatible, so >127 is not possible
		return "~", "~", "~"
	end

	local major, minor, patch = version:gsub("*", "~"):match("([%d~]+)%.([%d~]+)%.([%d~]+)")
	self:assert(major and minor and patch, "malformed version string: %s", version)

	return major, minor, patch
end

local function _isEqual(current, required)
	if required == "~" or current == "~" then
		return true
	end

	return current == required
end

local function _isGreater(current, required)
	if required == "~" or current == "~" then
		return true
	end

	return current > required
end

local function _isGreaterThanEqual(current, required)
	return _isGreater(current, required) or _isEqual(current, required)
end

function RatScratchCommon:isVersionMatch(packageVersion, requiredVersion)
	local packageMajor, packageMinor, packagePatch = self:splitVersion(packageVersion)
	local requiredMajor, requiredMinor, requiredPatch = self:splitVersion(requiredVersion)

	return _isEqual(packageMajor, requiredMajor)
		and (
			_isGreater(packageMinor, requiredMinor)
			or (_isEqual(packageMinor, requiredMinor) or _isGreaterThanEqual(packagePatch, requiredPatch))
		)
end

function RatScratchCommon:isVersionMaybeMatch(packageVersion, requiredVersion)
	local packageMajor, packageMinor, packagePatch = self:splitVersion(packageVersion)
	local requiredMajor, requiredMinor, requiredPatch = self:splitVersion(requiredVersion)

	return _isGreaterThanEqual(packageMajor, requiredMajor)
		and (
			_isGreater(packageMinor, requiredMinor)
			or (_isEqual(packageMinor, requiredMinor) or _isGreaterThanEqual(packagePatch, requiredPatch))
		)
end

function RatScratchCommon:compareVersion(a, b)
	local aMajor, aMinor, aPatch = self:splitVersion(a)
	local bMajor, bMinor, bPatch = self:splitVersion(b)

	if aMajor == bMajor then
		if aMinor == bMinor then
			return aPatch > bPatch
		end

		return aMinor > bMinor
	end

	return aMajor > bMajor
end

function RatScratchCommon:processPackages(packages)
	local packagesByName = {}

	for _, package in ipairs(packages) do
		local packageName = package.path:match("([^/]*)$")
		local packagesWithName = packagesByName[packageName]
		if not packagesWithName then
			packagesWithName = { packages = {} }
			packagesByName[packageName] = packagesWithName
		end

		local namedPackage = {
			path = package.path,
			require = package.path:gsub("/", "."),
			pattern = package.path:gsub("%-", "%%-"):gsub("/", "%%."),
			name = packageName,
			bundled = false,
			isRSLib = package.isRSLib,
			meta = package.meta and package.meta[1],
		}

		if package.isRSLib and package.packages then
			local childrenPrefix = (package.packages[1]["directory.library"] or "./lib")
				:gsub("^%.?/*", "")
				:gsub("/*$", "")
				:gsub("/", ".")

			namedPackage.version = package.packages[1].version
			namedPackage.childrenPrefix = childrenPrefix
			namedPackage.childrenPrefixPattern = childrenPrefix:gsub("[%-%.]", "%%%1")
			namedPackage.packages = {}

			for i = 2, #package.packages do
				local childPackage = package.packages[i]
				local childPackagesWithName = packagesByName[childPackage.name]
				if not childPackagesWithName then
					childPackagesWithName = { packages = {} }
					packagesByName[childPackage.name] = childPackagesWithName
				end

				local childPath = ("%s/%s/%s"):format(package.path, childrenPrefix, childPackage.name)
				local childRequire = childPath:gsub("/", ".")
				local childPattern = childPath:gsub("[%-%.]", "%%%1")

				local childNamedPackage = {
					path = childPath,
					require = childRequire,
					name = childPattern,
					version = childPackage.version,
					isRSLib = childPackage.isRSLib,
					bundled = true,
				}

				for j = 2, #package.meta do
					local otherMeta = package.meta[j]
					if otherMeta.name == childPackage.name then
						childNamedPackage.meta = otherMeta
						break
					end
				end

				table.insert(childPackagesWithName.packages, childNamedPackage)
				namedPackage.packages[childPackage.name] = childNamedPackage
			end
		else
			namedPackage.version = "*"
		end

		packagesWithName.base = namedPackage
		table.insert(packagesWithName.packages, namedPackage)
	end

	for _, namedPackage in pairs(packagesByName) do
		table.sort(namedPackage.packages, function(a, b)
			local aLessThanB = self:compareVersion(a.version, b.version)
			local bLessThanA = self:compareVersion(b.version, a.version)

			local isSameVersion = aLessThanB == bLessThanA
			if isSameVersion then
				return a.path < b.path
			end

			return aLessThanB
		end)

		for i = 2, #namedPackage.packages do
			local previousPackage = namedPackage.packages[i - 1]
			local currentPackage = namedPackage.packages[i]

			self:assert(
				(
					self:compareVersion(previousPackage.version, currentPackage.version)
					or (not self:compareVersion(currentPackage.version, previousPackage.version))
						and previousPackage.path < currentPackage.path
				),
				'package sorting logic failure: package "%s@%s" (path = "%s") should be BEFORE package "%s@%s" (path = "%s")',
				currentPackage.name,
				currentPackage.version,
				currentPackage.path,
				previousPackage.name,
				previousPackage.version,
				previousPackage.path
			)
		end
	end

	return packagesByName
end

function RatScratchCommon:parseTOML(fileData)
	if fileData == nil then
		self:assert("missing Rat Scratch meta TOML")
	end

	local packages = {}
	local currentPackage = {}
	local lineNumber = 0

	local function validatePackage()
		self:assert(
			currentPackage.version and currentPackage.name,
			"line %d: expected current package to have version and name",
			lineNumber - 1
		)

		for _, otherPackage in ipairs(packages) do
			self:assert(
				otherPackage.name ~= currentPackage.name,
				'line %d: duplicate package "%s"',
				currentPackage.name
			)
		end
	end

	for line in fileData:gmatch("([^\r\n]*)\r?\n?") do
		lineNumber = lineNumber + 1

		line = line:gsub("^%s*(.*)%s$", "%1"):gsub("(.-)#.*$", "%1")
		local key, value = line:match("%s*(.-)%s*=%s*(.*)%s*")
		local nextPackageName = line:match("%[%s*([%w][%w%d+-]*)%s*]")

		if key and value then
			currentPackage[key] = value
		elseif nextPackageName then
			validatePackage()

			table.insert(packages, currentPackage)
			currentPackage = { name = nextPackageName }
		else
			self:assert(
				#line == 0,
				"line %d: malformed Rat Scratch meta TOML line, could not parse; expected key/value or package name",
				lineNumber
			)
		end
	end

	validatePackage()

	table.insert(packages, currentPackage)
	return packages
end

return RatScratchCommon
