local CameraController = {
	Default_FoV = 70;
	BreathStrength = .85;
	BobStrength = .08;
	BobSpeed = 4.2;
	SwayIntensity = 6.7;
	SwaySpeed = 4.1;
	TiltStrength = 4.5;
}
CameraController.__index = CameraController

local index: typeof(CameraController)

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Janitor = require "@game/ReplicatedStorage/Packages/Shared/Janitor"
local advents = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
local FpsCamera = require "./FpsCamera"

local Recoil = require "@game/ReplicatedStorage/Modules/Client/Systems/Guns/Components/Recoil"
local Lighting = game:GetService("Lighting")

function CameraController.new(baseFov: number?)
	if index then return index end
	FpsCamera:Start()

	local self = setmetatable({}, CameraController)
	self.Character = nil :: Model?
	self.yOffset = 1.2
	self.BaseFov = baseFov or CameraController.Default_FoV or Camera.FieldOfView
	self.FieldOfView = self.BaseFov
	self.Janitor = Janitor.new()
	self.BobTime = 0
	self.LastBreathGrounded = false
	self.LastHRPPosition = nil :: vector?
	self.HeadLocalBase = nil :: vector?
	self.TorsoLocalBase = nil :: vector?

	self.FovSpring = advents.spring.new(self.FieldOfView)
	self.FovSpring.d = .9
	self.FovSpring.s = 12

	self.OffsetSpringX = advents.spring.new(0)
	self.OffsetSpringY = advents.spring.new(self.yOffset)
	self.OffsetSpringZ = advents.spring.new(0)
	self.OffsetSpringX.d = .86
	self.OffsetSpringY.d = .86
	self.OffsetSpringZ.d = .86
	self.OffsetSpringX.s = 12
	self.OffsetSpringY.s = 12
	self.OffsetSpringZ.s = 12

	self.BreathSpringX = advents.spring.new(0)
	self.BreathSpringY = advents.spring.new(0)
	self.BreathSpringZ = advents.spring.new(0)
	self.BreathRollSpring = advents.spring.new(0)
	self.BreathSpringX.d = .84
	self.BreathSpringY.d = .82
	self.BreathSpringZ.d = .86
	self.BreathRollSpring.d = .84
	self.BreathSpringX.s = 10
	self.BreathSpringY.s = 10
	self.BreathSpringZ.s = 10
	self.BreathRollSpring.s = 10

	self.ToolOffsetSpringX = advents.spring.new(0)
	self.ToolOffsetSpringY = advents.spring.new(0)
	self.ToolOffsetSpringZ = advents.spring.new(0)
	self.ToolOffsetSpringX.d = .6
	self.ToolOffsetSpringY.d = .6
	self.ToolOffsetSpringZ.d = .6
	self.ToolOffsetSpringX.s = 6
	self.ToolOffsetSpringY.s = 6
	self.ToolOffsetSpringZ.s = 6
	self.ToolOffsetRot = CFrame.identity

	self.Recoil = Recoil.new()
	self.BlurEffect = nil
	self.BlurSpring = advents.spring.new(0)
	self.BlurSpring.d = .72
	self.BlurSpring.s = 16
	self._blurConn = nil

	self.TiltSpring = advents.spring.new(0)
	self.TiltSpring.d = .78
	self.TiltSpring.s = 8
	local function ensureSprings()
		if not self.OffsetSpringX then
			self.OffsetSpringX = advents.spring.new(0)
			self.OffsetSpringY = advents.spring.new(self.yOffset)
			self.OffsetSpringZ = advents.spring.new(0)
			self.OffsetSpringX.d = .86
			self.OffsetSpringY.d = .86
			self.OffsetSpringZ.d = .86
			self.OffsetSpringX.s = 12
			self.OffsetSpringY.s = 12
			self.OffsetSpringZ.s = 12
		end
		if not self.ToolOffsetSpringX then
			self.ToolOffsetSpringX = advents.spring.new(0)
			self.ToolOffsetSpringY = advents.spring.new(0)
			self.ToolOffsetSpringZ = advents.spring.new(0)
			self.ToolOffsetSpringX.d = .6
			self.ToolOffsetSpringY.d = .6
			self.ToolOffsetSpringZ.d = .6
			self.ToolOffsetSpringX.s = 6
			self.ToolOffsetSpringY.s = 6
			self.ToolOffsetSpringZ.s = 6
		end
		if not self.BreathSpringX then
			self.BreathSpringX = advents.spring.new(0)
			self.BreathSpringY = advents.spring.new(0)
			self.BreathSpringZ = advents.spring.new(0)
			self.BreathRollSpring = advents.spring.new(0)
			self.BreathSpringX.d = .84
			self.BreathSpringY.d = .82
			self.BreathSpringZ.d = .86
			self.BreathRollSpring.d = .84
			self.BreathSpringX.s = 10
			self.BreathSpringY.s = 10
			self.BreathSpringZ.s = 10
			self.BreathRollSpring.s = 10
		end
		if not self.FovSpring then
			self.FovSpring = advents.spring.new(self.FieldOfView)
			self.FovSpring.d = .9
			self.FovSpring.s = 12
		end
		if not self.TiltSpring then
			self.TiltSpring = advents.spring.new(0)
			self.TiltSpring.d = .78
			self.TiltSpring.s = 8
		end
	end

	local function reset(char: Model?)
		ensureSprings()
		self.Character = char
		self.BobTime = 0
		self.LastBreathGrounded = false
		self.LastHRPPosition = nil
		self.HeadLocalBase = nil
		self.TorsoLocalBase = nil
		self.OffsetSpringX.p = 0
		self.OffsetSpringY.p = self.yOffset
		self.OffsetSpringZ.p = 0
		self.OffsetSpringX.t = 0
		self.OffsetSpringY.t = self.yOffset
		self.OffsetSpringZ.t = 0
		self.ToolOffsetSpringX.p = 0
		self.ToolOffsetSpringY.p = 0
		self.ToolOffsetSpringZ.p = 0
		self.ToolOffsetSpringX.t = 0
		self.ToolOffsetSpringY.t = 0
		self.ToolOffsetSpringZ.t = 0
		self.ToolOffsetRot = CFrame.identity
		self.BreathSpringX.p = 0
		self.BreathSpringY.p = 0
		self.BreathSpringZ.p = 0
		self.BreathRollSpring.p = 0
		self.BreathSpringX.t = 0
		self.BreathSpringY.t = 0
		self.BreathSpringZ.t = 0
		self.BreathRollSpring.t = 0
		self.TiltSpring.p = 0
		self.TiltSpring.t = 0
		self.FovSpring.p = self.BaseFov
		self.FovSpring.t = self.BaseFov
		self.FieldOfView = self.BaseFov
		if Camera then
			Camera.FieldOfView = self.BaseFov
		end
	end

	if Player.Character then
		reset(Player.Character)
	end

	self.Janitor:Add(Player.CharacterAdded:Connect(reset), "Disconnect")

	self.Janitor:Add(RunService.PreRender:Connect(function(dt)
		ensureSprings()
		self.SwayRot = self.SwayRot or 0

		local MouseDelta = UserInputService:GetMouseDelta()

		self.SwayRot = math.lerp(self.SwayRot, math.clamp(MouseDelta.X, -CameraController.SwayIntensity, CameraController.SwayIntensity), CameraController.SwaySpeed * dt)

		if not self.Character then return end
		local HRP = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local Humanoid = self.Character:FindFirstChild("Humanoid") :: Humanoid?
		local Head = self.Character:FindFirstChild("Head") :: BasePart?
		local Torso = (self.Character:FindFirstChild("UpperTorso") or self.Character:FindFirstChild("Torso") or self.Character:FindFirstChild("LowerTorso") or HRP) :: BasePart?
		if not HRP or not Humanoid or not Head or not Torso then return end

		local grounded = Humanoid.FloorMaterial ~= Enum.Material.Air
		local currentPosition = HRP.Position :: vector
		local previousPosition = self.LastHRPPosition
		local horizontalSpeed = 0
		if previousPosition then
			local displacement = currentPosition - previousPosition
			horizontalSpeed = vector.magnitude(vector.create(displacement.X, 0, displacement.Z)) / math.max(dt, 1e-3)
		end
		self.LastHRPPosition = currentPosition

		local baseWalk = math.max(Humanoid.WalkSpeed, 1)
		local speedAlpha = math.clamp(horizontalSpeed / math.max(baseWalk * 1.4, 1), 0, 1)

		local localVelocity = HRP.CFrame:VectorToObjectSpace(HRP.AssemblyLinearVelocity)
		self.TiltSpring.t = -math.clamp(localVelocity.X / math.max(Humanoid.WalkSpeed, 1), -1, 1)

		self.BobTime += dt * (CameraController.BobSpeed + (speedAlpha * 3.6))
		local bobWave = math.sin(self.BobTime)
		local bobSide = math.sin(self.BobTime * .6)
		local bobX = bobSide * ((.01) + (CameraController.BobStrength * speedAlpha))
		local bobY = math.abs(bobWave) * ((.012) + (CameraController.BobStrength * .4 * (1 + speedAlpha)))

		local headLocal = HRP.CFrame:PointToObjectSpace(Head.Position)
		local torsoLocal = HRP.CFrame:PointToObjectSpace(Torso.Position)
		if not self.HeadLocalBase then
			self.HeadLocalBase = headLocal
		end
		if not self.TorsoLocalBase then
			self.TorsoLocalBase = torsoLocal
		end

		local rigFollow = 1 - math.exp(-(((grounded and 3.4 or 1.1) + (speedAlpha * 2.6)) * dt))
		self.HeadLocalBase = vector.lerp(self.HeadLocalBase, headLocal, rigFollow)
		self.TorsoLocalBase = vector.lerp(self.TorsoLocalBase, torsoLocal, rigFollow)

		local headDelta = headLocal - self.HeadLocalBase
		local torsoDelta = torsoLocal - self.TorsoLocalBase
		local idleBreathAlpha = math.clamp((1 - speedAlpha) * (grounded and 1 or .35), 0, 1)
		local breathScale = CameraController.BreathStrength * (.75 + (idleBreathAlpha * 1.1))

		local breathTarget = vector.create(
			((headDelta.X * .7) + (torsoDelta.X * .3)) * breathScale,
			((headDelta.Y * .9) + (torsoDelta.Y * .2)) * breathScale * 1.25,
			((headDelta.Z * .55) + (torsoDelta.Z * .45)) * breathScale * .85
		)

		self.BreathSpringX.t = breathTarget.X
		self.BreathSpringY.t = breathTarget.Y
		self.BreathSpringZ.t = breathTarget.Z
		self.BreathRollSpring.t = ((-headDelta.X * 2.4) + (-torsoDelta.X * 1.1) + (headDelta.Y * .28)) * (1 + idleBreathAlpha)

		if grounded and not self.LastBreathGrounded then
			self.BreathSpringX.p = breathTarget.X
			self.BreathSpringY.p = breathTarget.Y
			self.BreathSpringZ.p = breathTarget.Z
			self.BreathRollSpring.p = self.BreathRollSpring.t
		end
		self.LastBreathGrounded = grounded

		local targetOffset = vector.create(
			bobX + self.BreathSpringX.p,
			self.yOffset + bobY + self.BreathSpringY.p,
			self.BreathSpringZ.p
		)

		self.OffsetSpringX.t = targetOffset.X
		self.OffsetSpringY.t = targetOffset.Y
		self.OffsetSpringZ.t = targetOffset.Z

		local offset = vector.create(
			self.OffsetSpringX.p + self.ToolOffsetSpringX.p,
			self.OffsetSpringY.p + self.ToolOffsetSpringY.p,
			self.OffsetSpringZ.p + self.ToolOffsetSpringZ.p
		)
		local roll = math.rad(self.BreathRollSpring.p)
		local tilt = math.rad(self.TiltSpring.p * CameraController.TiltStrength)

		local inFirstPerson = FpsCamera:IsInFirstPerson()
		if inFirstPerson then
			local lookDir = Camera.CFrame.LookVector :: vector
			local rightDir = Camera.CFrame.RightVector :: vector
			local upDir = Camera.CFrame.UpVector :: vector
			local worldOffset = (rightDir * offset.X) + (upDir * offset.Y) + (lookDir * (offset.Z + .18))
			Camera.CFrame = Camera.CFrame * self.ToolOffsetRot
			Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, roll)
			Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, tilt)
			Camera.CFrame = Camera.CFrame + worldOffset
			Camera.Focus = Camera.Focus + worldOffset
			Humanoid.CameraOffset = vector.zero
		else
			Humanoid.CameraOffset = vector.lerp(Humanoid.CameraOffset, offset, 1 - math.exp(-14 * dt))
			Camera.CFrame = Camera.CFrame * self.ToolOffsetRot
			Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, roll)
			Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, tilt)
		end

		Camera.CFrame *= CFrame.Angles(0, 0, math.rad(self.SwayRot))

		self.FovSpring.t = self:GetFieldOfView()
		Camera.FieldOfView = self.FovSpring.p
	end), "Disconnect", "CameraUpdate")

	RunService:BindToRenderStep("CameraControllerRecoil", Enum.RenderPriority.Camera.Value + 1, function()
		if not Camera then return end
		if self.Recoil and self.Recoil.Step then
			self.Recoil:Step()
		end
		if self.Recoil and self.Recoil.GetDelta then
			local r = self.Recoil:GetDelta()
			local m = 8
			Camera.CFrame = Camera.CFrame * CFrame.Angles(
				math.rad(r.y * m),
				math.rad(r.x * m),
				math.rad(r.z * m)
			)
		end
	end)
	self.Janitor:Add(function()
		RunService:UnbindFromRenderStep("CameraControllerRecoil")
	end)

	index = self
	return self
