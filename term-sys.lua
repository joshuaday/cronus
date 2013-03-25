-- system-specific substitutes for functionality that is lacking in one
-- terminal library or another (and for detecting, e.g., which terminal
-- emulator is in use.)

local ffi = require "ffi"
local Sys = { }


ffi.cdef [[
	unsigned int timeGetTime();
]] 

if ffi.os == "Windows" then
	local mm = ffi.load "winmm.dll"

	function Sys.getms()
		return mm.timeGetTime()
	end
else
	function Sys.getms()
		local time = ffi.new "struct timeb"
		ffi.C.ftime(time)
		return 1000 * time.time + time.millitm
	end
end

return Sys

