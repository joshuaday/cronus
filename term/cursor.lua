local Cursor = { }
local Cursor_mt = { __index = Cursor }

local function new_cursor(root, panel, x1, y1, width, height)
	local self = setmetatable({
		root = root,
		panel = panel,

		links = nil, -- one reference per cell, for mouse i/o
		traces = nil, -- stack traces for debugging

		x1 = x1,
		y1 = y1,
		width = width,
		height = height,
		
		x = 0, y = 0,
		fg_c = 7, bg_c = 0, link_c = 0
	}, Cursor_mt)

	return self
end

function Cursor:clip(x, y, w, h, mode)
	x, y = x or 0, y or 0
	if x < 0 then x = x + self.width end
	if y < 0 then y = y + self.height end

	w, h = w or (self.width - x), h or (self.height - y)
	if w <= 0 then w = self.width + w - x end
	if h <= 0 then h = self.height + h - y end

	if mode == "square" then
		if w * self.panel.aspect > h then
			w = math.ceil(h / self.panel.aspect)
		elseif w * self.panel.aspect < h then
			h = math.ceil(h * self.panel.aspect)
		end
	end

	local child = new_cursor(self.root, self.panel, x, y, w, h)
	child.fg_c, child.bg_c, child.link_c = self.fg_c, self.bg_c, self.link_c

	return child
end


function Cursor:at(x, y)
	self.x, self.y = x, y or self.y
	return self
end

function Cursor:skip(x, y)
	self.x, self.y = self.x + (x or 0), self.y + (y or 0)
	return self
end
	
function Cursor:cr( )
	self.x, self.y = 0, 1 + self.y
	return self
end

-- color modes mix very uncomfortably here
function Cursor:fg(c, g, b)
	if g ~= nil then
		self.fg_c = color(c, g, b, 1)
		self.fg_c_4 = false
	else
		if type(c) == "number" then
			self.fg_c = bit.band(c, 15)
			self.fg_c_4 = true
		else
			self.fg_c = c
			self.fg_c_4 = false
		end
	end
	return self
end

function Cursor:bg(c, g, b)
	if g ~= nil then
		self.bg_c = color(c, g, b, 1)
		self.bg_c_4 = false
	else
		if type(c) == "number" then
			self.bg_c = bit.band(c, 15)
			self.bg_c_4 = true
		else
			self.bg_c = c
			self.bg_c_4 = false
		end
	end
	return self
end

function Cursor:link(v)
	self.link_c = v or 0
	return self
end

function Cursor:put(ch)
	--[[if self.fg_c_4 then
		self.adapter.color4(self.attrib.fg_c, self.attrib.bg_c)
	else
		self.adapter.color32(self.attrib.fg_c, self.attrib.bg_c)
	end]]

	-- local st = debug.traceback()

	local x, y = self.x, self.y

	if x >= 0 and y >= 0 and x < self.width and y < self.height then
		local idx = self.panel:index(x + self.x1, y + self.y1)
		if type(ch) == "string" then
			self.panel:putch(idx, self.fg_c, self.bg_c, string.byte(ch), self.link_c)
		elseif type(ch) == "number" then
			self.panel:putch(idx, self.fg_c, self.bg_c, ch, self.link_c)
		end

		--[[self.run.x1 = math.min(self.run.x1, x)
		self.run.x2 = math.max(self.run.x2, x)
		self.run.y1 = math.min(self.run.y1, y)
		self.run.y2 = math.max(self.run.y2, y)]]--
	end

	self.x = self.x + 1

	return self
end

function Cursor:print(ch)
	ch = tostring(ch)
	
	-- todo: add masks
	--[[if self.maskmap then
		local x, y = self.cursor.x, self.cursor.y
		if self.maskmap.blocked(x, y, #ch) then
			return self, false
		else
			-- maskmap.block(x + math.floor(#ch / 2), y - 1, 2)
			self.maskmap.block(x - 1, y, 2 + #ch)
			-- maskmap.block(x + math.floor(#ch / 2), y + 1, 2)
		end
	end]]--

	for i = 1, #ch do
		self:put(string.byte(ch, i, i))
	end
	return self, true
end

function Cursor:toend(ch)
	-- todo: mark this as not changing the panel's "size"
	ch = ch or 32
	for x = self.x, self.width - 1 do
		self:put(ch)
	end

	return self
end

function Cursor:center(ch)
	if type(ch) == "string" then
		self.x = self.x - math.floor(#ch / 2)
	end
	return self:print(ch)
end


function Cursor:fill(glyph)
	-- todo: clip to the panel too

	local fg, bg, link = self.fg_c, self.bg_c, self.link_c
	glyph = glyph or 32
	for y = self.y1, self.y1 + self.height - 1 do
		local idx = self.panel:index(self.x1, y)
		for x = self.x1, self.x1 + self.width - 1 do
			self.panel:putch(idx, fg, bg, glyph, link)
			idx = idx + 1
		end
	end
	return self
end

function Cursor:border(glyph)
	-- todo: clip to the panel too

	local fg, bg, link = self.fg_c, self.bg_c, self.link_c
	glyph = glyph or 32
	
	local top_idx, bottom_idx = self.panel:index(self.x1, self.y1), self.panel:index(self.x1, self.height)

	for x = self.x1, self.x1 + self.width - 1 do
		self.panel:putch(top_idx, fg, bg, glyph, link)
		self.panel:putch(bottom_idx, fg, bg, glyph, link)
		top_idx, bottom_idx = top_idx + 1, bottom_idx + 1
	end

	for y = self.y1, self.y1 + self.height - 1 do
		local left_idx, right_idx = self.panel:index(self.x1, y), self.panel:index(self.x1 + self.width - 1, y)
		self.panel:putch(left_idx, fg, bg, glyph, link)
		self.panel:putch(right_idx, fg, bg, glyph, link)
	end

	return self:clip(1, 1, -2, -2)
end


function Cursor:wipe()
	return self:link():fill(0)
end


-- todo : remove the ADAPTER somehow
-- uncomfortable with these, but eh --

function Cursor:getch(waitms)
	local key, code = self.root:getch(waitms)
	if key == "mouse" then
		local x, y = self.panel:coords_from_screen_coords(code.x, code.y)
		local _, _, _, link = self.panel:getch(self.panel:index(x, y))
		code.link = link
	end
	return key, code
end

function Cursor:nbgetch()
	return self.root:getch(0)
end

function Cursor:flush()
	while self.root:getch(0) do end
end

function Cursor:mask()
	--todo add back
end


return {
	new = new_cursor
}

