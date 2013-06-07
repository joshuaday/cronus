local Layer = require "layer"
local Geometry = require "geometry"

local Mask = { }
local cache = { }

function Mask.new(w, h, tag)
	if tag then
		if not cache[tag] then
			cache[tag] = Layer.new("int", w, h)
		end
		return cache[tag]
	else
		return Layer.new("int", w, h)
	end
end

function Mask.ovoid(w, h)
	local map = Mask.new(w, h)

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

function Mask.rectangle(w, h)
	local output = Mask.new(w, h)
	output:fill(1)
	return output
end

function Mask.poly(points)
	 --local points = {{0, 0}, {9, 4}, {-9, 4}}
	 --local points = {{0, 0}, {9, 12}, {-9, 12}}
	--local points = {{-9, 1}, {9, 0}, {9, 11}, {-9, 12}}
	
	local npoints = #points
	local function I(i) if i > npoints then return 1 else return i end end
	local function X(i) return points[I(i)][1] end
	local function Y(i) return points[I(i)][2] end

	local x1, y1, x2, y2 = X(1), Y(1), X(1), Y(1)

	for i = 2, npoints do
		x1 = math.min(x1, X(i))
		x2 = math.max(x2, X(i))

		y1 = math.min(y1, Y(i))
		y2 = math.max(y2, Y(i))
	end
	
	local w, h = 1 + x2 - x1, 1 + y2 - y1
	local mask = Mask.new(w, h)
	mask:moveto(x1, y1)
	
	-- these could be stored temporarily in the mask, but how often will this even be called?
	local minx, maxx = {}, {}
	
	for y = y1, y2 do
		minx[y], maxx[y] = x2, x1
	end

	for i = 1, npoints do
		for x, y in Geometry.bresenham(X(i), Y(i), X(i + 1), Y(i + 1)) do
			minx[y] = math.min(x, minx[y])
			maxx[y] = math.max(x, maxx[y])
		end
	end
	for y = y1, y2 do
		for x = minx[y], maxx[y] do
			mask:set(x, y, 1)
		end
	end
	
	return mask
end

function Mask.polygon(sides, radius, rotate)
	local points = { }
	
	
	for i = 1, sides do
		local orient = rotate + (i / sides)
		local angle = 2 * math.pi * orient
		points[i] = {
			math.floor(radius * math.cos(angle)),
			math.floor(radius * math.sin(angle))
		}
	end
	
	return Mask.poly(points)
end

function Mask.splash(cellcount)
	-- todo: extend splash to accept an existing mask and a squish parameter that describes how
	--       completely it should attempt to fill that mask (possibly a new mask type?)
	local squish = .2 --.25
	local side = math.ceil(math.sqrt(cellcount / squish))
	local w, h = side, side

	local workspace = Layer.new("int", w, h)
	local output = Mask.new(w, h)
	output:zero()

	local remain = .9 * cellcount
	for accept, x, y in workspace:spill(math.floor(.5 * w), math.floor(.5 * h)) do
		remain = remain - 1
		if remain > 0 then accept() end
		output:set(x, y, 1.0)
	end
	
	return output
end

-- circle is really a different kind of mask, and this is a dicey issue
function Mask.circle(w, h)
	-- todo: replace this floating point circle with a proper discrete bresenham-style circle
	local radius = math.floor(.5 * (math.min(w, h) - 1))
	local edge = 1 + radius * 2
	local output = Mask.new(w, h)
	local r2 = (radius + 1) * (radius + 1)
	local falloff_r2 = (radius) * (radius)
	local c3p0 = 1 / (r2 - falloff_r2)

	output:fill(1.0)
	output:default(0.0)
	output:recenter(0, 0)

	local lower_y = -(radius + .5)
	for y = -radius, 0 do
		local outer_x = math.sqrt(r2 - y * y)
		local inner_x = math.sqrt(falloff_r2 - y * y)
		for x = -radius, -math.floor(outer_x) do
			output:set(x, y, 0)
			output:set(-x, y, 0)
			output:set(x, -y, 0)
			output:set(-x, -y, 0)
		end
		for x = math.floor(-outer_x), -math.floor(inner_x) do
			local d2 = y * y + x * x
			local m = c3p0 * (r2 - d2)
			if (.5 < m and m < 1) then
				m = 1 -- this booleanizes it -- I should really just write a proper discrete circle algo instead of reusing old code
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
