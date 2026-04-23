local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local FastCast = require(ReplicatedStorage.Packages.Shared.FastCastRedux)
local ProjectileShared = require(ReplicatedStorage.Modules.Shared.Systems.Guns.ProjectileShared)

local BlinkClient = Networking.Client

local ProjectileClient = {}

local registry = {}
local spawnConn

local debrisFolder = workspace:WaitForChild("objects"):WaitForChild("debris")

local function channel(name)
	if BlinkClient and BlinkClient[name] then
		return BlinkClient[name]
	end
	local evt = ReplicatedStorage:FindFirstChild(name)
	if not evt then
		evt = Instance.new("RemoteEvent")
		evt.Name = name
		evt.Parent = ReplicatedStorage
	end
	return {
		Fire = function(data)
			evt:FireServer(data)
		end;
		On = function(fn)
			return evt.OnClientEvent:Connect(fn)
		end;
	}
end

local ProjectileFire = channel("ProjectileFire")
local ProjectileSpawn = channel("ProjectileSpawn")

function ProjectileClient.Register(name, hooks)
	registry[name] = hooks or {}
end

local function resolvePath(pathTbl)
	if type(pathTbl) ~= "table" then return nil end
	local root = ReplicatedStorage
	for _, name in next, pathTbl do
		root = root and root:FindFirstChild(name)
	end
	return root
end

function ProjectileClient.Fire(payload)
	if type(payload) ~= "table" then return end
	if type(payload.Origin) ~= "vector" or type(payload.Direction) ~= "vector" then return end
	if vector.magnitude(payload.Direction) == 0 then return end
	payload.Direction = vector.normalize(payload.Direction)
	payload.ShotId = payload.ShotId or HttpService:GenerateGUID(false)
	local shared = ProjectileShared[payload.Name]
	local baseSpeed = shared and shared.Speed or 0
	local maxSpeed = (shared and shared.MaxSpeed) or 2000
	payload.Speed = math.clamp(tonumber(payload.Speed) or baseSpeed, 0, maxSpeed)
	ProjectileFire.Fire(payload)
end

local function makeBulletCosmetic(def): BasePart?
	local bullet = resolvePath(def.Bullet and def.Bullet.Path)
	if not bullet or not bullet:IsA("BasePart") then return nil end
	local clone = bullet:Clone()
	clone.CanCollide = false
	clone.CanQuery = false
	clone.CanTouch = false
	clone.Anchored = true
	clone.Parent = debrisFolder
	return clone
end

local function destroyCosmetic(obj: BasePart?)
	if obj and obj.Parent then
		obj:Destroy()
	end
end

local function spawnCast(payload, isBounce: boolean?)
	local hooks = registry[payload.Name]
	local def = ProjectileShared[payload.Name]
	if not def then return end

	local faceOffset = (def.Bullet and def.Bullet.FaceOffset) or CFrame.identity
	local ric = def.Ricochet

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.IgnoreWater = true
	params.FilterDescendantsInstances = {
		ProjectileShared.Map;
		ProjectileShared.Map.Parent.entities;
		workspace.Terrain;
	}

	local b = FastCast.newBehavior()
	b.MaxDistance = def.MaxDistance or 1000
	b.Acceleration = vector.create(
		(def.Acceleration and def.Acceleration.X) or 0,
		(def.Acceleration and def.Acceleration.Y) or 0,
		(def.Acceleration and def.Acceleration.Z) or 0
	)
	b.RaycastParams = params
	b.CanPierceFunction = function(_, result, _, _)
		local inst = result.Instance
		if not inst then return false end
		if inst:IsDescendantOf(debrisFolder) then return true end
		return false
	end

	local cosmeticObj = makeBulletCosmetic(def)
	local currentSpeed = payload.Speed
	local hitFired = false

	local caster = FastCast.new()

	caster.LengthChanged:Connect(function(_, lastPoint, rayDir, rayDisplacement, segmentVelocity, _)
		currentSpeed = vector.magnitude(segmentVelocity)
		if cosmeticObj and cosmeticObj.Parent then
			local position = lastPoint + vector.normalize(rayDir) * rayDisplacement
			local look = position + rayDir
			cosmeticObj.CFrame = CFrame.new(position, look) * faceOffset
		end
	end)

	caster.RayHit:Connect(function(_, result, _, _)
		if hitFired then return end
		hitFired = true

		destroyCosmetic(cosmeticObj)
		cosmeticObj = nil

		if not isBounce then
			if hooks and hooks.OnHit then
				hooks.OnHit(result, payload, currentSpeed)
			end
		end

		if ric then
			local bounces = (payload.Meta and payload.Meta.Bounces) or 0
			if bounces >= (ric.MaxBounces or 2) then return end

			local incoming = vector.normalize(payload.Direction)
			local normal = result.Normal
			local dot = vector.dot(incoming, normal)
			local incidentAngle = 90 - math.deg(math.acos(math.clamp(math.abs(dot), 0, 1)))

			if incidentAngle > (ric.MaxAngle or 85) then return end

			local vel = incoming * currentSpeed
			local reflected = vel - normal * (2 * vector.dot(vel, normal))
			local newSpeed = vector.magnitude(reflected) * (ric.SpeedRetention or .8)

			if newSpeed < 50 then return end

			task.defer(function()
				spawnCast({
					Name = payload.Name;
					Origin = result.Position + normal * .15;
					Direction = vector.normalize(reflected);
					Speed = newSpeed;
					ShotId = payload.ShotId;
					Meta = { Bounces = bounces + 1 };
				}, true)
			end)
		end
	end)

	caster.CastTerminating:Connect(function(_)
		destroyCosmetic(cosmeticObj)
		cosmeticObj = nil
	end)

	local active = caster:Fire(payload.Origin, payload.Direction, payload.Speed, b)
	if not active then
		destroyCosmetic(cosmeticObj)
		cosmeticObj = nil
		return
	end

	if not isBounce then
		if hooks and hooks.OnSpawn then
			hooks.OnSpawn(payload, active, cosmeticObj)
		end
	end

	local dir = payload.Direction
	if cosmeticObj and dir and vector.magnitude(dir) > 0 then
		cosmeticObj.CFrame = CFrame.new(payload.Origin, payload.Origin + dir) * faceOffset
	end

	local attName = def.Bullet and def.Bullet.Attachment
	local emitName = def.Bullet and def.Bullet.Emit
	if cosmeticObj and attName and emitName then
		local att = cosmeticObj:FindFirstChild(attName)
		local emitter = att and att:FindFirstChild(emitName)
		if emitter and emitter.Emit then
			pcall(function()
				emitter:Emit(emitter:GetAttribute("EmitCount") or 10)
			end)
		end
	end
end

local function onSpawn(payload)
	if type(payload) ~= "table" or type(payload.Name) ~= "string" then return end
	spawnCast(payload, false)
end

if ProjectileSpawn and ProjectileSpawn.On then
	spawnConn = ProjectileSpawn.On(onSpawn)
end

for name, def in next, ProjectileShared do
	if type(def) ~= "table" then continue end
	ProjectileClient.Register(name, {
		OnSpawn = function(payload, active, cosmeticObj)
		end;
		OnHit = function(result, payload, currentSpeed)
		end;
	})
end

return ProjectileClient