local luadb = require 'luadb'

-- used for testing step vs next
local function return_arg(arg)
	return arg
end

print("Hello")
luadb.b()
print(return_arg("World"))
print("Hows it going?")
luadb.b()
print("Good, if this works!")
