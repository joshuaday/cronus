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

	self.dlvl:would_overlap(self, x, y, function (cog, x, y)
		local tile = cog:gettile(x, y)
		if tile.blocking > 0 then
			blocked = true
		end
	end)

	return not blocked
end

function cog:may_take_step(dx, dy)
	-- todo: adapt for media
	-- todo: enumerate complaints

	local dlvl = self.dlvl

	local old_stamped = self.stamped
	dlvl:restamp(self, false)

	for y = self.map.y1, self.map.y2 do
		for x = self.map.x1, self.map.x2 do
			local idx = self.map:get(x, y)
			if idx ~= 0 then
				-- the cog has a presence in this cell, so make sure this cell can move properly:
				local tile = Catalog.tiles[idx]

				if 0 ~= bit.band(3, dlvl.blocking:get(x + dx, y + dy)) then 
					dlvl:restamp(self, old_stamped)
					return false
				end

				if dx ~= 0 and dy ~= 0 then
					if 2 < bit.band(2, dlvl.blocking:get(x + dx, y))
					   + bit.band(2, dlvl.blocking:get(x, y + dy))
					   + bit.band(2, tile.blocking)
					then
						dlvl:restamp(self, old_stamped)
						return false
					end
				end
			end
		end
	end

	dlvl:restamp(self, old_stamped)

	return true
end

function cog:remove_pushes(dx, dy)
	-- todo : put this on the dlvl instead of cog

	-- this IGNORES all diagonal rules and inserts (into 'bumps') all cells that
	-- would be push-interacted with if the step were taken

	local dlvl = self.dlvl
	local bumps = { }
	local wontbudge = false

	local function addbump(bump)
		if bumps[bump.cog] then
			-- make sure it's the same as what's there, or it's invalid
			local oldbump = bumps[bump.cog]
			if bump.dx == oldbump.dx and bump.dy == oldbump.dy then
				-- ok
			else
				-- trying to push one cog two directions will always fail
				oldbump.failed = true
				wontbudge = true
			end
		else
			bumps[bump.cog] = bump
			bumps[1 + #bumps] = bump

			-- add linked cogs too!
			if bump.cog.link then
				local link = bump.cog.link
				local cog = bump.cog.link.cog
				addbump {cog = cog, dx = link.dx * bump.dx, dy = link.dy * bump.dy}
			end
		end
	end

	addbump {cog = self, dx = dx, dy = dy}

	-- whittle down the numbered array of bumps until none remain; for each one,
	-- look at which others will be pushed by it, and so forth.  each one will
	-- be removed from the map as we proceed; inconsistencies (except the most
	-- trivial) will be handled later.

	while #bumps > 0 do
		local bump = bumps[1]
		local mover = bump.cog
		local dx, dy = bump.dx, bump.dy

		bump.old_stamped = mover.stamped
		dlvl:restamp(mover, false)
		for y = mover.map.y1, mover.map.y2 do
			for x = mover.map.x1, mover.map.x2 do
				local idx = mover.map:get(x, y)
				if idx ~= 0 then
					-- the cog has a presence in this cell, so check what this cell's presence will bump
					-- (note that this cell should probably be marked as an INTERACTOR/WEAPON/etc.)
					-- (but that for now, this rule is not respected, even remotely.)
					local tile = Catalog.tiles[idx]

					local cx, cy = x + dx, y + dy

					-- detect the cogs that are in the position we're peeking at, and detect
					-- which cells of theirs are there
					
					local cog_idx = dlvl.top:get(cx, cy)
					while cog_idx ~= 0 do
						local cog = dlvl.cogs[cog_idx]
						local tile2 = cog:gettile(cx, cy)
						
						if tile2.interact == "push" then
							addbump {cog = cog, interact = tile2.interact, x = cx, y = cy, dx = dx, dy = dy}
							if wontbudge then
								return false, bumps
							end
						end

						cog_idx = cog.down:get(cx, cy)
					end
				end
			end
		end
		bumps[1] = bumps[#bumps]
		bumps[#bumps] = nil
	end

	-- now put them all back on the map?

	return true, bumps
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
			if self:get_floor() == "slick" and (self.vx ~= 0 or self.vy ~= 0) then
				-- return self:automove(self.lastdx or 0, self.lastdy or 0)
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

function cog:newpush(dx, dy)
	-- collect all the cogs that get engaged by this motion

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


	-- step one: enumerate everything that would be PUSHED by this motion

	local dlvl = self.dlvl
	local valid, bumps = self:remove_pushes(dx, dy)

	if valid then
		-- notice also that all of these cogs have been UNSTAMPED from the map as a side effect of
		-- enumerate_pushes
		local blocked = false
		for cog, bump in pairs(bumps) do
			if not cog:may_take_step(bump.dx, bump.dy) then
				blocked = true
			end
		end

		-- put them all back on the map now!
		for cog, bump in pairs(bumps) do
			dlvl:restamp(cog, true)
		end

		if blocked then
			-- it won't budge!
			return false
		end

		-- ok!
		for cog, bump in pairs(bumps) do
			cog:moveto(cog.x1 + bump.dx, cog.y1 + bump.dy)
		end
	else
		-- in any case, put them all back on the map
		for cog, bump in pairs(bumps) do
			if type(cog) == "table" then -- filter out numeric entries (which are left in erroneously)
				dlvl:restamp(cog, true)
			end
		end
	end



	-- now run through all of these 
	
	
	-- todo : adapt floor_type to work for bigger cogs !
	--[[ local floor_type = self:get_floor()
	
	if floor_type == "slick" then
		if dx ~= self.vx or dy ~= self.vy then
			-- return false
		end
 
		--[==[local dx1, dy1 = self.lastdx or 0, self.lastdy or 0
		if dx == 0 and dy == 0 then
			dx, dy = dx1, dy1
		else
			-- you can turn but you can't stop
			
		end]==]
	end ]] 
	
	-- single-step motion is easy to resolve
	
	--[[self:moveto(x + dx, y + dy)

	if blocked then
		-- revert the motion
		self:moveto(x, y)
		return false
	end]]

	self.vx, self.vy = dx, dy -- mark motion for, e.g., slipping
	return true
end

return {
	new = new_cog,
	mob = new_mob_cog,
	item = new_item_cog
}

