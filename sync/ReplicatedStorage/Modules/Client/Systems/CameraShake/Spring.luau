local Spring = {}

function Spring.new(Initial)
	local t0 = os.clock()
	local p0 = Initial or 0
	local v0 = Initial and 0*Initial or 0
	local t  = Initial or 0
	local d  = 1
	local s  = 1

	local function positionVelocity(Tick)
		local x  = Tick - t0
		local c0 = p0 - t
		if s <= 1e-6 then
			return p0, 0
		elseif d < 1 then
			local wd = s * math.sqrt(1 - d^2)
			local ex = math.exp(-d * s * x)
			local c1 = (v0 + d*s*c0) / wd
			local cs = math.cos(wd * x)
			local sn = math.sin(wd * x)
			local p  = t + ex * (c0*cs + c1*sn)
			local v  = ex * ((v0 + d*s*c0)*cs - (d*s*c1 + wd*c0)*sn) - d*s*(p - t)
			return p, v
		elseif d == 1 then
			local ex = math.exp(-s * x)
			local c1 = v0 + s*c0
			return t + ex*(c0 + c1*x), ex*(c1 - s*(c0 + c1*x))
		else
			local sq = math.sqrt(d^2 - 1)
			local r1 = s*(-d + sq)
			local r2 = s*(-d - sq)
			local c2 = (v0 - r1*c0) / (r2 - r1)
			local c1 = c0 - c2
			local e1 = math.exp(r1 * x)
			local e2 = math.exp(r2 * x)
			return t + c1*e1 + c2*e2, c1*r1*e1 + c2*r2*e2
		end
	end

	return setmetatable(
		{
			accelerate = function(_, acceleration)
				local T = os.clock()
				local p, v = positionVelocity(T)
				p0, v0, t0 = p, v + acceleration, T
			end;
			impulse = function(_, force)
				local T = os.clock()
				local p, v = positionVelocity(T)
				p0, v0, t0 = p, v + force/math.max(s, 1e-6), T
			end;
		},
		{
			__index = function(_, index)
				if index == "value" or index == "position" or index == "p" then
					local p = positionVelocity(os.clock())
					return p
				elseif index == "velocity" or index == "v" then
					local _, v = positionVelocity(os.clock())
					return v
				elseif index == "acceleration" or index == "a" then
					local p, v = positionVelocity(os.clock())
					local disp = p - t
					return -s^2 * disp - 2*d*s*v
				elseif index == "target" or index == "t" then
					return t
				elseif index == "damper" or index == "d" then
					return d
				elseif index == "speed" or index == "s" then
					return s
				elseif index == "magnitude" or index == "m" then
					local p = positionVelocity(os.clock())
					return type(p) == "number" and math.abs(p) or (type(p) == "vector" and vector.magnitude(p :: any) or typeof(p) == "Vector2" and p.Magnitude)
				elseif index == "settling" then
					if s <= 0 then return math.huge end
					local threshold = -math.log(0.001)
					if d >= 1 then
						local sq = math.sqrt(math.max(d^2 - 1, 0))
						return threshold / math.max(s*(d - sq), 1e-9)
					end
					return threshold / (d * s)
				else
					error(index.." is not a valid member of spring", 0)
				end
			end;

			__newindex = function(_, index, value)
				local T = os.clock()
				if index == "value" or index == "position" or index == "p" then
					local _,v = positionVelocity(T)
					p0, v0 = value, v
				elseif index == "velocity" or index == "v" then
					local p = positionVelocity(T)
					p0, v0 = p, value
				elseif index == "acceleration" or index == "a" then
					local p, v = positionVelocity(T)
					p0, v0 = p, v + value
				elseif index == "target" or index == "t" then
					p0, v0 = positionVelocity(T)
					t = value
				elseif index == "damper" or index == "d" then
					p0, v0 = positionVelocity(T)
					d = value < 0 and 0 or value < 1 and value or 1
				elseif index == "speed" or index == "s" then
					p0, v0 = positionVelocity(T)
					s = value < 0 and 0 or value
				else
					error(index.." is not a valid member of spring", 0)
				end
				t0 = T
			end;
		}
	)
end

return Spring