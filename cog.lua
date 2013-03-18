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
		x1 = 1, y1 = 1, priority = 1
	}, cog_mt)
	
	return self
end

local function new_mob_cog(spawn_name)
	-- mobs will be fashioned better soon
	local spawn = Catalog.spawns[spawn_name]
	local tile = spawn.tile

	local self = new_cog(1, 1)
	self.map:set(1, 1, spawn.tile.idx)
	--self.map:set(1, 3, Catalog:idx(tile_type))
	--self.map:set(3, 1, Catalog:idx(tile_type))
	--self.map:set(3, 3, Catalog:idx(tile_type))

	self.info = spawn
	self.tile = tile
	self.active = spawn.ai ~= nil
	self.health = spawn.health
	self.name = spawn.name
	self.priority = spawn.priority or 100

	if spawn.bagslots then
		self.bag = {slots = spawn.bagslots}
	end

	return self
end

local function new_item_cog(spawn_name)
	local spawn = type(spawn_name) == "string" and Catalog.items[spawn_name] or spawn_name
	local tile = spawn.tile

	-- items are ALWAYS 1x1
	local self = new_cog(1, 1)
	self.map:set(1, 1, spawn.tile.idx)

	self.info = spawn
	self.item = true
	self.tile = tile
	self.name = spawn.name
	self.priority = spawn.priority or 99

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

local eight_ways = {{-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}} -- todo merge these
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

function cog:can_stand_at(x, y)
	local blocked = false
	local oldx, oldy = x, y
	self:moveto(x, y)
	
	self.dlvl:overlap(self, function (cog, x, y)
		local tile = cog:gettile(x, y)
		if tile.blocking > 0 then
			blocked = true
		end
	end)
	self:moveto(oldx, oldy)

	return not blocked
end

function cog:may_take_step(dx, dy)
	local dlvl = self.dlvl

	if dlvl.blocking:get(self.x1 + dx, self.y1 + dy) > 0 then
		return false 
	end

	if dx ~= 0 and dy ~= 0 then
		if dlvl.blocking:get(self.x1 + dx, self.y1) == 2
		   and dlvl.blocking:get(self.x1, self.y1 + dy) == 2 
		then
			return false
		end
	end

	return true
end

function cog:autorun_stop_point(dir)
	-- this cog is moving in direction dir and wonders whether this is a good place
	-- to stop.  rather incomplete.

	-- for now, just do a 1x1 lookup (SUNDAY)
	-- cog.dlvl:attach_floormap(cog)

	-- scan eight directions from the player to see if this
	-- is a place to stop running

	if dir[1] == 0 and dir[2] == 0 then
		return false
	end

	if not self:may_take_step(dir[1], dir[2]) then
		return true
	end

	for i = 1, 8 do
		local dx, dy = eight_ways[i][1], eight_ways[i][2]
		if dx ~= dir[x] or dy ~= dir[y] then
			-- look forward
		end
	end
	return false
end

function cog:known()
	local known = false
	if self.dlvl then
		self:each(function(t, x, y, idx)
			if self.dlvl.fov:get(x, y) > 0 then
				known = true
			end
		end)
	end
	return known
end

function cog:say(msg)
	if self:known() then
		Messaging:announce {
			msg,
			ttl = 1500, turn = true,
			x = self.map.x2 - 4, y = self.map.y1 - 2,
			bg = 0, fg = 11
		}
	end
end

function cog:attack(victim)
	-- todo : generate messages in all directions
	if victim.team == self.team and victim.team ~= nil then
		return -- don't attack friends
	end

	-- roll attack and defense
	

	if victim.health then
		victim.health = victim.health - 1
		if victim.health <= 0 then
			victim.dlvl:removecog(victim)

			if self.is_player then
				Messaging:announce {"You kill the " .. victim.name .. ".", ttl = 1500}
			end
		else
			victim:say(victim.health .. "/" .. victim.info.health)
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

function cog:get_floor()
	return self.dlvl:topmost(self.x1, self.y1, function(cog, tile)
		return tile.floor
	end)
end

function cog:automove(dx, dy)
	if self.has_initiative then
		if dx == 0 and dy == 0 then
			if self:get_floor() == "slick" and (self.lastdx ~= 0 or self.lastdy ~= 0) then
				return self:automove(self.lastdx or 0, self.lastdy or 0)
			end

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

function cog:pickup(item)
	-- find a slot to put it in
	local i = 0
	repeat
		i = i + 1
		if i > self.bag.slots then
			return false
		end
	until self.bag[i] == nil

	-- remove it from the level (if it's on it)
	if item.dlvl then
		item.dlvl:removecog(item)
	end

	-- check for the victory condition
	if item.info.slot == "victory" then
		VICTORY = true
	end

	-- put it in the bag
	self.bag[i] = item
	return i
end

function cog:endturn()
	if self.bag then
		local items = { }
		self.dlvl:overlap(self, function(cog)
			if cog.item then
				items[cog] = true
			end
		end)

		for cog in pairs(items) do
			local i = self:pickup(cog)
			if i then
				self:say ("A " .. cog.name .. " (" ..string.char(i - 1 + string.byte 'a') .. ")")
			else
				self:say ("No room for a " .. cog.name)
			end
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
	
	-- todo : adapt floor_type to work for bigger cogs !
	local floor_type = self:get_floor()
	
	if floor_type == "slick" then
		local dx1, dy1 = self.lastdx or 0, self.lastdy or 0
		if dx == 0 and dy == 0 then
			dx, dy = dx1, dy1
		else
			-- you can turn but you can't stop
			
		end
	end
	
	self.lastdx, self.lastdy = 0, 0
	
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
		local interaction, interacting = nil, nil

		self.dlvl:overlap(self, function (cog, x, y)
			local tile = cog:gettile(x, y)
			if tile.interact then
				interaction, interacting = tile.interact, cog
			end
			if tile.blocking > 0 then
				blocked = true
			end
		end)
		
		if interaction then
			if interaction == "push" then
				blocked = not interacting:push(dx, dy)
			end
			if interaction == "down" then
				-- 
				-- blocked = false
			end
		end
		if blocked then
			-- revert the motion
			self:moveto(x, y)
			return false
		end

		self.lastdx, self.lastdy = dx, dy -- mark motion for, e.g., slipping
		return true
	end
end

return {
	new = new_cog,
	mob = new_mob_cog,
	item = new_item_cog
}

