

local tiles, spawns

local levels = {
	{
	}
}

local hordes = {
	"ape ape ape ape ape",
	"squid squid squid",
	"eel eel eel"
}

local raw_tiles = {
	void = {
		glyph = "?!", fg = 0, bg = 5, -- black on magenta, ew
		-- glyph = "#", fg = 1, bg = 7,
		transparency = 0.0, blocking = true,
		complaint = "The unforgiving cold of Titan waits beyond."
	},

	[ [[stairs-up]] ] = {
		glyph = "<", fg = 0, bg = 3, blocking = true, transparency = 0.0,
		complaint = "The stairs back up are blocked."
	},

	[ [[stairs-down]] ] = {
		glyph = ">", fg = 11, bg = 5, blocking = true, transparency = 0.0,
		interact = "down"
	},


	water = {
		glyph = "~", fg = 12, bg = 4, blocking = false,
		transparency = 1.0
	},

	floor = {
		glyph = " ", fg = 7, bg = 1,
		transparency = 1.0,
		complaint = "The ground crunches."
	},
	floor2 = {
		glyph = " ", fg = 1, bg = 3,
		transparency = 1.0
	},
	floor3 = {
		glyph = " ", fg = 0, bg = 7,
		transparency = 1.0
	},

	wall = {
		glyph = "#", fg = 1, bg = 0, blocking = true,
		transparency = 0.0, 
		complaint = "The stone is rough and warm to the touch."
	},
	wall2 = {
		glyph = "#", fg = 3, bg = 0, blocking = true,
		transparency = 0.0,
		complaint = "The stone is slick and soapy."
	},
	wall3 = {
		glyph = "#", fg = 7, bg = 0, blocking = true,
		transparency = 0.0,
		complaint = "The stone is cool and unyielding."
	},




	-- need cryovolcanoes!


	bushes = {
		glyph = "\"", fg = 2, bg = 0,
		transparency = 0.0
	},

	handle = {
		glyph = "!", fg = 1, bg = 7, blocking = true, interact = "push",
		transparency = 0.0
	},

	-- item tiles
	weapon = {
		glyph = "(", fg = 11, bg = nil,
		transparency = 1.0, blocking = false,
	},
	tank = {
		glyph = "!", fg = 11, bg = nil,
		transparency = 1.0, blocking = false,
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
			transparency = 1.0, blocking = true,
		},

		must_stand = true, ai = "you",
		health = 12, bagslots = 17
	},
	
	ape = {
		name = "nine-eyed macuaque", tile = {
			glyph = "m", fg = 10,
			transparency = 1.0, blocking = true
		},
		noises = [[eeeee,oo oo,SCRAW]],
		attack_pattern = pattern.bump,
		must_stand = true, ai = "ape",
		health = 3
	},

	squid = {
		name = "squid", tile = {
			glyph = "s", fg = 15,
			transparency = 1.0, blocking = true
		},
		noises = [[blub]],
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
		health = 3
	},
	
	titan = {
		name = "bearded titan", tile = {
			glyph = "T", fg = 11, 
			transparency = 1.0, blocking = true
		},

		noises = [[groan]],

		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 4
	},

	olympian = {
		name = "olympian", tile = {
			glyph = "O", fg = 11, 
			transparency = 1.0, blocking = true
		},

		noises = [[groan]],

		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 4
	},

	horror = {
		name = "ionian horror", tile = {
			glyph = "I", fg = 1,
			transparency = 1.0, blocking = true
		},
		
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
		health = 16
	},

	prelate = {
		name = "mimantean prelate", tile = {
			glyph = "M", fg = 1,
			transparency = 1.0, blocking = true
		},
		
		attack_pattern = pattern.bump,
		must_stand = true, ai = "eel",
		health = 16
	},

	borer = {
		name = "callistonian borer", tile = {
			glyph = "C", fg = 7,
			transparency = 0.0, blocking = true
		},

		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 16
	},

	priest = {
		name = "high priest of Huygens", tile = {
			glyph = "p", fg = 15,
			transparency = 1.0, blocking = false
		},
		attack_pattern = pattern.bump,
		must_stand = true, ai = "troll",
		health = 16
	},




	air = {
		name = "tank of air", tile = "tank", slot = "quaff",
		must_stand = true, item = true
	},
	petn = {
		name = "stick of PETN", tile = "tank", slot = "quaff",
		must_stand = true, item = true
	},

	chisel = {
		name = "chisel", tile = "weapon", slot = "wield",
		attack_pattern = pattern.scythe,
		must_stand = true, item = true
	},

	scythe = {
		name = "scythe", tile = "weapon", slot = "wield",
		attack_pattern = pattern.scythe,
		must_stand = true, item = true
	},

	lance = {
		name = "lance", tile = "weapon", slot = "wield",
		attack_pattern = pattern.lance,
		must_stand = true, item = true
	},

	rapier = {
		name = "rapier", tile = "weapon", slot = "wield",
		attack_pattern = pattern.lunge,
		must_stand = true, item = true
	},
	
	holowhip = {
		name = "holowhip", tile = "weapon", slot = "wield",
		attack_pattern = pattern.checkers,
		description = [[
		]],
		must_stand = true, item = true
	},
	
	cleaver = {
		name = "cleaver", tile = "weapon", slot = "wield",
		attack_pattern = pattern.backthrow,
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

		tiles[tile] = tile
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
spawns = index_spawns()

return {
	tiles = tiles,
	spawns = spawns,
	idx = idx,
	tile = tile
}

