local Options = {
	["common-meta"] = {
		option = "meta",
		argument = "path",
		description = "path to the Rat Scratch module meta file",
	},

	["common-out"] = {
		option = "out",
		argument = "directory",
		description = "directory relative to Rat Scratch module meta file to output files",
	},

	["inspect-package"] = {
		option = "package",
		argument = "name",
		description = "package to inspect",
	},

	["add-name"] = {
		option = "name",
		argument = "name",
		description = "specify name of library",
	},

	["add-github"] = {
		option = "github",
		description = "magically download module from GitHub",
	},

	["add-root"] = {
		option = "root",
		argument = "directory",
		description = "specify root directory of zip",
	},

	["add-version"] = {
		option = "version",
		argument = "version",
		description = "manually specify version",
	},

	["add-hash"] = {
		option = "hash",
		argument = "<algorithm:hash>",
		description = "manually specify hash (only sha256 and sha512 algorithms supported)",
	},

	["add-source"] = {
		option = "source",
		argument = "<directory>",
		description = "manually specify root directory/file of library or Rat Scratch module meta",
	},

	["common-force"] = {
		option = "force",
		description = "proceed, ignoring warnings",
	},
}

return Options
