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
	self.tiles:set_default(tiles.void.idx)
	self.tiles:fill(tiles.void.idx)

	self.transparency:zero()
	self.top:zero()

	-- copy cogs onto the level, maintaining the cog list (top->down->down->down->...),
	-- which tells us which cogs are overlapping in each cell of the map
	for i = 1, #self.cogs do
		self.cogs[i].idx = i
		self.cogs[i]:stamp(self)
	end

	-- update the level's auxiliary masks (opacity and obstruction)
	-- self.tiles:each()
	
	-- self.cogs[2]:push(math.random(3) - 2, math.random(3) - 2)
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

			level.tiles:set(x, y, tile_idx)
			level.top:set(x, y, cog.idx)
			
			-- update the level's properties (or maybe wait until we actually need them, using the down list?)
			local tile = Catalog.tiles[tile_idx]
			level.transparency:set(x, y, tile.transparency)
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
			eye.fov:each(function(t, x, y)
				self.fov:set(x, y, t)
			end)
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
				local idx = self.tiles:get(x, y)
				local tile = tiles[idx]

				term
					.at(x - 1, y - 1)
					.fg(tile.fg)
					.bg(tile.bg)
					.put(string.byte(tile.glyph, 1))
			end
		end
	end
end

function level:addcog(cog)
	-- also remove the cog from any level it's on right now
	self.cogs[1 + #self.cogs] = cog
end

function level:removecog(cog)
	for i = 1, #self.cogs do
		if self.cogs[i] == cog then
			table.remove(self.cogs, i)
			return
		end
	end
end

function level:spawn(name)
	local dude = Cog.mob(name)
	dude.map:recenter(5, 5)
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

		tiles = Layer.new("int", width, height),
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
		bigmask:fill(0)
		for i = 1, #rooms do
			local room = rooms[i]
			bigmask:stamp(room, math.add)
		end
	end

	for i = 1, 29 do
		local room = Gen.random_room_mask()

		room:moveto(math.random(1, width - room.width), math.random(height - room.height))
		rooms[i] = room
	end

	for j = 1, 90 do
		refresh_bigmask()

		for i = 1, #rooms do
			local room = rooms[i]
			--if room.intersections / room.cells > math.random() * .5 then
				--room:push(math.random(-2, 2), math.random(-2, 2))
			--end
		end
	end

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

