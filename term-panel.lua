local ffi = require("ffi")
local coerce = require("coerce")

local Panel = { }
local panel_mt = {__index = Panel}

ffi.cdef [[
	//struct panel_color {
		//unsigned char r, g, b, a;
	//};
	typedef unsigned char panel_color;

	struct panel_cell {
		int glyph;
		panel_color fg, bg;
		unsigned char mask;
	};
]]

local function new_panel(width, height, aspect)
	local self = setmetatable({
		width = 0,
		height = 0,
		aspect = 1
	}, panel_mt)

	self:resize(width, height)
	
	return self
end

function Panel:resize(width, height, aspect)
	aspect = aspect or self.aspect

	if self.width == width and self.height == height and self.aspect == aspect then
		return
	else
		local cells = ffi.new("struct panel_cell[?]", 1 + width * height)
		if self.cells then
			for y = 0, math.min(height, self.height) - 1 do
				for x = 0, math.min(width, self.width) - 1 do
					cells[x + y * width] = self.cells[x + y * self.width]
				end
			end
		end

		self.width, self.height, self.cells = width, height, cells
		self.aspect = aspect
	end
end

function Panel:putch(idx, fg, bg, glyph)
	self.cells[idx].fg = fg
	self.cells[idx].bg = bg
	self.cells[idx].glyph = glyph
	-- panel_cell[idx].mask = mask
end

function Panel:getch(idx)
	return 
		self.cells[idx].fg,
		self.cells[idx].bg,
		self.cells[idx].glyph
end

--[[
function term:mask(on)
	if on then
		local width, height = self.adapter.getsize()

		-- it'll be good to reuse this grid!
		-- (also, might make more of this kind of thing, for refreshing,
		--  for panels, etc.)

		local grid = ffi.new("char[?]", width * height)
		ffi.fill(grid, ffi.sizeof(grid), 0)

		self.maskmap = { }

		-- and it'll be great to do this with metatables to save luajit some trouble
		function self.maskmap.blocked(x, y, w)
			-- x, y = x - x1, y - y1
			if y >= 0 and y < height then
				for x = math.max(x, 0), math.min(x + w - 1, width - 1) do
					if grid[x + y * width] ~= 0 then
						return true
					end
				end
			end
			return false
		end
		function self.maskmap.block(x, y, w)
			-- x, y = x - x1, y - y1
			if y >= 0 and y < height then
				for x = math.max(x, 0), math.min(x + w - 1, width - 1) do
					grid[x + y * width] = 1
				end
			end
		end
	else
		self.maskmap = nil
	end
end
]]

function Panel:index(x, y)
	if x < 0 or y < 0 or x >= self.width or y >= self.height then
		return self.width * self.height
	end
	return x + y * self.width
end

return {
	new = new_panel
}

