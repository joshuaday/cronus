local ffi = require "ffi"
local Layer = require "layer"

-- use layers to do demoscene plasmas (wrapping displacement, etc)

local function uniform_noise(w, h)
	local layer = Layer.new("double", w, h)
	for i = 1, layer.length do
		layer.cells[i] = random.uniform(0, 1)
	end
end

local function gaussian_noise(w, h)
	local layer = Layer.new("double", w, h)
	for i = 1, layer.length do
		layer.cells[i] = random.gauss(0, 1)
	end
end

local function midpoint(w, h, sigma, turbulence)
	-- get the output ready
	local output = Layer.new("double", w, h)
	
	sigma = sigma or 5
	turbulence = turbulence or .5

	-- get gaussian noise
	-- local gauss = gaussian_noise(w, h)

	-- recurse internally
	local function subdivide(sigma, x, y, w, h, p1, p2, p3, p4)
		local mid = .25 * (p1 + p2 + p3 + p4)
		if w > 1 or h > 1 then
			local hw = math.floor(.5 * w)
			local hh = math.floor(.5 * h)
			
			mid = mid + random.gauss(0, sigma)
			-- center = shift(transWidth + transHeight);
			
			local side1 = .5 * (p1 + p2)
			local side2 = .5 * (p2 + p3)
			local side3 = .5 * (p3 + p4)
			local side4 = .5 * (p4 + p1)
			local ss = turbulence * sigma

			subdivide(ss, x, y, hw, hh, p1, side1, mid, side4)
			subdivide(ss, x + hw, y, w - hw, hh, side1, p2, side2, mid)
			subdivide(ss, x + hw, y + hh, w - hw, h - hh, mid, side2, p3, side3)
			subdivide(ss, x, y + hh, hw, h - hh, side4, mid, side3, p4)
		else
			output:set(x, y, mid)
		end
	end

	subdivide(sigma, 1, 1, w, h, 0, 1, 1, 0)
	return output
end

local function bands(w, h, bandwidth, angle)
	local output = Layer.new("int", w, h)
	local xc, yc = math.cos(angle) / bandwidth, math.sin(angle) / bandwidth
	output:each(function(_, x, y)
		output:set(x, y, math.floor(xc * x + yc * y))
	end)
	return output
end

local function displace(input, dispx, dispy)
	local output = Layer.new(input.ctype, input.width, input.height)
	output:each(function(_, x, y)
		local dx, dy = dispx:get(x, y), dispy:get(x, y)
		local srcx, srcy = math.floor(x + .5 + dx), math.floor(y + .5 + dy)
		local ival = input:get(srcx, srcy)
		
		output:set(x, y, ival)
	end)
	return output
end


return {
	displace = displace,
	bands = bands,
	midpoint = midpoint
}
