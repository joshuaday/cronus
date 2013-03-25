local ffi = require "ffi"
local coerce = require "coerce"
local Sys = require "term-sys"

local hasbold, hasblink = true, true

-- rather than focus on the similarities between pdcurses and ncurses,
-- it seems simpler and cleaner to keep them separate

local function getcurses()
	local pdcurses, mouse_support
	
	pdcurses = ffi.load "pdcurses"
	mouse_support = false

	require "cdefheader"
	ffi.cdef [[ int     wgetch(WINDOW *); ]] -- until a proper pdc header is generated


	-- a table of attributes and colors

	local attr = {
		blink = tonumber("400000", 16),
		bold = tonumber("800000", 16),
		color = { -- these get remapped dynamically to the proper values
			black = 0,
			red = 1,
			green = 2,
			yellow = 3,
			blue = 4,
			magenta = 5,
			cyan = 6,
			gray = 7
		},
		mouse_support = mouse_support
	}
	
	local function clean()
		pdcurses.erase()
		pdcurses.refresh()
		pdcurses.endwin()
	end

	os.atexit(clean)
	-- ffi.C.atexit(pdcurses.endwin) -- it'll be nice to add this, just in case

	return pdcurses, attr
end

local raw_keys = { -- hex constants
	BREAK = "101",
	DOWN = "102",
	UP = "103",
	LEFT = "104",
	RIGHT = "105",
	HOME = "106",
	BACKSPACE= "107",
	F0 = "108",

	DL = "148",
	IL = "149",
	DC = "14a",
	IC = "14b",
	EIC = "14c",
	CLEAR = "14d",
	EOS = "14e",
	EOL = "14f",
	SF = "150",
	SR = "151",
	NPAGE = "152",
	PPAGE = "153",
	STAB = "154",
	CTAB = "155",
	CATAB = "156",
	ENTER = "157",
	SRESET = "158",
	RESET = "159",
	PRINT = "15a",
	LL = "15b",
	ABORT = "15c",
	SHELP = "15d",
	LHELP = "15e",
	BTAB = "15f",
	BEG = "160",
	CANCEL = "161",
	CLOSE = "162",
	COMMAND = "163",
	COPY = "164",
	CREATE = "165",
	END = "166",
	EXIT = "167",
	FIND = "168",
	HELP = "169",
	MARK = "16a",
	MESSAGE = "16b",
	MOVE = "16c",
	NEXT = "16d",
	OPEN = "16e",
	OPTIONS = "16f",
	PREVIOUS = "170",
	REDO = "171",
	REFERENCE= "172",
	REFRESH = "173",
	REPLACE = "174",
	RESTART = "175",
	RESUME = "176",
	SAVE = "177",
	SBEG = "178",
	SCANCEL = "179",
	SCOMMAND = "17a",
	SCOPY = "17b",
	SCREATE = "17c",
	SDC = "17d",
	SDL = "17e",
	SELECT = "17f",
	SEND = "180",
	SEOL = "181",
	SEXIT = "182",
	SFIND = "183",
	SHOME = "184",
	SIC = "185",

	SLEFT = "187",
	SMESSAGE = "188",
	SMOVE = "189",
	SNEXT = "18a",
	SOPTIONS = "18b",
	SPREVIOUS= "18c",
	SPRINT = "18d",
	SREDO = "18e",
	SREPLACE = "18f",
	SRIGHT = "190",
	SRSUME = "191",
	SSAVE = "192",
	SSUSPEND = "193",
	SUNDO = "194",
	SUSPEND = "195",
	UNDO = "196",

	-- /* PDCurses-specific key definitions -- PC only */

	ALT_0 = "197",
	ALT_1 = "198",
	ALT_2 = "199",
	ALT_3 = "19a",
	ALT_4 = "19b",
	ALT_5 = "19c",
	ALT_6 = "19d",
	ALT_7 = "19e",
	ALT_8 = "19f",
	ALT_9 = "1a0",
	ALT_A = "1a1",
	ALT_B = "1a2",
	ALT_C = "1a3",
	ALT_D = "1a4",
	ALT_E = "1a5",
	ALT_F = "1a6",
	ALT_G = "1a7",
	ALT_H = "1a8",
	ALT_I = "1a9",
	ALT_J = "1aa",
	ALT_K = "1ab",
	ALT_L = "1ac",
	ALT_M = "1ad",
	ALT_N = "1ae",
	ALT_O = "1af",
	ALT_P = "1b0",
	ALT_Q = "1b1",
	ALT_R = "1b2",
	ALT_S = "1b3",
	ALT_T = "1b4",
	ALT_U = "1b5",
	ALT_V = "1b6",
	ALT_W = "1b7",
	ALT_X = "1b8",
	ALT_Y = "1b9",
	ALT_Z = "1ba",

	CTL_LEFT = "1bb",
	CTL_RIGHT = "1bc",
	CTL_PGUP = "1bd",
	CTL_PGDN = "1be",
	CTL_HOME = "1bf",
	CTL_END = "1c0",

	A1 = "1c1",
	A2 = "1c2",
	A3 = "1c3",
	B1 = "1c4",
	B2 = "1c5",
	B3 = "1c6",
	C1 = "1c7",
	C2 = "1c8",
	C3 = "1c9",

	PADSLASH = "1ca",
	PADENTER = "1cb",
	CTL_PADENTER = "1cc",
	ALT_PADENTER = "1cd",
	PADSTOP = "1ce",
	PADSTAR = "1cf",
	PADMINUS = "1d0",
	PADPLUS = "1d1",
	CTL_PADSTOP = "1d2",
	CTL_PADCENTER = "1d3",
	CTL_PADPLUS = "1d4",
	CTL_PADMINUS = "1d5",
	CTL_PADSLASH = "1d6",
	CTL_PADSTAR = "1d7",
	ALT_PADPLUS = "1d8",
	ALT_PADMINUS = "1d9",
	ALT_PADSLASH = "1da",
	ALT_PADSTAR = "1db",
	ALT_PADSTOP = "1dc",
	CTL_INS = "1dd",
	ALT_DEL = "1de",
	ALT_INS = "1df",
	CTL_UP = "1e0",
	CTL_DOWN = "1e1",
	CTL_TAB = "1e2",
	ALT_TAB = "1e3",
	ALT_MINUS = "1e4",
	ALT_EQUAL = "1e5",
	ALT_HOME = "1e6",
	ALT_PGUP = "1e7",
	ALT_PGDN = "1e8",
	ALT_END = "1e9",
	ALT_UP = "1ea",
	ALT_DOWN = "1eb",
	ALT_RIGHT = "1ec",
	ALT_LEFT = "1ed",
	ALT_ENTER = "1ee",
	ALT_ESC = "1ef",
	ALT_BQUOTE = "1f0",
	ALT_LBRACKET = "1f1",
	ALT_RBRACKET = "1f2",
	ALT_SEMICOLON = "1f3",
	ALT_FQUOTE = "1f4",
	ALT_COMMA = "1f5",
	ALT_STOP = "1f6",
	ALT_FSLASH = "1f7",
	ALT_BKSP = "1f8",
	CTL_BKSP = "1f9",
	PAD0  = "1fa",

	CTL_PAD0 = "1fb",
	CTL_PAD1 = "1fc",
	CTL_PAD2 = "1fd",
	CTL_PAD3 = "1fe",
	CTL_PAD4 = "1ff",
	CTL_PAD5 = "200",
	CTL_PAD6 = "201",
	CTL_PAD7 = "202",
	CTL_PAD8 = "203",
	CTL_PAD9 = "204",

	ALT_PAD0 = "205",
	ALT_PAD1 = "206",
	ALT_PAD2 = "207",
	ALT_PAD3 = "208",
	ALT_PAD4 = "209",
	ALT_PAD5 = "20a",
	ALT_PAD6 = "20b",
	ALT_PAD7 = "20c",
	ALT_PAD8 = "20d",
	ALT_PAD9 = "20e",

	CTL_DEL = "20f",
	ALT_BSLASH = "210",
	CTL_ENTER = "211",

	SHF_PADENTER = "212",
	SHF_PADSLASH = "213",
	SHF_PADSTAR = "214",
	SHF_PADPLUS = "215",
	SHF_PADMINUS = "216",
	SHF_UP = "217",
	SHF_DOWN = "218",
	SHF_IC = "219",
	SHF_DC = "21a",

	MOUSE = "21b",
	SHIFT_L = "21c",
	SHIFT_R = "21d",
	CONTROL_L= "21e",
	CONTROL_R= "21f",
	ALT_L = "220",
	ALT_R = "221",
	RESIZE = "222",
	SUP = "223",
	SDOWN = "224"
}

