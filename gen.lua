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
local masks = {Mask.splash}
function random_room_mask(ss)
	local w, h = math.random(ss, 3 * ss), math.random(ss, 2 * ss)
	local midx, midy = math.floor(w / 2), math.floor(h / 2)
	local chunk = Cog.new(w, h)
	local map = chunk.map
	
	local mtype = masks[math.random(#masks)]
	local room = mtype(w, h)
	room:moveto(1, 1)

	return room
end

return {
	random_room_mask = random_room_mask
}

