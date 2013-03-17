

local tiles, spawns

local levels = {
	{
		rooms = ([[30*splash-50;30*splash-30]]),
		floors = ("redfloor redfloor brownfloor grayfloor brownfloor"):split" ",
		walls = ("redwall redwall brownwall graywall brownfloor"):split " ",
		hordes = {
			"ape ape ape ape ape",
		}
	},
	{
		rooms = ([[30*splash-50;30*splash-30]]),
		floors = ("redfloor redfloor brownfloor grayfloor grayfloor brownfloor"):split" ",
		walls = ("redwall redwall brownwall graywall graywall brownfloor"):split " ",
		hordes = {
			"ape ape ape ape ape",
		}
	},
}

local hordes = {
	"squid squid squid",
	"eel eel eel"
}

-- blocking:
-- 1  blocks everything, but only from entering
-- 2  blocks everything and forbids squeezing

local raw_tiles = {
	void = {
		glyph = "?!", fg = 0, bg = 5, -- black on magenta, ew
		-- glyph = "#", fg = 1, bg = 7,
		transparency = 0.0, blocking = 1,
		complaint = "The unforgiving cold of Titan waits beyond."
	},

	[ [[stairs-up]] ] = {
		glyph = "<", fg = 0, bg = 3, blocking = 1, transparency = 0.0,
		complaint = "The stairs back up are blocked."
	},

	[ [[stairs-down]] ] = {
		glyph = ">", fg = 11, bg = 5, blocking = 1, transparency = 0.0,
		interact = "down"
	},


	water = {
		glyph = "~", fg = 12, bg = 4, blocking = 0,
		transparency = 1.0
	},

	redfloor = {
		glyph = ".", fg = 0, bg = 1,
		transparency = 1.0,
		complaint = "The ground crunches."
	},
	brownfloor = {
		glyph = ".", fg = 3, bg = 3,
		transparency = 1.0
	},
	grayfloor = {
		glyph = ".", fg = 8, bg = 7,
		transparency = 1.0
	},

	redwall = {
		glyph = "#", fg = 1, bg = 0, blocking = 2,
		transparency = 0.0, 
		complaint = "The stone is rough and warm to the touch."
	},
	brownwall = {
		glyph = "#", fg = 3, bg = 0, blocking = 2,
		transparency = 0.0,
		complaint = "The stone is slick and soapy."
	},
	graywall = {
		glyph = "#", fg = 7, bg = 0, blocking = 2,
		transparency = 0.0,
		complaint = "The stone is cool and unyielding."
	},

	-- need cryovolcanoes!


	bushes = {
		glyph = "\"", fg = 2, bg = 0,
		transparency = 0.0
	},

	handle = {
		glyph = "!", fg = 1, bg = 7, blocking = 2, interact = "push",
		transparency = 0.0
	},

	-- item tiles
	weapon = {
		glyph = "(", fg = 11, bg = nil,
		transparency = 1.0, blocking = 0,
	},
	tank = {
		glyph = "!", fg = 11, bg = nil,
		transparency = 1.0, blocking = 0,
	}
}

local pattern = {
	-- referenced in the spawns, but not indexed or cloned
	bump = {
		bump = true
	},
	scythe = {
		scythe = true
	},
	lance = {
		lance = true
	},
	lunge = {
		lunge = true
	},
	checkers = {
		checkers = true
	},
	backthrow = {
		backthrow = true
	}
}

