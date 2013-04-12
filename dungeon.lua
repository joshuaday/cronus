local ffi = require "ffi"

local Layer = require "layer"
local Catalog = require "catalog"
local Cog = require "cog"
local Gen = require "gen"
local Fov = require "fov"
local Mask = require "mask"
local Marble = require "marble"
local Puzzle = require "puzzle"

local level = { }
local level_mt = { __index = level }

local tiles = Catalog.tiles

local FOV_OFF = false

function level:refresh()
	-- the level is marked dirty whenever operations that cannot be kept consistent are taken
	-- (generally once per turn, or more for combat and spawning and the slike)
	if self.dirty then
		-- clear the level to void
		self.transparency:zero()
		self.blocking:zero()
		self.top:zero()

		self.blocking:set_default(1) -- obstructions outside

		self.fg:zero()
		self.bg:zero()
		self.glyph:zero()

		-- copy cogs onto the level, maintaining the cog list (top->down->down->down->...),
		-- which tells us which cogs are overlapping in each cell of the map,
		for i = 1, #self.cogs do
			self.cogs[i].idx = i
			self.cogs[i]:stamp(self)
		end

		self.dirty = false

		-- update the level's auxiliary masks (opacity and obstruction)
		-- self.tiles:each()
		
		-- self.cogs[2]:push(math.random(3) - 2, math.random(3) - 2)
	end
end

function level:update()
	-- self.me.has_initiative = false

	-- handle initiative!
	
	if self.going and self.going.dlvl == self and self.going.has_initiative == true then
		-- we already have an active mob, so just wait for it
		return
	else
		self.going = nil
	end

	-- todo: detect the case where the player has been removed
	local visited = { }
	while self.turnorder[1] do
		local mob = self.turnorder[1] 
		if visited[mob] then
			-- the player must be dead or something, so let the keyboard take some input
			return
		end
		table.remove(self.turnorder, 1)

		if mob.dlvl == self and mob.active then
			-- if the mob is active and is still on this level, it gets its turn now

			mob.has_initiative = true
			self.going = mob

			table.insert(self.turnorder, mob)

			if mob.is_player then
				return
			else
				-- automatically play the mob!
				mob:automove(math.random(-1, 1), math.random(-1, 1))
				if mob.info.noises and math.random(1,40) == 1 then
					mob:say(mob.info.noises[random.index(mob.info.noises)])
				end

				mob.has_initiative = false
				self.going = nil
			end

			visited[mob] = true
		end
	end
end

function level:toggle_setting(name)
	if DEBUG_MODE then
		if name == "omniscience" then
			FOV_OFF = not FOV_OFF
		end

		if self.going then
			self.going:say("toggled " .. name)
		end
	end
end

function level:cogs_at(x, y)
	local cog_idx = self.top:get(x, y)
	return function ()
		local cog = self.cogs[cog_idx]
		if cog ~= nil then
			cog_idx = cog.down:get(x, y)
		end

		return cog
	end
end

