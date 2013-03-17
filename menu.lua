local Menu = { }

-- this "dry run" idea isn't a bad one, but I think I'd rather do proper
-- panels when I have the chance

local ok_cancel = { {"o", "Ok"}, {"c", "Cancel"} }

function Menu:dialog(term, prompt, options)
	local termw, termh = term.getsize()

	options = options or ok_cancel
	
	for rep = 1, 2 do
		if rep == 1 then
			term.dryrun(true)
			x1, y1 = 0, 0
		else
			local minx, miny, maxx, maxy = term.dryrun(false)
			term.clip(7, 1, maxx + 7, maxy + 5).bg(4).fill()
			term.clip(8, 2, maxx + 5, maxy + 3).bg(0).fill()
			x1, y1 = 2, 1
		end
		
		term.at(40, 0).center(prompt)
		term.at(40, 1)
		for i = 1, #options do
			term.print(options[i][2]).skip(3)
		end
	end

	term.flush()
	return term.getch()
end


local inventory_prompts = {
	e = "Equip what?",
	d = "Drop what?",
	a = "Apply what?",
	r = "Remove what?"
}

function Menu:inventory(term, bag, action)
	local y1, x1 = 1, 20

	for rep = 1, 2 do
		if rep == 1 then
			term.dryrun(true)
			x1, y1 = 0, 0
		else
			local minx, miny, maxx, maxy = term.dryrun(false)
			term.clip(7, 1, maxx + 7, maxy + 5).bg(4).fill()
			term.clip(8, 2, maxx + 5, maxy + 3).bg(0).fill()
			x1, y1 = 2, 1
		end

		local y, x = y1, x1

		if inventory_prompts[action] then
			term.at(x, y).fg(15).bg(0).print(inventory_prompts[action])
			y = y + 2
		end

		local nitems = 0
		for i = 1, bag.slots do
			local item = bag[i]
			if item then
				term
					.link(i)
					.at(x, y).fg(11).bg(1)
					.put(string.byte ' ').put(i - 1 + string.byte 'a').put(string.byte ' ')
					.bg(0)
					.put(string.byte ' ')
					.fg(item.tile.fg or 15).bg(item.tile.bg or 0)
					.put(string.byte (item.tile.glyph)).put(string.byte ' ')
					.fg(15)
					.print("a ").print(item.name)
				y = y + 1
				nitems = nitems + 1
			end
		end

		term.link()
		if nitems == 0 then
			term.at(x, y).fg(11).bg(0).print("Your inventory is empty.")
			y = y + 1
		end

		term.at(x, y + 1).fg(15).bg(0)
		if bag.slots == nitems then
			term.print("Your pack is full.")
		else
			term.print("You have room for " .. (bag.slots - nitems) .. " more items.")
		end
	end

	term.flush()
	
	if action ~= "i" then
		repeat
			local key = term.getch()
			local idx = 1 + string.byte(key) - string.byte('a')
			
			if idx >= 1 and idx <= bag.slots and bag[idx] ~= nil then
				return idx, action
			end
		until key == " "
	else
		term.getch()
	end
end


return Menu

