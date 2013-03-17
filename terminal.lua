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

local function rootterm()
	local adapter = require (mode)

	local x1, y1 = 0, 0
	local clipwidth, clipheight
	
	local term
	local cursor = {
		x = 0, y = 0
	}
	local run = { }

	local attrib = { fg = 7, bg = 0, link = nil }
	
	local maskmap = nil
	
	local function at(x, y)
		cursor.x, cursor.y = x, y or cursor.y
		return term
	end

	local function skip(x, y)
		cursor.x, cursor.y = cursor.x + (x or 0), cursor.y + (y or 0)
		return term
	end
	
	local function cr( )
		cursor.x, cursor.y = 0, 1 + cursor.y
	end

	local function fg(c, g, b)
		if g ~= nil then
			attrib.fg = color(c, g, b, 1)
			attrib.fg_4 = false
		else
			if type(c) == "number" then
				attrib.fg = bit.band(c, 15)
				attrib.fg_4 = true
			else
				attrib.fg = c
				attrib.fg_4 = false
			end
		end
		return term
	end

	local function bg(c, g, b)
		if g ~= nil then
			attrib.bg = color(c, g, b, 1)
			attrib.bg_4 = false
		else
			if type(c) == "number" then
				attrib.bg = bit.band(c, 15)
				attrib.bg_4 = true
			else
				attrib.bg = c
				attrib.bg_4 = false
			end
		end
		return term
	end

	local function link(...)
		link = { ... }
		return term
	end
	
	local function put(ch)
		if attrib.fg_4 then
			adapter.color4(attrib.fg, attrib.bg)
		else
			adapter.color32(attrib.fg, attrib.bg)
		end

		local x, y = cursor.x, cursor.y

		if x >= 0 and y >= 0 and x < clipwidth and y < clipheight then
			if not run.dry then
				if type(ch) == "string" then
					adapter.putch(x + x1, y + y1, string.byte(ch))
				elseif type(ch) == "number" then
					adapter.putch(x + x1, y + y1, ch)
				end
			end

			run.x1 = math.min(run.x1, x)
			run.x2 = math.max(run.x2, x)
			run.y1 = math.min(run.y1, y)
			run.y2 = math.max(run.y2, y)
		end

		cursor.x = cursor.x + 1

		return term
	end

	local function print(ch)
		ch = tostring(ch)
		
		if maskmap then
			local x, y = cursor.x, cursor.y
			if maskmap.blocked(x, y, #ch) then
				return term, false
			else
				-- maskmap.block(x + math.floor(#ch / 2), y - 1, 2)
				maskmap.block(x - 1, y, 2 + #ch)
				-- maskmap.block(x + math.floor(#ch / 2), y + 1, 2)
			end
		end

		for i = 1, #ch do
			put(string.byte(ch, i, i))
		end
		return term, true
	end

	local function toend(ch)
		if not run.dry then
			ch = ch or 32
			for x = cursor.x, clipwidth - 1 do
				put(ch)
			end
		end
	end

	local function fill(ch)
		ch = ch or 32
		for y = 0, clipheight - 1 do
			at(0, y)
			for x = 0, clipwidth - 1 do
				put(ch)
			end
		end
	end

	local function center(ch)
		if type(ch) == 'string' then
			cursor.x = cursor.x - math.floor(#ch / 2)
		end
		return term.print(ch)
	end

	local function nbgetch()
		return adapter.getch(0)
	end

	local function flush()
		while adapter.getch(0) do end
	end
	
	local function mask(on)
		if on then
			local width, height = adapter.getsize()
			local grid = ffi.new("char[?]", width * height)

			for i = 0, width * height - 1 do
				grid[i] = 0
			end

			maskmap = { }

			function maskmap.blocked(x, y, w)
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
			function maskmap.block(x, y, w)
				-- x, y = x - x1, y - y1
				if y >= 0 and y < height then
					for x = math.max(x, 0), math.min(x + w - 1, width - 1) do
						grid[x + y * width] = 1
					end
				end
			end
		else
			maskmap = nil
		end
	end
	
	local function getsize() 
		local width, height, aspect = adapter.getsize()
		return clipwidth or width, clipheight or height, aspect
	end

	local function clip(x, y, w, h, mode)
		x1, y1 = x or 0, y or 0
		local cols, lines, aspect = adapter.getsize()
		local maxw, maxh = cols - x1, lines - y1

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

		clipwidth, clipheight = w, h

		return term
	end

	local function dryrun(dry)
		local inf = 10000
		local _x1, _y1, _x2, _y2 = run.x1, run.y1, run.x2, run.y2
		run.x1, run.y1, run.x2, run.y2, run.dry = inf, inf, -1, -1, dry
		return _x1, _y1, _x2, _y2
	end
	dryrun(false)

	-- local function panel

	--ncurses.attrset(ncurses.COLOR_PAIR(2))
	--ncurses.attrset(attr.bold)

	term = {
		fg = fg,
		bg = bg,
		at = at,
		skip = skip,
		cr = cr,
		put = put,
		print = print,
		toend = toend,
		center = center,
		link = link,

		dryrun = dryrun,

		nbgetch = nbgetch,
		getch = adapter.getch,
		flush = flush,
		getsize = getsize,
		
		clip = clip,
		mask = mask,
		fill = fill,

		refresh = adapter.refresh,
		erase = adapter.erase,
		endwin = adapter.endwin,
		napms = adapter.napms,
		getms = adapter.getms,
		
		settitle = adapter.settitle,

		panel = panel,
		color = color
	}
	
	return term
end



return rootterm() 

