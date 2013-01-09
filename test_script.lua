luadb = require 'luadb'

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

local eval_me = [[
luadb.b()
for i = 1, 10 do
	print(i, "squared:", i * i)
end
]]

local eval_me_chunk = loadstring(eval_me)
luadb.b()
eval_me_chunk()
