local term = require "terminal"
local Dungeon = require "dungeon"
local Messaging = require "messaging"
local Menu = require "menu"
local Cog = require "cog"

local ERRORED_OUT = false

_G.DEBUG_MODE = false
_G.VICTORY = false

-- local pds = require "pds/pds"

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
	a3 = "u",
	b2 = ".",
	c1 = "b",
	c3 = "n",
	
	f1 = "?",
	help = "?"
}

term.settitle "Cogs of Cronus"

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
you:moveto(dlvl.entry.x, dlvl.entry.y)
you.team = "player"

you:pickup(Cog.item "chisel", true)
you:pickup(Cog.item "tank of air")
you:pickup(Cog.item "petn")
you:pickup(Cog.item "radio")
you:pickup(Cog.item "camera")

you.is_player = true

local function you_win()
	local function finally()
		io.stdout:write("You have defeated Cogs of Cronus (7DRL Edition)!\n")
		io.stdout:write("Stay tuned for the post 7DRL releases.\n\n")
		io.stdout:write("(It should have been a 14DRL, really.)\n")
	end
	os.exit(0, finally) 
end
local function you_lose()
	local function finally()
		io.stdout:write("You have attempted Cogs of Cronus (7DRL Edition)!\n")
		io.stdout:write("Stay tuned for the post 7DRL releases.\n\n")
		io.stdout:write("(It should have been a 14DRL, really.)\n")
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
		local key, code = term.getch(waitms)
		if remap[key] then
			key = remap[key]
		end
		-- playerturn(player, key)

		if key then
			auto.time, auto.dir = nil, nil
			Messaging:input()
		end

		if auto.time and auto.time <= 0 then
			autorun()
		end

		if DEBUG_MODE and key == "f8" then
			error("Testing the error handling.")
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
			if key == "i" or key == "e" or key =="r" or key =="d" or key == "a" and you.bag then
				term.erase()
				dlvl:draw(term) -- clear the screen of messages (for now)
				local item, command, _, cb = Menu:inventory(term, you.bag, key)
				if command then
					you:manipulate(item, command, cb) -- cb is a hack
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
	local last_time = term.getms()

	local function protected()
		if ERRORED_OUT then
			auto.time = nil
			ERRORED_OUT = false
		end

		dlvl:update()
		dlvl:draw(term)
		local next_animation_event = Messaging:draw(term, next_animation_event)
		local animating = next_animation_event ~= nil

		term.refresh()

		if auto.time then
			-- autorun
			next_animation_event = math.min(auto.time, next_animation_event or auto.time)
			if next_animation_event < 0 then next_animation_event = 0 end
			animating = true
		end

		interactiveinput(dlvl.going, next_animation_event)

		if animating then
			term.napms(0) -- give the os a slice in case we haven't yet
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

		local time_now = term.getms()
		local time_delta = time_now - last_time
		last_time = time_now

		if auto.time then
			auto.time = auto.time - time_delta
		end

		Messaging:time_spent(time_delta)
	end

	local function protection(msg)
		local traceback = string.split(debug.traceback(msg, 2), "\n")
		term.clip(0, 0, 80, 24)
		term.mask(false)
		term.dryrun(false)

		for i = 1, 2 do
			if i == 1 then
				term.dryrun(true)
			else
				local x1, y1, w, h = term.dryrun(false)
				w = w + 5
				h = h + 3

				x1, y1 = math.floor(40 - .5 * w), math.floor(12 - .5 * h)
				term.clip(x1, y1, w, h)
				term.fg(0).bg(7).fill()

				term.clip(x1 + 2, y1 + 1, w - 4, h - 2)
			end

			local y = 0
			term.bg(4).fg(11).at(0, y).print("There has been an error, but you can probably keep playing.").toend()
			term.bg(7).fg(0)
			y = y + 1
			
			for i = 1, #traceback do 
				local line = traceback[i]
				if line:match "xpcall" then break end -- stop when we get to xpcall
				term.at(0, y).print(line)
				y = y + 1
			end

			term.at(0, y).fg(11).bg(4).print("-- press space to continue, Q to quit --").toend()
		end
		
		ERRORED_OUT = true

		repeat
			local ch = term.getch()
			if ch == "Q" then os.exit(1) end
		until ch == " "
	end


	repeat
		-- rotinplace(screen[1], screen[3], .001)
		term.clip()
		term.erase()
		term.clip(0, 0, 80, 24)

		xpcall(protected, protection)
	until hasquit
end

simulate(term)

term.erase()
term.refresh()
term.endwin()

