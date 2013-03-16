

local tiles, spawns

local raw_tiles = {
	void = {
		glyph = "?!", fg = 0, bg = 5, -- black on magenta, ew
		-- glyph = "#", fg = 1, bg = 7,
		transparency = 0.0, blocking = true
	},

	water = {
		glyph = "~", fg = 12, bg = 4, blocking = true,
		transparency = 1.0
	},
	floor = {
		glyph = ".", fg = 7, bg = 0,
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

	weapon = {
		glyph = "(", fg = 11, bg = nil,
		transparency = 1.0, blocking = false,
	}
}

local raw_spawns = {
	rogue = {
		name = "you", tile = {
			glyph = "@", fg = 15,
			transparency = 1.0, blocking = true,
		},

		must_stand = true, ai = "you",
		health = 6, bagslots = 17
	},

	titan = {
		name = "titan", tile = {
			glyph = "T", fg = 11, 
			transparency = 1.0, blocking = true,
		},

		must_stand = true, ai = "troll",
		health = 2
	},

	scythe = {
		name = "scythe", tile = "weapon", slot = "wield",
		attack_pattern = {
			scythe = true
		},
		must_stand = true, item = true
	},

	lance = {
		name = "lance", tile = "weapon", slot = "wield",
		attack_pattern = {
			lance = true
		},
		must_stand = true, item = true
	},

	rapier = {
		name = "rapier", tile = "weapon", slot = "wield",
		attack_pattern = {
			lunge = true
		},
		must_stand = true, item = true
	},
	
	holowhip = {
		name = "holowhip", tile = "weapon", slot = "wield",
		attack_pattern = {
			lunge = true
		},
		description = [[
		]],
		must_stand = true, item = true
	},
	
	cleaver = {
		name = "cleaver", tile = "weapon", slot = "wield",
		attack_pattern = {
			backthrow = true
		},
		must_stand = true, item = true
	}
}

local function index_tiles()
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

local function index_spawns()
	local spawns = {}
	for tag, spawn in pairs(raw_spawns) do
		local tile = spawn.tile
		if type(spawn.tile) == "string" then
			tile = tiles[spawn.tile]
		else
			tile.idx = 1 + #tiles
			tile.tag = tag .. ".tile"

			tiles[tile.idx] = tile
			tiles[tile.tag] = tile
		end

		spawn.tile_idx = tile.idx
		spawn.tile = tiles[tile.idx]

		spawns[tag] = spawn
	end
	return spawns
end

local function idx(self, name)
	-- note that name can be a number -- so the idx function works on names and numbers alike
	return (self.tiles[name] or self.tiles[0]).idx
end

local function tile(self, name)
	return (self.tiles[name] or self.tiles[0])
end

tiles = index_tiles()
spawns = index_spawns()

return {
	tiles = tiles,
	spawns = spawns,
	idx = idx,
	tile = tile
}

