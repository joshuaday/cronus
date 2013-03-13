local Messaging = { }

local log = { }

function Messaging:announce(msg)
	log[1 + #log] = msg

	msg.ttl = msg.ttl or 2000
end

function Messaging:time_spent(ms)
	local splice = 0
	for i = 1, #log do
		log[i].ttl = log[i].ttl - ms
		if log[i].ttl <= 0 then splice = i end
	end
	if splice > 0 then
		table.remove(log, 1)
	end
end

function Messaging:draw(term)
	for i = 1, #log do
		term.at(1, i).fg(15).bg(0).print(log[i][1])
	end

	if #log > 0 then
		return log[1].ttl
	else
		return nil
	end
end

function Messaging:confirm()
	log = { }
end

return Messaging

