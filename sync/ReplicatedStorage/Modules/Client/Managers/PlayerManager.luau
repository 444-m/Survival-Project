local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ViewportManager = require "./ViewportManager"
local CameraController = require(ReplicatedStorage.Modules.Client.Controllers.Player.Camera.CameraController)
local FpsCamera = require(ReplicatedStorage.Modules.Client.Controllers.Player.Camera.FpsCamera)
local ToolManagerClient = require "./ToolManagerClient"

local Janitor = require(ReplicatedStorage.Modules.Client.Systems.CameraShake.Janitor)
local Animations = require(ReplicatedStorage.Modules.Shared.Animations)
local Input = require(ReplicatedStorage.Modules.Client.Input)

local advents = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local Tools = require(ReplicatedStorage.Modules.Shared.Storage.Tools)
local ADS = require(ReplicatedStorage.Modules.Client.Systems.Guns.Components.ADS)
local GunManager = require(ReplicatedStorage.Modules.Client.Systems.Guns.GunManager)

local BlinkClient = Networking.Client
local BetterAnimate = require(ReplicatedStorage.Packages.Shared.BetterAnimate)
local Promise = require(ReplicatedStorage.Modules.Client.Systems.CameraShake.Promise)
local ToolSetups = ToolManagerClient.Setups

local PlayerManager = {}
PlayerManager.__index = PlayerManager
PlayerManager.__GunHudRefs = nil

local function pickHudRefs(player: Player)
	local pg = player:FindFirstChild("PlayerGui")
	if not pg then return nil end
	local gui = pg:FindFirstChild("GunHUD")
	if not gui then return nil end
	if gui:IsA("ScreenGui") then gui.Enabled = true end
	local panel = gui:FindFirstChildOfClass("Frame") or gui:FindFirstChild("panel") or gui:FindFirstChild("Panel")
	if not panel then return nil end
	local refs = { panel = panel }

	local labels = panel:GetDescendants()
	local ammoLabel, capLabel, nameLabel
	local reloadOverlay, reloadBarFill
	local segs = {}

	local numericLabels = {}
	for _, d in ipairs(labels) do
		if d:IsA("TextLabel") then
			local num = tonumber(d.Text)
			if num then
				table.insert(numericLabels, d)
			end
			if d.TextSize <= 12 and not tonumber(d.Text) and d.Text ~= "/" then
				nameLabel = nameLabel or d
			end
			if d.Text == "RELOADING" then
				reloadOverlay = d.Parent
			end
		end
	end

	table.sort(numericLabels, function(a, b)
		if a.TextSize == b.TextSize then
			return a.AbsolutePosition.X < b.AbsolutePosition.X
		end
		return a.TextSize > b.TextSize
	end)
	ammoLabel = numericLabels[1]
	capLabel = numericLabels[2] or capLabel

	if not reloadOverlay then
		for _, d in ipairs(labels) do
			if d:IsA("Frame") and d.Visible == false and d.BackgroundTransparency < 1 then
				reloadOverlay = reloadOverlay or d
			end
		end
	end
	if reloadOverlay then
		for _, kid in ipairs(reloadOverlay:GetDescendants()) do
			if kid:IsA("Frame") and kid.Parent == reloadOverlay then
				reloadBarFill = reloadBarFill or kid:FindFirstChildWhichIsA("Frame") or kid
			end
		end
	end

	-- segments: pick first frame with >=10 direct frame children
	local function gatherSegments(root)
		for _, f in ipairs(root:GetDescendants()) do
			if f:IsA("Frame") then
				local count = 0
				for _, c in ipairs(f:GetChildren()) do
					if c:IsA("Frame") then count += 1 end
				end
				if count >= 10 then
					local ordered = {}
					for _, c in ipairs(f:GetChildren()) do
						if c:IsA("Frame") then table.insert(ordered, c) end
					end
					table.sort(ordered, function(a,b) return a.Position.X.Offset < b.Position.X.Offset end)
					return ordered
				end
			end
		end
	end
	segs = gatherSegments(panel) or {}

	refs.ammo = ammoLabel
	refs.cap = capLabel
	refs.name = nameLabel
	refs.segs = segs
	refs.reloadOverlay = reloadOverlay
	refs.reloadBarFill = reloadBarFill
	return refs
end

local function clonePreset(preset)
	if type(preset) ~= "table" then return nil end
	local copy = {}
	for className, classData in next, preset do
		if type(classData) == "table" then
			local inner = {}
			for k, v in next, classData do
				inner[k] = v
			end
			copy[className] = inner
		else
			copy[className] = classData
		end
	end
	return copy
end

const ROTATION_FACTORS = {
	Head = { Pitch = .6, Yaw = .575 };
	UpperTorso = { Pitch = .45, Yaw = .5; };
	LeftUpperArm = { Pitch = .575, Yaw = -.05 };
	RightUpperArm = { Pitch = .575, Yaw = -.05 };
	LeftLowerArm = { Pitch = .525, Yaw = -.05 };
	RightLowerArm = { Pitch = .525, Yaw = -.05 };
	LeftHand = { Pitch = .45, Yaw = -.05 };
	RightHand = { Pitch = .45, Yaw = -.05 };
	Torso = { Pitch = .4, Yaw = .2 };
	["Left Arm"] = { Pitch = .575, Yaw = -.05 };
	["Right Arm"] = { Pitch = .575, Yaw = -.05 };
	["Left Leg"] = { Pitch = 0, Yaw = -.01 };
	["Right Leg"] = { Pitch = 0, Yaw = -.01 };
}

local function roundNearestInterval(number, factor)
	return math.floor((number / factor) + .5) * factor
end

local function stepTowards(value, goal, rate)
	if math.abs(value - goal) < rate then
		return goal
	elseif value > goal then
		return value - rate
	else
		return value + rate
	end
end

local function promiseValue(object, prop, andThen)
	task.spawn(function()
		local timeOut = os.clock() + 10
		while not object[prop] do
			if os.clock() > timeOut then return end
			task.wait()
		end
		andThen(object[prop])
	end)
end

local function promiseChild(object, name, andThen)
	task.spawn(function()
		local child = object:WaitForChild(name, 10)
		if child then andThen(child) end
	end)
end

local function getTiltKey(motor: Motor6D)
	local name = motor.Name
	local p1 = motor.Part1 and motor.Part1.Name or ""
	if name:find("Root") or name:find("Waist") or p1:find("HumanoidRootPart") or p1:find("LowerTorso") then
		return "Root"
	end
	if name:find("Neck") or p1 == "Head" then
		return "Neck"
	end
	if name:find("Shoulder") or p1:find("UpperArm") or p1:find(" Arm") then
		if name:find("Right") or p1:find("Right") then return "RShoulder" end
		return "LShoulder"
	end
	if name:find("Hip") or p1:find("UpperLeg") or p1:find(" Leg") then
		if name:find("Right") or p1:find("Right") then return "RHip" end
		return "LHip"
	end
	return nil
end

local function zeroTilt()
	return {
		Root = CFrame.Angles(0,0,0);
		Neck = CFrame.Angles(0,0,0);
		RShoulder = CFrame.Angles(0,0,0);
		LShoulder = CFrame.Angles(0,0,0);
		RHip = CFrame.Angles(0,0,0);
		LHip = CFrame.Angles(0,0,0);
	}
end

function PlayerManager:_applyCameraEffects(toolConf, name)
	local cam = self.CameraController
	if not cam or not toolConf then return end
	if toolConf.Recoil then
		cam:ApplyRecoil(toolConf.Recoil)
	end
	if toolConf.Blur then
		local b = toolConf.Blur
		cam:PulseBlur(b.Size or 8, b.Duration or .12)
	end
