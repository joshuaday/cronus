-- each mob is actually a cog, but the spawning and intelligence of mobs rests here

local Cog = require "cog"
local Catalog = require "catalog"
local Messaging = require "messaging"

local function new_mob_cog(spawn_name)
	-- mobs will be fashioned better soon
	-- todo : add mobs with maps!
	local spawn = Catalog.spawns[spawn_name]
	local tile = spawn.tile

	local self = Cog.new(1, 1)
	self.map:set(1, 1, spawn.tile.idx)
	--self.map:set(1, 3, spawn.tile.idx)
	--self.map:set(3, 1, spawn.tile.idx)
	--self.map:set(3, 3, spawn.tile.idx)

	self.info = spawn
	self.tile = tile
	self.active = spawn.ai ~= nil
	self.health = spawn.health
	self.name = spawn.name
	self.priority = spawn.priority or 100
	self.attack_pattern = spawn.attack_pattern

	if spawn.bagslots then
		self.bag = {slots = spawn.bagslots}
	end

	return self
end


return {
	new = new_mob_cog
}

