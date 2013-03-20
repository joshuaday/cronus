local ffi = require("ffi")
local coerce = require("coerce")

-- Supplies the generic terminal implementation that plugs into
-- the curses and libtcod terminal adapters to supply a unified
-- terminal interface to tact (and other related projects.)
--
-- Subterminals, masks, etc., are handled in this layer.
-- 
-- Color coercion happens here, too, but the terminal adapter
-- must specify color capabilities.


--local mode = "libtcod"
local mode = "curses"

local term = { }
local term_mt = { __index = term }

function term:at(x, y)
	self.cursor.x, self.cursor.y = x, y or self.cursor.y
	return self
end

function term:skip(x, y)
	self.cursor.x, self.cursor.y = self.cursor.x + (x or 0), self.cursor.y + (y or 0)
	return self
end
	
function term:cr( )
	self.cursor.x, self.cursor.y = 0, 1 + self.cursor.y
	return self
end

-- color modes mix very uncomfortably here
function term:fg(c, g, b)
	if g ~= nil then
		self.attrib.fg = color(c, g, b, 1)
		self.attrib.fg_4 = false
	else
		if type(c) == "number" then
			self.attrib.fg = bit.band(c, 15)
			self.attrib.fg_4 = true
		else
			self.attrib.fg = c
			self.attrib.fg_4 = false
		end
	end
	return self
end

function term:bg(c, g, b)
	if g ~= nil then
		self.attrib.bg = color(c, g, b, 1)
		self.attrib.bg_4 = false
	else
		if type(c) == "number" then
			self.attrib.bg = bit.band(c, 15)
			self.attrib.bg_4 = true
		else
			self.attrib.bg = c
			self.attrib.bg_4 = false
		end
	end
	return self
end

function term:link(...)
	self.attrib.link = { ... } -- todo: it is probably better just to set the link to the first argument  
	return self
end
	
function term:put(ch)
	if self.attrib.fg_4 then
		self.adapter.color4(self.attrib.fg, self.attrib.bg)
	else
		self.adapter.color32(self.attrib.fg, self.attrib.bg)
	end

	local x, y = self.cursor.x, self.cursor.y

	if x >= 0 and y >= 0 and x < self.clipwidth and y < self.clipheight then
		if not self.run.dry then
			if type(ch) == "string" then
				self.adapter.putch(x + self.x1, y + self.y1, string.byte(ch))
			elseif type(ch) == "number" then
				self.adapter.putch(x + self.x1, y + self.y1, ch)
			end
		end

		self.run.x1 = math.min(self.run.x1, x)
		self.run.x2 = math.max(self.run.x2, x)
		self.run.y1 = math.min(self.run.y1, y)
		self.run.y2 = math.max(self.run.y2, y)
	end

	self.cursor.x = self.cursor.x + 1

	return self
end

function term:print(ch)
	ch = tostring(ch)
	
	if self.maskmap then
		local x, y = self.cursor.x, self.cursor.y
		if self.maskmap.blocked(x, y, #ch) then
			return self, false
		else
			-- maskmap.block(x + math.floor(#ch / 2), y - 1, 2)
			self.maskmap.block(x - 1, y, 2 + #ch)
			-- maskmap.block(x + math.floor(#ch / 2), y + 1, 2)
		end
	end

	for i = 1, #ch do
		self:put(string.byte(ch, i, i))
	end
	return self, true
end

function term:toend(ch)
	if not self.run.dry then
		ch = ch or 32
		for x = self.cursor.x, self.clipwidth - 1 do
			self:put(ch)
		end
	end
end

function term:fill(ch)
	ch = ch or 32
	for y = 0, self.clipheight - 1 do
		self:at(0, y)
		for x = 0, self.clipwidth - 1 do
			self:put(ch)
		end
	end
end

function term:center(ch)
	if type(ch) == 'string' then
		self.cursor.x = self.cursor.x - math.floor(#ch / 2)
	end
	return self:print(ch)
end

function term:getch(waitms)
	return self.adapter.getch(waitms)
end

function term:nbgetch()
	return self.adapter.getch(0)
end

function term:flush()
	while self.adapter.getch(0) do end
end
	
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

function term:getsize() 
	local width, height, aspect = self.adapter.getsize()
	return self.clipwidth or width, self.clipheight or height, aspect
end

function term:clip(x, y, w, h, mode)
	-- todo: rewrite in terms of nested parenting!
	self.x1, self.y1 = x or 0, y or 0

	local cols, lines, aspect = self.adapter.getsize()
	local maxw, maxh = cols - self.x1, lines - self.y1

	w, h = w or maxw, h or maxh
	if w > maxw then w = maxw end
	if h > maxh then h = maxh end
	
	if mode == "square" then
		if w * aspect > h then
			w = math.ceil(h / aspect)
		elseif w * aspect < h then
			h = math.ceil(h * aspect)
		end
	end

	self.clipwidth, self.clipheight = w, h

	return self
end

function term:dryrun(dry)
	local run = self.run
	local inf = 10000
	local _x1, _y1, _x2, _y2 = run.x1, run.y1, run.x2, run.y2
	run.x1, run.y1, run.x2, run.y2, run.dry = inf, inf, -1, -1, dry
	return _x1, _y1, _x2, _y2
end


function term:refresh()
	self.adapter.refresh()
end

function term:erase()
	self.adapter.erase()
end

function term:endwin()
	-- todo : add some protection here
	self.adapter.endwin()
end

function term:napms(ms)
	self.adapter.napms(ms)
end

function term:getms(ms)
	return self.adapter.getms()
end

function term:settitle(name)
	self.adapter.settitle(name)
end

local function rootterm()
	local self = setmetatable({
		adapter = require (mode), -- expose this as an option, and find a way to switch it at runtime
		x1 = 0,
		y1 = 0,
		clipwidth = nil,
		clipheight = nil,
		
		cursor = {x = 0, y = 0},
		attrib = { fg = 7, bg = 0, link = nil },

		run = { }, -- change dry run stuff (if I keep it at all) to switch metatables
		
		maskmap = nil
	}, term_mt)
	
	self:dryrun(false)

	-- local function panel

	--ncurses.attrset(ncurses.COLOR_PAIR(2))
	--ncurses.attrset(attr.bold)

	return self
end



return rootterm() 