end

function PlayerManager:_ensureGunHud()
	if self.__GunHudRefs then return self.__GunHudRefs end
	local refs = pickHudRefs(self.Player)
	self.__GunHudRefs = refs
	return refs
end

local function _colorForAmmo(ratio)
	if ratio < .25 then
		return Color3.fromRGB(190, 50, 40)
	elseif ratio < .5 then
		return Color3.fromRGB(205, 125, 35)
	else
		return Color3.fromRGB(225, 220, 210)
	end
end

function PlayerManager:_updateGunHud(pool)
	local refs = self:_ensureGunHud()
	if not refs or not pool then return end
	local ammo = pool.Ammo or 0
	local cap = pool.MaxAmmo or 0
	if refs.ammo then
		refs.ammo.Text = tostring(ammo)
		refs.ammo.TextColor3 = _colorForAmmo(cap > 0 and ammo / cap or 0)
	end
	if refs.cap then
		refs.cap.Text = tostring(cap)
	end
	if refs.segs and #refs.segs > 0 and cap > 0 then
		local ratio = ammo / cap
		for i, seg in ipairs(refs.segs) do
			local filled = i <= math.ceil(ratio * #refs.segs)
			seg.BackgroundTransparency = filled and 0 or 0.5
			seg.BackgroundColor3 = _colorForAmmo(ratio)
		end
	end
end

function PlayerManager:_setHudReload(active, progress)
	local refs = self:_ensureGunHud()
	if not refs then return end
	if refs.reloadOverlay then
		refs.reloadOverlay.Visible = active and true or false
	end
	if refs.reloadBarFill then
		if active then
			refs.reloadBarFill.Size = UDim2.new(progress or 0, 0, 1, 0)
		else
			refs.reloadBarFill.Size = UDim2.new(0, 0, 1, 0)
		end
	end
end

function PlayerManager.new(Player: Player)
	local self = setmetatable({}, PlayerManager)

	self.Player = Player
	self.PlayerJanitor = Janitor.new()
	self.GunManager = GunManager.Get()
	self.ReloadJanitor = Janitor.new()
	self.PlayerJanitor:Add(self.ReloadJanitor, "Cleanup", "ReloadJanitor")

	self.CameraController = CameraController.new(70)
	self.ToolManager = ToolManagerClient.new(Player)
	self.FpsCamera = FpsCamera
	self.BetterAnimate = nil
	self.BetterAnimateConn = nil
	self.DefaultClasses = nil

	self.Rotators = {}
	self.BindTag = "RealismHook"
	self.LastLookSend = 0
	self.LookAngles = { Pitch = 0, Yaw = 0 }
	self.RotationFactors = ROTATION_FACTORS
	self.RealismLoaded = true
	self.TiltMap = {}
	self.StrafeEnabled = true
	self.StrafeTickRate = 1/120
	self.StrafeDotThreshold = .6
	self.StrafeLastUpdate = 0
	self.StrafeTiltState = {
		Root = CFrame.identity;
		Neck = CFrame.identity;
		RShoulder = CFrame.identity;
		LShoulder = CFrame.identity;
		RHip = CFrame.identity;
		LHip = CFrame.identity;
	}

	self:_setupLookReplication()

	self.PlayerJanitor:Add(function()
		if not getmetatable(self) then return end
		if self.ViewportManager and self.ViewportManager.Destroy then
			self.ViewportManager:Destroy()
		end
		self.CameraController:Destroy()
	end, nil, "Cleanup")

	self.PlayerJanitor:Add(Player.CharacterAdded:Connect(function(Character)
		if not getmetatable(self) then return end
		self:BindCharacter(Character)
	end), "Disconnect", "OnCharacter")

	Input.AddClass("PlayerManager")
	Input.AddBind("PlayerManager", "Reload", Enum.KeyCode.R, Enum.InputActionType.Direction1D, {
		OnStart = function()
			if self.CurrentEquipped then
				self.GunManager:Reload(self.CurrentEquipped, 1)
			end
		end;
	})

	local function canAds()
		local weapon = self.CurrentEquipped
		if not weapon then return false end
		local conf = Tools[weapon]
		if not conf or conf.CanAds == false then return false end
		return true
	end

	self.PlayerJanitor:Add(UIS.InputBegan:Connect(function(input, processed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if processed then return end
			if self.ADS and canAds() then self.ADS:Toggle(true) end
		end
	end), "Disconnect", "ADSDown")
	self.PlayerJanitor:Add(UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.ADS and self.ADS.Active then self.ADS:Toggle(false) end
		end
	end), "Disconnect", "ADSUp")

	self.PlayerJanitor:Add(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.ADS and canAds() then self.ADS:Toggle(true) end
		end
	end), "Disconnect", "ADSDown")
	self.PlayerJanitor:Add(UIS.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			if self.ADS and self.ADS.Active then self.ADS:Toggle(false) end
		end
	end), "Disconnect", "ADSUp")

	if Player.Character then
		self:BindCharacter(Player.Character)
	end

	return self
end

function PlayerManager:_setupLookReplication()
	self.PlayerJanitor:Add(BlinkClient.LookAngles.On(function(payload)
		self:OnLookAngles(payload)
	end), nil, "LookAnglesListener")

	if BlinkClient.JointReplicator and BlinkClient.JointReplicator.On then
		self.PlayerJanitor:Add(BlinkClient.JointReplicator.On(function(player, payload)
			self:OnJointTilt(player, payload)
		end), nil, "JointReplicatorListener")
	end

	for _, humanoid in CollectionService:GetTagged(self.BindTag) do
		self:OnHumanoidTagged(humanoid)
	end

	self.PlayerJanitor:Add(CollectionService:GetInstanceAddedSignal(self.BindTag):Connect(function(humanoid)
		self:OnHumanoidTagged(humanoid)
	end), "Disconnect", "RealismTagListener")

	self.PlayerJanitor:Add(RunService.Heartbeat:Connect(function(delta)
		self:UpdateLookAngles(delta)
	end), "Disconnect", "LookAngleHeartbeat")
end

function PlayerManager:OnHumanoidTagged(humanoid: Instance)
	if not humanoid:IsA("Humanoid") then return end
	self:MountLookAngle(humanoid)
end

function PlayerManager:AddMotor(rotator, motor: Motor6D)
	if not self.RealismLoaded then return end
	local parent = motor.Parent
	if parent and parent.Name == "Head" then
		parent.CanCollide = false
	end
	promiseValue(motor, "Active", function()
		local data = {
			Motor = motor;
			C0 = motor.C0;
		}
		promiseChild(motor.Part0, motor.Name .. "RigAttachment", function(origin)
			if origin:IsA("Attachment") then
				data.Origin = origin
				data.C0 = nil
			end
		end)
		local id = motor.Part1.Name
		rotator.Motors[id] = data
	end)
end

function PlayerManager:MountLookAngle(humanoid: Humanoid)
	if not self.RealismLoaded then return nil end
	local character = humanoid.Parent
	if not character then return end

	local rotator = self.Rotators[character]
	if not rotator then
		rotator = {
			Motors = {};
			Pitch = { Goal = 0; Current = 0 };
			Yaw = { Goal = 0; Current = 0 };
			LookYaw = { Goal = 0; Current = 0 };
			Tilts = {};
		}

		local player = Players:GetPlayerFromCharacter(character)
		if player == self.Player then
			rotator.SnapFirstPerson = true
		end

		self.Rotators[character] = rotator

		local function onDescendantAdded(desc)
			if desc:IsA("Motor6D") then
				self:AddMotor(rotator, desc)
			end
		end

		for _, desc in next, character:GetDescendants() do
			onDescendantAdded(desc)
		end

		rotator.Listener = character.DescendantAdded:Connect(onDescendantAdded)
	end

	return rotator
