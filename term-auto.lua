local ffi = require "ffi"

local attempt
if ffi.os == "Windows" then
	attempt = {"term-pdc", "term-tcod"}
else
	attempt = {"term-tcod", "term-nc", "term-pdc"}
end

local function try_to_load(lib)
	local ok, lib = pcall(require, lib)
	if ok then
		return lib
	else
		return nil
	end
end

for i = 1, #attempt do
	lib = try_to_load(attempt[i])
	if lib ~= nil then
		return lib
	end
end

-- could not load any terminal mode!  oh no!

error ("Could not start " .. table.concat(attempt, " or "))

