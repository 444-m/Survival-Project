local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)

local Packages = ReplicatedStorage.Packages
local SharedPackages = ReplicatedStorage.Packages.Shared
local ClientPackages = ReplicatedStorage.Packages.Client

local Spring = advents.spring
local TableUtils = require(SharedPackages.TableUtils)
local Janitor = require(SharedPackages.Janitor)

local CameraController = require("../Controllers/Player/Camera/CameraController")
local ViewportAnimator = require("@self/ViewportAnimator")
local ViewportCollisions = require("@self/ViewportCollisions")

local Animations = require(ReplicatedStorage.Modules.Shared.Animations)

local ViewportManager = {}
ViewportManager.__index = ViewportManager

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

export type Configs = {
	FirstPersonFieldOfView: number?;
	BaseFieldOfView: number?;
	ViewModelSpeed: number?;
	Smoothing: number?;

	ViewModel: {
		XOffset: number;
		YOffset: number;
		ZOffset: number;

		Size: vector | Vector3;
		Rotation: {
			X: number;
			Y: number;
			Z: number;
		};
	};

	Sway: {
		SwayDecay: number;
		MaxSway: number;
		SwayBuildup: number;
	};

	Type: "Basic" | "Advanced"
}

local Presets: Configs = {
	BaseFieldOfView = 70;
	FirstPersonFieldOfView = 75;
	ViewModelSpeed = .35; -- alpha
	Smoothing = .65; -- alpha

	ViewModel = {
		XOffset = .8;
		YOffset = -1.05;
		ZOffset = -.2;

		Size = vector.create(.6, 2.5, .6); -- 0NLY APPLIES IF TYPE IS ADVANCED!!
		Rotation = { X = 0; Y = 0; Z = 0 };
	};

	Sway = {
		SwayDecay = 1.5;
		MaxSway = 3;
		SwayBuildup = .03;
	};

	Type = "Basic"
}

function ViewportManager.new(Configs: Configs)
	if Configs then
		assert(type(Configs) == "table", `expected type table for Configs got {typeof(Configs)}`)
	end

	Configs = Configs or {}
	Configs = TableUtils.mergeDeep(Presets, Configs)
	Configs.ViewModel.XOffset = math.abs(Configs.ViewModel.XOffset)

	local self = setmetatable({}, ViewportManager)

	self.Configs = Configs

	self.ViewportJanitor = Janitor.new()
	self.CameraManager = CameraController.new(Configs.BaseFieldOfView)

	self:Setup()
	self.IsInFirstPerson = false

	self.FovSpring = Spring.new(self.CameraManager:GetFieldOfView())
	self.SwaySpring = Spring.new(vector.zero)
	self.JumpSpring = Spring.new(vector.zero)
	self.RotSpring = Spring.new(vector.zero)
	self.RecoilSpring = Spring.new(vector.zero)

	self.FovSpring.s, self.FovSpring.d = 14, 1
	self.SwaySpring.s, self.SwaySpring.d = 0, 0
	self.RotSpring.s, self.RotSpring.d = 0, 0
	self.JumpSpring.s, self.JumpSpring.d = 8, .6
	self.RecoilSpring.s, self.RecoilSpring.d = 14, .82

	return self
end

function ViewportManager:ImpulseRecoil(vec: vector)
	if not self.RecoilSpring then return end
	self.RecoilSpring:impulse(vec or vector.zero)
end