end

function PlayerManager:OnLookReceive(player: Player, pitch: number, yaw: number, lookYaw: number)
	local character = player.Character
	local rotator = self.Rotators[character]
	if rotator then
		rotator.Pitch.Goal = pitch
		rotator.Yaw.Goal = yaw
		rotator.LookYaw.Goal = lookYaw or 0
	end
end

function PlayerManager:ComputeLookAngle(lookVector: Vector3?)
	local inFirstPerson = self.CameraController:IsInFirstPerson()
	local pitch, yaw, lookYaw, dir = 0, 0, 0, 1

	if not lookVector then
		local camera = workspace.CurrentCamera
		if camera then
			lookVector = camera.CFrame.LookVector
		end
	end

	if lookVector then
		local character = self.Player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")

		if rootPart and rootPart:IsA("BasePart") then
			local cf = rootPart.CFrame

			pitch = -cf.UpVector:Dot(lookVector)

			local rightDot = cf.RightVector:Dot(lookVector)
			lookYaw = math.clamp(rightDot, -1, 1)

			if not inFirstPerson then
				dir = math.clamp(cf.LookVector:Dot(lookVector) * 10, -1, 1)
			end
		end

		yaw = lookVector.Y
	end

	pitch *= dir
	yaw *= dir

	return pitch, yaw, lookYaw
end

function PlayerManager:StepValue(state, delta)
	if not self.RealismLoaded then return state.Current end
	local current = state.Current or 0
	local goal = state.Goal

	local pan = 5 / (delta * 60)
	local rate = math.min(1, (delta * 20) / 3)
	local step = math.min(rate, math.abs(goal - current) / pan)
	state.Current = stepTowards(current, goal, step)

	return state.Current
end

function PlayerManager:UpdateLookAngles(delta)
	if not self.RealismLoaded then return end

	local character = self.Player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and not self.Rotators[character] then
		self:MountLookAngle(humanoid)
	end

	local inFirstPerson = self.FpsCamera and self.FpsCamera:IsInFirstPerson()

	local pitch, yaw, lookYaw = self:ComputeLookAngle()
	pitch = math.clamp(pitch, -1, 1)
	yaw = math.clamp(yaw, -1, 1)
	lookYaw = math.clamp(lookYaw, -1, 1)
	self:OnLookReceive(self.Player, pitch, yaw, lookYaw)

	local now = os.clock()
	if (now - self.LastLookSend) > 0.15 then
		local rPitch = roundNearestInterval(pitch, 0.05)
		local rYaw = roundNearestInterval(yaw, 0.05)
		local rLookYaw = roundNearestInterval(lookYaw, 0.05)

		if rPitch ~= self.LookAngles.Pitch or rYaw ~= self.LookAngles.Yaw or rLookYaw ~= (self.LookAngles.LookYaw or 0) then
			self.LookAngles.Pitch = rPitch
			self.LookAngles.Yaw = rYaw
			self.LookAngles.LookYaw = rLookYaw
			self.LastLookSend = now

			BlinkClient.LookAngles.Fire({
				UserId = self.Player.UserId;
				Pitch = rPitch;
				Yaw = rYaw;
				LookYaw = rLookYaw;
			})
		end
	end

	local camera = workspace.CurrentCamera
	if not camera then return end

	local camPos = camera.CFrame.Position
	local dropList

	for trackedCharacter, rotator in next, self.Rotators do
		if not trackedCharacter.Parent then
			dropList = dropList or {}
			dropList[trackedCharacter] = true
			continue
		end

		local owner = Players:GetPlayerFromCharacter(trackedCharacter)
		local dist = owner and owner:DistanceFromCharacter(camPos) or 0

		if trackedCharacter == character and inFirstPerson then
			continue
		end

		local lastStep = rotator.LastStep or 0
		local stepDelta = now - lastStep

		local trackedHumanoid = trackedCharacter:FindFirstChildOfClass("Humanoid")
		local rootPart = trackedHumanoid and trackedHumanoid.RootPart
		if not rootPart then continue end

		self:StepValue(rotator.Pitch, stepDelta)
		self:StepValue(rotator.Yaw, stepDelta)
		self:StepValue(rotator.LookYaw, stepDelta)

		local motors = rotator.Motors
		rotator.LastStep = now

		if not motors then continue end

		local tool = trackedCharacter:FindFirstChildWhichIsA("Tool")

		if trackedCharacter == character and self.StrafeEnabled then
			if (now - self.StrafeLastUpdate) >= self.StrafeTickRate then
				self.StrafeLastUpdate = now
				local tilts = self:ComputeLocalTilts(delta)
				if tilts then
					rotator.Tilts = tilts

					local serialized = {}
					for k, cf in next, tilts do
						local rx, ry, rz = cf:ToEulerAnglesXYZ()
						serialized[k] = { rx, ry, rz }
					end

					BlinkClient.LookAngles.Fire({
						UserId = self.Player.UserId;
						Pitch = self.LookAngles.Pitch;
						Yaw = self.LookAngles.Yaw;
						LookYaw = self.LookAngles.LookYaw or 0;
						Tilts = serialized;
					})
				end
			end
		end

		for name, factors in next, self.RotationFactors do
			local data = motors[name]
			if not data then continue end

			local motor = data.Motor
			local origin = data.Origin

			if origin then
				local part0 = motor.Part0
				local setPart0 = origin.Parent
				if part0 and part0 ~= setPart0 then
					local newOrigin = part0:FindFirstChild(origin.Name)
					if newOrigin and newOrigin:IsA("Attachment") then
						origin = newOrigin
						data.Origin = newOrigin
					end
				end
				origin = origin.CFrame
			elseif data.C0 then
				origin = data.C0
			else
				continue
			end

			local fPitch = (rotator.Pitch.Current or 0) * factors.Pitch
			local fYaw = (rotator.Yaw.Current or 0) * factors.Yaw
			local fLookYaw = (rotator.LookYaw.Current or 0) * .35

			if rotator.SnapFirstPerson and name == "Head" then
				if self.CameraController:IsInFirstPerson() then
					fPitch = rotator.Pitch.Goal * factors.Pitch
					fYaw = rotator.Yaw.Goal * factors.Yaw
					fLookYaw = rotator.LookYaw.Goal * .35
				end
			end

			if name:sub(-4) == " Arm" or name:sub(-8) == "UpperArm" then
				local t = tool or trackedCharacter:FindFirstChildOfClass("Tool")
				if t and not CollectionService:HasTag(t, "NoArmRotation") then
					if name:sub(1, 5) == "Right" and rootPart:GetRootPart() ~= rootPart then
						fPitch = (rotator.Pitch.Current or 0) * 1.3
						fYaw = (rotator.Yaw.Current or 0) * 1.3
					else
						fYaw = (rotator.Yaw.Current or 0) * .8
					end
				end
			end

			local rot = origin - origin.Position
			local tiltCf
			if rotator.Tilts then
				local tiltKey = getTiltKey(motor)
				if tiltKey and rotator.Tilts[tiltKey] then
					tiltCf = rotator.Tilts[tiltKey]
				end
			end

			local cf
			if tiltCf then
				cf = tiltCf * CFrame.Angles(-fPitch, fLookYaw, 0) * CFrame.Angles(0, fYaw, 0)
			else
				cf = CFrame.Angles(-fPitch, fLookYaw, 0) * CFrame.Angles(0, fYaw, 0)
			end

			motor.C0 = origin * rot:Inverse() * cf * rot
		end
	end

	if dropList then
		for trackedCharacter in next, dropList do
			local rotator = self.Rotators[trackedCharacter]
			local listener = rotator and rotator.Listener
			if listener then listener:Disconnect() end
			self.Rotators[trackedCharacter] = nil
		end
	end
