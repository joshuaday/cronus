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

local pdc_keys = {
	BREAK = "0x101",
	DOWN = "0x102",
	UP = "0x103",
	LEFT = "0x104",
	RIGHT = "0x105",
	HOME = "0x106",
	BACKSPACE= "0x107",
	F0 = "0x108",

	DL = "0x148",
	IL = "0x149",
	DC = "0x14a",
	IC = "0x14b",
	EIC = "0x14c",
	CLEAR = "0x14d",
	EOS = "0x14e",
	EOL = "0x14f",
	SF = "0x150",
	SR = "0x151",
	NPAGE = "0x152",
	PPAGE = "0x153",
	STAB = "0x154",
	CTAB = "0x155",
	CATAB = "0x156",
	ENTER = "0x157",
	SRESET = "0x158",
	RESET = "0x159",
	PRINT = "0x15a",
	LL = "0x15b",
	ABORT = "0x15c",
	SHELP = "0x15d",
	LHELP = "0x15e",
	BTAB = "0x15f",
	BEG = "0x160",
	CANCEL = "0x161",
	CLOSE = "0x162",
	COMMAND = "0x163",
	COPY = "0x164",
	CREATE = "0x165",
	END = "0x166",
	EXIT = "0x167",
	FIND = "0x168",
	HELP = "0x169",
	MARK = "0x16a",
	MESSAGE = "0x16b",
	MOVE = "0x16c",
	NEXT = "0x16d",
	OPEN = "0x16e",
	OPTIONS = "0x16f",
	PREVIOUS = "0x170",
	REDO = "0x171",
	REFERENCE= "0x172",
	REFRESH = "0x173",
	REPLACE = "0x174",
	RESTART = "0x175",
	RESUME = "0x176",
	SAVE = "0x177",
	SBEG = "0x178",
	SCANCEL = "0x179",
	SCOMMAND = "0x17a",
	SCOPY = "0x17b",
	SCREATE = "0x17c",
	SDC = "0x17d",
	SDL = "0x17e",
	SELECT = "0x17f",
	SEND = "0x180",
	SEOL = "0x181",
	SEXIT = "0x182",
	SFIND = "0x183",
	SHOME = "0x184",
	SIC = "0x185",

	SLEFT = "0x187",
	SMESSAGE = "0x188",
	SMOVE = "0x189",
	SNEXT = "0x18a",
	SOPTIONS = "0x18b",
	SPREVIOUS= "0x18c",
	SPRINT = "0x18d",
	SREDO = "0x18e",
	SREPLACE = "0x18f",
	SRIGHT = "0x190",
	SRSUME = "0x191",
	SSAVE = "0x192",
	SSUSPEND = "0x193",
	SUNDO = "0x194",
	SUSPEND = "0x195",
	UNDO = "0x196",

	-- /* PDCurses-specific key definitions -- PC only */

	ALT_0 = "0x197",
	ALT_1 = "0x198",
	ALT_2 = "0x199",
	ALT_3 = "0x19a",
	ALT_4 = "0x19b",
	ALT_5 = "0x19c",
	ALT_6 = "0x19d",
	ALT_7 = "0x19e",
	ALT_8 = "0x19f",
	ALT_9 = "0x1a0",
	ALT_A = "0x1a1",
	ALT_B = "0x1a2",
	ALT_C = "0x1a3",
	ALT_D = "0x1a4",
	ALT_E = "0x1a5",
	ALT_F = "0x1a6",
	ALT_G = "0x1a7",
	ALT_H = "0x1a8",
	ALT_I = "0x1a9",
	ALT_J = "0x1aa",
	ALT_K = "0x1ab",
	ALT_L = "0x1ac",
	ALT_M = "0x1ad",
	ALT_N = "0x1ae",
	ALT_O = "0x1af",
	ALT_P = "0x1b0",
	ALT_Q = "0x1b1",
	ALT_R = "0x1b2",
	ALT_S = "0x1b3",
	ALT_T = "0x1b4",
	ALT_U = "0x1b5",
	ALT_V = "0x1b6",
	ALT_W = "0x1b7",
	ALT_X = "0x1b8",
	ALT_Y = "0x1b9",
	ALT_Z = "0x1ba",

	CTL_LEFT = "0x1bb",
	CTL_RIGHT = "0x1bc",
	CTL_PGUP = "0x1bd",
	CTL_PGDN = "0x1be",
	CTL_HOME = "0x1bf",
	CTL_END = "0x1c0",

	KEY_A1 = "0x1c1",
	KEY_A2 = "0x1c2",
	KEY_A3 = "0x1c3",
	KEY_B1 = "0x1c4",
	KEY_B2 = "0x1c5",
	KEY_B3 = "0x1c6",
	KEY_C1 = "0x1c7",
	KEY_C2 = "0x1c8",
	KEY_C3 = "0x1c9",

	PADSLASH = "0x1ca",
	PADENTER = "0x1cb",
	CTL_PADENTER = "0x1cc",
	ALT_PADENTER = "0x1cd",
	PADSTOP = "0x1ce",
	PADSTAR = "0x1cf",
	PADMINUS = "0x1d0",
	PADPLUS = "0x1d1",
	CTL_PADSTOP = "0x1d2",
	CTL_PADCENTER = "0x1d3",
	CTL_PADPLUS = "0x1d4",
	CTL_PADMINUS = "0x1d5",
	CTL_PADSLASH = "0x1d6",
	CTL_PADSTAR = "0x1d7",
	ALT_PADPLUS = "0x1d8",
	ALT_PADMINUS = "0x1d9",
	ALT_PADSLASH = "0x1da",
	ALT_PADSTAR = "0x1db",
	ALT_PADSTOP = "0x1dc",
	CTL_INS = "0x1dd",
	ALT_DEL = "0x1de",
	ALT_INS = "0x1df",
	CTL_UP = "0x1e0",
	CTL_DOWN = "0x1e1",
	CTL_TAB = "0x1e2",
	ALT_TAB = "0x1e3",
	ALT_MINUS = "0x1e4",
	ALT_EQUAL = "0x1e5",
	ALT_HOME = "0x1e6",
	ALT_PGUP = "0x1e7",
	ALT_PGDN = "0x1e8",
	ALT_END = "0x1e9",
	ALT_UP = "0x1ea",
	ALT_DOWN = "0x1eb",
	ALT_RIGHT = "0x1ec",
	ALT_LEFT = "0x1ed",
	ALT_ENTER = "0x1ee",
	ALT_ESC = "0x1ef",
	ALT_BQUOTE = "0x1f0",
	ALT_LBRACKET = "0x1f1",
	ALT_RBRACKET = "0x1f2",
	ALT_SEMICOLON = "0x1f3",
	ALT_FQUOTE = "0x1f4",
	ALT_COMMA = "0x1f5",
	ALT_STOP = "0x1f6",
	ALT_FSLASH = "0x1f7",
	ALT_BKSP = "0x1f8",
	CTL_BKSP = "0x1f9",
	PAD0  = "0x1fa",

	CTL_PAD0 = "0x1fb",
	CTL_PAD1 = "0x1fc",
	CTL_PAD2 = "0x1fd",
	CTL_PAD3 = "0x1fe",
	CTL_PAD4 = "0x1ff",
	CTL_PAD5 = "0x200",
	CTL_PAD6 = "0x201",
	CTL_PAD7 = "0x202",
	CTL_PAD8 = "0x203",
	CTL_PAD9 = "0x204",

	ALT_PAD0 = "0x205",
	ALT_PAD1 = "0x206",
	ALT_PAD2 = "0x207",
	ALT_PAD3 = "0x208",
	ALT_PAD4 = "0x209",
	ALT_PAD5 = "0x20a",
	ALT_PAD6 = "0x20b",
	ALT_PAD7 = "0x20c",
	ALT_PAD8 = "0x20d",
	ALT_PAD9 = "0x20e",

	CTL_DEL = "0x20f",
	ALT_BSLASH = "0x210",
	CTL_ENTER = "0x211",

	SHF_PADENTER = "0x212",
	SHF_PADSLASH = "0x213",
	SHF_PADSTAR = "0x214",
	SHF_PADPLUS = "0x215",
	SHF_PADMINUS = "0x216",
	SHF_UP = "0x217",
	SHF_DOWN = "0x218",
	SHF_IC = "0x219",
	SHF_DC = "0x21a",

	KEY_MOUSE = "0x21b",
	KEY_SHIFT_L = "0x21c",
	KEY_SHIFT_R = "0x21d",
	KEY_CONTROL_L= "0x21e",
	KEY_CONTROL_R= "0x21f",
	KEY_ALT_L = "0x220",
	KEY_ALT_R = "0x221",
	KEY_RESIZE = "0x222",
	KEY_SUP = "0x223",
	KEY_SDOWN = "0x224"
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

			if ch > 31 and ch < 256 then
				return string.char(ch), ch
			elseif keys[ch] then
				if keys[ch] == "mouse" then
					return getmouse()
				end
				return keys[ch], ch
			elseif ch > 1 then
				return string.char(ch), ch
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


