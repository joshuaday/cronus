

local raw_tiles = {
	water = {
		glyph = "~", fg = 12, bg = 4, blocking = true,
		transparency = 1.0
	},
	floor = {
		glyph = ".", fg = 7, bg = 1,
		transparency = 1.0
	},
	wall = {
		glyph = "#", fg = 1, bg = 7, blocking = true,
		transparency = 0.0
	},

	handle = {
		glyph = "!", fg = 1, bg = 7, blocking = true, pushing = true,
		transparency = 0.0
	},

	void = {
		glyph = "?!", fg = 0, bg = 5, -- black on magenta, ew
		-- glyph = "#", fg = 1, bg = 7,
		transparency = 0.0, blocking = true
	},

	rogue = {
		glyph = "@", fg = 15, bg = nil,
		transparency = 1.0, blocking = true,

		must_stand = true, ai = "you",
		health = 6
	},

	titan = {
		glyph = "T", fg = 11, bg = nil,
		transparency = 1.0, blocking = true,

		must_stand = true, ai = "troll",
		health = 2
	}
}


local function indexed_tiles()
	local tiles = { }
	local next_idx = 1
	for tag, tile in pairs(raw_tiles) do
		-- add an integer index to every tile, and mark the tile's tag
		tile.idx = next_idx
		tile.tag = tag
		tiles[next_idx] = tile
		tiles[tag] = tile

		next_idx = 1 + next_idx
	end
	-- move void to 0
	tiles.void.idx = 0
	tiles[0] = tiles.void
	return tiles
end

local function idx(self, name)
	-- note that name can be a number -- so the idx function works on names and numbers alike
	return (self.tiles[name] or self.tiles[0]).idx
end

local function tile(self, name)
	return (self.tiles[name] or self.tiles[0])
end


return {
	tiles = indexed_tiles(),
	idx = idx,
	tile = tile
}

