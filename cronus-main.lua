local Terminal = require "terminal"
local Dungeon = require "dungeon"
local Messaging = require "messaging"
local Menu = require "menu"
local Cog = require "cog"
local Catalog = require "catalog"

local topterm = Terminal.open()
local term -- this will be clipped to 80x24

local ERRORED_OUT = false

_G.DEBUG_MODE = true
_G.VICTORY = false

local compass = {
	h = {-1, 0},
	j = {0, 1},
	k = {0, -1},
	l = {1, 0},
	y = {-1, -1},
	u = {1, -1},
	b = {-1, 1},
	n = {1, 1},

	z = {0, 0}
}

local remap = {
	up = "k",
	down = "j",
	left = "h",
	right = "l",

	sr = "K",
	sf = "J",
	sleft = "H",
	sright = "L",

	ic = "i",
	[ [[0]] ] = "i",
	[ [[-]] ] = "d",
	enter = "a",
	
	home = "y",
	[ [[end]] ] = "b",
	ppage = "u",
	npage = "n",

	[ [[1]] ] = "b",
	[ [[2]] ] = "j",
	[ [[3]] ] = "n",
	[ [[4]] ] = "h",
	[ [[5]] ] = ".",
	[ [[6]] ] = "l",
	[ [[7]] ] = "y",
	[ [[8]] ] = "k",
	[ [[9]] ] = "u",

	a1 = "y",
	a2 = "k",
	a3 = "u",
	b1 = "h",
	b2 = ".",
	b3 = "l",
	c1 = "b",
	c2 = "j",
	c3 = "n",

	ctl_pad1 = "B",
	ctl_pad2 = "J",
	ctl_pad3 = "N",
	ctl_pad4 = "H",
	ctl_pad5 = "Z",
	ctl_pad6 = "L",
	ctl_pad7 = "Y",
	ctl_pad8 = "K",
	ctl_pad9 = "U",
	
	f1 = "?",
	f40 = "Q", -- under pdcurses, on Windows, this is what we get for alt-f4
	help = "?"
}

term = topterm:clip(0, 0, 80, 24)
term.root:settitle "Cogs of Cronus"

