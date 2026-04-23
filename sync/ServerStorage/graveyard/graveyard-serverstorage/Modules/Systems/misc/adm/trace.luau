local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local BlinkServer = require(ReplicatedStorage.Packages.Shared.Blink.Server)

local module = {}

local Defaults = table.freeze({
	TouchRadius = 4.25;
	NearRadius = 20;
	TeleportDistance = 25;
	TeleportHeight = 7;
	TeleportDepth = 22;
	TeleportRaise = .2;
	TouchCooldown = .9;
	ManualCooldown = .45;
	DamageDivisor = 1.5;
	NearShakeScale = .42;
	BoomShakeScale = 1.12;
	ProbeAngleStep = 24;
	ProbeAngleMax = 180;
	VelocityLeadTime = .18;
	MinApproachSpeed = 1.8;
	TouchRadiusPadding = 1.35;
	AllowManual = true;
	AllowBurst = true;
	AllowNearFx = true;
})

local Config = {}
for key, value in next, Defaults do
	Config[key] = value
end

local DefaultsEnabled = {
	[1175918694] = true;
}

local Enabled = {}
local Bound = {}
local BoundByPlayer = {}
local LoopConnection = nil

local RimBase = Color3.fromRGB(240, 248, 255)
local RimPeak = Color3.fromRGB(118, 225, 255)
local RimCore = Color3.fromRGB(255, 255, 255)
local TraceVector = advents.vector

local function isAlive(character, humanoid, rootPart)
	return character and character.Parent and humanoid and humanoid.Parent and humanoid.Health > 0 and rootPart and rootPart.Parent
end

local function ensureLoop()
	if LoopConnection then
		return
	end

	LoopConnection = RunService.Heartbeat:Connect(function()
		local hasEntries = false
		for _, data in next, Bound do
			hasEntries = true

			local character = data.Character
			local humanoid = data.Humanoid
			local rootPart = data.RootPart
			local mark = data.Mark
			if not isAlive(character, humanoid, rootPart) or not mark or not mark.Parent then
				module.Clear(data.Handler)
				continue
			end

			local now = os.clock()
			local speed = vector.magnitude(rootPart.AssemblyLinearVelocity * TraceVector.flat)
			local moveAlpha = math.clamp(speed / math.max(46 * .72, 1), 0, 1)
			local groundedAlpha = humanoid.FloorMaterial ~= Enum.Material.Air and 1 or .55
			local calmWave = (math.sin((now * 2.45) + (math.sin(now * .85) * .55)) + 1) * .5
			local shimmerWave = (math.sin((now * 7.8) + (math.sin(now * 2.6) * .9)) + 1) * .5
			local driftWave = (math.sin((now * 1.35) + .8) + 1) * .5
			local emberWave = (math.sin((now * 12.6) + (math.sin(now * 4.1) * .7)) + 1) * .5
			local liftTarget = (.26 + (calmWave * .28) + (shimmerWave * .14)) * groundedAlpha
			local toneTarget = math.clamp((calmWave * .68) + (shimmerWave * .22) + (moveAlpha * .18) + (driftWave * .08), 0, 1)
			local veilTarget = ((calmWave * .08) + (shimmerWave * .04) + (emberWave * .03)) * groundedAlpha
			local driftTarget = (driftWave * .12) + (moveAlpha * .06)

			if now >= data.NextAt then
				data.Burst.p += .42 + (math.random() * .16)
				data.Burst.v += 1.2 + (math.random() * .9)
				data.NextAt = now + .95 + (math.random() * 1.85)
			end

			if now >= data.NextMinorAt then
				data.Ember.p += .08 + (math.random() * .08)
				data.Ember.v += .45 + (math.random() * .55)
				data.NextMinorAt = now + .18 + (math.random() * .4)
			end

			data.Lift.t = liftTarget
			data.Burst.t = 0
			data.Tone.t = toneTarget
			data.Veil.t = veilTarget
			data.Drift.t = driftTarget
			data.Ember.t = 0

			local burstAlpha = math.clamp(data.Burst.p, 0, 1)
			local emberAlpha = math.clamp(data.Ember.p, 0, 1)
			local glowAlpha = math.clamp(data.Lift.p + (burstAlpha * .55), 0, 1)
			local toneAlpha = math.clamp(data.Tone.p + (burstAlpha * .4) + (emberAlpha * .18), 0, 1)
			local fillAlpha = math.clamp(data.Veil.p + (burstAlpha * .05) + (emberAlpha * .04), 0, .16)
			local driftAlpha = math.clamp(data.Drift.p + (emberAlpha * .12), 0, 1)

			local toneBlend = advents.easing.bezier_out(math.clamp((toneAlpha * .66) + (driftAlpha * .34) + (burstAlpha * .12), 0, 1), 0, .18, .82, 1)
			mark.FillColor = RimCore:Lerp(RimPeak, toneBlend)
			mark.FillTransparency = math.clamp(.985 - (fillAlpha * .82) - (burstAlpha * .08), .04, .985)
			mark.OutlineTransparency = math.clamp(.32 - (glowAlpha * .3) - (moveAlpha * .08) - (emberAlpha * .05) - (burstAlpha * .08), .015, .54)
			mark.OutlineColor = RimBase:Lerp(RimPeak, advents.easing.bezier_out(math.clamp(toneAlpha + (burstAlpha * .16), 0, 1), 0, .18, .82, 1))
			if data.Light and data.Light.Parent then
				data.Light.Color = RimCore:Lerp(RimPeak, math.clamp((toneAlpha * .72) + (emberAlpha * .18), 0, 1))
				data.Light.Brightness = .8 + (glowAlpha * 1.8) + (burstAlpha * 2.8) + (moveAlpha * .5)
				data.Light.Range = 10 + (glowAlpha * 8) + (burstAlpha * 10)
			end

			if now < data.NextScanAt then
				continue
			end

			data.NextScanAt = now + .08
			local nearestPlayer = nil
			local nearestHumanoid = nil
			local nearestRoot = nil
			local nearestDistance = math.huge
			local nextNear = {}

			for _, otherPlayer in next, Players:GetPlayers() do
				if otherPlayer ~= data.Player then
					local otherCharacter = otherPlayer.Character
					local otherHumanoid = otherCharacter and otherCharacter:FindFirstChildOfClass("Humanoid")
					local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")
					if otherHumanoid and otherRoot and otherRoot:IsA("BasePart") and otherHumanoid.Health > 0 then
						local distance = vector.magnitude(otherRoot.Position - rootPart.Position)
						if Config.AllowNearFx and distance <= Config.NearRadius then
							nextNear[otherPlayer] = true
							if not data.Near[otherPlayer] then
								BlinkServer.TraceNear.Fire(otherPlayer, {
									UserId = data.Player.UserId;
									Enabled = true;
									Scale = Config.NearShakeScale;
								})
							end
						end
						local burstDistance = getBurstTarget(rootPart, otherRoot)
						if burstDistance and burstDistance < nearestDistance then
							nearestDistance = burstDistance
							nearestPlayer = otherPlayer
							nearestHumanoid = otherHumanoid
							nearestRoot = otherRoot
						end
					end
				end
			end

			for otherPlayer in next, data.Near do
				if not nextNear[otherPlayer] then
					BlinkServer.TraceNear.Fire(otherPlayer, {
						UserId = data.Player.UserId;
						Enabled = false;
						Scale = 0;
					})
				end
			end

			data.Near = nextNear

			if Config.AllowBurst and nearestPlayer and nearestHumanoid and nearestRoot and not data.SequenceActive and (now - data.LastBurstAt) >= Config.TouchCooldown then
				data.LastBurstAt = now
				module.Transmit(data.Player, nearestRoot.Position, nearestHumanoid, nearestPlayer, true)
			end
		end

		if not hasEntries and LoopConnection then
			LoopConnection:Disconnect()
			LoopConnection = nil
		end
	end)
