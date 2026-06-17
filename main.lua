local App = require("RatScratch.App")

local IS_DEBUG = false

for i = 2, #arg do
	if arg[i] == "/debug" or arg[i] == "--debug" then
		IS_DEBUG = true
	end
end

IS_DEBUG = IS_DEBUG and os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1"
if IS_DEBUG then
	require("lldebugger").start()

	function love.errorhandler(msg)
		error(msg, 2)
	end
end

function love.load(args)
	App.run(args)

	love.event.quit(0)
end
