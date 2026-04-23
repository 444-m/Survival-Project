local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local FastCast = require(ReplicatedStorage.Packages.Shared.FastCastRedux)
local ProjectileShared = require(ReplicatedStorage.Modules.Shared.Systems.Guns.ProjectileShared)

local BlinkServer = Networking.Server

local ProjectileServer = {}

local registry = {}
local casters = {}
local fireCooldown = {}
const COOLDOWN = .05
const MAX_SPEED_DEFAULT = 2000

local Signal = require(ReplicatedStorage.Packages.Shared.Signal)
local GunEvents = require(ServerStorage.Modules.Systems.Guns.GunEvents)

local function channel(name)
	if BlinkServer and BlinkServer[name] then
		return BlinkServer[name]
	end
	local evt = ReplicatedStorage:FindFirstChild(name)
	if not evt then
		evt = Instance.new("RemoteEvent")
		evt.Name = name
		evt.Parent = ReplicatedStorage
	end
	return {
		On = function(fn)
			return evt.OnServerEvent:Connect(fn)
		end,
		Fire = function(player, data)
			evt:FireClient(player, data)
		end,
		FireAll = function(data)
			evt:FireAllClients(data)
		end
	}
end

local ProjectileFire = channel("ProjectileFire")
local ProjectileSpawn = channel("ProjectileSpawn")

local function getCaster(name)
	local c = casters[name]
	if c then return c end
	c = FastCast.new()
	casters[name] = c
	return c
end

function ProjectileServer.Register(name, def)
	registry[name] = def or {}
end

local function clampPayload(player, payload)
	if type(payload) ~= "table" or type(payload.Name) ~= "string" then return nil end
	local def = registry[payload.Name]
	if not def then return nil end
	if type(payload.Origin) ~= "vector" or type(payload.Direction) ~= "vector" then return nil end
	if payload.Direction.Magnitude == 0 then return nil end
	local maxSpeed = def.MaxSpeed or MAX_SPEED_DEFAULT
	local origin = payload.Origin
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and def.MaxOriginOffset then
		local offset = (payload.Origin - root.Position).Magnitude
		if offset > def.MaxOriginOffset then
			origin = root.Position + (payload.Direction.Unit * def.MaxOriginOffset)
		end
	end
	local clean = {
		Name = payload.Name,
		Owner = player.UserId,
		Origin = origin,
		Direction = payload.Direction.Unit,
		Speed = math.clamp(tonumber(payload.Speed) or 0, 0, maxSpeed),
		Meta = payload.Meta,
		ShotId = payload.ShotId,
	}
	if def.OnServerValidate and def.OnServerValidate(player, clean) == false then
		return nil
	end
	return clean
end

local function onFire(player, payload)
	local now = os.clock()
	if fireCooldown[player] and (now - fireCooldown[player]) < COOLDOWN then return end
	fireCooldown[player] = now
	local clean = clampPayload(player, payload)
	if not clean then return end

	local def = registry[clean.Name] or {}
	local behavior = def.Behavior and def.Behavior(clean) or FastCast.newBehavior()
	behavior.MaxDistance = def.MaxDistance or behavior.MaxDistance or 1000
	if def.Acceleration then
		behavior.Acceleration = def.Acceleration
	end
	if not behavior.RaycastParams then
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		local include = {ProjectileShared.Map, ProjectileShared.Map.Parent.entities, workspace.Terrain}
		params.FilterDescendantsInstances = include
		params.IgnoreWater = true
		behavior.RaycastParams = params
	end

	local caster = getCaster(clean.Name)
	local active = caster:Fire(clean.Origin, clean.Direction, clean.Speed, behavior)

	local hitFired = false
	if def.OnHit and active and active.Caster then
		active.Caster.RayHit:Connect(function(_, result, _, _)
			if hitFired then return end
			hitFired = true
			
			GunEvents.OnHit:Fire({
				player = player;
				result = result;
				payload = clean;
				def = def;
				shotId = clean.ShotId;
			})
		end)
	end

	if ProjectileSpawn.FireAll then
		ProjectileSpawn.FireAll(clean)
	end
end

ProjectileFire.On(onFire)

for name, def in next, ProjectileShared do
	ProjectileServer.Register(name, def)
end

return ProjectileServer
