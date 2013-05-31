local ffi = require "ffi"
math.randomseed(os.time())

local random = {}
local rng = math.random

function random.index(arr) return rng(#arr) end

function random.pick(arr) 
	if arr.SCORE then
		local u = rng() * arr.SCORE
		for k, v in pairs(arr) do
			if type(v) == "table" then
				u = u - v.SCORE
				if u <= 0 then
					return v
				end
			end
		end
	else
		return arr[rng(#arr)]
	end
end

function random.gauss(mean, stdev)
	local x, y = rng(), rng()

	return mean + ((math.sqrt(-2 * math.log(x)) * math.cos(2 * math.pi * y)) * stdev)
end

function random.uniform(min, max)
	return min + (max - min) * rng()
end

function random.int(min, max)
	return min + math.floor((1 + max - min) * rng())
end


_G.random = random