end

function PlayerManager:OnLookAngles(payload)
	if not self.RealismLoaded then return end
	if type(payload) ~= "table" then return end

	local userId = payload.UserId
	local pitch = payload.Pitch
	local yaw = payload.Yaw
	local lookYaw = payload.LookYaw
	local tilts = payload.Tilts

	if type(userId) ~= "number" or type(pitch) ~= "number" or type(yaw) ~= "number" then return end

	pitch = math.clamp(pitch, -1, 1)
	yaw = math.clamp(yaw, -1, 1)
	lookYaw = type(lookYaw) == "number" and math.clamp(lookYaw, -1, 1) or 0

	if userId == self.Player.UserId then return end

	local targetPlayer = Players:GetPlayerByUserId(userId)
	if not targetPlayer then return end

	local character = targetPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local rotator = self:MountLookAngle(humanoid)
	if not rotator then return end

	rotator.Pitch.Goal = pitch
	rotator.Yaw.Goal = yaw
	rotator.LookYaw = rotator.LookYaw or { Goal = 0; Current = 0 }
	rotator.LookYaw.Goal = lookYaw

	if tilts and type(tilts) == "table" then
		local decoded = {}
		for k, v in next, tilts do
			if type(v) == "table" and #v == 3 then
				decoded[k] = CFrame.Angles(v[1], v[2], v[3])
			end
		end
		rotator.Tilts = decoded
	end
end

function PlayerManager:ComputeLocalTilts(dt)
	local character = self.Player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not hrp then return nil end

	local TiltMultipliersBase = {
		ForwardZ = 5;
		ForwardRoll = 25;
		ForwardNeck = 15;
		DiagonalZ = 5;
		DiagonalRoll = 25;
		DiagonalNeck = 25;
		DiagonalLimb = 10;
		StraightZ = 10;
		SideRoll = 35;
		SideNeck = 35;
		SideLimb = 15;
	}

	local TiltMultipliers = {}
	local walkSpeed = math.min(humanoid.WalkSpeed, 50)
	local defaultWalk = math.min(game:GetService("StarterPlayer").CharacterWalkSpeed, 50)
	for i, v in next, TiltMultipliersBase do
		TiltMultipliers[i] = v * walkSpeed / (defaultWalk / (defaultWalk / 16))
	end

	local MoveDirection = hrp.CFrame:VectorToObjectSpace(humanoid.MoveDirection)

	local Directions = {
		{ Name = "FW_R"; Dir = vector.normalize(vector.create(1, 0, -1)); Weight = 1; Tilts = function(md, s)
			local neckS = math.clamp(s, 0, .15)
			s = math.clamp(s, 0, .8)
			return {
				Root = CFrame.Angles(math.rad(-md.Z) * TiltMultipliers.ForwardZ * s, 0, math.rad(-md.X) * TiltMultipliers.ForwardRoll * s * .4);
				Neck = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.ForwardZ * neckS, 0, math.rad(md.X) * TiltMultipliers.ForwardNeck * neckS * .2);
				RShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
				LShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
				RHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
				LHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
			}
		end };
		{ Name = "BW_R"; Dir = vector.normalize(vector.create(1, 0, 1)); Weight = 1; Tilts = function(md, s)
			local neckS = math.clamp(s, 0, .15)
			s = math.clamp(s, 0, .8)
			return {
				Root = CFrame.Angles(math.rad(-md.Z) * TiltMultipliers.DiagonalZ * s, 0, math.rad(md.X) * TiltMultipliers.DiagonalRoll * s * .4);
				Neck = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.DiagonalZ * neckS, 0, math.rad(-md.X) * TiltMultipliers.DiagonalNeck * neckS * .2);
				RShoulder = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
				LShoulder = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
				RHip = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
				LHip = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
			}
		end };
		{ Name = "BW_L"; Dir = vector.normalize(vector.create(-1, 0, 1)); Weight = 1; Tilts = function(md, s)
			local neckS = math.clamp(s, 0, .15)
			s = math.clamp(s, 0, .8)
			return {
				Root = CFrame.Angles(math.rad(-md.Z) * TiltMultipliers.DiagonalZ * s, 0, math.rad(md.X) * TiltMultipliers.DiagonalRoll * s * .4);
				Neck = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.DiagonalZ * neckS, 0, math.rad(-md.X) * TiltMultipliers.DiagonalNeck * neckS * .2);
				RShoulder = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
				LShoulder = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
				RHip = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
				LHip = CFrame.Angles(0, math.rad(md.X) * TiltMultipliers.DiagonalLimb * s * .45, 0);
			}
		end };
		{ Name = "FW_L"; Dir = vector.normalize(vector.create(-1, 0, -1)); Weight = 1; Tilts = function(md, s)
			local neckS = math.clamp(s, 0, .15)
			s = math.clamp(s, 0, .8)
			return {
				Root = CFrame.Angles(math.rad(-md.Z) * TiltMultipliers.ForwardZ * s, 0, math.rad(-md.X) * TiltMultipliers.ForwardRoll * s * .4);
				Neck = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.ForwardZ * neckS, 0, math.rad(md.X) * TiltMultipliers.ForwardNeck * neckS * .2);
				RShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
				LShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
				RHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
				LHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.DiagonalLimb * s * .4, 0);
			}
		end };
		{ Name = "R"; Dir = vector.create(1, 0, 0); Weight = 1.28; Tilts = function(md, s)
			local neckS = math.clamp(s, 0, .2)
			s = math.clamp(s, 0, .95)
			return {
				Root = CFrame.Angles(0, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .6);
				Neck = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.StraightZ * neckS * .6, math.rad(-md.X) * neckS * .3, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .18);
				RShoulder = CFrame.Angles(math.rad(-md.Z) * TiltMultipliers.StraightZ * s * .3, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				LShoulder = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.StraightZ * s * .3, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				RHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				LHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
			}
		end };
		{ Name = "L"; Dir = vector.create(-1, 0, 0); Weight = 1.28; Tilts = function(md, s)
			local neckS = math.clamp(s, 0, .2)
			s = math.clamp(s, 0, .95)
			return {
				Root = CFrame.Angles(0, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .6);
				Neck = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.StraightZ * neckS * .6, math.rad(md.X) * neckS * .3, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .18);
				RShoulder = CFrame.Angles(math.rad(md.Z) * TiltMultipliers.StraightZ * s * .3, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				LShoulder = CFrame.Angles(math.rad(-md.Z) * TiltMultipliers.StraightZ * s * .3, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				RHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				LHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
			}
		end };
	}

	local Velocity = hrp.AssemblyLinearVelocity
	local HorizontalSpeed = vector.magnitude(Velocity * vector.create(1, 0, 1))
	local SpeedMult = math.clamp(HorizontalSpeed / 16, 0, 2)

	local CurrentTilts = zeroTilt()

	local CurrentTilts = zeroTilt()

	if MoveDirection ~= vector.zero then
		local blended = zeroTilt()
		local scores = {}
		local totalWeight = 0

		for _, data in next, Directions do
			local score = vector.dot(MoveDirection, data.Dir) * (data.Weight or 1)
			if score > 0 then
				scores[data] = score
				totalWeight = totalWeight + score
			end
		end

		if totalWeight > 0 then
			for data, score in next, scores do
				local tilts = data.Tilts(MoveDirection, SpeedMult * score)
				local alpha = score / totalWeight
				for key, cf in next, tilts do
					local rx1, ry1, rz1 = blended[key]:ToEulerAnglesXYZ()
					local rx2, ry2, rz2 = cf:ToEulerAnglesXYZ()
					blended[key] = CFrame.Angles(
						rx1 + rx2 * alpha,
						ry1 + ry2 * alpha,
						rz1 + rz2 * alpha
					)
				end
			end
		end

		CurrentTilts = blended
	end

	local alpha = math.clamp(dt * 10, 0, 1)
	for key, cf in next, CurrentTilts do
		local prev = self.StrafeTiltState[key] or CFrame.identity
		self.StrafeTiltState[key] = prev:Lerp(cf, alpha)
	end

	return self.StrafeTiltState
