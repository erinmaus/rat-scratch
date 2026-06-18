# Rat Scratch

`rat-scratch` is a tool to bundle specific types of Lua libraries together.

The magic of `rat-scratch` is it provides a special entry point to load libraries and dependencies easily. With `rat-scratch`, you can just import your module like so:

```lua
-- Completely made up libraries!
local rs_graphics_2d = require("lib.rat-scratch-graphics-2d")
local rs_graphics_3d = require("lib.rat-scratch-graphics-3d")
local rs_common = require("lib.rat-scratch-common")

local camera2D = rs_graphics_2d.Camera()
local camera3D = rs_graphics_3d.Camera()

-- The cool part... This will be true!
-- rs_graphics_2d and rs_graphics_3d will use the same rs_math
-- module at runtime using dark magic!
assert(getmetatable(camera2D:getPosition()) == getmetatable(camera3D:getPosition()))
```

`rat-scratch` really only works with libraries that have a single entry point, currently.

## Using Rat Scratch

Create a `.rsmeta` in the root of your project, like so:

```
name = test
version = 1.0.0
source = test.lua
```

Then, run `rat-scratch` to add a library:

```sh
ratscratch add --github --source=json.lua rxi/json.lua@v0.1.2
```

Now use the library in your project:

```lua
local json = require("lib.json")
return {
	hello = function()
		return json.encode({ message = "hello, world!" })
	end
}
```

Then build the app:

```sh
ratscratch build
```

And then zip up `build/test-v1.0.0` and distribute it!

Others can put your library anywhere:

```lua
local test = require("game.lib.test")
print(test.hello())
```

No need to force them to bundle `json` and put it somewhere specific!

## License

`rat-scratch` is licensed under the MPL 2.0
