local English = require "english"
local Menu = { }

-- this "dry run" idea isn't a bad one, but I think I'd rather do proper
-- panels when I have the chance

local ok_cancel = { {"o", "Ok"}, {"c", "Cancel"} }

function Menu:dialog(term, prompt, options)
	local termw, termh = term.width, term.height

	options = options or ok_cancel
	
	term = term:clip(0, 0, 80, 24)

	local minx, miny, maxx, maxy = term:dryrun(false)
	term:clip(7, 1, maxx + 7, maxy + 5):bg(4):fill()
	term:clip(8, 2, maxx + 5, maxy + 3):bg(0):fill()
	x1, y1 = 2, 1
	
	term:at(40, 0):center(prompt)
	term:at(40, 1)
	for i = 1, #options do
		term:print(options[i][2]):skip(3)
	end

	term.root:flush()
	return term.root:getch()
end


local inventory_prompts = {
	e = "Equip what?",
	d = "Drop what?",
	a = "Apply what?",
	r = "Remove what?",
	T = "Attach to what?"
}

function Menu:inventory(term, bag, action, player_x)
	local panel = term.root:panel_from_cursor(term)
	panel:fg(0):bg(0):fill()


	term = panel:clip(2, 1, -4, -2)

	local function callback (action)
		return self:inventory(term, bag, action, player_x)
	end

	local y, x = 0, 0 

	if inventory_prompts[action] then
		term:at(x, y):fg(15):bg(0):print(inventory_prompts[action])
		y = y + 2
	end

	local nitems = 0
	for i = 1, bag.slots do
		local item = bag[i]
		if item then
			term
				:link(i)
				:at(x, y):fg(11):bg(1)
				:put(string.byte ' '):put(i - 1 + string.byte 'a'):put(string.byte ' ')
				:bg(0)
				:put(string.byte ' ')
				:fg(item.tile.fg or 15):bg(item.tile.bg or 0)
				:put(string.byte (item.tile.glyph)):put(string.byte ' ')
				:fg(15)
				:print(English.a(item.name))
			if item.equipped then
				term:print(" (equipped)")
			end
			y = y + 1
			nitems = nitems + 1
		end
	end

	term:link()
	if nitems == 0 then
		term:at(x, y):fg(11):bg(0):print("Your inventory is empty.")
		y = y + 1
	end

	term:at(x, y + 1):fg(15):bg(0)
	if bag.slots == nitems then
		term:print("Your pack is full.")
	else
		term:print("You have room for " .. (bag.slots - nitems) .. " more items.")
	end

	local x1, y1, w, h = term.panel:get_printable_bounds()
	term.panel:resize(w + 4, h + 2)

	term.panel.x1 = math.floor((player_x > 50 and .25 or .75) * (80 - w))
	term.panel.y1 = math.floor(.125 * (24 - h))

	term.root:flush()

	
	if action ~= "i" then
		repeat
			local key = term.root:getch()
			local idx = 1 + string.byte(key) - string.byte('a')
			
			if idx >= 1 and idx <= bag.slots and bag[idx] ~= nil then
				return idx, action, bag[idx], callback
			end
		until key == " "
	else
		term.root:getch()
	end
end


return Menu

