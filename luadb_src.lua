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
