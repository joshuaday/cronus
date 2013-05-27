local ffi = require "ffi"
local coerce = require "coerce"
local Sys = require "term-sys"

local hasbold, hasblink = true, true

local function getcurses()
	local ncurses, mouse_support

	ncurses = ffi.load "ncurses"
	mouse_support = true

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

local ascii_remap = {
	tab = string.byte "\t",
	escape = 27,
	enter = string.byte "\n",
	
	-- modified keys:
	cleft = 539,
	cright = 554,
	csleft = 540,
	csright = 555,

	cup = 560,
	cdown = 519,

	cppage = 549,
	cnpage = 544,

	cdc = 513
}

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


local MOUSE

do
	local NCURSES_MOUSE_VERSION = 1
	local NCURSES_MOUSE_MASK
	if NCURSES_MOUSE_VERSION > 1 then
		function NCURSES_MOUSE_MASK(b,m) return bit.lshift((m), (((b) - 1) * 5)) end
	else
		function NCURSES_MOUSE_MASK(b,m) return bit.lshift((m), (((b) - 1) * 6)) end
	end

	local NCURSES_BUTTON_RELEASED = 1
	local NCURSES_BUTTON_PRESSED = 2
	local NCURSES_BUTTON_CLICKED = 4
	local NCURSES_DOUBLE_CLICKED = 8
	local NCURSES_TRIPLE_CLICKED = 16
	local NCURSES_RESERVED_EVENT = 32

	MOUSE = {
		BUTTON1_RELEASED = NCURSES_MOUSE_MASK(1, NCURSES_BUTTON_RELEASED),
		BUTTON1_PRESSED	 = NCURSES_MOUSE_MASK(1, NCURSES_BUTTON_PRESSED),
		BUTTON1_CLICKED	 = NCURSES_MOUSE_MASK(1, NCURSES_BUTTON_CLICKED),
		BUTTON1_DOUBLE_CLICKED = NCURSES_MOUSE_MASK(1, NCURSES_DOUBLE_CLICKED),
		BUTTON1_TRIPLE_CLICKED = NCURSES_MOUSE_MASK(1, NCURSES_TRIPLE_CLICKED),

		BUTTON2_RELEASED = NCURSES_MOUSE_MASK(2, NCURSES_BUTTON_RELEASED),
		BUTTON2_PRESSED	 = NCURSES_MOUSE_MASK(2, NCURSES_BUTTON_PRESSED),
		BUTTON2_CLICKED	 = NCURSES_MOUSE_MASK(2, NCURSES_BUTTON_CLICKED),
		BUTTON2_DOUBLE_CLICKED = NCURSES_MOUSE_MASK(2, NCURSES_DOUBLE_CLICKED),
		BUTTON2_TRIPLE_CLICKED = NCURSES_MOUSE_MASK(2, NCURSES_TRIPLE_CLICKED),

		BUTTON3_RELEASED = NCURSES_MOUSE_MASK(3, NCURSES_BUTTON_RELEASED),
		BUTTON3_PRESSED	 = NCURSES_MOUSE_MASK(3, NCURSES_BUTTON_PRESSED),
		BUTTON3_CLICKED	 = NCURSES_MOUSE_MASK(3, NCURSES_BUTTON_CLICKED),
		BUTTON3_DOUBLE_CLICKED = NCURSES_MOUSE_MASK(3, NCURSES_DOUBLE_CLICKED),
		BUTTON3_TRIPLE_CLICKED = NCURSES_MOUSE_MASK(3, NCURSES_TRIPLE_CLICKED),

		BUTTON4_RELEASED = NCURSES_MOUSE_MASK(4, NCURSES_BUTTON_RELEASED),
		BUTTON4_PRESSED	 = NCURSES_MOUSE_MASK(4, NCURSES_BUTTON_PRESSED),
		BUTTON4_CLICKED	 = NCURSES_MOUSE_MASK(4, NCURSES_BUTTON_CLICKED),
		BUTTON4_DOUBLE_CLICKED = NCURSES_MOUSE_MASK(4, NCURSES_DOUBLE_CLICKED),
		BUTTON4_TRIPLE_CLICKED = NCURSES_MOUSE_MASK(4, NCURSES_TRIPLE_CLICKED),

		-- these get replaced by special code below for mouse versions above 1:
		BUTTON1_RESERVED_EVENT = NCURSES_MOUSE_MASK(1, NCURSES_RESERVED_EVENT),
		BUTTON2_RESERVED_EVENT = NCURSES_MOUSE_MASK(2, NCURSES_RESERVED_EVENT),
		BUTTON3_RESERVED_EVENT = NCURSES_MOUSE_MASK(3, NCURSES_RESERVED_EVENT),
		BUTTON4_RESERVED_EVENT = NCURSES_MOUSE_MASK(4, NCURSES_RESERVED_EVENT),

		BUTTON_CTRL	= NCURSES_MOUSE_MASK(5, 1),
		BUTTON_SHIFT = NCURSES_MOUSE_MASK(5, 2),
		BUTTON_ALT = NCURSES_MOUSE_MASK(5, 4),
		REPORT_MOUSE_POSITION = NCURSES_MOUSE_MASK(5, 8)
	}

	if NCURSES_MOUSE_VERSION > 1 then
		-- these don't really exist in 32-bit version-1:
		MOUSE.BUTTON5_RELEASED = NCURSES_MOUSE_MASK(5, NCURSES_BUTTON_RELEASED)
		MOUSE.BUTTON5_PRESSED = NCURSES_MOUSE_MASK(5, NCURSES_BUTTON_PRESSED)
		MOUSE.BUTTON5_CLICKED = NCURSES_MOUSE_MASK(5, NCURSES_BUTTON_CLICKED)
		MOUSE.BUTTON5_DOUBLE_CLICKED = NCURSES_MOUSE_MASK(5, NCURSES_DOUBLE_CLICKED)
		MOUSE.BUTTON5_TRIPLE_CLICKED = NCURSES_MOUSE_MASK(5, NCURSES_TRIPLE_CLICKED)
		MOUSE.BUTTON_CTRL = NCURSES_MOUSE_MASK(6, 1)
		MOUSE.BUTTON_SHIFT = NCURSES_MOUSE_MASK(6, 2)
		MOUSE.BUTTON_ALT = NCURSES_MOUSE_MASK(6, 4)
		MOUSE.REPORT_MOUSE_POSITION	= NCURSES_MOUSE_MASK(6, 8)
	end

	MOUSE.ALL_MOUSE_EVENTS = (MOUSE.REPORT_MOUSE_POSITION - 1)

	-- macros to extract single event-bits from masks
	function MOUSE.BUTTON_RELEASE(e, x) return bit.band((e), NCURSES_MOUSE_MASK(x, 1)) end
	function MOUSE.BUTTON_PRESS(e, x) return bit.band((e), NCURSES_MOUSE_MASK(x, 2)) end
	function MOUSE.BUTTON_CLICK(e, x) return bit.band((e), NCURSES_MOUSE_MASK(x, 4)) end
	function MOUSE.BUTTON_DOUBLE_CLICK(e, x) return bit.band((e), NCURSES_MOUSE_MASK(x, 8)) end
	function MOUSE.BUTTON_TRIPLE_CLICK(e, x) return bit.band((e), NCURSES_MOUSE_MASK(x, 16)) end
	function MOUSE.BUTTON_RESERVED_EVENT(e, x) return bit.band((e), NCURSES_MOUSE_MASK(x, 32)) end