local function adapter()
	local adapter

	local pdcurses, attr, extended = getcurses()
	local keys

	local function initialize()
		local function index_keys()
			keys = { }
			for name, code in pairs(raw_keys) do
				code = tonumber(code, 16)
				name = string.lower(name)

				keys[code] = name
				keys[name] = code
			end

			-- f1...f64
			for n = 1, 64 do
				local code = keys.f0 + n
				local name = "f" .. tostring(n)
				keys[code] = name
				keys[name] = code
			end

			-- tab
			keys.tab = string.byte "\t"
			keys[keys.tab] = "tab"
		end

		local function startcurses()
			local stdscr = pdcurses.initscr()
			-- pdcurses.raw()
			pdcurses.noecho()
			pdcurses.cbreak()
			pdcurses.curs_set(0)
			pdcurses.scrollok(stdscr, false)
			pdcurses.keypad(stdscr, true)
		end

		local function preparecolor()
			local flipflop = ffi.new("int[?]", 8)
			flipflop[0], flipflop[1], flipflop[2], flipflop[3],
			flipflop[4], flipflop[5], flipflop[6], flipflop[7] = 
			0, 4, 2, 6, 1, 5, 3, 7 -- pdc uses a different color space than ncurses

			if pdcurses.has_colors() then
				pdcurses.start_color( )
				for bg = 0, 7 do
					for fg = 0, 7 do
						pdcurses.init_pair(1 + fg + bg * 8, flipflop[fg], flipflop[bg])
					end
				end
			end
		end

		local function startmouse()
			if attr.mouse_support and pdcurses.has_mouse and pdcurses.has_mouse() then
				-- mousemask( , nil);

				-- getmouse( );
				--[[extern int     getmouse (MEVENT *);
				extern int     ungetmouse (MEVENT *);
				extern mmask_t mousemask (mmask_t, mmask_t *);
				extern bool    wenclose (const WINDOW *, int, int);
				extern int     mouseinterval (int);
				extern bool    wmouse_trafo (const WINDOW*, int*, int*, bool);
				extern bool    mouse_trafo (int*, int*, bool);              /* generated */
				]]
				
			end
		end

		index_keys()
		startcurses()
		preparecolor()
		startmouse()
	end

	local current_timeout = -1

	local function settitle(title)
		-- this is actually system specific, so pdc and nc should use the same Sys.* logic
		-- io.stdout:write("\027]2;", title, "\007") -- ESC ]0; title BEL
	end

	local function putch(x, y, ch)
		pdcurses.mvaddch(y, x, ch)
	end

	local function timeout(timeout)
		if timeout == nil or type(b) == "boolean" then
			timeout = timeout and 0 or -1
		elseif timeout < 0 then
			timeout = -1 -- all negative values are the same, so use -1
		end

		if current_timeout ~= timeout then
			pdcurses.wtimeout(pdcurses.stdscr, timeout)
			current_timeout = timeout
		end
	end

	local function getch(waitms)
		timeout(waitms)

		do
			local ch = pdcurses.wgetch(pdcurses.stdscr)
			if ch > 31 and ch < 256 then
				return string.char(ch), ch
			elseif keys[ch] then
				return keys[ch], ch
			elseif ch > 1 then
				return string.char(ch), ch
			end
		end
	end

	local current_attr = -1

	color4 = function(fg, bg)
		-- # define PDC_COLOR_SHIFT 24
		-- #define COLOR_PAIR(n)      (((chtype)(n) << PDC_COLOR_SHIFT) & A_COLOR)

		local color = bit.lshift(1 + bit.band(7, fg) + 8 * bit.band(7, bg), 24)

		if hasbold and fg > 7 then
			color = bit.bor(color, attr.bold)
		end
		if hasblink and bg > 7 then
			color = bit.bor(color, attr.blink)
		end
		if color ~= current_attr then
			pdcurses.attrset(color)
			current_attr = color
		end
	end

	local function color32(fg, bg)
		fg, bg = coerce.pair(fg, bg)
		color4(fg, bg)
	end

	local aspect = .5
	local function getsize()
		return pdcurses.COLS, pdcurses.LINES, aspect
	end

	initialize()

	adapter = {
		color4 = color4,
		color32 = color32,
		putch = putch,
		getch = getch,
		getsize = getsize,
		refresh = pdcurses.refresh,
		erase = pdcurses.erase,
		endwin = pdcurses.endwin,
		napms = pdcurses.napms,
		getms = Sys.getms,
		settitle = settitle
	}

	local function debug_wrap()
		for k, v in pairs(adapter) do
			adapter[k] = function(...)
				print (k)
				return v(...)
			end
		end
	end
	--debug_wrap()
	
	return adapter
end

return adapter()