end

function PlayerManager:OnJointTilt(player: Player, payload)
	if type(payload) ~= "table" then return end
	local character = player and player.Character
	if not character then return end
	local rotator = self:MountLookAngle(character:FindFirstChildOfClass("Humanoid"))
	if not rotator then return end
	rotator.Tilts = payload
	rotator.TiltTime = os.clock()
end

function PlayerManager:BindCharacter(Character: Model)
	if self.PlayerJanitor:Get("CharacterRemoving") then
		self.PlayerJanitor:Remove("CharacterRemoving")
	end

	if self.Character and self.Rotators[self.Character] then
		local rot = self.Rotators[self.Character]
		local listener = rot.Listener
		if listener then listener:Disconnect() end
		self.Rotators[self.Character] = nil
	end

	self.Character = Character

	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local Animator = Humanoid:WaitForChild("Animator") :: Animator

	Animations.init(Animator)

	self.ViewportManager = ViewportManager.new({
		Type = "Advanced";
		ViewModel = {
			--[[XOffset = .62;
			YOffset = -.92;
			ZOffset = -.35;]]
			Size = vector.create(1, 2, 1);
		};
	})
	if self.ViewportManager then
		self.ViewportManager:SetArmMover("Left", false)
		self.ViewportManager:SetArmMover("Right", false)
	end
	self.ADS = ADS.new(self.CameraController, self.ViewportManager)

	self.EquipJanitor = Janitor.new()
	self.PlayerJanitor:Add(self.EquipJanitor, "Cleanup", "EquipJanitor")

	self.ToolManager.States.Equipped:Connect(function(slot: number?, _, weapon: string)
		local now = os.clock()
		if now - (self.LastEquipTime or 0) < 0.15 then return end
		self.LastEquipTime = now
		if self.CurrentEquipped == weapon and self.CurrentEquippedSlot == slot then return end

		self.CurrentEquipped = weapon
		self.CurrentEquippedSlot = slot
		self.EquipJanitor:Cleanup()

		if self.CurrentEquippingTrack then
			advents.animator.stopAnim(self.CurrentEquippingTrack)
			self.CurrentEquippingTrack = nil
		end
		if self.CurrentEquipPromise and self.CurrentEquipPromise.cancel then
			self.CurrentEquipPromise:cancel()
			self.CurrentEquipPromise = nil
		end

		local toolData = weapon and Tools[weapon]
		if self.ADS then
			self.ADS:SetEquipped(weapon, toolData)
			self.ADS:Toggle(false)
		end
		if toolData and toolData.Ammo and self.GunManager then
			self:_updateGunHud(self.GunManager:GetState(weapon))
		else
			self:_updateGunHud(nil)
		end
		local hud = self:_ensureGunHud()
		if hud and hud.name then
			hud.name.Text = string.upper(weapon or "")
		end
		if hud and hud.panel then
			hud.panel.Visible = weapon ~= nil and toolData and toolData.Ammo ~= nil
		end
		self.CurrentBaseRotation = nil
		local baseCfg = toolData and toolData.ViewportConfigs
		if baseCfg and baseCfg.Rotation then
			self.CurrentBaseRotation = {
				X = baseCfg.Rotation.X or 0;
				Y = baseCfg.Rotation.Y or 0;
				Z = baseCfg.Rotation.Z or 0;
			}
		end

		self:ChangeToDefault("Idle")
		self:ChangeToDefault("Run")
		self:ChangeToDefault("Walk")

		local ToolAnimation = Animations.LoadedAnimations.Weapons[weapon]

		if self.ViewportManager then
			self.ViewportManager:SetArmMover("Left", false)
			self.ViewportManager:SetArmMover("Right", false)

			local toolData = Tools[weapon]
			local ViewportConfig = toolData and toolData.ViewportConfigs
			if ViewportConfig then
				for config, value in next, ViewportConfig do
					self.ViewportManager:ChangeConfig(config, value)
				end
			end
		end
		if self.CameraController and self.CameraController.SetToolOffset then
			self.CameraController:SetToolOffset(vector.zero)
		end

		self:_setupToolMovementAnims(ToolAnimation)

		local targetSlot = slot
		local sendEquip = function()
			if BlinkClient and BlinkClient.StateUpdate and BlinkClient.StateUpdate.Fire then
				BlinkClient.StateUpdate.Fire({
					Id = targetSlot or 0;
					Name = weapon;
					NewState = "ToolEquip";
					Brute = true;
				})
			end
			local armConf = Tools[weapon] and Tools[weapon].Arms
			if armConf and self.ViewportManager then
				self.ViewportManager:SetArmMover("Left", armConf.Left ~= false)
				self.ViewportManager:SetArmMover("Right", armConf.Right ~= false)
			end
		end

		if self.CameraController and self.CameraController.SetToolOffset then
			local cam = workspace.CurrentCamera
			local offsetCf = CFrame.new()
			if cam then
				local toolInst = self.Character and self.Character:FindFirstChildWhichIsA("Tool")
				local primary = toolInst and (toolInst.PrimaryPart or toolInst:FindFirstChildWhichIsA("BasePart"))
				if primary then
					local rel = cam.CFrame:ToObjectSpace(primary.CFrame)
					local p = rel.Position * 10
					local rawPos = vector.create(
						math.clamp(p.X, -24, 24),
						math.clamp(p.Y, -24, 24),
						math.clamp(p.Z, -24, 24)
					)
					offsetCf = CFrame.new(rawPos.X, rawPos.Y, rawPos.Z) * (rel - rel.Position)
				elseif toolData and toolData.CameraOffset then
					local v = toolData.CameraOffset
					offsetCf = CFrame.new(v.X * 2.4, v.Y * 2.4, v.Z * 2.4)
				end
			end
			self.CameraController:SetToolOffset(offsetCf)
		end

		self.CurrentEquipPromise = Promise.new(function(resolve, _, onCancel)
			local cancelled = false
			local fired = false
			onCancel(function()
				cancelled = true
				if self.CurrentEquippingTrack then
					advents.animator.stopAnim(self.CurrentEquippingTrack)
					if self.CurrentEquippingTrack.Destroy then
						self.CurrentEquippingTrack:Destroy()
					end
					self.CurrentEquippingTrack = nil
				end
				return true
			end)

			local function finalize()
				if cancelled or fired then return end
				fired = true
				sendEquip()
				resolve()
			end

			if ToolAnimation and ToolAnimation.Equip then
				local animator = self.Character and self.Character:FindFirstChildOfClass("Humanoid") and self.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")

				local track = advents.animator.playAnim(self.Character.Humanoid.Animator, ToolAnimation.Equip.loaded)
				self.CurrentEquippingTrack = track
				track.Priority = Enum.AnimationPriority.Action4

				local markerConn = track:GetMarkerReachedSignal("EquipAt"):Connect(function()
					finalize()
				end)
				self.EquipJanitor:Add(markerConn, "Disconnect")
				self.EquipJanitor:Add(track.Stopped:Connect(function()
					finalize()
					if self.CurrentEquippingTrack == track then
						self.CurrentEquippingTrack = nil
					end
					if track.Destroy then track:Destroy() end
				end), "Disconnect")

				task.delay(0.75, function()
					finalize()
				end)
			else
				finalize()
			end
		end)
		self.EquipJanitor:Add(function()
			if self.CurrentEquipPromise and self.CurrentEquipPromise.cancel then
				self.CurrentEquipPromise:cancel()
				self.CurrentEquipPromise = nil
			end
		end, nil, "EquipPromise")

		self.EquipJanitor:Add(RunService.Heartbeat:Connect(function()
			if not self.CameraController or not self.CameraController.SetToolOffset then return end
			local cam = workspace.CurrentCamera
			local toolInst = self.Character and self.Character:FindFirstChildWhichIsA("Tool")
			local primary = toolInst and (toolInst.PrimaryPart or toolInst:FindFirstChildWhichIsA("BasePart"))
			if not cam or not primary then
				self.CameraController:SetToolOffset(vector.zero)
				return
			end
			local rel = cam.CFrame:ToObjectSpace(primary.CFrame)
			local p = rel.Position * 10
			local rawPos = vector.create(
				math.clamp(p.X, -24, 24),
				math.clamp(p.Y, -24, 24),
				math.clamp(p.Z, -24, 24)
			)
			local offsetCf = CFrame.new(rawPos.X, rawPos.Y, rawPos.Z) * (rel - rel.Position)
			self.CameraController:SetToolOffset(offsetCf)
		end), "Disconnect")
	end)

	self.ToolManager.States.UnEquipped:Connect(function(prevSlot: number?, _, weapon: string)
		if self.CurrentEquipped == weapon then
			local suppress = self._suppressUnequip == weapon
			if suppress then
				self._suppressUnequip = nil
			end
			self:ChangeToDefault("Idle")
			self:ChangeToDefault("Run")
			self:ChangeToDefault("Walk")
			self:_stopToolMovement()

			local ToolSetup = ToolSetups[weapon]
			if ToolSetup and ToolSetup.Cancel and not suppress then
				ToolSetup:Cancel()
			end
			if self.ToolManager and self.ToolManager.GetEquipLockOwner and self.ToolManager:GetEquipLockOwner() == weapon then
				self.ToolManager:SetEquipLocked(false)
			end

			if self.ADS then
				self.ADS:SetEquipped(nil, nil)
				self.ADS:Toggle(false)
			end
			local hud = self:_ensureGunHud()
			if hud and hud.panel then
				hud.panel.Visible = false
			end

			self.EquipJanitor:Cleanup()

			if BlinkClient and BlinkClient.StateUpdate and BlinkClient.StateUpdate.Fire then
				if not suppress then
					BlinkClient.StateUpdate.Fire({
						Id = 0;
						NewState = "ToolEquip";
						Brute = true;
					})
				end
			end

			if self.CurrentEquippingTrack then
				advents.animator.stopAnim(self.CurrentEquippingTrack)
				self.CurrentEquippingTrack = nil
			end

			self.ViewportManager:SetArmMover("Right", false)
			self.ViewportManager:SetArmMover("Left", false)

			if self.CameraController and self.CameraController.SetToolOffset then
				self.CameraController:SetToolOffset(vector.zero)
			end

			if self.GunManager then
				self.GunManager:CancelReload()
			end
			if self.ReloadJanitor then
				self.ReloadJanitor:Cleanup()
			end

			self.CurrentEquipped = nil
			self.CurrentEquippedSlot = nil
		end
	end)

	self.ToolManager.States.Activated:Connect(function(slot: number?, item)
		if not self.ToolCooldowns then
			self.ToolCooldowns = {}
		end

		local toolConf = item and Tools[item.name] or nil
		if not toolConf then return end

		if not self.ToolCooldowns[item.name] then
			self.ToolCooldowns[item.name] = 0
		end

		local cooldown = toolConf.Cooldown or 0
		if os.clock() - self.ToolCooldowns[item.name] < cooldown then
			return
		end

		self.ToolCooldowns[item.name] = os.clock()

		local ToolUser = ToolSetups[item.name]
		local UseData = {}

		local CurrentEquippingTrack = self.CurrentEquippingTrack :: AnimationTrack
		if CurrentEquippingTrack then
			local RequiredTimeFrame: number = Tools[item.name].ReadyAt
			if RequiredTimeFrame then
				if CurrentEquippingTrack.TimePosition < RequiredTimeFrame then
					return
				end
			end
		end

		if ToolUser and ToolUser.Use then
			if ToolUser.ViewportConfigs then
				for config, value in next, ToolUser.ViewportConfigs do
					self.ViewportManager:ChangeConfig(config, value)
				end
			end
			UseData = ToolUser:Use(Tools[item.name])
			local baseCfg = Tools[item.name].ViewportConfigs
			local adsCfg = Tools[item.name].AdsViewportConfigs
			local applyCfg = (self.ADS and self.ADS.Active and adsCfg) or baseCfg
			if applyCfg then
				self.ViewportManager:ChangeConfig("Rotation", applyCfg.Rotation or { X = 0; Y = 0; Z = 0 })
				for config, value in next, applyCfg do
					if config ~= "Rotation" then
						self.ViewportManager:ChangeConfig(config, value)
					end
				end
			end
		end
		if not UseData then
			UseData = {}
		elseif UseData.Cancel then
			if UseData.DryRecoil and self.ViewportManager then
				self.ViewportManager:ImpulseRecoil(vector.create(-0.005, 0.003, -0.008))
				if self.CameraController and self.CameraController.Recoil and self.CameraController.Recoil.Kick then
					self.CameraController.Recoil:Kick(0.35)
				end
			end
			return
		end

		if toolConf and toolConf.AutoUnequipOnUse and self.ToolManager then
			self._suppressUnequip = item.name
			self.ToolManager:_setEquipped(nil)
		end

		self:_applyCameraEffects(toolConf, item.name)
		if self.ViewportManager and toolConf and toolConf.Recoil then
			local mul = toolConf.Recoil.multiplier or 1
			local impulse = vector.create(-0.01 * mul, 0.006 * mul, -0.012 * mul)
			self.ViewportManager:ImpulseRecoil(impulse)
		end

		local usePromise = type(UseData) == "table" and UseData.Promise or nil
		local serverPromise = type(UseData) == "table" and (UseData.ServerPromise or usePromise) or nil
		local lockEquip = type(UseData) == "table" and UseData.LockEquip or nil
		local deferServer = type(UseData) == "table" and UseData.DeferServer or nil

		if lockEquip and self.ToolManager then
			self.ToolManager:SetEquipLocked(true, item.name)
		end

		local Data = {
			name = item.name;
		}

		if type(UseData) == "table" and next(UseData) then
			for i,v in next, UseData do
				if i ~= "Promise" and i ~= "LockEquip" and i ~= "DeferServer" then
					Data[i] = v
				end
			end
		end

		local function unlockEquip()
			if lockEquip and self.ToolManager then
				self.ToolManager:SetEquipLocked(false)
			end
		end

		local function fireServer()
			if not slot or not item then return end
			if BlinkClient and BlinkClient.ActiveTool and BlinkClient.ActiveTool.Fire then
				BlinkClient.ActiveTool.Fire(slot, item.name, Data)
			elseif BlinkClient and BlinkClient.StateUpdate and BlinkClient.StateUpdate.Fire then
				BlinkClient.StateUpdate.Fire({
					Id = slot;
					Name = item.name;
					NewState = "ToolActivate";
					Data = Data;
				})
			end
		end

		if deferServer and serverPromise and serverPromise.andThen then
			serverPromise:andThen(function()
				fireServer()
			end):catch(function()
			end):finally(function()
				unlockEquip()
			end)
			return
		end

		fireServer()
		local unlockTarget = usePromise or serverPromise
		if unlockTarget and unlockTarget.finally then
			unlockTarget:finally(function()
				unlockEquip()
			end)
		end
	end)

	if self.ToolManager and self.ToolManager.States and self.ToolManager.States.Ads then
		self.ToolManager.States.Ads:Connect(function(on, item, toolConf)
			local name = item and item.name or self.CurrentEquipped
			toolConf = toolConf or (name and Tools[name])
			if self.CameraController and self.CameraController.Recoil and self.CameraController.Recoil.Aim then
				self.CameraController.Recoil:Aim(on == true)
			end
			if self.ViewportManager then
				local cfg = nil
				if on and toolConf and toolConf.AdsViewportConfigs then
					cfg = toolConf.AdsViewportConfigs
				elseif toolConf and toolConf.ViewportConfigs then
					cfg = toolConf.ViewportConfigs
				end
				if cfg then
					if cfg.Rotation then
						self.CurrentBaseRotation = {
							X = cfg.Rotation.X or 0;
							Y = cfg.Rotation.Y or 0;
							Z = cfg.Rotation.Z or 0;
						}
					end
					for k, v in next, cfg do
						self.ViewportManager:ChangeConfig(k, v)
					end
				end
			end
		end)
	end

	if self.GunManager then
		self.GunManager.ReloadTick:Connect(function(name: string, cycle: number)
			if name ~= self.CurrentEquipped then return end
			local character = self.Character
			if not character then return end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
			local animSet = Animations.LoadedAnimations.Weapons[name]
			local reloadTable = animSet and animSet.Reload
			local reloadSet = reloadTable and (reloadTable[tostring(cycle)] or reloadTable["1"])
			local clip = reloadSet and reloadSet.loaded
			if animator and clip then
				if self.ReloadJanitor then
					self.ReloadJanitor:Cleanup()
				end
				if self.ReloadTrack then
					advents.animator.stopAnim(self.ReloadTrack, .12)
					self.ReloadTrack = nil
				end
				self.ReloadTrack = advents.animator.playAnim(animator, clip, .18)
				if self.ReloadTrack then
					self.ReloadTrack.Priority = Enum.AnimationPriority.Action4
					local fired = false
					local marker = self.ReloadTrack:GetMarkerReachedSignal("ReloadAt"):Connect(function()
						if fired then return end
						fired = true
						self.GunManager.ReloadCommit:Fire(name)
					end)
					local stopped = Promise.fromEvent(self.ReloadTrack.Stopped)
					local lengthWait = Promise.delay(math.max(self.ReloadTrack.Length or 0.6, 0.6) + 0.25)
					Promise.any({stopped, lengthWait}):andThen(function()
						if not fired then
							fired = true
							self.GunManager.ReloadCommit:Fire(name)
						end
						self.ReloadTrack = nil
						local pool = self.GunManager and self.GunManager:GetState(name)
						if pool then
							self:_setHudReload(true, math.min(1, (pool.Ammo or 0) / (pool.MaxAmmo or 1)))
						end
					end)
					if self.ReloadJanitor then
						self.ReloadJanitor:Add(marker, "Disconnect", "ReloadMarker")
						self.ReloadJanitor:Add(self.ReloadTrack, "Stop", "ReloadTrack")
					end
				end
			else
				-- no clip available; commit immediately so loop continues
				self.GunManager.ReloadCommit:Fire(name)
			end
		end)
		self.GunManager.ReloadingSignal:Connect(function(name: string, on: boolean)
			if not on then
				if self.ReloadTrack then
					advents.animator.stopAnim(self.ReloadTrack, .28)
					self.ReloadTrack = nil
				end
				if self.ReloadJanitor then
					self.ReloadJanitor:Cleanup()
				end
			else
				if toolData and toolData.Ammo then
					self:_setHudReload(true, 0)
				end
			end
		end)
		self.GunManager.AmmoSignal:Connect(function(name: string, pool)
			if name ~= self.CurrentEquipped then return end
			self:_updateGunHud(pool)
			if self.GunManager:IsReloading(name) then
				self:_setHudReload(true, math.min(1, (pool.Ammo or 0) / (pool.MaxAmmo or 1)))
			else
				self:_setHudReload(false, 0)
			end
		end)

		-- side-tilt for viewmodel while moving
		self.PlayerJanitor:Add(RunService.Heartbeat:Connect(function(dt)
			if not self.ViewportManager then return end
			if not self.CurrentBaseRotation then return end
			local character = self.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			if not humanoid or not hrp then return end
			local md = hrp.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
			local side = math.clamp(md.X, -1, 1)
			local targetRoll = side * 6
			self._vmRoll = self._vmRoll or 0
			self._vmRoll = self._vmRoll + (targetRoll - self._vmRoll) * math.clamp(dt * 8, 0, 1)
			local base = self.CurrentBaseRotation
			self.ViewportManager:ChangeConfig("Rotation", {
				X = base.X;
				Y = base.Y;
				Z = base.Z + self._vmRoll;
			})
		end), "Disconnect", "VmSideTilt")
	end

	self.LastLookSend = 0
	self.LookAngles = { Pitch = 0; Yaw = 0; LookYaw = 0 }
	self.LastEquipTime = 0

	self:MountLookAngle(Humanoid)
	if self.ADS then
		self.ADS:SetHumanoid(Humanoid)
	end
	if self.BetterAnimate and self.BetterAnimate.Destroy then
		self.BetterAnimate:Destroy()
	end
	self.BetterAnimate = BetterAnimate.New(Character) --JOIN VC PLS

	self.BetterAnimate:SetInverseEnabled(true)
	self.BetterAnimate.FastConfig.SetAnimationOnIdDifference = true
	self.BetterAnimate.FastConfig.AnimationPlayTransition = .35
	self.BetterAnimate.FastConfig.AnimationStopTransition = .35

	--[[
	self.PlayerJanitor:Add(Humanoid:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		local BaseFieldOfView = self.ViewportManager.Configs.BaseFieldOfView;
		if BaseFieldOfView then
			local fovMultipler = math.clamp(Humanoid.WalkSpeed / 11, 1, 2);
			print("mul:", fovMultipler);
			self.ViewportManager:ChangeConfig(
				"BaseFieldOfView",
				70 * math.lerp(fovMultipler, 1, 0.75)
			);
		end
	end), "Disconnect", "WalkSpeedHook")
	]]

	local preset = BetterAnimate.GetClassesPreset(Humanoid.RigType.Name)
	if preset then
		self.DefaultClasses = clonePreset(preset)
		self.BetterAnimate:SetClassesPreset(preset)
	end

	if self.BetterAnimateConn then
		self.BetterAnimateConn:Disconnect()
	end
	self.BetterAnimateConn = RunService.Heartbeat:Connect(function(dt)
		if self.BetterAnimate and self.BetterAnimate.Step then
			local humanoid = self.Character and self.Character:FindFirstChildOfClass("Humanoid")
			local root = humanoid and humanoid.RootPart
			if humanoid and root then
				self.BetterAnimate.FastConfig.MoveDirection = root.CFrame:VectorToObjectSpace(humanoid.MoveDirection)
				self.BetterAnimate:Step(dt, humanoid:GetState().Name)
			end
		end
	end)

	self.PlayerJanitor:Add(self.Player.CharacterRemoving:Connect(function()
		if self.ViewportManager then
			self.ViewportManager:Destroy()
			self.ViewportManager = nil
		end
		if self.ADS then
			self.ADS:Toggle(false)
			self.ADS:SetHumanoid(nil)
		end
		self:_stopToolMovement()
		if self.Character and self.Rotators[self.Character] then
			local rot = self.Rotators[self.Character]
			local listener = rot.Listener
			if listener then listener:Disconnect() end
			self.Rotators[self.Character] = nil
		end
		self.Character = nil
	end), "Disconnect", "CharacterRemoving")
