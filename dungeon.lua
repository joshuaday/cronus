local ffi = require "ffi"

local Layer = require "layer"
local Catalog = require "catalog"
local Cog = require "cog"
local Gen = require "gen"
local Fov = require "fov"
local Mask = require "mask"

local level = { }
local level_mt = { __index = level }

local tiles = Catalog.tiles


function level:refresh()
	-- clear the level to void
	self.transparency:zero()
	self.top:zero()

	self.fg:zero()
	self.bg:zero()
	self.glyph:zero()

	-- copy cogs onto the level, maintaining the cog list (top->down->down->down->...),
	-- which tells us which cogs are overlapping in each cell of the map,
	for i = 1, #self.cogs do
		self.cogs[i].idx = i
		self.cogs[i]:stamp(self)
	end

	-- update the level's auxiliary masks (opacity and obstruction)
	-- self.tiles:each()
	
	-- self.cogs[2]:push(math.random(3) - 2, math.random(3) - 2)
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
				mob.has_initiative = false
				self.going = nil
			end

			visited[mob] = true
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

function level:overlap(cog, fn)
	cog:each(function (_, x, y)
		local cog_idx = self.top:get(x, y)
		-- notice that if a cog appears in the overlap list, then the cell
		-- it shares is not empty
		while cog_idx ~= 0 do
			local next_cog = self.cogs[cog_idx]
			if next_cog ~= cog then
				fn(next_cog, x, y)
			end
			cog_idx = next_cog.down:get(x, y)
		end
	end)
end

function level.stamp(level, cog)
	cog.cells = 0

	cog.down:zero()
	cog.map:each(function(tile_idx, x, y)
		if tile_idx > 0 then
			cog.cells = cog.cells + 1

			local top = level.top:get(x, y)
			if top ~= 0 then
				cog.down:set(x, y, top)
			end

			local tile = Catalog.tiles[tile_idx]
			level.top:set(x, y, cog.idx)
			if tile.fg then level.fg:set(x, y, tile.fg) end
			if tile.glyph then level.glyph:set(x, y, string.byte(tile.glyph)) end
			if tile.bg then level.bg:set(x, y, tile.bg) end

			level.transparency:set(x, y, tile.transparency)
			
			-- update the level's properties (or maybe wait until we actually need them, using the down list?)
		end
	end)
	return level
end

function level:update_fov()
	-- do an fov scan for everything that can see, and then stamp them onto the fov layer
	self.fov:zero()
	for i = 1, #self.cogs do
		local eye = self.cogs[i]
		if eye.fov ~= nil then
			local eye_x, eye_y = eye.map.x1, eye.map.y1
			eye.fov:recenter(eye_x, eye_y)

			Fov.scan(self.transparency, eye.fov, eye_x, eye_y, eye.fov_mask)

			if eye.is_player then -- todo: restore seeing eye coolness
				self.fov:stamp(eye.fov, math.max)
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
			if bright > 0 then
				local fg = self.fg:get(x, y)
				local bg = self.bg:get(x, y)
				local glyph = self.glyph:get(x, y)
				
				term
					.at(x - 1, y - 1)
					.fg(fg)
					.bg(bg)
					.put(glyph)
			end
		end
	end
end

function level:addcog(cog)
	if cog.dlvl ~= self then
		-- also remove the cog from any level it's on right now
		if cog.dlvl then
			cog.dlvl:remove(cog)
		end
		self.cogs[1 + #self.cogs] = cog
		self.turnorder[1 + #self.turnorder] = cog -- give it a turn (the dispatcher will ignore it if it can't take turns)
		cog.dlvl = self
	end
end

function level:removecog(cog)
	if cog.dlvl == self then
		for i = 1, #self.cogs do
			if self.cogs[i] == cog then
				table.remove(self.cogs, i)
				cog.dlvl = nil
				return
			end
		end
	end
end

function level:spawn(name)
	local dude = Cog.mob(name)
	dude:moveto(30, 12)
	self:addcog(dude)

	range = 11
	dude.fov = Layer.new("double", range * 2 + 1, range * 2 + 1)
	dude.fov_mask = Mask.circle(range * 2 + 1, range * 2 + 1)
	
	return dude
end

local function new_level(width, height)
	local self = setmetatable({
		width = width,
		height = height,
		cogs = { },
		turnorder = { },

		-- tiles = Layer.new("int", width, height),
		glyph = Layer.new("int", width, height),
		fg = Layer.new("int", width, height),
		bg = Layer.new("int", width, height),

		top = Layer.new("int", width, height), -- the top cog in the cog stack for each tile
		transparency = Layer.new("double", width, height),
		fov = Layer.new("double", width, height),
	
	}, level_mt)
	
	-- first, generate a set of rooms, and try to place as many as possible without overlapping
	-- (random placement is ok)

	local floor = Cog.new(width, height)
	local rocks = Cog.new(width, height)

	self:addcog(floor)
	self:addcog(rocks)

	floor:fill("floor")
	rocks:fill("wall")

	local rooms = { } -- masks
	local bigmask = Mask.new(width, height)
	
	local function refresh_bigmask()
		bigmask:zero()
		for i = 1, #rooms do
			local room = rooms[i]
			bigmask:stamp(room, math.max)
		end
	end

	local function count_overlap()
	end

	for i = 1, 31 do
		local room = Gen.random_room_mask()

		room:moveto(math.random(1, width - room.width), math.random(height - room.height))
		rooms[i] = room

		refresh_bigmask()
	end

	refresh_bigmask()

	bigmask:each(function(v, x, y)
		if v == 1 then
			rocks:erase(x, y)
		end
	end)

	
	
	-- now try to place as many as possible without overlapping

	self:refresh()

	return self
end

return {
	new_level = new_level
}

