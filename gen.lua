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


function generate( )
	local chunk = Cog.new(13, 13)
	local map = chunk.map
	
	local circle = Mask.circle(5)
	circle:recenter(6, 6)

	probable_draw_from_mask(
		chunk, circle, 
		Catalog:idx "floor"
			-- edge = Catalog:idx "wall"
	)

	return chunk
end

return {
	generate = generate
}

