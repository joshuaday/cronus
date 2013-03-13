local term = require "terminal"
local Dungeon = require "dungeon"
local Messaging = require "messaging"

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

local function simulate(term)
	local command = nil
	local hasquit = false
	local paused = false

	local time = 0

	local beeping = false

	local function beep()
		beeping = 7
	end

	local function interactiveinput(waitms)
		local key, code = term.getch(waitms)
		-- playerturn(player, key)

		if key == "Q" then
			hasquit = true
			return
		end

		if key ~= nil then
			local lowerkey = string.lower(key)
			local dir = compass[lowerkey]
			
			if dir ~= nil then
				-- world.feed(dir[1], dir[2])
				if key >= "A" and key <= "Z" then
			--
				else
					you:push(dir[1], dir[2])
				end
			end

			if key == "p" then paused = not paused end
		end
	end

	local time_step = 20
	local last_time = term.getms()
	repeat
		-- rotinplace(screen[1], screen[3], .001)
		term.clip()
		term.erase()
		term.clip(0, 0, 80, 24)

		dlvl:draw(term)
		local next_animation_event = Messaging:draw(term, next_animation_event)

		term.refresh()

		interactiveinput(next_animation_event)

		if next_animation_event ~= nil then
			term.napms(0) -- give the os a slice in case we haven't yet
		end

		local time_now = term.getms()
		local time_delta = time_now - last_time
		last_time = time_now

		Messaging:time_spent(time_delta)
	until hasquit
end

simulate(term)

term.erase()
term.refresh()
term.endwin()

