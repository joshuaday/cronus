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


--local masks = {Mask.rectangle, Mask.ovoid, Mask.splash}

return {
	random_room_mask = random_room_mask
}