end

local function flatDirection(direction)
	local result = direction * vector.create(1, 0, 1)
	if vector.magnitude(result) <= .001 then
		return vector.zero
	end

	return vector.normalize(result)
end

function getBurstTarget(rootPart, otherRoot)
	local relativePosition = (otherRoot.Position - rootPart.Position) * vector.create(1, 0, 1)
	local relativeVelocity = (otherRoot.AssemblyLinearVelocity - rootPart.AssemblyLinearVelocity) * vector.create(1, 0, 1)
	local nowDistance = vector.magnitude(relativePosition)
	local futureDistance = vector.magnitude(relativePosition + (relativeVelocity * Config.VelocityLeadTime))
	local radiusPadding = ((math.max(rootPart.Size.X, rootPart.Size.Z) + math.max(otherRoot.Size.X, otherRoot.Size.Z)) * .25) + (Config.TouchRadiusPadding or 0)
	local hitDistance = (Config.TouchRadius or 0) + radiusPadding
	local approachSpeed = if nowDistance > .001
		then math.max(0, vector.dot(vector.normalize(relativePosition), -(relativeVelocity)))
		else vector.magnitude(relativeVelocity)

	if nowDistance <= hitDistance then
		return nowDistance
	end

	if futureDistance <= hitDistance and approachSpeed >= Config.MinApproachSpeed then
		return futureDistance
	end

	return nil
end

local function rotateY(direction, angle)
	local c = math.cos(angle)
	local s = math.sin(angle)
	return vector.create((direction.X * c) - (direction.Z * s), 0, (direction.X * s) + (direction.Z * c))
end

