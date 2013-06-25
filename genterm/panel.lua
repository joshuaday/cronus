local ffi = require("ffi")
local coerce = require("genterm/coerce")

local Panel = { }
local panel_mt = {__index = Panel}

ffi.cdef [[
	//struct panel_color {
		//unsigned char r, g, b, a;
	//};
	typedef unsigned char panel_color;

	struct panel_cell {
		int glyph, link;
		panel_color fg, bg;
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
	
		cells[width * height].fg = 0
		cells[width * height].bg = 0
		cells[width * height].glyph = 0
		cells[width * height].link = 0

		self.width, self.height, self.cells = width, height, cells
		self.aspect = aspect
	end
end

function Panel:putch(idx, fg, bg, glyph, link)
	self.cells[idx].fg = fg
	self.cells[idx].bg = bg
	self.cells[idx].glyph = glyph
	self.cells[idx].link = link
end

function Panel:getch(idx)
	return 
		self.cells[idx].fg,
		self.cells[idx].bg,
		self.cells[idx].glyph,
		self.cells[idx].link
end

function Panel:coords_from_screen_coords(x, y)
	if self.parent then
		return self.parent:coords_from_screen_coords(x - self.x1, y - self.y1)
	else
		return x - self.x1, y - self.y1
	end
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

function Panel:get_printable_bounds()
	local x1, y1, x2, y2 = self.width, self.height, 0, 0
	for y = 0, self.height - 1 do
		local idx = self:index(0, y)
		for x = 0, self.width - 1 do
			local ch = self.cells[idx].glyph 
			if ch > 32 then
				if x < x1 then x1 = x end
				if x > x2 then x2 = x end
				if y < y1 then y1 = y end
				if y > y2 then y2 = y end
			end
			idx = idx + 1
		end
	end

	if x1 < x2 then
		return x1, y1, 1 + x2 - x1, 1 + y2 - y1
	else
		return 0, 0, 0, 0
	end
end


return {
	new = new_panel
}