end

function PlayerManager:Cleanup()
	if not getmetatable(self) then return end
	if self.BetterAnimate and self.BetterAnimate.Destroy then
		self.BetterAnimate:Destroy()
		self.BetterAnimate = nil
	end
	if self.BetterAnimateConn then
		self.BetterAnimateConn:Disconnect()
		self.BetterAnimateConn = nil
	end

	for i,v in next, ToolSetups do
		if ToolSetups.Cancel then
			ToolSetups:Cancel()
		end
	end

	self:_stopToolMovement()

	self.PlayerJanitor:Destroy()
	setmetatable(self, nil)
end

function PlayerManager:_stopToolMovement()
	if self.ToolMoveTrack then
		advents.animator.stopAnim(self.ToolMoveTrack, .2)
	end
	if self.ToolHoldTrack then
		advents.animator.stopAnim(self.ToolHoldTrack, .2)
	end
	self.ToolMoveTrack = nil
	self.ToolHoldTrack = nil
	self.ToolMoveState = nil
	self.ToolIdleAnim = nil
	self.ToolHoldAnim = nil
	if self.ToolMoveConn then
		self.ToolMoveConn:Disconnect()
		self.ToolMoveConn = nil
	end
	if self.ToolHoldConn then
		self.ToolHoldConn:Disconnect()
		self.ToolHoldConn = nil
	end
