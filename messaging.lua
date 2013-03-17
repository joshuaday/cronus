local Messaging = { }

local log = { }

function Messaging:announce(msg)
	log[1 + #log] = msg

	msg.ttl = type(msg.ttl) == "number" and msg.ttl or 2000
	msg.x = msg.x or 0
	msg.y = msg.y or 0
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
				table.remove(log, i)
				i = i - 1
			end
		end
		i = i + 1
	end
end

function Messaging:draw(term)
	local ttl = 10000
	term.mask(true)
	for i = 1, #log do
		local x, y = log[i].x, log[i].y

		term.fg(log[i].fg).bg(log[i].bg)

		repeat
			local _, ok = term.at(x, y).print(log[i][1])
			y = y + 1
		until ok

		log[i].drawn = true -- mark it so we know to start counting time
		ttl = math.min(ttl, log[i].ttl)
	end
	term.mask(false)

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

