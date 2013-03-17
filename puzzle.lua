local Cog = require "cog"
local Catalog = require "catalog"
local Marble = require "marble"
local Layer = require "layer"

local random = require "random"



local function puzzlefy(dlvl, floormask)
	-- we'll copy the mask, and as we proceed we'll be
	-- SPLITTING IT BACK UP INTO ZONES.  the zones will
	-- have a puzzley tree structure or something.  it's cool.

	local bigmask = floormask:clone()
	-- get the passable gradient from the entry
	


	-- junk pasted in from the dlvl generator
	-- ensure the connectivity of the mask
	local zonemap = Layer.new("int", bigmask.width, bigmask.height)

	local workspace = Layer.new("int", bigmask.width, bigmask.height)
	local paths = Layer.new("int", bigmask.width, bigmask.height)

	local path_to_entry, path_to_exit = paths:clone(), paths:clone()

	local zones = bigmask:zones(zonemap)


	-- get entry and exit gradients
		-- bigmask:set(self.entry.x, self.entry.y, 1)
		-- bigmask:set(self.exit.x, self.exit.y, 1)

--[[
	local panic = 3

	while true do -- almost always runs once, no worries
		panic = panic - 1 -- well almost no worries
		if panic == 0 then
			return new_level(width, height, dlvl_up)
		end


		
		do
			local zonecount = 0
			for i = 1, #zones do
				if zones[i].value == 1 then
					zonecount = zonecount + 1
				end
			end
			if zonecount == 1 then
				break -- this is the way out!
			end
		end

		repeat
			local progress = false

			-- todo : this is horrifically slow; speed it up
			-- todo : also, move it elsewhere
			for zonenum = 1, #zones do
				local zone = zones[zonenum]
				if zone.value == 1 then
					for accept, x, y, v in workspace:spill(zone.x, zone.y, 1) do
						local z = zonemap:get(x, y)
						if z == zonenum then
							-- same zone, accept its neighbors at cost 2, and adjust our own score
							accept(2)
							paths:set(x, y, 1)
						else
							paths:set(x, y, v)
							-- and if, by chance, it is an open zone, roll back and break
							if zones[z].value == 1 then
								-- hooray!  now find our path back (can we?)
								for x, y in paths:rolldown(x, y) do
									bigmask:set(x, y, 1)
								end

								zonemap:replace(z, zonenum)
								zones[z].value = -1 -- replaced, see

								progress = true
								break
							end

							-- different zone, accept it at cost v + 1
							accept(1 + (v or 1))
						end
					end
					-- rocks.map:set(zone.x, zone.y, Catalog:idx "water")
					if progress then break end
				end
			end
		until not progress
	end
		
	]]
end


return {
	puzzlefy = puzzlefy
}
