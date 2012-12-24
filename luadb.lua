local enabled = false
local command_handlers = {}

local function listen_for_input()
	local finished = false
	repeat
		io.write("(LuaDB) >> ")
		local input = io.read()
		local command = string.match(input, "%w+")

		local handler = command_handlers[command]
		if handler then
			finished, error_msg = pcall(function() handler(input) end)
			if not finished and error_msg then
				print("(LuaDB) Failed running command: " .. tostring(error_msg))
			end
		else
			print("(LuaDB) Unknown command: " .. command)
		end
	until finished
end

local function line_event(event, line)
	listen_for_input()
end


command_handlers["continue"] = function()
	debug.sethook()
	enabled = false
end
command_handlers["c"] = command_handlers["continue"]

local function breakpoint()
	if not enabled then
		local debug_info = debug.getinfo(2, "Sl")
		local src = debug_info.short_src
		local line = debug_info.currentline
		print("(LuaDB) Hit breakpoint: " .. src .. ":" .. line)

		enabled = true
		debug.sethook(line_event, "l")
	end
end

-- Public interface
local luadb = {}
luadb.b = breakpoint
luadb.breakpoint = breakpoint

return luadb
