local Layer = require "layer"

local Mask = { }

function Mask.ovoid(w, h)
	local map = Layer.new("double", w, h)

	local midx, midy = .5 * (map.x2 + map.x1), .5 * (map.y2 + map.y1)
	local inv_rx, inv_ry = (2 / (1.0 + map.x2 - map.x1)) ^ 2, (2 / (1.0 + map.y2 - map.y1)) ^ 2

	map:each(function(_, x, y)
		local dx, dy = midx - x, midy - y
		if (dx * dx) * inv_rx + (dy * dy) * inv_ry <= 1 then
			map:set(x, y, 1.0)
		end
	end)

	return map
end

function Mask.rectangle( )
	chunk.map:each(function(_, x, y)
		chunk.map:set(x, y, floor)
	end)
end

function Mask.circle(w, h)
	local radius = math.floor(.5 * (math.min(w, h) - 1))
	local edge = 1 + radius * 2
	local output = Layer.new("double", w, h)
	local r2 = (radius + 1) * (radius + 1)
	local falloff_r2 = (radius) * (radius)
	local c3p0 = 1 / (r2 - falloff_r2)

	output:fill(1.0)
	output:set_default(0.0)
	output:recenter(0, 0)

	local lower_y = -(radius + .5)
	for y = -radius, 0 do
		local outer_x = math.sqrt(r2 - y * y)
		local inner_x = math.sqrt(falloff_r2 - y * y)
		for x = -radius, -math.floor(outer_x) do
			output:set(x, y, 0.0)
			output:set(-x, y, 0.0)
			output:set(x, -y, 0.0)
			output:set(-x, -y, 0.0)
		end
		for x = math.floor(-outer_x), -math.floor(inner_x) do
			local d2 = y * y + x * x
			local m = c3p0 * (r2 - d2)
			if (0 < m and m < 1) then
				output:set(x, y, m)
				output:set(-x, y, m)
				output:set(x, -y, m)
				output:set(-x, -y, m)
			end
		end
	end

	return output
end

return Mask
