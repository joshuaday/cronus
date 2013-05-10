local English = { }

local function prefix(nv, v, name)
	name = tostring(name)
	if name[1] == "'" then
		return nv .. name:sub(2)
	elseif name:match "^[aeiou]" then
		return v .. name
	else
		return nv .. name
	end
end

function English.a(name)
	return prefix("a ", "an ", name)
end

function English.A(name)
	return prefix("A ", "An ", name)
end

function English.the(name)
	return prefix("the ", "the ", name)
end

function English.The(name)
	return prefix("The ", "The ", name)
end

return English

