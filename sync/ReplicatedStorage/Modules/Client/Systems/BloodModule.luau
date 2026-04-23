local BloodModule = {}
BloodModule.__index = BloodModule

local RS = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local BlinkClient = Networking.Client
local debrisFolder = workspace:WaitForChild("objects"):WaitForChild("debris")

local RayParams = RaycastParams.new()
RayParams.FilterType = Enum.RaycastFilterType.Include
RayParams.FilterDescendantsInstances = {workspace:WaitForChild("objects"):WaitForChild("map"), workspace.Terrain}

local function getPresetSplat()
	return ReplicatedStorage.Assets.Effects.Blood.Splat
end

local function getPresetDroplet()
	return ReplicatedStorage.Assets.Effects.Blood.Droplet
end

local function randFloat(min: number, max: number): number
	return min + math.random() * (max - min)
end

local function cubicBezier(p0: vector, p1: vector, p2: vector, p3: vector, t: number): vector
	local mt = 1 - t
	local mt2 = mt * mt
	local mt3 = mt2 * mt
	local t2 = t * t
	local t3 = t2 * t
	return p0 * mt3 + p1 * (3 * mt2 * t) + p2 * (3 * mt * t2) + p3 * t3
end

local function cubicBezierTangent(p0: vector, p1: vector, p2: vector, p3: vector, t: number): vector
	local mt = 1 - t
	local d = (p1 - p0) * (3 * mt * mt) + (p2 - p1) * (6 * mt * t) + (p3 - p2) * (3 * t * t)
	local mag = vector.magnitude(d)
	if mag < 1e-6 then return vector.create(0, -1, 0) end
	return d / mag
end

function BloodModule.new(hitPos: vector, hitNormal: vector)
	local self = setmetatable({}, BloodModule)
	self.HitPos = hitPos
	self.HitNormal = hitNormal
	return self
end

local function makeSplat(pos: vector, normal: vector, scale: number?)
	local SplatFX = getPresetSplat():Clone()

	local UpVector = vector.normalize(normal)
	local Ref = math.abs(vector.dot(UpVector, vector.create(0,1,0))) < .9 and vector.create(0,1,0) or vector.create(1,0,0)
	local RightVector = vector.normalize(vector.cross(UpVector, Ref))
	local ForwardVector = vector.cross(RightVector, UpVector)

	local s = scale or 1
	SplatFX.Size = SplatFX.Size * s
	SplatFX.Anchored = true
	SplatFX.CanCollide = false
	SplatFX.CanQuery = false
	SplatFX.CanTouch = false
	SplatFX.CFrame = CFrame.fromMatrix(pos + normal * .15, RightVector, UpVector, ForwardVector) * CFrame.Angles(math.rad(-180), 0, 0)
	SplatFX.Parent = debrisFolder

	local emitters = {}
	for _, fx in next, SplatFX:GetDescendants() do
		if fx:IsA("ParticleEmitter") then
			table.insert(emitters, {fx = fx, count = fx:GetAttribute("EmitCount") or 1})
		end
	end

	task.spawn(function()
		for _, entry in next, emitters do
			entry.fx:Emit(entry.count * 2)
			task.wait()
		end
	end)

	task.delay(25, function()
		if SplatFX and SplatFX.Parent then
			SplatFX:Destroy()
		end
	end)
end

