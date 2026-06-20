if love and love.filesystem then
	return require("rat-scratch-module.Filesystem.LoveFilesystem")
else
	error("lua-native filesystem library NYI")
end
