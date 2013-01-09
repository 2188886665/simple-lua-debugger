-------------------
-- A simple Lua debugger
-- 
-- Usage:
-- 
-- Require this file:
-- local luadb = require 'luadb'
-- 
-- Set a breakpoint:
-- luadb.b() / luadb.breakpoint()
--
-------------------

local OUR_SOURCE = debug.getinfo(1, "S").source

-------------------
-- "Modules"
-- For the sake of simplicity of integration, I wanted to keep
-- everything in a single file.  I separate some separate components
-- below:
-------------------

-------------------
-- luadb_src - Gets contents of source code files and chunks
-- Currently used to show current line of code at prompt
-------------------
local luadb_src = (function()
	local files = {}

	-- returns an array of lines in 'file'
	local function get_file(file)
		local file_contents = files[file]
		if file_contents then
			return file_contents
		else
			local lines = {}
			local success, line_iter = pcall(function () return io.lines(file) end)
			if success ~= true then
				return nil
			end

			for line in line_iter do
				lines[#lines + 1] = line
			end
			files[file] = lines
			return lines
		end
	end

	-- takes a source string that contains code, and returns an array of lines
	local function parse_string(str)
		local lines, pos = {}, 0
		while pos ~= nil do
			local match_pos = string.find(str, "\n", pos)

			local substr_end = nil
			if match_pos then substr_end = match_pos - 1 end
			
			lines[#lines + 1] = string.sub(str, pos, substr_end)
			
			pos = match_pos
			if pos then pos = pos + 1 end
		end
		return lines
	end

	local function get_line(source, line_number)
		local lines
		if string.sub(source, 1, 1) == "@" then
			lines = get_file(string.sub(source, 2)) -- strip "@" off before!
		else
			lines = parse_string(source)
		end

		if lines == nil then
			return nil
		end

		return lines[line_number]
	end

	-------------------
	-- Public interface
	-------------------
	local luadb_src = {}
	luadb_src.get_line = get_line

	return luadb_src
end)()

-------------------
-- luadb_vars - Helps with variables in the script being debugged
-------------------

local luadb_vars = (function()
	local function new_local_ref(name, value)
		return { name=name, value=value, scope="local" }
	end

	local function new_global_ref(name, value)
		return { name=name, value=value, scope="global" }
	end

	-- finds a variable (only locals currently, upvalues in the future)
	local function find_variable(var_name)
		-- we can start at 3 because: 0 - getinfo, 1 - this func, 2 - internal method calling this func
		local level = 3
		local info = debug.getinfo(level, "S")

		-- navigate up the stack...
		while info ~= nil do
			-- are we out of this file yet?
			if info.source ~= OUR_SOURCE then
				-- loop through all local variables at current level
				local local_index = 1
				local name, value = debug.getlocal(level, local_index)

				while name ~= nil do
					if name == var_name then
						return new_local_ref(name, value)
					else
						local_index = local_index + 1
						name, value = debug.getlocal(level, local_index)
					end
				end
			end

			level = level + 1
			info = debug.getinfo(level, "S")
		end

		if _G[var_name] ~= nil then
			return new_global_ref(var_name, _G[var_name])
		end

		return nil
	end

	-------------------
	-- Public interface
	-------------------
	local luadb_vars = {}
	luadb_vars.find_variable = find_variable

	return luadb_vars
end)()



-------------------
-- Core
-------------------

local MODE_RUNNING = nil
local MODE_PAUSED = "paused"
local MODE_STEP_INTO = "step_into"
local MODE_STEP_OVER = "step_over"

local mode = nil
local step_over_depth = 0

local command_handlers = {}

local function get_line_of_code(debug_info)
	return luadb_src.get_line(debug_info.source, debug_info.currentline)
end

local function listen_for_input(debug_info)
	local finished = false
	repeat
		local loc = get_line_of_code(debug_info)
		if loc then
			print("(db) " .. debug_info.short_src .. ":" .. debug_info.currentline .. ":", loc)
		end
		io.write("(db) >> ")
		local input = io.read()
		local command = string.match(input, "%w+")

		local handler = command_handlers[command]
		if handler then
			local success, result = pcall(function() return handler(input) end)
			if not success then
				print("(db) Failed running command: " .. tostring(result))
			else
				if result == true then
					finished = true
				end
			end
		else
			print("(db) Unknown command: " .. command)
		end
	until finished
end

local function debug_event(event, line)
	-- ignore events if they are happening inside luadb
	local debug_info = debug.getinfo(2, "lS")
	local source = debug_info.source
	if source == OUR_SOURCE then
		return
	end
	
	if event == "line" then
		if mode == MODE_PAUSED then
			listen_for_input(debug_info)
		elseif mode == MODE_STEP_INTO then
			mode = MODE_PAUSED
			listen_for_input(debug_info)
		elseif mode == MODE_STEP_OVER then
			if step_over_depth == 0 then
				mode = MODE_PAUSED
				listen_for_input(debug_info)
			end
		end
	elseif mode == MODE_STEP_OVER then
		if event == "call" then
			step_over_depth = step_over_depth + 1
		elseif event == "return" or event == "tail return" then
			step_over_depth = step_over_depth - 1
		end
	end
end

local function breakpoint()
	if mode == MODE_RUNNING then
		local debug_info = debug.getinfo(2, "Sl")
		local src = debug_info.short_src
		local line = debug_info.currentline
		print("(db) Hit breakpoint: " .. src .. ":" .. line)

		mode = MODE_PAUSED
		debug.sethook(debug_event, "lrc")
	end
end

-------------------
-- Commands
-------------------

-- If a command returns true, it'll continue execution

command_handlers["continue"] = function()
	debug.sethook()
	mode = MODE_RUNNING
	return true
end
command_handlers["c"] = command_handlers["continue"]

command_handlers["step"] = function()
	mode = MODE_STEP_INTO
	return true
end
command_handlers["s"] = command_handlers["step"]

command_handlers["next"] = function()
	mode = MODE_STEP_OVER
	return true
end
command_handlers["n"] = command_handlers["next"]

command_handlers["do"] = function(input)
	-- parse out the 'do':
	local code = string.sub(input, 3)
	if #code == 0 then  -- multiline input
		print("(db) multiline input, finish with a line containing only ';'")
		code = ""
		local line = ""
		while line ~= ";" do
			line = io.read()
			if line ~= ";" then
				code = code .. line .. "\n"
			end
		end
	end
	local func, err = loadstring(code)
	if func == nil then
		error(err)
	else
		func()
	end
end

command_handlers["print"] = function(input)
	local var_name = string.match(input, "%a+%s+([%a_]+)")
	local var = luadb_vars.find_variable(var_name)
	
	if var == nil then
		print(nil)
	else
		print(var.value)
	end
end
command_handlers["p"] = command_handlers["print"]

-------------------
-- Public interface
-------------------

local luadb = {}
luadb.b = breakpoint
luadb.breakpoint = breakpoint

return luadb