local function makeBloodPool(pos: vector, normal: vector, baseScale: number?)
	local PoolFX = getPresetSplat():Clone()

	local UpVector = vector.normalize(normal)
	local Ref = math.abs(vector.dot(UpVector, vector.create(0,1,0))) < .9 and vector.create(0,1,0) or vector.create(1,0,0)
	local RightVector = vector.normalize(vector.cross(UpVector, Ref))
	local ForwardVector = vector.cross(RightVector, UpVector)

	local scale = baseScale or randFloat(1.5, 3)
	PoolFX.Size = PoolFX.Size * scale
	PoolFX.Anchored = true
	PoolFX.CanCollide = false
	PoolFX.CanQuery = false
	PoolFX.CanTouch = false

	local rot = math.rad(randFloat(0, 360))
	PoolFX.CFrame = CFrame.fromMatrix(pos + normal * .02, RightVector, UpVector, ForwardVector) * CFrame.Angles(0, rot, 0)
	PoolFX.Parent = debrisFolder

	for i = 1, math.random(3, 6) do
		local extra = getPresetSplat():Clone()
		local offset = vector.create(randFloat(-scale, scale), 0, randFloat(-scale, scale))
		extra.Size = extra.Size * randFloat(.5, 1.2)
		extra.Anchored = true
		extra.CanCollide = false
		extra.CanQuery = false
		extra.CanTouch = false
		extra.CFrame = PoolFX.CFrame * CFrame.new(offset.X, 0, offset.Z) * CFrame.Angles(0, math.rad(randFloat(0, 360)), 0)
		extra.Parent = debrisFolder
	end

	task.delay(30, function()
		if PoolFX and PoolFX.Parent then
			PoolFX:Destroy()
		end
	end)
end

