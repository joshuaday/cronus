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

local function new_mob_cog(spawn_name)
	-- mobs will be fashioned better soon
	local spawn = Catalog.spawns[spawn_name]
	local tile = spawn.tile

	local self = new_cog(3, 3)
	self.map:set(1, 1, spawn.tile.idx)
	--self.map:set(1, 3, Catalog:idx(tile_type))
	--self.map:set(3, 1, Catalog:idx(tile_type))
	--self.map:set(3, 3, Catalog:idx(tile_type))

	self.tile = tile
	self.active = spawn.ai ~= nil
	self.health = spawn.health
	self.item = spawn.item
	self.name = spawn.name

	if spawn.bagslots then
		self.bag = {slots = spawn.bagslots}
	end

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

function cog:set(x, y, tag)
	self.map:set(x, y, Catalog:idx(tag))
end

function cog:get(x, y)
	return Catalog.tiles[self.map:get(x, y)]
end

function cog:moveto(x, y)
	-- mark dirty?
	self.map:moveto(x, y)
	self.down:moveto(x, y)
	self.x1, self.y1 = x, y
end

local eight_ways = {{-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}}
function cog:neighbors()
	-- todo: extend to bigger cogs.  here's how:
	--       any cog that you aren't _currently_ overlapping but
	--       which you overlap when convolved eight ways, is a neighbor
	local n = {}
	for i = 1, 8 do
		local way = eight_ways[i]
		
		for cog in self.dlvl:cogs_at(self.x1 + way[1], self.y1 + way[2]) do
			n[cog] = true
		end
	end
	return n
end


function cog:say(msg)
	Messaging:announce {
		msg,
		ttl = 1500, turn = true,
		x = self.map.x2 - 1, y = self.map.y1 - 1,
		bg = 0, fg = 11
	}
end

function cog:attack(victim)
	-- todo : generate messages in all directions
	if victim.health then
		victim.health = victim.health - 1
		if victim.health <= 0 then
			victim.dlvl:removecog(victim)

			if self.is_player then
				Messaging:announce {"You kill the " .. victim.name .. ".", ttl = 500}
			end
		else
			victim:say(victim.health .. "hp")
			-- if self.is_player then
				-- Messaging:announce {"You hit the " .. victim.name .. ".", ttl = 500}
			-- end
		end
		if victim.is_player then
			Messaging:announce {victim.health .. " hp", ttl = 500}
		end
	end
end

function cog:manipulate(item_idx, command)
	local item = self.bag[item_idx]
	if command == "d" then
		self.bag[item_idx] = nil
		
		item:moveto(self.x1, self.y1)
		self.dlvl:addcog(item)
	elseif command == "e" then
	elseif command == "a" then
	elseif command == "r" then
		
	end
end

function cog:automove(dx, dy)
	if self.has_initiative then
		if dx == 0 and dy == 0 then
			-- just yield initiative
			self.has_initiative = false
			if self.is_player then
				Messaging:announce {"You wait.", ttl = 500}
			end
		else
			local targets = self:neighbors()

			if self:push(dx, dy) then
				-- took our turn!
				self:endturn() -- todo : move this elsewhere
				self.has_initiative = false

				local same_targets = self:neighbors()
				for k in pairs(same_targets) do
					if k.health and targets[k] then
						self:attack(k)
					end
				end
			elseif self.is_player then
				self.dlvl:refresh()
				-- find a message
				local complaint = self.dlvl:topmost(self.x1 + dx, self.y1 + dy, function(cog, tile)
					return tile.complaint
				end) or "The gap is too narrow."

				self:say (complaint)
			end
		end
	end
end

function cog:endturn()
	if self.bag then
		local items = { }
		self.dlvl:overlap(self, function(cog)
			if cog.item then
				items[cog] = true
			end
		end)

		local i = 0
		for cog in pairs(items) do
			repeat
				i = i + 1
				if i > self.bag.slots then
					Messaging:announce{"Your pack is full.", ttl = 500}
					return
				end
			until self.bag[i] == nil
			self.bag[i] = cog.dlvl:removecog(cog)
			Messaging:announce{"You got a " .. self.bag[i].name .. " (" .. string.char(i - 1 + string.byte 'a') .. ").", ttl = 2500}
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
	mob = new_mob_cog
}