end



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

			-- ascii control keys
			for name, code in pairs(ascii_remap) do
				keys[name] = code
				keys[code] = name
			end
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
			if attr.mouse_support then


				local all_buttons = 0
				all_buttons = bit.bor(all_buttons, bit.bor(MOUSE.BUTTON1_RELEASED, MOUSE.BUTTON1_PRESSED))
				all_buttons = bit.bor(all_buttons, bit.bor(MOUSE.BUTTON2_RELEASED, MOUSE.BUTTON2_PRESSED))
				all_buttons = bit.bor(all_buttons, bit.bor(MOUSE.BUTTON3_RELEASED, MOUSE.BUTTON3_PRESSED))
	
				ncurses.mousemask(all_buttons, nil)
				ncurses.mouseinterval(0) -- no click processing

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

	local mouse = {
		x = 0, y = 0,
		shift = false, ctrl = false, alt = false,
		left = {isPressed = false, justPressed = false, justReleased = false},
		middle = {isPressed = false, justPressed = false, justReleased = false},
		right = {isPressed = false, justPressed = false, justReleased = false},
		fourth = {isPressed = false, justPressed = false, justReleased = false},
		justMoved = false
	}

	local mevent = ffi.new "MEVENT"
	local function getmouse()
		-- called by getch; never used otherwise

		ncurses.getmouse (mevent)

		mouse.justMoved = (mouse.x ~= mevent.x or mouse.y ~= mevent.y)
		mouse.x = mevent.x
		mouse.y = mevent.y

		mouse.shift = bit.band(mevent.bstate, MOUSE.BUTTON_SHIFT) ~= 0
		mouse.ctrl = bit.band(mevent.bstate, MOUSE.BUTTON_CTRL) ~= 0
		mouse.alt = bit.band(mevent.bstate, MOUSE.BUTTON_ALT) ~= 0
		
		function checkButton(button, pressed, released)
			button.justPressed = false
			button.justReleased = false

			if bit.band(mevent.bstate, pressed) ~= 0 then
				button.justPressed = true
				button.isPressed = true
			elseif bit.band(mevent.bstate, released) ~= 0 then
				if button.isPressed then
					button.justReleased = true
					button.isPressed = false
				end
			--else -- debugging hints:
				--for k, v in pairs(MOUSE) do
					--if v == mevent.bstate then error(k) end
				--end
			end
		end

		checkButton(mouse.left, MOUSE.BUTTON1_PRESSED, bit.bor(MOUSE.BUTTON1_RELEASED, MOUSE.REPORT_MOUSE_POSITION))
		checkButton(mouse.middle, MOUSE.BUTTON2_PRESSED, bit.bor(MOUSE.BUTTON2_RELEASED, MOUSE.REPORT_MOUSE_POSITION))
		checkButton(mouse.right, MOUSE.BUTTON3_PRESSED, bit.bor(MOUSE.BUTTON3_RELEASED, MOUSE.REPORT_MOUSE_POSITION))
		checkButton(mouse.fourth, MOUSE.BUTTON4_PRESSED, bit.bor(MOUSE.BUTTON4_RELEASED, MOUSE.REPORT_MOUSE_POSITION))

		-- return "mouse: " .. mevent.bstate, 1
		return "mouse", mouse
	end

	local function getch(waitms)
		timeout(waitms)

		do
			local ch = ncurses.getch()

			if ch > 31 and ch < 128 then
				return string.char(ch), ch
			elseif keys[ch] == "mouse" then
				return getmouse()
			elseif keys[ch] then
				return keys[ch], ch
			elseif ch > 1 then
				return tostring(ch), ch
			end
		end
	end

	local current_attr = -1
	local function color4(fg, bg)
		local color = ncurses.COLOR_PAIR(1 + bit.band(7, fg) + 8 * bit.band(7, bg))

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


