-------------------
-- Tracks contents of source code files.
--
-- Currently used to show current line of code at prompt
--
-- NOTE: Doesn't currently handle multiple paths being used to access the same
-- file. For example: using 'example.lua', '/home/example_user/lua/example.lua'
-- and '~/lua/example.lua' would read the file 3 times
-------------------

local files = {}

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

local function get_line(file, line_number)
	local lines = get_file(file)
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
