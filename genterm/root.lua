local ffi = require("ffi")
local coerce = require "genterm/coerce"
local Panel = require "genterm/panel"
local Cursor = require "genterm/cursor"
local Menu = require "menu"

-- Supplies the generic terminal implementation that plugs into
-- the curses and libtcod terminal adapters to supply a unified
-- terminal interface to tact (and other related projects.)
--
-- Subterminals, masks, etc., are handled in this layer.
-- 
-- Color coercion happens here, too, but the terminal adapter
-- must specify color capabilities.


--local mode = "term-libtcod"
--local mode = "term-nc"
local mode = "genterm/auto"

local Terminal = { }
local term_mt = {__index = Terminal}

-- the mask goes into the panel, now

function Terminal:getsize() 
	local width, height, aspect = self.adapter.getsize()
	return self.clipwidth or width, self.clipheight or height, aspect
end

function Terminal:dryrun(dry)
	local run = self.run
	local inf = 10000
	local _x1, _y1, _x2, _y2 = run.x1, run.y1, run.x2, run.y2
	run.x1, run.y1, run.x2, run.y2, run.dry = inf, inf, -1, -1, dry
	return _x1, _y1, _x2, _y2
end


function Terminal:refresh()
	-- collect garbage (!!!) to remove orphaned panels
	collectgarbage "collect"

	-- (this is a terrible algorithm but there are so few panels, it's silly to worry)
	-- copy panels over
	local children = { }

	for k, v in pairs(self.panels) do
		local p = k.parent or children -- pretend that all unrooted panels are children of /children/

		if not children[p] then
			children[p] = { }
		end

		children[p][1 + #children[p]] = k
	end

	-- sort children of each parent
	for k, v in pairs(children) do
		table.sort(v, function (a, b)
			if a.z < b.z then return 1 elseif a.z > b.z then return -1 else return 0 end
		end)
	end

	-- todo only write each cell once no matter how many panels overlap
	children._x1, children._y1 = 0, 0
	local function draw_panel(panel)
		local x1, y1 = panel._x1, panel._y1

		for y = 0, panel.height - 1 do
			for x = 0, panel.width - 1 do
				local idx = panel:index(x, y)
				local fg, bg, glyph = panel:getch(idx)

				if glyph > 0 then
					self.adapter.color4(fg, bg)
					self.adapter.putch(x + x1, y + y1, glyph)
				end
			end
		end
	end

	local function draw_children(panel)
		local x1, y1 = panel._x1, panel._y1

		local kids = children[panel]
		if kids then
			for i = 1, #kids do
				local kid = kids[i]
				kid._x1, kid._y1 = x1 + kid.x1, y1 + kid.y1
				draw_panel(kid)
				draw_children(kid)
			end
		end
	end

	draw_children(children)

	-- and refresh the adapter
	self.adapter.refresh()
end

function Terminal:erase()
	self.adapter.erase()
end

function Terminal:endwin()
	-- todo : add some protection here
	self.adapter.endwin()
end

function Terminal:napms(ms)
	self.adapter.napms(ms)
end

function Terminal:getms()
	return self.adapter.getms()
end

function Terminal:settitle(name)
	self.adapter.settitle(name)
end

function Terminal:getch(waitms)
	self:refresh()
	return self.adapter.getch(waitms)
end

function Terminal:nbgetch()
	self:refresh()
	return self.adapter.getch(0)
end

function Terminal:flush()
	while self.adapter.getch(0) do end
end

function Terminal:cursor()
	local cols, lines, aspect = self.adapter.getsize()
	return Cursor.new(self, self.panel, 0, 0, self.panel.width, self.panel.height)
end

function Terminal:panel_from_cursor(term)
	local panel = Panel.new(term.width, term.height, self.panel.aspect)
	panel.x1, panel.y1, panel.z, panel.parent = term.x1, term.y1, 0, term.panel

	self.panels[panel] = true
	
	return Cursor.new(self, panel, 0, 0, term.width, term.height)
end


local function open_terminal()
	local adapter = require(mode)
	local cols, lines, aspect = adapter.getsize()

	local self = setmetatable({
		adapter = adapter, -- expose this as an option, and find a way to switch it at runtime
		panel = Panel.new(cols, lines, aspect),
		panels = setmetatable({ }, {__mode = "k"})
	}, term_mt)

	self.panel.x1, self.panel.y1, self.panel.z = 0, 0, 0
	self.panels[self.panel] = true

	return self:cursor()
end

return {
	open = open_terminal
}

