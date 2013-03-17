

local tiles, spawns

local levels = {
	{
		rooms = ([[30*splash-50;30*splash-30]]),
		floors = ("redfloor redfloor brownfloor grayfloor brownfloor"):split" ",
		walls = ("redwall redwall brownwall graywall brownfloor"):split " ",
		hordes = {
			"ape",
			"ape ape",
			"eel eel",
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

-- tile content flags:
-- 1   blocks everything, but only from entering
-- 2   blocks everything and forbids squeezing
-- 4   blocks non-watery
-- 8   blocks non-flying
-- 16  blocks non-firey

local raw_tiles = {
	void = {
		glyph = "?!", fg = 0, bg = 5, -- black on magenta, ew
		-- glyph = "#", fg = 1, bg = 7,
		transparency = 0.0, blocking = 1,
		complaint = "The unforgiving cold of Titan waits beyond."
	},

	[ [[stairs-up]] ] = {
		-- I want the stairs to block, but there are generation issues
		glyph = "<", fg = 0, bg = 3, blocking = 0, transparency = 0.0,
		complaint = "The stairs back up are blocked."
	},

	[ [[stairs-down]] ] = {
		glyph = ">", fg = 11, bg = 5, blocking = 0, transparency = 0.0,
		interact = "down"
	},

	water = {
		glyph = "~", fg = 12, bg = 4, blocking = 0,
		transparency = 1.0
	},
	ice = {
		glyph = "-", fg = 12, bg = 6, blocking = 0,
		transparency = 1.0, slick = true
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
	crystal = {
		glyph = "#", fg = 15, bg = 6, blocking = 2,
		transparency = 1.0,
		complaint = "Light refracts gloriously through the crystal's facets."
	},

	-- need cryovolcanoes!


	tree = {
		glyph = "&", fg = 2, bg = 0,
		transparency = 0.0, blocking = 1,
		complaint = "The growth feels pulpy and unpleasant."
	},

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
	},
	detonator = {
		glyph = "?", fg = 11, bg = nil,
		transparency = 1.0, blocking = 0
	},
	trinket = {
		glyph = "*", fg = 11, bg = nil,
		transparency = 1.0, blocking = 0
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
	pango = {
		name = "promethean pangolin", tile = {
			glyph = "m", fg = 12,
			transparency = 1.0, blocking = 1
		},
		noises = [[roo hrr]],
		attack_pattern = pattern.bump,
		must_stand = true, ai = "ape",
		health = 5
	},


	eel = {
		name = "dielectric eel", tile = {
			glyph = "e", fg = 15,
			transparency = 1.0, blocking = 1
		},
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
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

	spider = {
		name = "spider", tile = {
			glyph = "S", fg = 0,
			transparency = 1.0, blocking = 2
		},
		attack_pattern = pattern.bump,	
		must_stand = true, ai = "troll",
		health = 9
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

	
	siarnaqean = {
		name = "siarnaqean pohlsepid", tile = {
			glyph = "o", fg = 0,
			transparency = 1.0, blocking = 2
		},
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",	
		health = 6
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
	macguffin = {
		name = "Huygens S-band Radio", tile = "trinket", slot = "victory", SCORE = 0
	},
	air = {
		name = "tank of air", tile = "tank", slot = "quaff"
	},
	radio = {
		name = "remote detonator", tile = "detonator", slot = "quaff"
	},
	timer = {
		name = "timed detonator", tile = "detonator", slot = "quaff"
	},
	petn = {
		name = "stick of PETN", tile = "tank", slot = "quaff"
	},
	c4 = {
		name = "stick of C-4", tile = "tank", slot = "quaff"
	},
	incendiary = {
		name = "incendiary charge", tile = "tank", slot = "quaff"
	},

	chisel = {
		name = "chisel", tile = "weapon", slot = "wield",
		attack_pattern = pattern.scythe, SCORE = .2
	},

	scythe = {
		name = "scythe", tile = "weapon", slot = "wield",
		attack_pattern = pattern.scythe, SCORE = .2
	},

	lance = {
		name = "lance", tile = "weapon", slot = "wield",
		attack_pattern = pattern.lance, SCORE = .2
	},

	rapier = {
		name = "rapier", tile = "weapon", slot = "wield",
		attack_pattern = pattern.lunge, SCORE = .2
	},
	
	holowhip = {
		name = "holowhip", tile = "weapon", slot = "wield",
		attack_pattern = pattern.checkers,
		description = [[
		]], SCORE = .2
	},
	
	cleaver = {
		name = "cleaver", tile = "weapon", slot = "wield",
		attack_pattern = pattern.backthrow, SCORE = .2
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
	local SCORE = 0
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

		spawn.SCORE = spawn.SCORE or 1
		SCORE = SCORE + spawn.SCORE

		if type(spawn.noises) == "string" then
			spawn.noises = spawn.noises:split ","
		end

		spawns[tag] = spawn
		spawns[spawn.name] = spawn
	end

	spawns.SCORE = SCORE -- used for picking a random item to spawn
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

