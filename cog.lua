-- In Cronus there are only cogs.  Each turn, at the outset,
-- all cogs get copied to the main map.  The z-order of cogs
-- and their blocking rules ultimately determines what gets
-- shown in the aggregate map.  The main map is itself a cog.
--
-- Mobs are cogs, too.

local Layer = require "layer"
local Catalog = require "catalog"
local Messaging = require "messaging"

local cog = { }
local cog_mt = { __index = cog }

local function new_cog(width, height)
	-- even as small as 1x1 is ok for mobs!
	local self = setmetatable({
		map = Layer.new("int", width, height),
		down = Layer.new("int", width, height), -- the next cog down in the cog stack for each cell
		x1 = 1, y1 = 1
	}, cog_mt)
	
	return self
end

local function new_mob_cog(tile_type)
	-- mobs will be fashioned better soon
	local tile_idx = Catalog:idx(tile_type)
	local tile = Catalog.tiles[tile_idx]

	local self = new_cog(1, 1)
	self.map:set(1, 1, tile_idx)
	--self.map:set(1, 3, Catalog:idx(tile_type))
	--self.map:set(3, 1, Catalog:idx(tile_type))
	--self.map:set(3, 3, Catalog:idx(tile_type))

	self.active = tile.ai ~= nil

	return self
end

function cog:each(fn)
	-- just filters the layer input so no void cells get passed through
	self.map:each(function (t, x, y, idx)
		if t ~= 0 then
			fn(t, x, y, idx)
		end
	end)
end

function cog:gettile(x, y)
	return Catalog.tiles[self.map:get(x, y)]
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

function cog:moveto(x, y)
	-- mark dirty?
	self.map:moveto(x, y)
	self.down:moveto(x, y)
	self.x1, self.y1 = x, y
end

function cog:automove(dx, dy)
	if self.has_initiative then
		if dx == 0 and dy == 0 then
			-- just yield initiative
			self.has_initiative = false
			if self.is_player then
				Messaging:announce {"You wait.", ttl = 500}
			end
		end

		if self:push(dx, dy) then
			-- took our turn!
			self.has_initiative = false
		elseif self.is_player then
			Messaging:announce {"You can't go there!", ttl = 500}
		end
	end
end

function cog:push(dx, dy)
	-- kicks off a wonderful recursive process of making sure that everything involved can be pushed.
	--
	-- diagonal rule: must be able to move first in dx and then in dy, or first in dy and then dx;
	--                ending in a valid state does not suffice.  (restrictions may be weakened in the
	--                intermediate state, however.)
	-- simultaneity rule: all motion initiated by pushing is understood to happen at once.  like as the
	--                    diagonal rule, either A then B _or_ B then A must be a valid sequence.
	--                    pushing is a simple example: A pushes B, so B moves, and then A moves.  but
	--                    if B also moves C 
	
	local x, y = self.x1, self.y1
	
	local distance = math.abs(dx) + math.abs(dy)
	if distance > 1 then
		-- decompose the motion into single steps and try them in arbitrary order until something sticks
		if self:push(dx, 0) then
			if self:push(0, dy) then
				return true
			else
				self:moveto(x, y)
			end
		end
		if self:push(0, dy) then
			if self:push(dx, 0) then
				return true
			else
				self:moveto(x, y)
			end
		end
		return false
	else
		-- single-step motion is easy to resolve

		self:moveto(x + dx, y + dy)
		self.dlvl:refresh()
		
		-- check for collisions
		local blocked = false
		local pushing = nil

		self.dlvl:overlap(self, function (cog, x, y)
			local tile = cog:gettile(x, y)
			if tile.pushing then
				pushing = cog
			end
			if tile.blocking then
				blocked = true
			end
		end)
		
		if pushing then
			blocked = not pushing:push(dx, dy)
		end
		if blocked then
			-- revert the motion
			self:moveto(x, y)
			return false
		end

		return true
	end
end

return {
	new = new_cog,
	generate = generate,
	mob = new_mob_cog
}

