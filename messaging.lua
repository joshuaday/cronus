local Messaging = { }

local log = { }

function Messaging:announce(msg)
	if msg == nil or msg[1] == nil then
		return
	end

	log[1 + #log] = msg

	msg.ttl = type(msg.ttl) == "number" and msg.ttl or 2000
	msg.x = msg.x or 1
	msg.y = msg.y or 1
	msg.fg = msg.fg or 15
	msg.bg = msg.bg or 0
end

function Messaging:time_spent(ms)
	local i = 1
	
	while i <= #log do
		if log[i].drawn then
			-- this condition seems weird, but consider how much time can be spent blocking
			-- for input when there is no message; the previous call to interaciveinput might
			-- well have caused a new message to be generated, which will be cleared (accidentally!)
			-- by this call

			log[i].ttl = log[i].ttl - ms
			if log[i].ttl <= 0 then
				if log[i].cb then
					log[i]:cb()
				end
				table.remove(log, i)
				i = i - 1
			end
		end
		i = i + 1
	end
end

function Messaging:draw(term)
	local ttl = 10000
	local w, h = term.width, term.height

	term:mask(true)
	for i = 1, #log do
		local msg = log[i]
		local x, y = msg.x, msg.y
		
		if x + #msg[1] >= w then
			x = w - #msg[1]
		end

		if y < 0 then y = 1 end
		if x < 0 then x = 0 end

		term:fg(msg.fg):bg(msg.bg)

		repeat
			local _, ok = term:at(x, y):print(msg[1])
			y = y + 1
		until ok or y > h

		msg.drawn = true -- mark it so we know to start counting time
		ttl = math.min(ttl, msg.ttl)
	end
	term:mask(false)

	if #log > 0 then
		return ttl
	else
		return nil
	end
end

function Messaging:input()
	for i = 1, #log do
		if log[i].turn and log[i].drawn then
			log[i].ttl = 0
		end
	end
end

function Messaging:confirm()
	log = { }
end

return Messaging