end

function CameraController:IsInFirstPerson()
	return FpsCamera:IsInFirstPerson()
end

function CameraController:SetFov(fov: number)
	if not fov then return end
	self.FieldOfView = fov
end

function CameraController:GetFieldOfView()
	return self.FieldOfView
end

function CameraController:SetToolOffset(v: Vector3? | vector? | CFrame?)
	if not getmetatable(self) then return end

	local function ensureToolSprings()
		if not self.ToolOffsetSpringX then
			self.ToolOffsetSpringX = advents.spring.new(0)
			self.ToolOffsetSpringY = advents.spring.new(0)
			self.ToolOffsetSpringZ = advents.spring.new(0)
			self.ToolOffsetSpringX.d = .6
			self.ToolOffsetSpringY.d = .6
			self.ToolOffsetSpringZ.d = .6
			self.ToolOffsetSpringX.s = 6
			self.ToolOffsetSpringY.s = 6
			self.ToolOffsetSpringZ.s = 6
		end
	end
	ensureToolSprings()

	local pos = vector.zero
	if typeof(v) == "CFrame" then
		self.ToolOffsetRot = v - v.Position
		pos = vector.create(v.Position.X, v.Position.Y, v.Position.Z)
	elseif v then
		self.ToolOffsetRot = CFrame.identity
		pos = vector.create(v.X, v.Y, v.Z)
	else
		self.ToolOffsetRot = CFrame.identity
	end
	self.ToolOffsetSpringX.t = pos.X
	self.ToolOffsetSpringY.t = pos.Y
	self.ToolOffsetSpringZ.t = pos.Z