local function tell_story(story, and_then)
	local chunk_idx = 1

	local function continue()
		local chunk = story[chunk_idx]
		if chunk then
			for i = 1, #chunk do
				local msg = {chunk[i], ttl = 1500 + 400 * #chunk, y = 4 + i, turn = true}
				if i == #chunk then
					msg.cb = continue
				end
				Messaging:announce (msg)
			end
		else
			if and_then then and_then() end
		end
		chunk_idx = chunk_idx + 1
	end

	continue()
end

tell_story {
	{
		"You are a prospector on Titan, near Xanadu."
	}, {
		"You are trapped in a strange cave, warm",
		"and with Earth-like air."
	}, {
		"There's a faint radio signal down below.",
		"If you can find the transmitter, you can",
		"probably call for help."
	}
}


local dlvl = Dungeon.new_level(80, 24)
local you = dlvl:spawn "rogue"
local mousemessage
you:moveto(dlvl.entry.x, dlvl.entry.y)
you.team = "player"

you:pickup(Cog.item "chisel", true)
you:pickup(Cog.item "tank of air")
you:pickup(Cog.item "petn")
you:pickup(Cog.item "incendiary")
you:pickup(Cog.item "oxypen")
you:pickup(Cog.item "radio")
you:pickup(Cog.item "camera")

you.is_player = true

local function you_win()
	local function finally()
		io.stdout:write("You have defeated Cogs of Cronus (Post-7DRL Edition)!\n")
	end
	os.exit(0, finally) 
end
local function you_lose()
	local function finally()
		io.stdout:write("You have attempted Cogs of Cronus (Post-7DRL Edition)!\n")
	end
	os.exit(0, finally) 
end


local function simulate(term)
	local command = nil
	local hasquit = false
	local paused = false

	local time = 0

	local auto = {
		time = nil,
		dir = nil
	}

	local beeping = false

	local function beep()
		beeping = 7
	end

	local function autorun(you, direction)
		auto.time = 50
		if direction ~= nil then
			auto.dir = direction
			auto.you = you
		else
			if auto.you:autorun_stop_point(auto.dir) then
				auto.time = nil
				return
			end
		end
		auto.you:automove(auto.dir[1], auto.dir[2])
	end

	local function interactiveinput(you, waitms)
		local key, code = term:getch(waitms)
		if remap[key] then
			key = remap[key]
		end
		-- playerturn(player, key)

		if key == "mouse" then
			-- get mouse event info!
			if DEBUG_MODE and code.left.justPressed and code.ctrl then
				-- teleport on ctrl+click
				you:moveto(1 + code.x, 1 + code.y)
				return
			end
			if code.left.justPressed then
				Messaging:forget (mousemessage)

				-- info box about the cell
				local whohere = ""
				for cog in you.dlvl:cogs_at(1 + code.x, 1 + code.y) do
					local name
					if cog.info and cog.info.description then
						name = cog.info.description
					elseif cog.info and cog.info.name then
						name = cog.info.name
					else
						local tile = cog:gettile(1 + code.x, 1 + code.y)
						if tile.tag then
							name = tile.tag
						end
					end

					if whohere ~= "" then
						whohere = whohere .. " on " .. name
					else
						whohere = name
					end
				end
				mousemessage = {whohere, x = code.x - 2, y = code.y - 1, fg = 12, bg = 0}
				Messaging:announce (mousemessage)
			end
			if code.left.justReleased then
				Messaging:forget (mousemessage)
			end
			
			return
		end

		if key then
			auto.time, auto.dir = nil, nil
			Messaging:input()
		end

		if auto.time and auto.time <= 0 then
			autorun()
		end

		if DEBUG_MODE and key == "f5" then
			dlvl.dirty = true
			dlvl:refresh()
			if you then you:say "(refresh)" end
			return
		end

		if DEBUG_MODE and key == "f8" then
			error("Testing the error handling.")
			return
		end

		if DEBUG_MODE and key == "f7" then
			dlvl.dirty = true
			return
		end

		if DEBUG_MODE and key == "f6" then
			local spname = Menu:get_string(term, function(s)
				if s == "" or Catalog.tiles[s] or Catalog.spawns[s] or Catalog.items[s] then
					return s
				end
			end)
			
			if spname == "" or not spname then return end

			if Catalog.spawns[spname] then
				local dude = dlvl:spawn(spname)
				dude:moveto(you.x1, you.y1)
			elseif Catalog.items[spname] then
				local item = Cog.item(spname)
				you.dlvl:addcog(item)
				item:moveto(you.x1, you.y1)
			else
				you.dlvl:overlap(you, function(cog, x, y)
					cog:set(x, y, spname)
				end)
			end
			
			return
		end

		if key == "Q" then
			-- Menu:dialog (term, "Quit?")
			hasquit = true
			return
		end

		if key == "p" then
			paused = not paused
		end

		if key == "btab" then
			dlvl:toggle_setting "omniscience"
			return
		end

		if you then
			if key and #key > 1 and DEBUG_MODE then
				you:say(key)
			end

			if key == "." then
				you:automove(0, 0)
			end
			if key ~= nil then
				local lowerkey = string.lower(key)
				local dir = compass[lowerkey]
				
				if dir ~= nil then
					-- world.feed(dir[1], dir[2])
					if key >= "A" and key <= "Z" then
						autorun(you, dir)
					else
						you:automove(dir[1], dir[2])
					end
				end
			end
			if you.bag and (key == "i" or key == "e" or key =="r" or key =="d" or key == "a") then
				term:bg(0):fill()
				dlvl:draw(term) -- clear the screen of messages (for now)
				local item, command, _, cb = Menu:inventory(term, you.bag, key, you.x1)
				if command then
					you:manipulate(item, command, cb) -- todo cb is a hack
				end
			end
			if key == "t" then
				you:say "There's no room to throw anything!"
			end
			if key == "?" then
				you:say "Help!"
			end
			if key == ">" and (DEBUG_MODE or you.x1 == dlvl.exit.x and you.y1 == dlvl.exit.y) then
				-- temporary
				dlvl = Dungeon.new_level(80, 24, dlvl)
				dlvl:addcog(you)
			end
		end
	end

	local time_step = 20
	local last_time = term.root:getms()

	local function protected()
		if ERRORED_OUT then
			auto.time = nil
			ERRORED_OUT = false
		end

		dlvl:update()
		dlvl:draw(term)
		local next_animation_event = Messaging:draw(term, next_animation_event)
		local animating = next_animation_event ~= nil

		term.root:refresh()

		if auto.time then
			-- autorun
			next_animation_event = math.min(auto.time, next_animation_event or auto.time)
			if next_animation_event < 0 then next_animation_event = 0 end
			animating = true
		end

		interactiveinput(dlvl.going, next_animation_event)

		if animating then
			term.root:napms(0) -- give the os a slice in case we haven't yet
		end

		if VICTORY == true then
			VICTORY = false -- so we don't keep spamming the player
			tell_story ({
				{
					"It's one of the transmitters from the Huygens",
					"probe, used as a bizarre idol!"
				}, {
					"Now you can call for help!"
				}, {
					"Then again, it's doubtful whether anyone will",
					"even hear..."
				},
			}, you_win)
		end

		if you.dlvl == nil then
			you.dlvl = false -- just keep it from repeating this text (hack)
			tell_story ({
				{"You were never supposed to die here."},
				{"It was only just a job."},
				{"What a terrible way to go."}
			}, you_lose)
		end

		local time_now = term.root:getms()
		local time_delta = time_now - last_time
		last_time = time_now

		if auto.time then
			auto.time = auto.time - time_delta
		end

		Messaging:time_spent(time_delta)
	end

	local function protection(msg)
		local traceback = string.split(debug.traceback(msg, 2), "\n")

		local function innerprotection(msg)
			local traceback2
			local function fail_report()
				io.stderr:write("\n===========\nError in gameplay:\n")
				for i = 1, #traceback do
					io.stderr:write(traceback[i], "\n")
				end
				io.stderr:write("\n===========\nError while presenting that error:\n")
				for i = 1, #traceback2 do
					io.stderr:write(traceback2[i], "\n")
				end
			end
			traceback2 = string.split(debug.traceback(msg, 2), "\n")

			os.exit(1, fail_report)
		end
		local function innerprotected()
			-- make a new panel
			local panel = term.root:panel_from_cursor(term):wipe()
			panel.z = 35

			-- todo : wrap everything from here on in xpcall, too, and if an error comes up while
			--        drawing the error panel, os.exit() our way out and dump the traceback to
			--        stderr

			-- fill the whole panel with a gray background
			panel:fg(0):bg(7):fill()

			-- clip the working space to guarantee a border (on the left)
			local term = panel:clip(2, 1, -4, -2)

			-- render the dialog content
			local y = 0
			term:bg(4):fg(11):at(0, y):print("There has been an error, but you can probably keep playing."):toend()
			term:bg(7):fg(0)
			y = y + 1
			
			for i = 1, #traceback do 
				local line = traceback[i]
				if line:match "xpcall" then break end -- stop when we get to xpcall
				term:at(0, y):print(line)
				y = y + 1
			end

			term:at(0, y):fg(11):bg(4):link(1):print("-- press space to continue, Q to quit --"):toend():link(0)

			-- term = term:clip(0, 0, -24, -22)
			local x1, y1, w, h = term.panel:get_printable_bounds()
			term.panel:resize(w + 4, h + 2)

			panel.width, panel.height = w + 4, h + 2 -- hack hack hack -- todo : fix the connection between cursor and panel !!!
			panel:clip(-2, 0, 0, 0):fg(0):bg(7):fill()
			panel.panel.x1 = math.floor(.5 * (80 - w))
			panel.panel.y1 = math.floor(.25 * (24 - h))
			
			ERRORED_OUT = true

			repeat
				local ch, code = term:getch()
				if ch == "mouse" and code.link == 1 then ch = " " end
				if ch == "Q" then os.exit(1) end
			until ch == " "
		end
		xpcall(innerprotected, innerprotection)
	end


	repeat
		-- rotinplace(screen[1], screen[3], .001)
		term:bg(0):fill()
		xpcall(protected, protection)
--		protected()
	until hasquit
end

simulate(term)

term.root:erase()
term.root:refresh()
term.root:endwin()

