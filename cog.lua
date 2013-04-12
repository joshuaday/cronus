-- In Cronus there are only cogs.  Each turn, at the outset,
-- all cogs get copied to the main map.  The z-order of cogs
-- and their blocking rules ultimately determines what gets
-- shown in the aggregate map.  The main map is itself a cog.
--
-- Mobs are cogs, too.

local Layer = require "layer"
local Catalog = require "catalog"
local Messaging = require "messaging"
local Mask = require "mask"

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
	self.attack_pattern = spawn.attack_pattern

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
	if self.dlvl then
		self.dlvl:restamp(self, false)
	end

	self.map:moveto(x, y)
	self.down:moveto(x, y)
	self.x1, self.y1 = x, y

	if self.dlvl then
		self.dlvl:restamp(self, true)
	end
end

local eight_ways = {{-1, -1}, {0, -1}, {1, -1}, {1, 0}, {1, 1}, {0, 1}, {-1, 1}, {-1, 0}} -- todo merge these
function cog:neighbors(dx, dy)
	-- todo: extend to bigger cogs.  here's how:
	--       any cog that you aren't _currently_ overlapping but
	--       which you overlap when convolved eight ways, is a neighbor
	local n = {}
	for i = 1, 8 do
		local way = eight_ways[i]
		
		if dx == nil or (dx == way[1] and dy == way[2]) then
			for cog in self.dlvl:cogs_at(self.x1 + way[1], self.y1 + way[2]) do
				n[cog] = true
			end
		end
	end
	return n
end

function cog:can_stand_at(x, y)
	local blocked = false
	local oldx, oldy = x, y

	-- todo: don't actually move it for this test!  silly, very silly
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
	
	local accuracy = (self.weapon and self.weapon.info.accuracy) or self.info.accuracy or 20
	local damage = (self.weapon and self.weapon.info.damage) or self.info.damage or 1

	if victim.health then
		if math.random(100) > accuracy then
			self:say "Missed!"
			return true
		end

		if self.attack_pattern.backthrow then
			-- this is inexact!
			local dx, dy = victim.x1 - self.x1, victim.y1 - self.y1
			local newx, newy = victim.x1 - 2 * dx, victim.y1 - 2 * dy
			if victim:can_stand_at(newx, newy) then
				victim:moveto(newx, newy)
			else
				return false -- well, this is not the place to announce this
			end
		end

		victim.health = victim.health - damage
		if victim.health <= 0 then
			victim.dlvl:removecog(victim)

			if self.is_player then
				Messaging:announce {"You kill the " .. victim.name .. ".", ttl = 1500}
			end
		else
			victim:say(victim.health .. "/" .. victim.info.health)
		end
		return true
	end
end

function cog:unequip(item)
	if item.equipped then
		if item.info.slot == "weapon" then
			self.weapon = nil
			self.attack_pattern = self.info.attack_pattern
		end
		item.equipped = false
		return true
	else
		cog:say "I wasn't using that."
	end
end

function cog:equip(item)
	if item.info.slot == "weapon" then
		self.weapon = item
		self.attack_pattern = item.info.attack_pattern
		item.equipped = true
	else
		cog:say "I can't equip that."
	end
end

function cog:get_item_in_slot(slot)
	if self.bag then
		for i = 1, #self.bag do
			local item = self.bag[i]
			if item and item.equipped and item.info.slot == slot then
				return i, item
			end
		end
	end
end

function cog:trigger()
	if self.info.does == "explode" then
		self:say "BOOM!"
		-- iterate nearby!
		local dlvl = self.dlvl

		local n = self:neighbors()
		for k in pairs(n) do
			if k.health and k.health > 0 then
				k:say "BOOM!"
				dlvl:removecog(k)
			end
		end

		dlvl:removecog(self)
	end
end

