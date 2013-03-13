local Mask = require "mask"
local Cog = require "cog"
local Catalog = require "catalog"

local function change_border( )
	
end

local function probable_draw_from_mask(cog, mask, feature)
	feature = Catalog:idx(feature)
	mask:each(function(degree, x, y)
		if math.random() < degree then
			cog.map:set(x, y, feature)
		end
	end)
end


function empty_room( )
	local w, h = math.random(6, 21), math.random(6, 21)
	local midx, midy = math.floor(w / 2), math.floor(h / 2)
	local chunk = Cog.new(w, h)
	local map = chunk.map
	
	local circle = Mask.ovoid(w, h)
	circle:recenter(midx + 1, midy + 1)

	probable_draw_from_mask(
		chunk, circle, 
		Catalog:idx "floor"
		-- edge = Catalog:idx "wall"
	)

	return chunk
end

return {
	empty_room = empty_room
}

