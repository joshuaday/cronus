local ffi = require "ffi"

local layer = { }

local layer_mt = { __index = layer }

local function new_layer(ctype, width, height) 
	local x1, y1 = 1, 1
	return setmetatable({
		x1 = x1,
		y1 = y1,
		x2 = x1 + width - 1,
		y2 = y1 + height - 1,
		width = width,
		height = height,
		length = width * height,

		cells = ffi.new(ctype .. "[?]", 1 + width * height),

		ctype = ctype
	}, layer_mt)
end

function layer:index(x, y)
	x, y = x - self.x1, y - self.y1
	if x < 0 or y < 0 or x >= self.width or y >= self.height then
		return 0
	else
		return 1 + x + y * self.width
	end
end

function layer:get(x, y)
	return self.cells[self:index(x, y)]
end

function layer:set(x, y, v)
	x, y = x - self.x1, y - self.y1
	if x < 0 or y < 0 or x >= self.width or y >= self.height then
		return
	end

	self.cells[1 + x + y * self.width] = v
	return self
end

function layer:moveto(x1, y1)
	self.x1, self.y1, self.x2, self.y2 = x1, y1, x1 + self.width - 1, y1 + self.height - 1
	return self
end

function layer:recenter(x, y)
	local x1, y1 = x - math.floor(self.width / 2), y - math.floor(self.height / 2)
	self.x1, self.y1, self.x2, self.y2 = x1, y1, x1 + self.width - 1, y1 + self.height - 1
	return self
end

function layer:fill(v)
	for i = 1, self.width * self.height do
		self.cells[i] = v
	end
	return self
end

function layer:zero()
	ffi.fill(self.cells, ffi.sizeof(self.cells), 0)
	return self
end

function layer:replace(old, sub)
	for i = 1, self.length do
		if self.cells[i] == old then
			self.cells[i] = sub
		end
	end
end

function layer:rolldown(x, y)
	local best, bestx, besty

	local function peek(x, y)
		local v = self:get(x, y)
		if v < best and v > 0 then
			best, bestx, besty = v, x, y
		end
	end

	local function iterator()
		x, y = bestx, besty
		if x ~= nil then
			bestx = nil

			peek(x - 1, y)
			peek(x + 1, y)
			peek(x, y - 1)
			peek(x, y + 1)
			
			return x, y
		end
	end
	
	best, bestx, besty = self:get(x, y), x, y
	return iterator
end

function layer.spill(workspace, x, y, v)
	local front_x, front_y, front_v = { }, { }, { }

	local function touch(x, y, v)
		if workspace:get(x, y) == 0 then
			front_x[1 + #front_x] = x
			front_y[1 + #front_y] = y
			front_v[1 + #front_v] = v
			workspace:set(x, y, 1)
		end
	end
	
	local function accept(new_v)
		v = new_v or v
		touch(x - 1, y, v)
		touch(x + 1, y, v)
		touch(x, y - 1, v)
		touch(x, y + 1, v)
	end

	local function iterator()
		if #front_x > 0 then
			local i = random.index(front_x)
			x, y, v = front_x[i], front_y[i], front_v[i]

			front_x[i] = front_x[#front_x]
			front_y[i] = front_y[#front_y]
			front_v[i] = front_v[#front_v]
			front_x[#front_x] = nil
			front_y[#front_y] = nil
			front_v[#front_v] = nil

			return accept, x, y, v
		else
			return nil
		end
	end

	workspace:zero()
	workspace:set_default(1)

	touch(x, y, 1)
	return iterator
end

function layer:zones(output, samezone_fn)
	-- not even pretending this is efficient
	-- todo : speed it up

	local zones = {}
	local workspace = new_layer("int", self.width, self.height)

	samezone_fn = samezone_fn or function(a, b)
		return a == b
	end
	
	output:zero()
	output:each(function(v, x, y)
		if v == 0 then -- new zone!
			local v1 = self:get(x, y)
			local zone_number, count = 1 + #zones, 0
			
			for accept, x, y in workspace:spill(x, y) do
				local v2 = self:get(x, y)
				if samezone_fn(v1, v2) then
					accept()
					count = count + 1
					output:set(x, y, zone_number)
				end
			end
			local zone = {x = x, y = y, idx = zone_number, value = v1, count = count}
			zones[zone_number] = zone
		end
	end)
	return zones
end



function layer:set_default(v)
	self.cells[0] = v
	return self
end

function layer:each(f)
	local i = 1
	for y = self.y1, self.y2 do
		for x = self.x1, self.x2 do
			f(self.cells[i], x, y, i)
			i = i + 1
		end
	end
	return self
end

function layer:count(f)
	local ct = 0
	self:each(function(v, x, y, i) if f(v, x, y, i) then ct = ct + 1 end end)
	return ct
end

function layer:all(f)
	local i = 1
	for y = self.y1, self.y2 do
		for x = self.x1, self.x2 do
			if not f(self.cells[i], x, y, i) then
				return false
			end
			i = i + 1
		end
	end
	return true
end

function layer:stamp(l2, fn)
	assert(self.ctype == l2.ctype)
	
	l2:each(function(v, x, y)
		local idx = self:index(x, y)
		if idx > 0 then 
			self.cells[idx] = fn(self.cells[idx], v)
		end
	end)
end

function layer:clone()
	local copy = new_layer(self.ctype, self.width, self.height)
	copy:moveto(self.x1, self.y1)
	ffi.copy(copy.cells, self.cells, ffi.sizeof(self.cells))

	return copy
end


return {
	new = new_layer
}

