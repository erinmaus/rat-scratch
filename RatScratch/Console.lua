local Common = {}

function Common.format(format, ...)
	if select("#", ...) == 0 then
		return format
	else
		return format:format(...)
	end
end

function Common.assert(value, format, ...)
	if not value then
		Common.error(format, ...)
	end
end

function Common.error(format, ...)
	local message = Common.format(format, ...)
	Common.write(io.stderr, "[error]: %s\n", message)
	error(message)
end

function Common.warn(format, ...)
	Common.write(io.stderr, "[warning]: %s\n", Common.format(format, ...))
end

function Common.print(format, ...)
	Common.write(io.stdout, "%s\n", Common.format(format, ...))
end

function Common.write(file, format, ...)
	file:write(Common.format(format, ...))
end

return Common