function level:attach_floormap(cog)
	if cog.width == 1 and cog.height == 1 then
		return self.blocking
	end

	-- if the cog has a map already
	if not cog.floormap then
		cog.floormap = Layer.new("int", self.width, self.height)
	else
		cog.floormap:zero()
	end

	-- 0: ok to walk here
	-- 1: not ok to stand here
	-- 2: not ok to take this diagonal

	for y = 1, self.height do
		for x = 1, self.width do
			-- check the cells here and, for now, assume that all non-void cells
			-- in the creature have the same obstruction settings (true for the
			-- moment; when it ceases to be true, we'll modify)
			
		
		end
	end
end

function level:overlap(cog, fn)
	cog:each(function (_, x, y)
		local cog_idx = self.top:get(x, y)
		-- notice that if a cog appears in the overlap list, then the cell
		-- it shares is not empty
		if cog_idx == 0 then
			-- must be outside the map!
			fn(self.voidcog, x, y)
		else
			while cog_idx ~= 0 do
				local next_cog = self.cogs[cog_idx]
				if next_cog ~= cog then
					fn(next_cog, x, y)
				end
				cog_idx = next_cog.down:get(x, y)
			end
		end
	end)
end

function level:topmost(x, y, fn)
	local cog_idx = self.top:get(x, y)
	if cog_idx == 0 then
		return fn(self.voidcog, Catalog.tiles.void)
	else
		while cog_idx ~= 0 do
			local next_cog = self.cogs[cog_idx]
			local result = fn(next_cog, next_cog:get(x, y))
			if result then
				return result
			end
			cog_idx = next_cog.down:get(x, y)
		end
	end
end

local function wipe_stamped_cell(level, x, y)
	-- uncertain here?
end

local function cell_stamp(level, cog, tile_idx, x, y)
	-- this is an auxiliary function used by stamp and unstamp both.
	-- it applies the tile in question of the cog in question to the
	-- dungeon's current cache

	-- assumes that tile_idx > 0 (i.e., the cog actually exists in this cell)

	local tile = Catalog.tiles[tile_idx]
	if tile.glyph then level.glyph:set(x, y, string.byte(tile.glyph)) end
	
	local fg, bg = cog.fg or tile.fg, cog.bg or tile.bg
	if bg then
		level.bg:set(x, y, bg)
		if fg then level.fg:set(x, y, fg) end
	else
		if fg then
			level.fg:set(x, y, level.bg:get(x, y) == fg and (fg == 0 and 4 or 0) or fg)
		end
	end

	level.transparency:set(x, y, tile.transparency)
	level.blocking:set(x, y, tile.blocking)
end

-- todo - there is a whole lot of repeated logic among the three stamping routines 

local unstamp_stack = { } -- ugly but better than the alternative -- it'll grow to the proper size and we never need to worry
function level.restamp(level, cog, include)
	-- remove the cog from the linked list of overlapped cogs (very short -- no performance worries)
	-- and regenerate the cells (from the remainder of the list) that still overlap it
	
	if not cog.idx then return end -- oy vey  todo : something else
	cog.stamped = include
	
	for y = cog.map.y1, cog.map.y2 do
		for x = cog.map.x1, cog.map.x2 do
			local tile_idx = cog.map:get(x, y)
			if tile_idx > 0 then
				local link_layer = level.top

				-- walk down the link structure, remove this cog from it, and stick it in the unstamp_stack
				local us = 1 
				local down

				while true do
					down = link_layer:get(x, y)

					if down <= cog.idx then
						break
					end

					local next_cog = level.cogs[down]
					unstamp_stack[us], us = next_cog, us + 1
					link_layer = next_cog.down
				end

				if down == cog.idx then
					if not include then
						-- remove it, since it shouldn't be here!
						down = cog.down:get(x, y)
						link_layer:set(x, y, down)
					end
				else
					if include then
						-- add it here, because it should be!
						cog.down:set(x, y, down)
						link_layer:set(x, y, cog.idx)

						down = cog.idx
					end
				end

				while down > 0 do
					local next_cog = level.cogs[down]
					unstamp_stack[us], us = next_cog, us + 1
					link_layer = next_cog.down

					down = link_layer:get(x, y)
				end
				
				-- wipe this particular cell and stamp all other cogs onto it
				wipe_stamped_cell(level, x, y)
				
				for i = us - 1, 1, -1 do
					local next_cog = unstamp_stack[i]
					local tile_idx = next_cog.map:get(x, y) -- todo -- don't reach in like this?

					cell_stamp(level, next_cog, tile_idx, x, y)
					unstamp_stack[i] = 0 -- not nil, because we don't want to free slots in this table ever
				end
			end
		end
	end
end

function level.stamp(level, cog)
	cog.cells = 0

	cog.down:zero()
	-- it will definitely be better to do this without a closure -- this happens a whole lot each turn
	cog.map:each(function(tile_idx, x, y)
		if tile_idx > 0 then
			-- track that we have another cell
			cog.cells = cog.cells + 1

			-- link this cell into the linked list of cogs here
			local top = level.top:get(x, y)
			cog.down:set(x, y, top)
			level.top:set(x, y, cog.idx)

			-- stamp the content onto the level
			cell_stamp(level, cog, tile_idx, x, y)
		end
		-- update the level's properties (or maybe wait until we actually need them, using the down list?)
	end)
	return level
end

function level:update_fov()
	-- do an fov scan for everything that can see, and then stamp them onto the player's fov layer if friendly
	self.fov:zero()
	for i = 1, #self.cogs do
		local eye = self.cogs[i]
		if eye.fov ~= nil then
			local eye_x, eye_y = eye.map.x1, eye.map.y1
			eye.fov:recenter(eye_x, eye_y)

			Fov.scan(self.transparency, eye.fov, eye_x, eye_y, eye.fov_mask, 0.0)

			if eye.team == "player" then
				self.fov:stamp(eye.fov, bit.bor)
			end
		end
	end
end

function level:draw(term)
	self:refresh()
	self:update_fov()
	-- draw from the cache
	for y = 1, self.height do
		for x = 1, self.width do
			local bright = self.fov:get(x, y)
			local fg, bg, glyph

			if FOV_OFF or bright > 0 then
				fg = self.fg:get(x, y)
				bg = self.bg:get(x, y)
				glyph = self.glyph:get(x, y)

				if bright > 0 then -- double check for FOV_OFF mode
					self.memory:set(x, y, glyph)
				end
			else
				fg, bg = 5, 0
				glyph = self.memory:get(x, y)
			end
				

			if glyph >= 32 then
				term
					:at(x - 1, y - 1)
					:fg(fg)
					:bg(bg)
					:put(glyph)
			end
		end
	end
	
	return nil -- no animation going on
end

function level:addcog(cog)
	if cog.dlvl ~= self then
		self.dirty = true

		-- also remove the cog from any level it's on right now
		if cog.dlvl then
			cog.dlvl:removecog(cog)
		end

		local ins = #self.cogs
		while ins > 0 and self.cogs[ins].priority > cog.priority do
			-- todo: mark dirty?
			-- self.cogs[ins].idx = ins
			ins = ins - 1
		end

		table.insert(self.cogs, ins + 1, cog)
		-- self.cogs[1 + #self.cogs] = cog
		self.turnorder[1 + #self.turnorder] = cog -- give it a turn (the dispatcher will ignore it if it can't take turns)
		cog.dlvl = self
	end
end

function level:removecog(cog)
	if cog.dlvl == self then
		self.dirty = true
		for i = 1, #self.cogs do
			if self.cogs[i] == cog then
				table.remove(self.cogs, i)
				cog.dlvl = nil
				return cog
			end
		end
	end
end

function level:spawn(name)
	local dude = Cog.mob(name)
	dude:moveto(self.width + 1, self.height + 1) -- start it off the map
	self:addcog(dude)

	local range = 13
	if dude.info.ai == "you" then
		dude.fov = Layer.new("int", range * 2 + 1, range * 2 + 1)
		dude.fov_mask = Mask.circle(range * 2 + 1, range * 2 + 1)
	end
	dude.team = "dungeon"
	
	return dude
end

local function smart_spawn_item(self)
	self:refresh()
	
	local item = Cog.item(random.pick(Catalog.items))
	self:addcog(item)

	-- find a safe place for the each monster in the horde
	local w, h = self.width, self.height
	local x, y = math.random(w), math.random(h)

	for tries = 1, 10 do
		if item:can_stand_at(x, y) then
			item:moveto(x, y)
			x, y = x + math.random(-2, 2), math.random(-2, 2)
			break
		else
			x, y = x + math.random(-2, 2), math.random(-2, 2)
			if x < 0 then x = 6 end
			if y < 0 then y = 6 end
			if x > w then x = w - 6 end
			if y > h then y = h - 6 end

			if tries == 10 then
				self:removecog(item)
			end
		end
	end
end

local function smart_spawn_horde(self, horde)
	self:refresh()
	
	local monsters = horde:split " "

	-- spawn all the guys
	for i = 1, #monsters do
		monsters[i] = self:spawn(monsters[i])
	end

	-- find a safe place for the each monster in the horde
	local w, h = self.width, self.height
	local x, y = math.random(w), math.random(h)

	for i = 1, #monsters do
		for tries = 1, 10 do
			if monsters[i]:can_stand_at(x, y) then
				monsters[i]:moveto(x, y)
				x, y = x + math.random(-2, 2), math.random(-2, 2)
				break
			else
				x, y = x + math.random(-2, 2), math.random(-2, 2)
				if x < 0 then x = 6 end
				if y < 0 then y = 6 end
				if x > w then x = w - 6 end
				if y > h then y = h - 6 end

				if tries == 10 then
					self:removecog(monsters[i])
				end
			end
		end
	end
end

local function new_level(width, height, dlvl_up)
	local self = setmetatable({
		depth = dlvl_up and (1 + dlvl_up.depth) or 1,

		width = width,
		height = height,
		cogs = { },
		turnorder = { },

		-- tiles = Layer.new("int", width, height),
		glyph = Layer.new("int", width, height),
		fg = Layer.new("int", width, height),
		bg = Layer.new("int", width, height),

		memory = Layer.new("int", width, height), -- just a glyph in memory

		top = Layer.new("int", width, height), -- the top cog in the cog stack for each tile
		transparency = Layer.new("double", width, height),
		blocking = Layer.new("int", width, height), -- actually a bitfield
		fov = Layer.new("int", width, height),

		voidcog = Cog.new(1, 1),

		dirty = true,

		entry = {x = 2, y = math.floor(.5 * height)}, -- updated later if it's not dlvl 1
		exit = { }
	}, level_mt)

	local prototype = Catalog.levels[self.depth]
	
	do
		-- locate the entry and exit
		local entry, exit = self.entry, self.exit
		if dlvl_up then
			local entry, exit = self.entry, self.exit
			entry.x, entry.y = dlvl_up.exit.x, dlvl_up.exit.y
		end
		
		exit.x, exit.y = entry.x, entry.y  -- force a random exit
		while math.abs(exit.x - entry.x) + math.abs(exit.y - entry.y) < .3 * (width + height) do
			exit.x, exit.y = math.random(0, width - 1), math.random(0, height - 1)
		end
	end

	-- first, generate a set of rooms, and try to place as many as possible without overlapping
	-- (random placement is ok)

	local floor = Cog.new(width, height)
	local rocks = Cog.new(width, height)
	local decor = Cog.new(width, height)

	self:addcog(floor)
	self:addcog(decor)
	self:addcog(rocks)

	local rooms = { } -- masks
	local bigmask = Mask.new(width, height)
	
	local function refresh_bigmask()
		bigmask:zero()
		for i = 1, #rooms do
			local room = rooms[i]
			bigmask:stamp(room, math.max)
		end
	end

	local function does_not_overlap_bigmask(v, x, y)
		return v < .5 or bigmask:get(x, y) < .5 
	end

	--local ss_seq = {0, 0, 0, 30, 3, 3, 3, 0, 0, 2}
	local ss_seq = {0, 6, 20, 0, 0, 3}
	local ss, numsofar = #ss_seq, 0
	
	while true do
		numsofar = 1 + numsofar
		while numsofar > ss_seq[ss] do
			ss = ss - 1
			numsofar = 1
			if ss < 1 then break end
		end
		if ss < 1 then break end

		local room = Mask.splash(ss * ss) --Gen.random_room_mask(ss)
		local positioned = false

		for j = 1, 20 do
			room:moveto(math.random(1, 1 + width - room.width), math.random(1 + height - room.height))
			positioned = room:all(does_not_overlap_bigmask) 
			if positioned then
				break
			end
		end
		if positioned then
			rooms[1 + #rooms] = room

			refresh_bigmask()
		end
	end
	
	refresh_bigmask()

	refresh_bigmask = nil -- clear this function name so we don't accidentally call it again!

	-- ensure the connectivity of the mask
	local zonemap = Layer.new("int", bigmask.width, bigmask.height)
	local workspace = Layer.new("int", bigmask.width, bigmask.height)
	local paths = Layer.new("int", bigmask.width, bigmask.height)

	local panic = 3

	while true do -- almost always runs once, no worries
		panic = panic - 1 -- well almost no worries
		if panic == 0 then
			return new_level(width, height, dlvl_up)
		end

		bigmask:set(self.entry.x - 1, self.entry.y, 1)
		bigmask:set(self.exit.x - 1, self.exit.y, 1)
		bigmask:set(self.entry.x + 1, self.entry.y, 1)
		bigmask:set(self.exit.x + 1, self.exit.y, 1)

		local zones = bigmask:zones(zonemap)
		
		do
			local zonecount = 0
			for i = 1, #zones do
				if zones[i].value == 1 then
					zonecount = zonecount + 1
				end
			end
			if zonecount == 1 then
				break -- this is the way out!
			end
		end

		repeat
			local progress = false

			-- todo : this is horrifically slow; speed it up
			-- todo : also, move it elsewhere
			for zonenum = 1, #zones do
				local zone = zones[zonenum]
				if zone.value == 1 then
					for accept, x, y, v in workspace:spill(zone.x, zone.y, 1) do
						local z = zonemap:get(x, y)
						if z == zonenum then
							-- same zone, accept its neighbors at cost 2, and adjust our own score
							accept(2)
							paths:set(x, y, 1)
						else
							paths:set(x, y, v)
							-- and if, by chance, it is an open zone, roll back and break
							if zones[z].value == 1 then
								-- hooray!  now find our path back (can we?)
								for x, y in paths:rolldown(x, y) do
									bigmask:set(x, y, 1)
								end

								zonemap:replace(z, zonenum)
								zones[z].value = -1 -- replaced, see

								progress = true
								break
							end

							-- different zone, accept it at cost v + 1
							accept(1 + (v or 1))
						end
					end
					-- rocks.map:set(zone.x, zone.y, Catalog:idx "water")
					if progress then break end
				end
			end
		until not progress
	end
		

	-- decorate the rocks and the floor!
	do
		-- not going to lie: these two lines shouldn't be necessary
		floor:fill("redfloor")
		rocks:fill("redwall")

		local floors, walls = prototype.floors, prototype.walls
		local sigma, turbulence = 25, 0.80
		local sediment = Marble.displace(
			Marble.bands(128, 128, 15, 2 * math.pi * math.random()):moveto(-30, -30),
			Marble.midpoint(128, 128, sigma, turbulence),
			Marble.midpoint(128, 128, sigma, turbulence)
		)
		floor:each(function(_, x, y)
			local s = sediment:get(x, y)
			floor:set(x, y, floors[1 + s % #floors])
			rocks:set(x, y, walls[1 + s % #walls])
		end)
	end

	-- floor:recolor( )

	bigmask:each(function(v, x, y)
		if v == 1 then
			rocks:erase(x, y)
		end
	end)

	rocks:set(self.entry.x, self.entry.y, "stairs-up")

	if prototype.exit == nil then
		rocks:set(self.exit.x, self.exit.y, "stairs-down")
	else
		rocks:erase(self.exit.x, self.exit.y)

		local item = Cog.item(prototype.exit)
		self:addcog(item)
		item:moveto(self.exit.x, self.exit.y)
	end

	-- we have already carved the map from the bigmask, so now we can use it
	-- to track the places we have already decorated! (we'll set it back to 0
	-- when we do.)

	-- rocks.map:set(20, 20, Catalog:idx("handle"))



	-- now splash a bunch of foliage and stuff onto the floor

	local decormask = bigmask:clone()

	local function splash_some(decoration, amt)
		local x, y

		for i = 1, 9 do
			x, y = math.random(self.width), math.random(self.height)
			if decormask:get(x, y) > 0 then break end
		end
		amt = amt or math.random(9, 12)
		for accept, x, y in workspace:spill(x, y) do
			if amt > 0 and decormask:get(x, y) > 0.0 then
				accept()
				decormask:set(x, y, 0.0)
				decor:set(x, y, decoration) -- todo : speed up lookups
				amt = amt - 1
			end
		end
	end

	-- splash_some("ice", 30) -- ice is still buggy
	-- splash_some("ice", 30)
	-- splash_some("ice", 30)
	splash_some("water", 90)
	splash_some("water", 90)
	splash_some("water", 90)
	splash_some("bushes", 12)
	splash_some("bushes", 12)
	splash_some("bushes", 12)
	splash_some("bushes", 12)
	splash_some("bushes", 12)
	splash_some("bushes", 12)
	splash_some("bushes", 12)
	splash_some("bushes", 12)


	-- to set up pushing puzzles (and lock and key puzzles, and the like), solve
	-- them backwards: start them in their final configuration (which must leave
	-- the map connectivity untouched) and push them backwards into their starting
	-- configuration.  repeat many times to layer multiple puzzles on top of each
	-- other.
	

	Puzzle.puzzlify(self, bigmask)

	-- spawn some hordes
	for i = 1, 5 do
		smart_spawn_horde(self, random.pick(prototype.hordes))
	end

	-- spawn some items
	for i = 1, math.random(3, 5) do
		smart_spawn_item(self)
	end

	-- finally, get the map ready for use and return it
	self:refresh()

	return self
end

return {
	new_level = new_level
}