local function makeRayParams(character)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist
	rayParams.FilterDescendantsInstances = {character}
	rayParams.RespectCanCollide = true
	return rayParams
end

local function makeOverlapParams(character)
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
	overlapParams.FilterDescendantsInstances = {character}
	overlapParams.RespectCanCollide = true
	return overlapParams
end

local function getVisuals(character)
	local visuals = {}
	for _, instance in next, character:GetDescendants() do
		if instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture") then
			table.insert(visuals, {
				Instance = instance;
				Transparency = instance.Transparency;
			})
		end
	end
	return visuals
end

local function tweenVisuals(visuals, alpha, duration)
	local info = TweenInfo.new(duration, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
	for _, entry in next, visuals do
		local instance = entry.Instance
		if instance and instance.Parent then
			local target = math.clamp(alpha >= 1 and 1 or entry.Transparency, 0, 1)
			TweenService:Create(instance, info, {Transparency = target}):Play()
		end
	end
end

local function findDestination(data, targetPosition, away)
	local character = data.Character
	local humanoid = data.Humanoid
	local rootPart = data.RootPart
	if not character or not humanoid or not rootPart then
		return nil
	end

	local rawDirection = targetPosition - rootPart.Position
	if away then
		rawDirection *= vector.create(-1, 1, -1)
	end
	local direction = flatDirection(rawDirection)
	if vector.magnitude(direction) <= .001 then
		direction = flatDirection(rootPart.CFrame.LookVector)
	end
	if vector.magnitude(direction) <= .001 then
		direction = vector.create(0, 0, -1)
	end

	local rayParams = makeRayParams(character)
	local overlapParams = makeOverlapParams(character)
	local extents = character:GetExtentsSize()
	local boxSize = Vector3.new(math.max(extents.X * .78, 3), math.max(extents.Y * .92, 5), math.max(extents.Z * .78, 3))
	local hipHeight = humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		hipHeight = 2.8
	end

	local function isClear(position, lookDirection)
		local cf = CFrame.lookAt(position, position + lookDirection)
		local touching = Workspace:GetPartBoundsInBox(cf, boxSize, overlapParams)
		for _, part in next, touching do
			if part.CanCollide and not part:IsDescendantOf(character) then
				return nil
			end
		end
		return cf
	end

	for offset = 0, Config.ProbeAngleMax, Config.ProbeAngleStep do
		for _, signed in next, {offset, -offset} do
			local probeDirection = rotateY(direction, math.rad(signed))
			local flatTarget = rootPart.Position + (probeDirection * Config.TeleportDistance)
			local rayOrigin = Vector3.new(flatTarget.X, flatTarget.Y + Config.TeleportHeight, flatTarget.Z)
			local rayDirection = Vector3.new(0, -(Config.TeleportHeight + Config.TeleportDepth), 0)
			local hit = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
			local destination = hit and hit.Position or flatTarget
			local finalPosition = vector.create(destination.X, destination.Y + hipHeight + (rootPart.Size.Y * .5) + Config.TeleportRaise, destination.Z)
			local clear = isClear(finalPosition, probeDirection)
			if clear then
				return clear
			end
		end
	end

	return nil
end

function module.GetRemote()
	return BlinkServer.TraceDash
end

function module.IsEnabled(player)
	local userId = typeof(player) == "Instance" and player.UserId or player
	if Enabled[userId] ~= nil then
		return Enabled[userId] == true
	end
	return DefaultsEnabled[userId] == true
end

function module.SetEnabled(player, enabled)
	local userId = typeof(player) == "Instance" and player.UserId or player
	Enabled[userId] = enabled == true
end

function module.GetConfigKeys()
	local keys = {}
	for key, value in next, Config do
		if type(value) == "number" or type(value) == "boolean" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function module.GetConfig(key)
	return Config[key]
end

function module.SetConfig(key, value)
	if Config[key] == nil then
		return false
	end
	Config[key] = value
	return true
end

function module.Clear(handler)
	local data = Bound[handler]
	if not data then
		if handler and handler.Player then
			BlinkServer.TraceBind.Fire(handler.Player, {
				Enabled = false;
			})
		end
		return
	end

	for player in next, data.Near do
		BlinkServer.TraceNear.Fire(player, {
			UserId = data.Player.UserId;
			Enabled = false;
			Scale = 0;
		})
	end

	if data.Mark and data.Mark.Parent then
		data.Mark:Destroy()
	end
	if data.Light and data.Light.Parent then
		data.Light:Destroy()
	end

	Bound[handler] = nil
	BoundByPlayer[data.Player] = nil
	if handler then
		handler.TraceData = nil
	end
	BlinkServer.TraceBind.Fire(data.Player, {
		Enabled = false;
	})
end

function module.Bind(handler, character)
	module.Clear(handler)

	if not handler or not handler.Player or not character or not module.IsEnabled(handler.Player) then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not rootPart or not humanoid or not rootPart:IsA("BasePart") then
		return
	end

	local mark = Instance.new("Highlight")
	mark.Name = "_r"
	mark.Adornee = character
	mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	mark.FillTransparency = 1
	mark.OutlineTransparency = .18
	mark.OutlineColor = RimBase
	mark.Parent = character

	local light = Instance.new("PointLight")
	light.Name = "_trl"
	light.Color = RimPeak
	light.Brightness = 1.4
	light.Range = 14
	light.Shadows = false
	light.Parent = rootPart

	local data = {
		Handler = handler;
		Player = handler.Player;
		Character = character;
		Humanoid = humanoid;
		RootPart = rootPart;
		Mark = mark;
		Light = light;
		Lift = advents.spring.new(0);
		Burst = advents.spring.new(0);
		Tone = advents.spring.new(0);
		Veil = advents.spring.new(0);
		Drift = advents.spring.new(0);
		Ember = advents.spring.new(0);
		NextAt = os.clock() + .45;
		NextMinorAt = os.clock() + .22;
		NextScanAt = 0;
		Near = {};
		LastBurstAt = 0;
		LastManualAt = 0;
		SequenceActive = false;
		Visuals = getVisuals(character);
	}

	data.Lift.d = .8
	data.Lift.s = 8.5
	data.Burst.d = .74
	data.Burst.s = 13.5
	data.Tone.d = .82
	data.Tone.s = 6.8
	data.Veil.d = .78
	data.Veil.s = 7.2
	data.Drift.d = .8
	data.Drift.s = 5.9
	data.Ember.d = .7
	data.Ember.s = 15.5

	Bound[handler] = data
	BoundByPlayer[handler.Player] = data
	handler.TraceData = data
	BlinkServer.TraceBind.Fire(handler.Player, {
		Enabled = true;
	})
	ensureLoop()
end

function module.Refresh(player, handler)
	if handler and handler.Character and module.IsEnabled(player) then
		module.Bind(handler, handler.Character)
	elseif handler then
		module.Clear(handler)
	end
end

function module.Transmit(player, targetPosition, victimHumanoid, victimPlayer, away)
	local data = BoundByPlayer[player]
	if not data or data.SequenceActive or not isAlive(data.Character, data.Humanoid, data.RootPart) then
		return false
	end

	local destination = findDestination(data, targetPosition, away == true)
	if not destination then
		return false
	end

	data.SequenceActive = true
	local character = data.Character
	local rootPart = data.RootPart
	local visuals = data.Visuals
	task.spawn(function()
		tweenVisuals(visuals, 1, .07)
		task.wait(.055)
		if character and character.Parent and rootPart and rootPart.Parent then
			rootPart.AssemblyLinearVelocity = vector.zero
			rootPart.AssemblyAngularVelocity = vector.zero
			character:PivotTo(destination)
			rootPart.AssemblyLinearVelocity = vector.zero
			rootPart.AssemblyAngularVelocity = vector.zero
		end
		--[[if victimHumanoid and victimHumanoid.Health > 0 then
			victimHumanoid:TakeDamage(victimHumanoid.MaxHealth / math.max(Config.DamageDivisor, .1))
		end]]
		BlinkServer.TraceBoom.Fire(player, {
			Magnitude = Config.BoomShakeScale;
			X = destination.Position.X;
			Y = destination.Position.Y;
			Z = destination.Position.Z;
		})
		if victimPlayer then
			BlinkServer.TraceBoom.Fire(victimPlayer, {
				Magnitude = Config.BoomShakeScale;
				X = destination.Position.X;
				Y = destination.Position.Y;
				Z = destination.Position.Z;
			})
		end
		for nearPlayer in next, data.Near do
			if nearPlayer ~= player and nearPlayer ~= victimPlayer then
				BlinkServer.TraceBoomFx.Fire(nearPlayer, {
					X = destination.Position.X;
					Y = destination.Position.Y;
					Z = destination.Position.Z;
				})
			end
		end
		task.wait(.035)
		tweenVisuals(visuals, 0, .24)
		data.SequenceActive = false
	end)

	return true
end

BlinkServer.TraceDash.On(function(player, payload)
	if not Config.AllowManual or not module.IsEnabled(player) then
		return
	end

	local data = BoundByPlayer[player]
	if not data or type(payload) ~= "table" then
		return
	end

	local now = os.clock()
	if (now - data.LastManualAt) < Config.ManualCooldown then
		return
	end

	data.LastManualAt = now
	module.Transmit(player, Vector3.new(payload.X, payload.Y, payload.Z), nil, nil, false)
end)

Players.PlayerRemoving:Connect(function(player)
	Enabled[player.UserId] = nil
	local data = BoundByPlayer[player]
	if data then
		module.Clear(data.Handler)
	end
end)

return module