local raw_spawns = {
	rogue = {
		name = "you", tile = {
			glyph = "@", fg = 15,
			transparency = 1.0, blocking = 1,
		},

		must_stand = true, ai = "you",
		health = 12, bagslots = 17
	},
	
	ape = {
		name = "nine-eyed macauque", tile = {
			glyph = "m", fg = 10,
			transparency = 1.0, blocking = 1
		},
		noises = [[eeeee,oo oo oo,SCRAW]],
		attack_pattern = pattern.bump,
		must_stand = true, ai = "ape",
		health = 3
	},

	squid = {
		name = "squid", tile = {
			glyph = "s", fg = 15,
			transparency = 1.0, blocking = 1
		},
		noises = [[blub]],
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
		health = 3
	},
	
	titan = {
		name = "bearded titan", tile = {
			glyph = "T", fg = 11, 
			transparency = 1.0, blocking = 2
		},

		noises = [[groan]],

		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 4
	},

	olympian = {
		name = "olympian", tile = {
			glyph = "O", fg = 11, 
			transparency = 1.0, blocking = 2
		},

		noises = [[groan]],

		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 4
	},

	horror = {
		name = "ionian horror", tile = {
			glyph = "I", fg = 1,
			transparency = 1.0, blocking = 2
		},
		
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
		health = 16
	},

	prelate = {
		name = "mimantean prelate", tile = {
			glyph = "M", fg = 1,
			transparency = 1.0, blocking = 2
		},
		
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
		health = 16
	},

	borer = {
		name = "callistonian borer", tile = {
			glyph = "C", fg = 7,
			transparency = 0.0, blocking = 2
		},

		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 16
	},

	priest = {
		name = "high priest of Huygens", tile = {
			glyph = "p", fg = 15,
			transparency = 1.0, blocking = 1
		},
		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 16
	},
}




local raw_items = {
	air = {
		name = "tank of air", tile = "tank", slot = "quaff",
		must_stand = true
	},
	petn = {
		name = "stick of PETN", tile = "tank", slot = "quaff",
		must_stand = true
	},

	chisel = {
		name = "chisel", tile = "weapon", slot = "wield",
		attack_pattern = pattern.scythe,
		must_stand = true
	},

	scythe = {
		name = "scythe", tile = "weapon", slot = "wield",
		attack_pattern = pattern.scythe,
		must_stand = true
	},

	lance = {
		name = "lance", tile = "weapon", slot = "wield",
		attack_pattern = pattern.lance,
		must_stand = true
	},

	rapier = {
		name = "rapier", tile = "weapon", slot = "wield",
		attack_pattern = pattern.lunge,
		must_stand = true
	},
	
	holowhip = {
		name = "holowhip", tile = "weapon", slot = "wield",
		attack_pattern = pattern.checkers,
		description = [[
		]],
		must_stand = true
	},
	
	cleaver = {
		name = "cleaver", tile = "weapon", slot = "wield",
		attack_pattern = pattern.backthrow,
		must_stand = true
	}
}

local function index_tiles()
	local tiles = { }
	local next_idx = 1
	for tag, tile in pairs(raw_tiles) do
		-- add an integer index to every tile, and mark the tile's tag
		tile.idx = next_idx
		tile.tag = tag

		tiles[tile] = tile
		tiles[next_idx] = tile
		tiles[tag] = tile

		tile.blocking = tile.blocking or 0

		next_idx = 1 + next_idx
	end
	-- move void to 0
	tiles.void.idx = 0
	tiles[0] = tiles.void
	return tiles
end

local function index_spawns(raw_spawns)
	local spawns = {}
	for tag, spawn in pairs(raw_spawns) do
		local tile = spawn.tile
		if type(spawn.tile) == "string" then
			tile = tiles[spawn.tile]
		else
			tile.idx = 1 + #tiles
			tile.tag = tag .. ".tile"
			tile.blocking = tile.blocking or 0

			tiles[tile] = tile
			tiles[tile.idx] = tile
			tiles[tile.tag] = tile
		end

		spawn.tile_idx = tile.idx
		spawn.tile = tiles[tile.idx]

		if type(spawn.noises) == "string" then
			spawn.noises = spawn.noises:split ","
		end

		spawns[tag] = spawn
		spawns[spawn.name] = spawn
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
spawns = index_spawns(raw_spawns)
items = index_spawns(raw_items)

return {
	levels = levels,

	tiles = tiles,
	spawns = spawns,
	items = items,

	idx = idx,
	tile = tile
}

