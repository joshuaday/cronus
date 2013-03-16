local term = require "terminal"
local Dungeon = require "dungeon"
local Messaging = require "messaging"
local Menu = require "menu"

-- local pds = require "pds/pds"

local compass = {
	h = {-1, 0},
	j = {0, 1},
	k = {0, -1},
	l = {1, 0},
	y = {-1, -1},
	u = {1, -1},
	b = {-1, 1},
	n = {1, 1}
}

term.settitle "Cogs of Cronus"

Messaging:announce {
[[The rift slams shut behind you
but air is seeping out.]], ttl = 2200}

local dlvl = Dungeon.new_level(80, 24)
local you = dlvl:spawn "rogue"

-- local rock = dlvl:spawn "handle"
-- rock:moveto(14, 14)

for i = 1, 9 do
	local mob = dlvl:spawn "titan"
	mob:moveto(17 + 3 * i, 14)
end

--[[
for i = 1, 13 do
	local mob = dlvl:spawn "scythe"
	mob:moveto(11 + i, 14 - 1)
end
for i = 14, 27 do
	local mob = dlvl:spawn "rapier"
	mob:moveto(11 + i, 14 - 1)
end
]]

you.is_player = true


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
		end
		auto.you:automove(auto.dir[1], auto.dir[2])
	end

	local function interactiveinput(you, waitms)
		local key, code = term.getch(waitms)
		-- playerturn(player, key)

		if key then
			auto.time, auto.dir = nil, nil
		end

		if auto.time and auto.time <= 0 then
			autorun()
		end

		if key == "Q" then
			-- Menu:dialog (term, "Quit?")
			hasquit = true
			return
		end

		if key == "p" then
			paused = not paused
		end

		if you then
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
			if key == "i" or key == "e" or key =="d" or key == "a" and you.bag then
				term.erase()
				dlvl:draw(term) -- clear the screen of messages (for now)
				local item, command = Menu:inventory(term, you.bag, key)
				if command then
					you:manipulate(item, command)
				end
			end
			if key == ">" then
				-- temporary
				dlvl = Dungeon.new_level(80, 24)
				dlvl:addcog(you)
			end
			if key == "x" then error("You pressed x") end
		end
	end

	local time_step = 20
	local last_time = term.getms()

	local function protected()
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
		term.clip(0, 0, 80, 22)
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