end

function PlayerManager:_playToolMovement(state: "Idle" | "Stop", force: boolean?)
	if self.ToolMoveState == state and not force then return end
	self.ToolMoveState = state
	local animator = self.Character and self.Character:FindFirstChildOfClass("Humanoid") and self.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	if not animator then return end
	if self.ToolMoveTrack then
		advents.animator.stopAnim(self.ToolMoveTrack, .18)
		self.ToolMoveTrack = nil
	end
	if state == "Stop" then return end
	local anim = self.ToolIdleAnim
	if not anim then return end
	if anim:IsA("AnimationTrack") then
		anim.Priority = Enum.AnimationPriority.Action
		anim.Looped = true
	elseif anim.AnimationPriority then
		anim.AnimationPriority = Enum.AnimationPriority.Action
		if anim:IsA("Animation") and anim:GetAttribute("Looped") ~= nil then
			anim:SetAttribute("Looped", true)
		end
	end
	if anim.Looped ~= nil then
		anim.Looped = true
	end
	local track = advents.animator.playAnim(animator, anim, .18)
	if track then
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
	end
	self.ToolMoveTrack = track
end

function PlayerManager:_setupToolMovementAnims(ToolAnimation)
	self:_stopToolMovement()
	if not ToolAnimation then return end
	self.ToolIdleAnim = ToolAnimation.Idle and ToolAnimation.Idle.loaded or nil
	self.ToolHoldAnim = ToolAnimation.Hold and ToolAnimation.Hold.loaded or nil
	local humanoid = self.Character and self.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	if self.ToolHoldAnim then
		local function playHold()
			local animator = self.Character and self.Character:FindFirstChildOfClass("Humanoid") and self.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
			if not animator then return end
			if self.ToolHoldTrack then
				advents.animator.stopAnim(self.ToolHoldTrack, .18)
				self.ToolHoldTrack = nil
			end
			local anim = self.ToolHoldAnim
			if anim:IsA("AnimationTrack") then
				anim.Priority = Enum.AnimationPriority.Action
				anim.Looped = true
			elseif anim.AnimationPriority then
				anim.AnimationPriority = Enum.AnimationPriority.Action
				if anim:IsA("Animation") and anim:GetAttribute("Looped") ~= nil then
					anim:SetAttribute("Looped", true)
				end
			end
			if anim.Looped ~= nil then
				anim.Looped = true
			end
			local track = advents.animator.playAnim(animator, anim, .18)
			if track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = true
			end
			self.ToolHoldTrack = track
		end
		playHold()
		self.ToolHoldConn = RunService.Heartbeat:Connect(function()
			if not humanoid.Parent then
				self:_stopToolMovement()
				return
			end
			if self.ToolHoldTrack and self.ToolHoldTrack.IsPlaying then return end
			playHold()
		end)
		if self.EquipJanitor then
			self.EquipJanitor:Add(self.ToolHoldConn, "Disconnect", "ToolHold")
		end
	else
		self:_playToolMovement("Idle")
		self.ToolMoveConn = RunService.Heartbeat:Connect(function()
			if not humanoid.Parent then
				self:_stopToolMovement()
				return
			end
			if not self.ToolMoveTrack or not self.ToolMoveTrack.IsPlaying then
				self:_playToolMovement("Idle", true)
			end
		end)
		if self.EquipJanitor then
			self.EquipJanitor:Add(self.ToolMoveConn, "Disconnect", "ToolMovement")
		end
	end
