local ffi = require "ffi"

local attempt
local errors = { }

if ffi.os == "Windows" then
	attempt = {"genterm/pdc", "genterm/tcod"}
else
	attempt = {"genterm/tcod", "genterm/nc", "genterm/pdc"}
end

local function try_to_load(lib)
	local ok, lib = pcall(require, lib)
	if ok then
		return lib
	else
		errors[1 + #errors] = lib
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
for i = 1, #errors do
	print (errors[i])
end

error ("Could not start " .. table.concat(attempt, " or "))

