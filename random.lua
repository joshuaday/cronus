local ffi = require "ffi"
math.randomseed(os.time())

local random = {}
local rng = math.random

function random.index(arr) return rng(#arr) end

function random.pick(arr) return arr[rng(#arr)] end

function random.gauss(mean, stdev)
	local x, y = rng(), rng()

	return mean + ((math.sqrt(-2 * math.log(x)) * math.cos(2 * math.pi * y)) * stdev)
end

function random.uniform(min, max)
	return min + (max - min) * rng()
end


_G.random = random