function BloodModule:Spawn()
	local normal = self.HitNormal
	local isFloor = vector.dot(normal, vector.create(0, 1, 0)) > .7
	local isCeiling = vector.dot(normal, vector.create(0, -1, 0)) > .7

	local Ref = math.abs(vector.dot(normal, vector.create(0,1,0))) < .9 and vector.create(0,1,0) or vector.create(1,0,0)
	local Tangent = vector.normalize(vector.cross(normal, Ref))
	local Bitangent = vector.cross(normal, Tangent)

	makeBloodPool(self.HitPos, normal)

	local DropletCount = math.random(12, 25)
	local ClusterCount = math.random(3, 6)
	local clusters = {}

	for c = 1, ClusterCount do
		local baseAngleH = math.rad(math.random(0, 360))
		local baseSpeed, baseNormal, baseTangent

		if isFloor then
			local angleV = math.rad(randFloat(50, 85))
			baseNormal = math.sin(angleV)
			baseTangent = math.cos(angleV) * randFloat(.1, .5)
			baseSpeed = randFloat(16, 28)
		elseif isCeiling then
			local angleV = math.rad(randFloat(50, 80))
			baseNormal = -math.sin(angleV) * .4
			baseTangent = math.cos(angleV) * randFloat(.1, .4)
			baseSpeed = randFloat(14, 24)
		else
			local angleV = math.rad(randFloat(55, 90))
			baseNormal = math.sin(angleV)
			baseTangent = math.cos(angleV) * randFloat(.1, .3)
			baseSpeed = randFloat(16, 28)
		end

		local baseJitter = vector.create(randFloat(-.5,.5), randFloat(-.5,.5), randFloat(-.5,.5))
		clusters[c] = {angleH = baseAngleH, speed = baseSpeed, normalStr = baseNormal, tangentStr = baseTangent, jitter = baseJitter}
	end

	for i = 1, DropletCount do
		local DropletFX = getPresetDroplet():Clone()
		local cl = clusters[math.random(1, ClusterCount)]
		local posNudge = vector.create(randFloat(-.2,.2), randFloat(-.2,.2), randFloat(-.2,.2))
		local StartPos = self.HitPos + normal * .05 + cl.jitter + posNudge
		local angleH = cl.angleH + math.rad(randFloat(-20,20))
		local normalStrength = cl.normalStr + randFloat(-.05,.05)
		local tangentStrength = cl.tangentStr + randFloat(-.03,.03)
		local speed = cl.speed + randFloat(-2,2)
		local tangentDir = Tangent * math.cos(angleH) + Bitangent * math.sin(angleH)
		local InitialVelocity = vector.normalize(normal * normalStrength + tangentDir * tangentStrength) * speed
		local gravScale = isFloor and randFloat(3,5) or isCeiling and randFloat(3.5,5.5) or randFloat(3,5)
		local gravity = vector.create(0, -28 * gravScale, 0)
		local MaxLifetime = randFloat(.6,1.6)

		local function physicsPos(t)
			return StartPos + InitialVelocity * t + gravity * (.5 * t * t)
		end

		local P0 = StartPos
		local P3 = physicsPos(MaxLifetime)
		local midT = MaxLifetime * .5
		local midPhys = physicsPos(midT)
		local ctrl1Offset = vector.create(randFloat(-.15,.15), randFloat(.05,.25), randFloat(-.15,.15)) * speed * .03
		local ctrl2Offset = vector.create(randFloat(-.15,.15), randFloat(-.05,.15), randFloat(-.15,.15)) * speed * .03
		local P1 = midPhys * (2/3) + P0 * (1/3) + ctrl1Offset
		local P2 = midPhys * (2/3) + P3 * (1/3) + ctrl2Offset

		local StartTime = os.clock()
		local HasSplatted = false
		local PrevPosition = StartPos

		DropletFX.Anchored = true
		DropletFX.CanCollide = false
		DropletFX.CanQuery = false
		DropletFX.CanTouch = false
		DropletFX.Position = StartPos
		DropletFX.Parent = debrisFolder

		local Connection
		Connection = RS.Heartbeat:Connect(function()
			local ElapsedTime = os.clock() - StartTime
			local t = math.clamp(ElapsedTime / MaxLifetime,0,1)

			if ElapsedTime > MaxLifetime or HasSplatted then
				Connection:Disconnect()
				if DropletFX and DropletFX.Parent then DropletFX:Destroy() end
				return
			end

			local NewPosition = cubicBezier(P0,P1,P2,P3,t)
			if vector.magnitude(NewPosition) > 2048 then
				Connection:Disconnect()
				if DropletFX and DropletFX.Parent then DropletFX:Destroy() end
				return
			end

			local MoveDir = NewPosition - PrevPosition
			local MoveMag = vector.magnitude(MoveDir)

			if MoveMag > 0 then
				local RayDir = MoveDir + vector.normalize(MoveDir) * .15
				local SurfaceRay = workspace:Raycast(PrevPosition, RayDir, RayParams)
				if SurfaceRay then
					HasSplatted = true
					Connection:Disconnect()
					if DropletFX and DropletFX.Parent then DropletFX:Destroy() end
					if SurfaceRay.Position.Y > -500 and SurfaceRay.Position.Y < 500 then
						local splatScale = randFloat(.7,1.6)
						makeSplat(SurfaceRay.Position, SurfaceRay.Normal, splatScale)
						for j=1,math.random(1,3) do
							makeSplat(SurfaceRay.Position + vector.create(randFloat(-.5,.5),0,randFloat(-.5,.5)), SurfaceRay.Normal, randFloat(.3,1.1))
						end
					end
					return
				end

				local TangentDir = cubicBezierTangent(P0,P1,P2,P3,t)
				local Right = vector.normalize(vector.cross(TangentDir, math.abs(vector.dot(TangentDir,vector.create(0,1,0))) < .9 and vector.create(0,1,0) or vector.create(1,0,0)))
				local Up = vector.cross(Right, TangentDir)
				DropletFX.CFrame = CFrame.fromMatrix(NewPosition, Right, Up, -TangentDir)
			else
				DropletFX.Position = NewPosition
			end

			PrevPosition = NewPosition
		end)

		task.delay(MaxLifetime + .5, function()
			if Connection then Connection:Disconnect() end
			if DropletFX and DropletFX.Parent then DropletFX:Destroy() end
		end)
	end
end

function BloodModule.Listen()
	BlinkClient.BloodSpawn.On(function(payload)
		local hitPos = vector.create(payload.X, payload.Y, payload.Z)
		local hitNormal = vector.create(payload.NX, payload.NY, payload.NZ)
		BloodModule.new(hitPos, hitNormal):Spawn()
	end)
end

return BloodModule