end

function CameraController:ApplyRecoil(preset)
	if not self.Recoil then return end
	if preset then
		self.Recoil:Load(preset)
	end
	self.Recoil:Fire()
end

function CameraController:PulseBlur(size: number, duration: number)
	if not size or size <= 0 then return end
	duration = duration or .08
	if not self.BlurEffect then
		local blur = Instance.new("BlurEffect")
		blur.Size = 0
		blur.Parent = Lighting
		self.BlurEffect = blur
	end
	if not self.BlurSpring then
		self.BlurSpring = advents.spring.new(0)
		self.BlurSpring.d = .72
		self.BlurSpring.s = 16
	end
	local blur = self.BlurEffect
	blur.Enabled = true
	blur.Size = size
	self.BlurSpring.t = 0
	self.BlurSpring.p = size
	self.BlurSpring.v = 0
	if not self._blurConn then
		self._blurConn = RunService.PreRender:Connect(function(dt)
			blur.Enabled = true
			blur.Size = math.max(0, self.BlurSpring.p)
			if math.abs(self.BlurSpring.p) < .05 and math.abs(self.BlurSpring.v or 0) < 0.05 and math.abs(self.BlurSpring.t or 0) < .01 then
				blur.Size = 0
				blur.Enabled = false
				if self._blurConn then
					self._blurConn:Disconnect()
					self._blurConn = nil
				end
			end
		end)
	end
end

function CameraController:Destroy()
	self.Janitor:Cleanup()
	self.Character = nil
	self.HeadLocalBase = nil
	self.TorsoLocalBase = nil
	self.LastHRPPosition = nil
	self.LastBreathGrounded = false
	self.BobTime = 0
	self.SwayRot = 0
	self.ToolOffsetSpringX = nil
	self.ToolOffsetSpringY = nil
	self.ToolOffsetSpringZ = nil
	self.ToolOffsetRot = nil
	self.TiltSpring = nil
	index = nil
end

return CameraController