function ViewportManager:Setup()
	if not Player then return false end

	local Character = Player.Character
	if not Character then return false end

	local Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	local isR15 = Humanoid.RigType == Enum.HumanoidRigType.R15

	local function findPart(names: {string})
		for _, name in next, names do
			local part = Character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				return part
			end
		end
		return nil
	end

	local Torso = findPart({ "UpperTorso", "LowerTorso", "Torso" }) :: Part
	if not Torso then
		Torso = Character:FindFirstChild("HumanoidRootPart") :: Part
	end
	local HRP = Character:WaitForChild("HumanoidRootPart") :: Part
	local Head = Character:WaitForChild("Head") :: Part
	local LeftArm = findPart(isR15 and { "LeftHand", "LeftLowerArm", "LeftUpperArm" } or { "Left Arm" }) :: Part
	local RightArm = findPart(isR15 and { "RightHand", "RightLowerArm", "RightUpperArm" } or { "Right Arm" }) :: Part
	if not (Torso and LeftArm and RightArm) then return false end

	local function findShoulder(side: string, arm: BasePart?): Motor6D?
		if not Torso then return nil end
		for _, name in next, { side .. " Shoulder", side .. "Shoulder" } do
			local m = Torso:FindFirstChild(name)
			if m and m:IsA("Motor6D") then
				return m
			end
		end
		for _, m in ipairs(Torso:GetDescendants()) do
			if m:IsA("Motor6D") then
				if arm and m.Part1 == arm then
					return m
				end
				local p1 = m.Part1 and m.Part1.Name or ""
				if string.find(p1, side) then
					return m
				end
			end
		end
		return nil
	end

	local RightShoulder = findShoulder("Right", RightArm)
	local LeftShoulder = findShoulder("Left", LeftArm)
	if not (RightShoulder and LeftShoulder) then return false end

	local Animator = Humanoid:WaitForChild("Animator") :: Animator

	local DefaultRightShoulderC0 = RightShoulder.C0
	local DefaultLeftShoulderC0 = LeftShoulder.C0
	self.Character = Character

	self.LeftArm, self.RightArm = LeftArm, RightArm
	self.Torso, self.HRP, self.Head = Torso, HRP, Head
	self.Humanoid, self.Animator = Humanoid, Animator
	self.RightShoulder, self.LeftShoulder = RightShoulder, LeftShoulder

	self.BaseArmSize = vector.create(1, 2, 1)
	self.DefaultArmSize = self.BaseArmSize
	self.DefaultRightShoulderC0, self.DefaultLeftShoulderC0 = DefaultRightShoulderC0, DefaultLeftShoulderC0
	self.ArmMover = { Left = true; Right = true }

	self.ViewportJanitor:Add(RunService.PreRender:Connect(function(dt)
		self.CameraManager:SetFov(self.FovSpring.p)
		local FirstPersonToggle = vector.magnitude(Head.Position :: vector - Camera.CFrame.Position) < 2
		self:ToggleFirstPerson(FirstPersonToggle)
	end), nil, "Handler")
end

local function toVec3(v)
	if typeof(v) == "Vector3" then return v end
	if typeof(v) == "vector" then
		return Vector3.new(v.x, v.y, v.z)
	end
	if type(v) == "table" and v.X and v.Y and v.Z then
		return Vector3.new(v.X, v.Y, v.Z)
	end
	if type(v) == "table" and v.x and v.y and v.z then
		return Vector3.new(v.x, v.y, v.z)
	end
	return nil
end

function ViewportManager:SetArmMover(side: "Left" | "Right", on: boolean)
	local flag = side == "Left" and "Left" or "Right"
	self.ArmMover[flag] = on and true or false

	local shoulder = flag == "Left" and self.LeftShoulder or self.RightShoulder
	local arm = flag == "Left" and self.LeftArm or self.RightArm
	if shoulder then
		if on then
			if self.IsInFirstPerson then
				self:_applyArmSize(flag)
			elseif arm then
				arm.Size = self.BaseArmSize
			end
			return
		end
		shoulder.C0 = flag == "Left" and self.DefaultLeftShoulderC0 or self.DefaultRightShoulderC0
		shoulder.Transform = CFrame.new()
	end
	if arm then
		arm.Size = self.BaseArmSize
	end
end

function ViewportManager:_applyArmSize(flag: "Left" | "Right")
	local arm = flag == "Left" and self.LeftArm or self.RightArm
	if not arm then return end
	if not self.IsInFirstPerson then
		arm.Size = self.BaseArmSize
		return
	end
	if self.ArmMover[flag] then
		if self.Configs.Type == "Advanced" then
			local sz = toVec3(self.Configs.ViewModel.Size) or self.BaseArmSize
			arm.Size = sz
		else
			arm.Size = self.BaseArmSize
		end
	else
		arm.Size = self.BaseArmSize
		arm.LocalTransparencyModifier = 0
	end
end

