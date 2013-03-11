local ffi = require "ffi"

local Layer = require "layer"
local Catalog = require "catalog"
local Cog = require "cog"

local level = { }
local level_mt = { __index = level }

local tiles = Catalog.tiles

function level:refresh()
	-- clear the level to void
	self.cache:set_default(tiles.void.idx)
	self.cache:fill(tiles.void.idx)

	-- copy cogs onto the level
	for i = 1, #self.cogs do
		self.cogs[i]:stamp(self)
	end
end

function level:draw(term)
	self:refresh()
	-- draw from the cache
	for y = 1, self.height do
		for x = 1, self.width do
			local idx = self.cache:get(x, y)
			local tile = tiles[idx]

			term
				.at(x, y)
				.fg(tile.fg)
				.bg(tile.bg)
				.put(string.byte(tile.glyph, 1))
		end
	end
end

function level:addcog(cog)
	-- also remove the cog from any level it's on right now
	self.cogs[1 + #self.cogs] = cog
end

function level:spawn(name)
	local dude = Cog.mob(name)
	dude.map:recenter(5, 5)
	self:addcog(dude)
	
	return dude
end

local function new_level(width, height)
	local self = setmetatable({
		width = width,
		height = height,
		cogs = { },
		cache = Layer.new("int", width, height)
	}, level_mt)
	
	self:addcog(Cog.generate())
	self:refresh()

	return self
end

return {
	new_level = new_level
}