end

-- removed this implementation because BetterAnimate already supports
-- changes to walkspeed animation via its config
--[[
function PlayerManager:_updateAnimSpeeds(h: Humanoid?)
	if not h then return end
	local ba = self.BetterAnimate
	if not ba or not ba.SetClassAnimationSpeedAdjust then return end
	local base = math.max(h.WalkSpeed, 1)
	ba:SetClassAnimationSpeedAdjust("Walk", base)
	ba:SetClassAnimationSpeedAdjust("Run", base * 1.6)
end
]]

function PlayerManager:ChangeAnimation(className: string, anim: AnimationTrack | Animation | number)
	local ba = self.BetterAnimate
	if not ba then return end
	local animator = self.Character and self.Character:FindFirstChildOfClass("Humanoid") and self.Character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	local animData = anim
	if typeof(anim) == "Instance" and anim:IsA("AnimationTrack") then
		animData = anim.Animation or anim
	end
	ba:StopClassAnimation(className)
	ba:SetClassPreset(className, { Custom = animData })
	ba:PlayClassAnimation(className)
end

function PlayerManager:ChangeToDefault(className: string)
	local ba = self.BetterAnimate
	if not ba then return end
	ba:StopClassAnimation(className)
	if self.DefaultClasses and self.DefaultClasses[className] then
		ba:SetClassPreset(className, self.DefaultClasses[className])
		ba:PlayClassAnimation(className)
	else
		ba:StopClassAnimation(className)
	end
end

return PlayerManager
