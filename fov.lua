local ffi = require "ffi"

ffi.cdef [[
	typedef struct {
		int idx, len;
		double angle[600];
		double light[600];

		double last_cell_color;
	} fovhead;
]]

local bufs = {ffi.new("fovhead"), ffi.new("fovhead")}

-- fovhead_zoomto always works with floating point, but the scan function
-- has been adapted to give integral output
function fovhead_zoomto(dest, src, close_angle, inv_angle, cell_color)
	local endangle = dest.angle[dest.idx - 1]
	
	if dest.idx > 1 then
		local lcc = dest.last_cell_color
		if cell_color == dest.last_cell_color then
			-- we're rewinding the _destination_ tape but not the _source_ tape
			-- (and we're keeping the real 'firstangle'
			dest.idx = dest.idx - 1
		end
	end
	
	-- we run from firstangle to close_angle, copying whatever angles and
	-- colors we see in src as we run them, but filtering (i.e., multiplying)
	-- them by cell_color before writing them out

	local sum = 0

	if cell_color == 0 then
		-- zip past all the input and then just write a single chunky block
		local breakout = false
		while src.idx < src.len do
			local oldangle = endangle
			endangle = src.angle[src.idx]

			if endangle >= close_angle then
				endangle = close_angle
				breakout = true
			end

			local angle = endangle - oldangle
			sum = sum + angle * src.light[src.idx]

			if breakout then
				break
			end
			src.idx = src.idx + 1
		end

		dest.angle[dest.idx] = close_angle
		dest.light[dest.idx] = cell_color
		dest.idx = dest.idx + 1

		dest.last_cell_color = cell_color
	else
		local breakout = false
		while src.idx < src.len do
			local oldangle = endangle
			endangle = src.angle[src.idx]

			-- now check whether this source angle goes farther than we need right now
			if endangle > close_angle then
				endangle = close_angle
				breakout = true
			end

			local angle = endangle - oldangle
			local d, s = dest.light[dest.idx], src.light[src.idx]
			sum = sum + angle * src.light[src.idx]

			dest.angle[dest.idx] = endangle
			dest.light[dest.idx] = src.light[src.idx]
			dest.idx = dest.idx + 1

			if breakout then
				break
			else
				src.idx = src.idx + 1
			end
		end

		dest.last_cell_color = cell_color
	end
	
	return sum * inv_angle
end

local clear = 1
local opaque = 0

local nonmask = {
	get = function () return 1.0 end
}

local function scan(board, output, view_x, view_y, mask, integer_permittivity)
	local src, dest = bufs[1], bufs[2]
	local range = math.ceil(math.max(output.height, output.width) / 2)

	-- these three lines make it so you can see the cells next to you
	src.len = 2
	src.angle[1] = 1.1 
	src.light[1] = clear

	dest.angle[0] = 0
	src.angle[0] = 0

	-- output.recenter(view_x, view_y) -- this is now an external requirement
	output:fill(opaque)
	output:set(view_x, view_y, clear)

	if mask then
		mask:recenter(view_x, view_y)
	else
		mask = nonmask
	end

	local out_cells, out_width = output.cells, output.width
	
	for z = 1, range - 1 do
		local x, y = view_x - z, view_y - z
		local idx = output:index(x, y)

		local sidelength = 2.0 * z
		local inv_cell_length = (4.0 * sidelength)
		local cell_length = 1 / (4.0 * sidelength)
		local cellnumber = .5
		
		src.idx, dest.idx = 1, 1

		for side = 0, 3 do
			local dx, dy, didx

			if side == 0 then dx, dy, didx = 1, 0, 1
			elseif side == 1 then dx, dy, didx = 0, 1, out_width
			elseif side == 2 then dx, dy, didx = -1, 0, -1
			elseif side == 3 then
				dx, dy, didx = 0, -1, -out_width
				sidelength = sidelength + 1.0 	
			end
				
			for t = 1, sidelength do
				local close = cellnumber * cell_length
				local index = board:index(x, y) -- branching in here is probably slow
				local m = mask:get(x, y)

				if true or index > 0 and m > 0.0 then 
					-- the commented test makes it faster, but causes weird artifacts
					local info = board.cells[index]
					local sight = fovhead_zoomto(dest, src, close, inv_cell_length, board.cells[index])
					-- out_cells[idx] = sight * m-- double version
					out_cells[idx] = sight > integer_permittivity and m or 0 -- integer version
				else
					-- a hack to keep the skipping happy.  doesn't work, though.
					dest.angle[dest.idx - 1] = close
				end
				
				x, y, idx = x + dx, y + dy, idx + didx

				cellnumber = cellnumber + 1
			end
		end
		dest.len = dest.idx

		-- swap!
		src, dest = dest, src
	end
end

return {
	scan = scan
}

