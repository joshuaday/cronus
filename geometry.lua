local Geometry = { }

function Geometry.bresenham(x1, y1, x2, y2)
	local Dx, Dy = x2 - x1, y2 - y1
	local xmag, ymag = math.abs(Dx), math.abs(Dy)
	local dx = Dx > 0 and 1 or -1
	local dy = Dy > 0 and 1 or -1
	
	local major, majorx, majory, minor

	if xmag > ymag then
		major, minor = xmag, ymag
		majorx, majory = dx, 0
	else
		major, minor = ymag, xmag
		
		majorx, majory = 0, dy
	end

	local steps_left, acc = 1 + major, math.floor(major * .5)
	
	return function()
		local x, y = x1, y1

		if steps_left == 0 then
			return nil
		end

		acc = acc + minor
		if acc >= major then
			acc = acc - major
			x1, y1 = x1 + dx, y1 + dy
		else
			x1, y1 = x1 + majorx, y1 + majory
		end

		steps_left = steps_left - 1
		
		return x, y
	end
end

return Geometry

