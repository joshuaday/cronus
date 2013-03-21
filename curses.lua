local ffi = require "ffi"
local coerce = require "coerce"

local hasbold, hasblink = true, true

local black = color(0, 0, 0, 1)

local function getcurses()
	local ncurses, mouse_support
	
	if ffi.os == "Windows" then
		ncurses = ffi.load "pdcurses"
		mouse_support = false
	else
		ncurses = ffi.load "ncurses"
		mouse_support = true
	end

	require "cdefheader"

	-- a table of attributes and colors

	local attr = {
		blink = bit.lshift(1, 8 + 11),
		bold = bit.lshift(1, 8 + 13),
		color = {
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
		ncurses.erase()
		ncurses.refresh()
		ncurses.endwin()
	end

	os.atexit(clean)
	-- ffi.C.atexit(ncurses.endwin) -- it'll be nice to add this, just in case

	return ncurses, attr
end

local raw_keys = {
	-- I desperately need to detect these from ncurses.h
	DOWN="0402",
	UP="0403",
	LEFT="0404",
	RIGHT="0405",
	HOME="0406",
	BACKSPACE="0407",
	F0="0410", -- F0 + n = Fn
	DL="0510",
	IL="0511",
	DC="0512",
	IC="0513",
	EIC="0514",
	CLEAR="0515",
	EOS="0516",
	EOL="0517",
	SF="0520",
	SR="0521",
	NPAGE="0522",
	PPAGE="0523",
	STAB="0524",
	CTAB="0525",
	CATAB="0526",
	ENTER="0527",
	PRINT="0532",
	LL="0533",
	A1="0534",
	A3="0535",
	B2="0536",
	C1="0537",
	C3="0540",
	BTAB="0541",
	BEG="0542",
	CANCEL="0543",
	CLOSE="0544",
	COMMAND="0545",
	COPY="0546",
	CREATE="0547",
	END="0550",
	EXIT="0551",
	FIND="0552",
	HELP="0553",
	MARK="0554",
	MESSAGE="0555",
	MOVE="0556",
	NEXT="0557",
	OPEN="0560",
	OPTIONS="0561",
	PREVIOUS="0562",
	REDO="0563",
	REFERENCE="0564",
	REFRESH="0565",
	REPLACE="0566",
	RESTART="0567",
	RESUME="0570",
	SAVE="0571",
	SBEG="0572",
	SCANCEL="0573",
	SCOMMAND="0574",
	SCOPY="0575",
	SCREATE="0576",
	SDC="0577",
	SDL="0600",
	SELECT="0601",
	SEND="0602",
	SEOL="0603",
	SEXIT="0604",
	SFIND="0605",
	SHELP="0606",
	SHOME="0607",
	SIC="0610",
	SLEFT="0611",
	SMESSAGE="0612",
	SMOVE="0613",
	SNEXT="0614",
	SOPTIONS="0615",
	SPREVIOUS="0616",
	SPRINT="0617",
	SREDO="0620",
	SREPLACE="0621",
	SRIGHT="0622",
	SRSUME="0623",
	SSAVE="0624",
	SSUSPEND="0625",
	SUNDO="0626",
	SUSPEND="0627",
	UNDO="0630",
	MOUSE="0631",
	RESIZE="0632",
	EVENT="0633"
}


local function adapter()
	local adapter

	local ncurses, attr, extended = getcurses()
	local keys

	local function initialize()
		local function index_keys()
			keys = { }
			for name, code in pairs(raw_keys) do
				code = tonumber(code, 8)
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
			local stdscr = ncurses.initscr()
			-- ncurses.raw()
			ncurses.noecho()
			ncurses.cbreak()
			ncurses.curs_set(0)
			ncurses.scrollok(stdscr, false)
			ncurses.keypad(stdscr, true)
		end

		local function preparecolor()
			if ncurses.has_colors() then
				ncurses.start_color( )
				for bg = 0, 7 do
					for fg = 0, 7 do
						ncurses.init_pair(1 + fg + bg * 8, fg, bg)
					end
				end
			end
		end

		local function startmouse()
			if attr.mouse_support and ncurses.has_mouse and ncurses.has_mouse() then
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
		io.stdout:write("\027]2;", title, "\007") -- ESC ]0; title BEL
	end

	local function putch(x, y, ch)
		ncurses.mvaddch(y, x, ch)
	end

	local function timeout(timeout)
		if timeout == nil or type(b) == "boolean" then
			timeout = timeout and 0 or -1
		elseif timeout < 0 then
			timeout = -1 -- all negative values are the same, so use -1
		end

		if current_timeout ~= timeout then
			ncurses.wtimeout(ncurses.stdscr, timeout)
			current_timeout = timeout
		end
	end

	local function getch(waitms)
		timeout(waitms)

		do
			local ch = ncurses.getch()
			if ch > 31 and ch < 256 then
				return string.char(ch), ch
			elseif keys[ch] then
				return keys[ch], ch
			elseif ch > 1 then
				return string.char(ch), ch
			end
		end
	end
	
	local function getms()
		local time = ffi.new "struct timeb"
		ffi.C.ftime(time)
		return 1000 * time.time + time.millitm
	end
	
	if ffi.os == "Windows" then
		ffi.cdef [[ unsigned int timeGetTime();]] -- until a proper windows header is generated 
		ffi.cdef [[ int     wgetch(WINDOW *); ]] -- until a proper windows header is generated
		local mm = ffi.load "winmm.dll"
		getms = function()
			return mm.timeGetTime()
		end

		getch = function (waitms)
			timeout(waitms)

			do
				local ch = ncurses.wgetch(ncurses.stdscr)
				if ch > 31 and ch < 256 then
					return string.char(ch), ch
				elseif keys[ch] then
					return keys[ch], ch
				elseif ch > 1 then
					return string.char(ch), ch
				end
			end
		end
	end

	local current_attr = -1
	local function color4(fg, bg)
		local color = ncurses.COLOR_PAIR(1 + bit.band(7, fg) + 8 * bit.band(7, bg)) -- won't work under pdcurses

		if hasbold and fg > 7 then
			color = bit.bor(color, attr.bold)
		end
		if hasblink and bg > 7 then
			color = bit.bor(color, attr.blink)
		end
		if color ~= current_attr then
			ncurses.attrset(color)
			current_attr = color
		end
	end

	if ffi.os == "Windows" then
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
				ncurses.attrset(color)
				current_attr = color
			end
		end
	end


	local function color32(fg, bg)
		fg, bg = coerce.pair(fg, bg)
		color4(fg, bg)
	end

	local aspect = .5
	local function getsize()
		return ncurses.COLS, ncurses.LINES, aspect
	end

	initialize()

	adapter = {
		color4 = color4,
		color32 = color32,
		putch = putch,
		getch = getch,
		getsize = getsize,
		refresh = ncurses.refresh,
		erase = ncurses.erase,
		endwin = ncurses.endwin,
		napms = ncurses.napms,
		getms = getms,
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


