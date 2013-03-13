-- In Cronus there are only cogs.  Each turn, at the outset,
-- all cogs get copied to the main map.  The z-order of cogs
-- and their blocking rules ultimately determines what gets
-- shown in the aggregate map.  The main map is itself a cog.
--
-- Mobs are cogs, too.

local Layer = require "layer"
local Catalog = require "catalog"

local cog = { }
local cog_mt = { __index = cog }

local function new_cog(width, height)
	-- even as small as 1x1 is ok for mobs!
	local self = setmetatable({
		map = Layer.new("int", width, height),
		down = Layer.new("int", width, height) -- the next cog down in the cog stack for each cell
	}, cog_mt)
	
	return self
end

local function new_mob_cog(tile_type)
	local self = new_cog(1, 1)
	self.map:set(1, 1, Catalog.tiles[tile_type].idx)

	return self
end


function cog:stamp(level)
	level:stamp(self)
	return self
end

function cog:fill(tag)
	self.map:fill(Catalog:idx(tag))
end

function cog:erase(x, y)
	self.map:set(x, y, 0)
end

function cog:push(dx, dy)
	self.map:moveto(self.map.x1 + dx, self.map.y1 + dy)
	return self
end

return {
	new = new_cog,
	generate = generate,
	mob = new_mob_cog
}

