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

function Menu:get_string(term, validate)
	local panel = term.root:panel_from_cursor(term)

	-- isnonpunct is used for ctrl-left / ctrl-right
	local function isnonpunct(ch)
		return (ch >= 48 and ch <= 58) or (ch >= 65 and ch <= 90) or (ch >= 96 and ch <= 121)
	end
	
	term.root:flush()
	
	local str, cursor, cursor_end = "", 1, 1
	local valid, beep

	while true do
		valid = validate(str)

		term:bg(beep and 4 or 0):fg(15):fill():at(0, 0):print(str)
		for i = cursor, cursor_end do
			term:at(i - 1, 0):bg(valid and 4 or 1):put(str:byte(i) or 32)
		end
		term:bg(0)
		
		local key, code = term:getch(beep and false or 120)

		beep = false

		if key == nil then
		elseif key == "escape" then
			return nil
		elseif key == "enter" then
			if valid then
				return str
			else
				beep = true
			end
		elseif key == "backspace" then
			if cursor < 2 then cursor = 2 end
			str = str:sub(1, cursor - 2) .. str:sub(cursor_end)
			cursor = cursor - 1
			cursor_end = cursor
		elseif key == "dc" then
			str = str:sub(1, cursor - 1) .. str:sub(cursor_end + 1)
			cursor_end = cursor
		elseif key == "left" then
			cursor = cursor - 1
			cursor_end = cursor
		elseif key == "right" then
			cursor_end = cursor_end + 1
			cursor = cursor_end
		elseif key == "sleft" then
			cursor = cursor - 1
		elseif key == "sright" then
			cursor_end = cursor_end + 1
		elseif key == "cleft" or key == "csleft" or key == "key 23" then
			-- go one word left; one word is one chunk of whitespace and then
			-- one alphanumeric sequence OR one non-alphanumeric sequence
			while cursor > 1 and (cursor >= #str or str:byte(cursor) <= 32) do
				cursor = cursor - 1
			end
			
			if cursor > 1 then
				local punct = isnonpunct(str:byte(cursor))
				
				while cursor > 1 and str:byte(cursor) > 32 and punct == isnonpunct(str:byte(cursor)) do
					cursor = cursor - 1
				end
			end
			if key == "cleft" then
				cursor_end = cursor
			end
			if key == "key 23" then
				-- ^W
				str = str:sub(1, cursor - 1) .. str:sub(cursor_end)
				cursor_end = cursor
			end
		elseif key == "cright" or key == "csright" then
			-- go one word right; one word is one chunk of whitespace and then
			-- one alphanumeric sequence OR one non-alphanumeric sequence
			while cursor_end <= #str and str:byte(cursor_end) <= 32 do
				cursor_end = cursor_end + 1
			end
			
			if cursor <= #str then
				local punct = isnonpunct(str:byte(cursor_end))
				
				while cursor_end <= #str and str:byte(cursor_end) > 32 and punct == isnonpunct(str:byte(cursor_end)) do
					cursor_end = cursor_end + 1
				end
			end
			if key == "cright" then
				cursor = cursor_end
			end
		elseif key == "home" or key == "up" or key == "sr" then
			cursor = 1
			if key ~= "sr" then
				cursor_end = cursor
			end
		elseif key == "end" or key == "down" or key == "sf" then
			cursor_end = 1 + #str
			if key ~= "sf" then
				cursor = cursor_end
			end
		elseif key == "mouse" then
			local x = code.x + 1
			if code.y == 0 and code.left.justPressed then
				if code.ctrl or code.shift then
					if x <= cursor then cursor = x
					elseif x >= cursor_end then cursor_end = x
					end
				else
					cursor = x
					cursor_end = cursor
				end
			end
			if code.left.justReleased then
				cursor_end = x
			end
		else
			str = str:sub(1, cursor - 1) .. key .. str:sub(cursor_end)
			cursor = cursor + #key
			cursor_end = cursor
		end

		if cursor > 1 + #str then cursor = 1 + #str end
		if cursor < 1 then cursor = 1 end
		if cursor_end > 1 + #str then cursor_end = 1 + #str end
		if cursor_end < 1 then cursor_end = 1 end
		if cursor > cursor_end then cursor, cursor_end = cursor_end, cursor end
	end

	return str
end

function Menu:number(term, prompt, top)
	local panel = term.root:panel_from_cursor(term)

	panel = panel:fg(0):bg(0):fill():bg(1):border()
	

	term.root:flush()
	
	term.root:getch()

	if action ~= "i" then
		repeat
			local key, code = term:getch()
			local idx = 1 + string.byte(key) - string.byte('a')

			if key == "mouse" then
				term:at(0, 0):print(tostring(code.link).. "     ")
				if code.left.justPressed then
					idx = code.link
				end
			end
			
			if idx >= 1 and idx <= bag.slots and bag[idx] ~= nil then
				return idx, action, bag[idx], callback
			end
		until key == " "
	else
	end
end

local inventory_prompts = {
	e = "Equip what?",
	d = "Drop what?",
	a = "Apply what?",
	r = "Remove what?",

	T = "Attach to which explosive?",
	T2 = "Attach which detonator?"
}

function Menu:inventory(topterm, bag, action, player_x)
	local panel = topterm.root:panel_from_cursor(topterm)
	panel:fg(0):bg(0):fill()

	local term = panel:clip(2, 1, -4, -2)

	local function callback (action)
		-- todo : this is part of a hack in cronus-main
		return self:inventory(topterm, bag, action, player_x)
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
			local key, code = term:getch()
			local idx = 1 + string.byte(key) - string.byte('a')

			if key == "mouse" then
				term:at(0, 0):print(tostring(code.link).. "     ")
				if code.left.justPressed then
					idx = code.link
				end
			end
			
			if idx >= 1 and idx <= bag.slots and bag[idx] ~= nil then
				return idx, action, bag[idx], callback
			end
		until key == " "
	else
		term.root:getch()
	end
end


return Menu