function cog:manipulate(item_idx, command, inventory)
	local item = self.bag[item_idx]
	if command == "d" then
		self.bag[item_idx] = nil
		
		if item.equipped then
			self:unequip(item)
		end

		item:moveto(self.x1, self.y1)
		self.dlvl:addcog(item)
	elseif command == "e" then
		if item.info.slot and not item.equipped then
			local _, olditem = self:get_item_in_slot(item.info.slot)
			if olditem then
				self:unequip(olditem)
			end
			self:equip(item)
			self.has_initiative = false
		else
			self:say "I can't equip that."
		end
	elseif command == "a" then
		local used = false

		if item.info.does == "heal" then
			if self.health == self.info.health then
				self:say "It'll heal me."
			else
				self.health = self.info.health
				self:say ("Healed!  (" .. self.health .. "/" .. self.info.health .. ")")
				used = true
			end
		end
		if item.info.does == "fov" then
			self:say "To use a camera, just drop it."
		end
		if item.info.does == "detonates" then
			if item.references == nil then
				local i, act, other = inventory "T"
				if other and other.info.needs == "detonator" then
					self:say ("Now I'll drop the " .. other.name .. "!")
					item.references = other
				end
			else
				local other = item.references
				local idx, letter = 0, '?'
				-- find the item in the inventory
				for i = 1, self.bag.slots do
					if self.bag[i] == other then
						idx = i
						letter = string.char(string.byte 'a' + idx - 1)
						break
					end
				end
				if idx ~= 0 then
					self:say ("Drop the " .. other.name .. " (" .. letter .. ") or you'll " .. other.info.complaint)
				else
					other:trigger()
					used = true
				end
			end
		end
		if item.info.needs == "detonator" then
			self:say "(a)pply a detonator to this to use this"
		end
	
		if used then
			self.bag[item_idx] = nil
		end
	elseif command == "r" then
		if self:unequip(item) then
			self.has_initiative = false
		end
	end
end

function cog:get_floor()
	return self.dlvl:topmost(self.x1, self.y1, function(cog, tile)
		return tile.floor
	end)
end

function cog:automove(dx, dy)
	local targets -- used for melee logic
	local function start_scythe_attack()
		if self.attack_pattern.scythe then
			targets = self:neighbors()
		end
	end

	local function attempt_bump_attack(bump)
		bump = bump or "bump"

		local bumped, fought = false, false
		targets = self:neighbors(dx, dy)

		for k in pairs(targets) do
			if k.health and k.team ~= self.team then
				bumped = true
				if self.attack_pattern[bump] then
					fought = true
					self:attack(k)
				end
			end
		end
		return bumped, fought
	end

	local function finish_scythe_attack()
		if self.attack_pattern.scythe then
			local same_targets = self:neighbors()
			for k in pairs(same_targets) do
				if k.health and targets[k] then
					self:attack(k)
				end
			end
		end
	end

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
			start_scythe_attack()

			if self:push(dx, dy) then
				-- took our turn!
				self:endturn() -- todo : move this elsewhere
				self.has_initiative = false

				finish_scythe_attack()

				attempt_bump_attack("lunge")
			else
				local bumped, fought = attempt_bump_attack()
				if fought then
					self.dlvl:refresh() -- todo : remove when consistency is maintained by adding/removing cogs
					self:endturn() -- todo : move this elsewhere
					self.has_initiative = false

					return
				end
			
				if self.is_player then
					if bumped then
						Messaging:announce {"You can't attack with a " .. self.weapon.name .. " from here."}
						return
					end
					-- find a message
					local complaint = self.dlvl:topmost(self.x1 + dx, self.y1 + dy, function(cog, tile)
						return tile.complaint
					end) or "The gap is too narrow."

					self:say (complaint)
				end
			end
		end
	end
end

function cog:pickup(item, autoequip)
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

	-- check whether the item does something special when picked up
	if item.info.does == "fov" and item.fov == nil then
		local range = 13

		item.team = "player"
		item.fov = Layer.new("int", range * 2 + 1, range * 2 + 1) -- unify with the other fov code
		item.fov_mask = Mask.circle(range * 2 + 1, range * 2 + 1)
	end

	-- put it in the bag
	self.bag[i] = item

	if autoequip then
		self:equip(item)
	end
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

		self.vx, self.vy = dx, dy -- mark motion for, e.g., slipping
		return true
	end
end

return {
	new = new_cog,
	mob = new_mob_cog,
	item = new_item_cog
}