local function deepsearch(t: {}, key: any)
	local queue = {t}
	local head = 1
	while head <= #queue do
		local current = queue[head]
		head += 1
		for k, v in next, current do
			if k == key then return current, k end
			if type(v) == "table" then
				queue[#queue + 1] = v
			end
		end
	end
end

function deepset(t: {}, key: any, value: any)
	local tbl, k = deepsearch(t, key)
	if tbl then
		tbl[k] = value
	end
end

function ViewportManager:ChangeConfig(key: string, value: any)
	if key == "Rotation" then
		value = value or { X = 0; Y = 0; Z = 0 }
	end
	deepset(self.Configs, key, value)
	if key == "Size" then
		self:_applyArmSize("Left")
		self:_applyArmSize("Right")
	elseif key == "BaseFieldOfView" and not self.IsInFirstPerson then
		self.FovSpring.t = self.Configs.BaseFieldOfView
	elseif key == "FirstPersonFieldOfView" and self.IsInFirstPerson then
		self.FovSpring.t = self.Configs.FirstPersonFieldOfView
	end
end

function ViewportManager:ToggleFirstPerson(Toggle)
	if self.IsInFirstPerson == Toggle then return end
	self.IsInFirstPerson = Toggle

	local TorsoSmoothing = self.Torso.CFrame :: CFrame
	local SwayEnergy = 0
	local WalkingTimer, AirTimer = 0,0
	local WasAirborne = false
	local FinalCFrame = Camera.CFrame

	local Types = {
		Basic = function(dt: number)
			local CameraCFrame = Camera.CFrame
			local FoVScale = self.Configs.BaseFieldOfView / self.CameraManager:GetFieldOfView()
			local ArmDepth = self.Configs.ViewModel.ZOffset * FoVScale

			self.LeftArm.LocalTransparencyModifier, self.RightArm.LocalTransparencyModifier = 0,0 
			local rotCfg = self.Configs.ViewModel.Rotation or {X = 0, Y = 0, Z = 0}
			local rotCf = CFrame.Angles(math.rad(rotCfg.X or 0), math.rad(rotCfg.Y or 0), math.rad(rotCfg.Z or 0))

			if not SafeCheckInstance(self.HRP, workspace) or not SafeCheckInstance(self.Humanoid, workspace) then return end
			local Speed = vector.magnitude(self.HRP.AssemblyLinearVelocity) / self.Humanoid.WalkSpeed
			local MoveSign = math.sign(vector.dot(self.HRP.CFrame.LookVector, (vector.normalize(self.HRP.AssemblyLinearVelocity) * vector.create(1,0,1))))
			Speed = math.clamp(Speed, 0, 1)

			if Speed > .08 then
				WalkingTimer += dt * 8.5 * Speed
			else
				WalkingTimer *= .85
			end

			local BobOffset = CFrame.new(
				math.sin(WalkingTimer) * .02 * Speed,
				math.abs(math.cos(WalkingTimer)) * .015 * Speed,
				0
			)

			if Speed < .08 then
				local IdleTimer = tick() * 1.25
				BobOffset *= CFrame.new(
					math.sin(IdleTimer) * .0055,
					math.cos(IdleTimer * 2) * .0044,
					0
				)
			end	

			FinalCFrame = CameraCFrame * BobOffset

			local LeftWorld = FinalCFrame * CFrame.new(-self.Configs.ViewModel.XOffset, self.Configs.ViewModel.YOffset, ArmDepth) * CFrame.Angles(0, math.rad(-90), 0) * rotCf
			local RightWorld = FinalCFrame * CFrame.new(self.Configs.ViewModel.XOffset, self.Configs.ViewModel.YOffset, ArmDepth) * CFrame.Angles(0, math.rad(90), 0) * rotCf

			if self.ArmMover.Right then
				self.RightShoulder.C0 = self.RightShoulder.C0:Lerp(TorsoSmoothing:ToObjectSpace(RightWorld), self.Configs.ViewModelSpeed)
			end
			if self.ArmMover.Left then
				self.LeftShoulder.C0 = self.LeftShoulder.C0:Lerp(TorsoSmoothing:ToObjectSpace(LeftWorld), self.Configs.ViewModelSpeed)
			end
		end;

		Advanced = function(dt: number)
			if not SafeCheckInstance(self.Character, workspace) then return end
			if not SafeCheckInstance(self.Torso, workspace) then return end
			if not SafeCheckInstance(self.RightArm, workspace) or not SafeCheckInstance(self.LeftArm, workspace) then return end

			self.LeftArm.LocalTransparencyModifier, self.RightArm.LocalTransparencyModifier = 0,0

			if self.ArmMover.Left then
				self.LeftArm.Size = toVec3(self.Configs.ViewModel.Size) or self.BaseArmSize
			else
				self.LeftArm.Size = self.BaseArmSize
			end
			if self.ArmMover.Right then
				self.RightArm.Size = toVec3(self.Configs.ViewModel.Size) or self.BaseArmSize
			else
				self.RightArm.Size = self.BaseArmSize
			end

			TorsoSmoothing = TorsoSmoothing:Lerp(self.Torso.CFrame, self.Configs.Smoothing)

			local MouseDelta = UIS:GetMouseDelta()
			local MouseX, MouseY = math.clamp(MouseDelta.X, -35, 35), math.clamp(MouseDelta.Y, -35, 35)

			SwayEnergy += Vector2.new(MouseX, MouseY).Magnitude * self.Configs.Sway.SwayBuildup * dt - self.Configs.Sway.SwayDecay * dt
			SwayEnergy = math.clamp(SwayEnergy, 0, self.Configs.Sway.MaxSway)
			local Intensity = 1 + (SwayEnergy^2.4) * 3.2

			if not SafeCheckInstance(self.HRP, workspace) or not SafeCheckInstance(self.Humanoid, workspace) then return end
			local Speed = vector.magnitude(self.HRP.AssemblyLinearVelocity) / self.Humanoid.WalkSpeed
			local MoveSign = math.sign(vector.dot(self.HRP.CFrame.LookVector, (vector.normalize(self.HRP.AssemblyLinearVelocity) * vector.create(1,0,1))))
			Speed = math.clamp(Speed, 0, 1)

			if Speed > .08 then
				WalkingTimer += dt * 8.5 * Speed
			else
				WalkingTimer *= .85
			end

			local WalkPositionForce = vector.create(math.sin(WalkingTimer) * (.065 * MoveSign) * Speed, 
				math.cos(WalkingTimer * 2) * (.035 * MoveSign) * Speed, 
				math.sin(WalkingTimer * 1.5) * (.015 * MoveSign) * Speed)
			local MousePositionForce = vector.create(MouseX * .0055 * Intensity, MouseY * .0065 * Intensity, -MouseX * .0025 * Intensity)
			self.SwaySpring:accelerate(MousePositionForce + WalkPositionForce - self.SwaySpring.p * .15)

			local Airborne = self.Humanoid:GetState() == Enum.HumanoidStateType.Freefall

			if Airborne then
				AirTimer += dt
				self.JumpSpring:accelerate(vector.create(math.sin(tick() * 2) * .008, -.025 * math.min(AirTimer, 1), .035 * math.min(AirTimer, .8)))
			else
				if WasAirborne and AirTimer > .08 then
					local Impact = math.clamp(AirTimer * .85, .25, .95)
					self.JumpSpring:accelerate(vector.create(0, Impact * 1.4, -Impact * .6))
				end
				AirTimer = 0
			end

			if Airborne and not WasAirborne then
				self.JumpSpring:accelerate(vector.create(0, -.35, .22))
			end
			WasAirborne = Airborne
			self.JumpSpring:accelerate(-self.JumpSpring.p * .08)

			local WalkRotationForce = vector.create(math.cos(WalkingTimer) * (.055 * MoveSign) * Speed, math.sin(WalkingTimer) * (.065 * MoveSign) * Speed, math.sin(WalkingTimer * 2) * (.035 * MoveSign) * Speed)
			local MouseRotationForce = vector.create(
				-MouseY * .008 * Intensity,
				-MouseX * .009 * Intensity,
				-MouseX * .0055 * Intensity
			)
			self.RotSpring:accelerate(MouseRotationForce + WalkRotationForce - self.RotSpring.p * .18)

			local Position = vector.create(
				math.clamp(self.SwaySpring.p.X + self.JumpSpring.p.X, -.18, .18),
				math.clamp(self.SwaySpring.p.Y + self.JumpSpring.p.Y, -.25, .25),
				math.clamp(self.SwaySpring.p.Z + self.JumpSpring.p.Z, -.15, .15)
			)
			local Rotation = vector.create(
				math.clamp(self.RotSpring.p.X, -.35, .35),
				math.clamp(self.RotSpring.p.Y, -.35, .35),
				math.clamp(self.RotSpring.p.Z, -.28, .28)
			)
			Position += self.RecoilSpring.p
			Rotation += vector.create(self.RecoilSpring.p.Y * 2, self.RecoilSpring.p.X * 1.5, 0)
			Position += self.RecoilSpring.p
			Rotation += vector.create(self.RecoilSpring.p.Y * 2, self.RecoilSpring.p.X * 1.5, 0)

			local BobOffset = CFrame.new(
				math.sin(WalkingTimer) * .035 * Speed,
				math.abs(math.cos(WalkingTimer)) * .028 * Speed,
				0
			)

			if Speed < .08 then
				local IdleTimer = tick() * 1.25
				BobOffset *= CFrame.new(
					math.sin(IdleTimer) * .0055,
					math.cos(IdleTimer * 2) * .0044,
					0
				)
			end

			local FoVScale = self.Configs.BaseFieldOfView / self.CameraManager:GetFieldOfView()
			local ArmDepth = self.Configs.ViewModel.ZOffset * FoVScale - (1 + math.abs(self.Configs.ViewModel.ZOffset)+.15) * 
				((self.Configs.BaseFieldOfView - self.CameraManager:GetFieldOfView()) / self.CameraManager:GetFieldOfView())

			local SwayTransform = CFrame.new(Position) * CFrame.Angles(Rotation.x, Rotation.y, Rotation.z)
			local DesiredCFrame = Camera.CFrame * BobOffset * SwayTransform
			local rotCfg = self.Configs.ViewModel.Rotation or {X = 0, Y = 0, Z = 0}
			local rotCf = CFrame.Angles(math.rad(rotCfg.X or 0), math.rad(rotCfg.Y or 0), math.rad(rotCfg.Z or 0))
			FinalCFrame = DesiredCFrame

			local LeftWorld = FinalCFrame * CFrame.new(-self.Configs.ViewModel.XOffset, self.Configs.ViewModel.YOffset, ArmDepth) * CFrame.Angles(0, math.rad(-90), 0) * rotCf
			local RightWorld = FinalCFrame * CFrame.new(self.Configs.ViewModel.XOffset, self.Configs.ViewModel.YOffset, ArmDepth) * CFrame.Angles(0, math.rad(90), 0) * rotCf

			if self.ArmMover.Right then
				self.RightShoulder.C0 = self.RightShoulder.C0:Lerp(TorsoSmoothing:ToObjectSpace(RightWorld), self.Configs.ViewModelSpeed)
			end
			if self.ArmMover.Left then
				self.LeftShoulder.C0 = self.LeftShoulder.C0:Lerp(TorsoSmoothing:ToObjectSpace(LeftWorld), self.Configs.ViewModelSpeed)
			end
		end;
	}

	if not self.IsInFirstPerson then
		self.RightShoulder.C0, self.LeftShoulder.C0 = self.DefaultRightShoulderC0, self.DefaultLeftShoulderC0
		self.RightShoulder.Transform, self.LeftShoulder.Transform = CFrame.new(), CFrame.new()
		self.ViewportJanitor:Remove("ViewportConnection")
		self.FovSpring.t = self.Configs.BaseFieldOfView

		if SafeCheckInstance(self.RightArm, workspace) and SafeCheckInstance(self.LeftArm, workspace) then
			self.RightArm.Size, self.LeftArm.Size = self.BaseArmSize, self.BaseArmSize
		end
	else
		if SafeCheckInstance(self.RightArm, workspace) and SafeCheckInstance(self.LeftArm, workspace) then
			self.RightArm.LocalTransparencyModifier, self.LeftArm.LocalTransparencyModifier = 0,0
		end

		self.FovSpring.t = self.Configs.FirstPersonFieldOfView

		self.ViewportJanitor:Add(RunService.PreRender:Connect(function(dt)
			dt = math.clamp(dt, 0, 1/30)

			if not SafeCheckInstance(self.Character, workspace) then return end
			self:_applyArmSize("Left")
			self:_applyArmSize("Right")
			TorsoSmoothing = TorsoSmoothing:Lerp(self.Torso.CFrame, self.Configs.Smoothing)
			local Type = self.Configs.Type
			if self.Character:FindFirstChildWhichIsA("Tool") then
				Type = "Advanced"
			else
				Type = "Basic"
			end

			if Types[Type] and type(Types[Type]) == "function" then
				Types[Type](dt)
			end
		end), nil, "ViewportConnection")
	end
end

function ViewportManager:Destroy()
	self.ViewportJanitor:Destroy()
	self.CameraManager:Destroy()
end

function SafeCheckInstance(Instance: Instance, Ancestor: Instance)
	if not Instance then return false end
	if not Instance:IsDescendantOf(Ancestor) then return false end

	return true
end

return table.freeze(ViewportManager)
