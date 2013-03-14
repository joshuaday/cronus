local Messaging = { }

local log = { }

function Messaging:announce(msg)
	log[1 + #log] = msg

	msg.ttl = msg.ttl or 2000
	msg.x = msg.x or 0
	msg.y = msg.y or 0
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
	for i = 1, #log do
		term.at(1, i).fg(15).bg(0).print(log[i][1])
		log[i].drawn = true -- mark it so we know to start counting time
		ttl = math.min(ttl, log[i].ttl)
	end

	if #log > 0 then
		return ttl
	else
		return nil
	end
end

function Messaging:confirm()
	log = { }
end

return Messaging

