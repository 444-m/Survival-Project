local Module = {}

do
	local TAU, PI = 2*math.pi, math.pi

	local function sortedKeys(map: {[number]: CFrame}): {number}
		local ks = {}
		for k in map do table.insert(ks, k) end
		table.sort(ks)
		return ks
	end

	local function hermite(p1, p2, m1, m2, u)
		local u2, u3 = u*u, u*u*u
		local h00 =  2*u3 - 3*u2 + 1
		local h10 =      u3 - 2*u2 + u
		local h01 = -2*u3 + 3*u2
		local h11 =      u3 -   u2
		return h00*p1 + h10*m1 + h01*p2 + h11*m2
	end

	local function unwrapAnglesZ(zs: {number}): {number}
		local out = table.create(#zs)
		if #zs == 0 then return out end
		out[1] = zs[1]
		for i = 2, #zs do
			local z = zs[i]
			-- bring z near previous
			local d = z - out[i-1]
			z = z - TAU * math.floor((d + PI)/TAU)
			out[i] = z
		end
		return out
	end

	-- Optional: tension in [0,1]. 0 = Catmull–Rom, 0.5 reduces overshoot.
	local function cubicInterpolateCFrameZ(offsets: {[number]: CFrame}, d: number, tension: number?): CFrame
		local keys = sortedKeys(offsets)
		local n = #keys
		if n == 0 then return CFrame.identity end
		if d <= keys[1] then
			local cf = offsets[keys[1]]
			local _,_,rz = cf.Rotation:ToOrientation()
			return CFrame.new(cf.Position) * CFrame.fromEulerAnglesXYZ(0,0,rz)
		end
		if d >= keys[n] then
			local cf = offsets[keys[n]]
			local _,_,rz = cf.Rotation:ToOrientation()
			return CFrame.new(cf.Position) * CFrame.fromEulerAnglesXYZ(0,0,rz)
		end

		-- build arrays once
		local P, Z = table.create(n), table.create(n)
		for i = 1, n do
			local cf = offsets[keys[i]]
			P[i] = cf.Position
			local _,_,rz = cf.Rotation:ToOrientation()
			Z[i] = rz
		end
		Z = unwrapAnglesZ(Z)

		-- find segment i so d ∈ [keys[i], keys[i+1]]
		local i = 1
		for k = 1, n-1 do
			if d >= keys[k] and d <= keys[k+1] then i = k break end
		end
		local k1, k2 = keys[i], keys[i+1]
		local u = (d - k1) / (k2 - k1)

		-- finite differences (slopes)
		local dt_im1_i = (i > 1) and (keys[i]   - keys[i-1]) or (keys[i+1] - keys[i])
		local dt_i_ip1 = (keys[i+1] - keys[i])
		local dt_ip1_ip2 = (i+2 <= n) and (keys[i+2] - keys[i+1]) or (keys[i+1] - keys[i])

		local s_im1 = (i > 1) and ((P[i]   - P[i-1]) / dt_im1_i) or ((P[i+1] - P[i]) / dt_i_ip1)
		local s_i   =             ((P[i+1] - P[i])     / dt_i_ip1)
		local s_ip1 = (i+2 <= n) and ((P[i+2] - P[i+1]) / dt_ip1_ip2) or s_i

		local tz = tension or 0.25 -- mild damping helps near endpoints
		local tscale = (1 - tz) * 0.5

		-- tangents for the segment, scaled to local dt
		local m1_pos = (tscale * (s_im1 + s_i))   * (k2 - k1)
		local m2_pos = (tscale * (s_i   + s_ip1)) * (k2 - k1)

		local pos = hermite(P[i], P[i+1], m1_pos, m2_pos, u)

		-- do same for Z (scalars)
		local s_im1_z = (i > 1) and ((Z[i]   - Z[i-1]) / dt_im1_i) or ((Z[i+1] - Z[i]) / dt_i_ip1)
		local s_i_z   =             ((Z[i+1] - Z[i])     / dt_i_ip1)
		local s_ip1_z = (i+2 <= n) and ((Z[i+2] - Z[i+1]) / dt_ip1_ip2) or s_i_z

		local m1_z = (tscale * (s_im1_z + s_i_z))   * (k2 - k1)
		local m2_z = (tscale * (s_i_z   + s_ip1_z)) * (k2 - k1)

		local rz_cont = hermite(Z[i], Z[i+1], m1_z, m2_z, u)
		-- fold back to principal range for constructing CFrame
		if rz_cont > PI then rz_cont -= TAU elseif rz_cont < -PI then rz_cont += TAU end

		return CFrame.new(pos) * CFrame.fromEulerAnglesXYZ(0,0,rz_cont)
	end

	function Module.getOffset(OffsetCamera, zoom: number): CFrame
		local data = OffsetCamera.settings

		local offset = cubicInterpolateCFrameZ(data.offsets, zoom, 0.5)

		local name = data.subjectName
		if name and data.mirrorOffsets then
			local rposition = offset.Position
			local rx, ry, rz = offset:ToEulerAnglesYXZ()
			offset = CFrame.fromEulerAnglesYXZ(0, 0, rz)

			local lposition = Vector3.new(-rposition.X, rposition.Y, rposition.Z)
			local lx, ly, lz = rx, -ry, -rz

			offset = CFrame.fromEulerAnglesYXZ(0, 0, lz) + lposition
		end

		return offset
	end
end

function Module.getSubjectRotationConvergence(OffsetCamera, zoom: number)
	local data = OffsetCamera.settings

	local convergence = 0

	if next(data.subjectRotationConvergence) then
		local convergences = {}
		for distance, convergenceAtDistance in data.subjectRotationConvergence do
			table.insert(convergences, {
				distance = distance,
				convergenceAtDistance = convergenceAtDistance
			})
		end
		table.sort(convergences, function(a, b)
			return a.distance < b.distance
		end)

		if zoom <= convergences[1].distance then
			convergence = convergences[1].convergenceAtDistance
		elseif convergences[#convergences].distance < zoom then
			convergence = convergences[#convergences].convergenceAtDistance
		else
			local minConvergence, maxConvergence
			for i = 1, #convergences - 1 do
				local minOffset, maxOffset = convergences[i], convergences[i + 1]
				if minOffset.distance < zoom and zoom <= maxOffset.distance then
					minConvergence, maxConvergence = minOffset, maxOffset
					break
				end
			end
			local percent = (zoom - minConvergence.distance) / (maxConvergence.distance - minConvergence.distance)
			convergence = math.lerp(minConvergence.convergenceAtDistance, maxConvergence.convergenceAtDistance, percent)
		end
	end

	return convergence
end


return Module
