local CameraController = {
	Default_FoV = 70;
	TargetFoV = 70;
	LevelUpFxDuration = .78;
	LevelUpFxRise = .12;
	LevelUpFxFovAdd = 6.75;
	LevelUpFxImpulse = 14.5;
	LevelUpFxPerExtraLevel = .12;
	LevelUpFxMaxStrength = 1.55;
	LevelUpFxTintAlpha = .14;
	LevelUpFxContrast = .12;
	LevelUpFxSaturation = .16;
	LevelUpFxBrightness = .014;
	LevelUpFxColor = Color3.fromRGB(255, 255, 0);
	LevelUpFxVignetteAlpha = .66;
	LevelUpFxVignetteScale = 2.34;
	LevelUpPowerVignetteAlpha = .34;
	LevelUpVignetteColor = Color3.fromRGB(255, 255, 0);
	LevelUpPowerDurationScale = .55;
	LevelUpPowerMaxDuration = 4.25;
	LevelUpPowerFovAdd = 4.1;
	LevelUpPowerBlurAdd = 1.45;
	LevelUpPowerRollAdd = .2;
	LevelUpPowerOffsetY = .11;
	LevelUpPowerOffsetZ = .15;
	LevelUpPowerSway = .018;
	LevelUpPowerSpringScale = .34;
	LevelUpPowerTintAlpha = .08;
	LevelUpPowerContrast = .08;
	LevelUpPowerSaturation = .11;
	LevelUpPowerBrightness = .012;
	LevelUpShakeX = .085;
	LevelUpShakeY = 0;
	LevelUpShakeZ = 0;
	LevelUpShakeSpeed = 30;
	LevelUpShakeSpeedFine = 53;
	FirstPersonCameraLower = .08;
	FirstPersonCameraForward = .22;
	FirstPersonOffsetXScale = .38;
	FirstPersonOffsetYScale = .72;
	FirstPersonOffsetZScale = .52;
	FirstPersonForwardOffset = .18;
	FirstPersonUpOffset = .74;
	FirstPersonDownOffset = .44;
	FirstPersonTorsoBlend = .72;
	FirstPersonTorsoLookBlend = .28;
	FirstPersonBodyBackOffset = .32;
	FirstPersonLookBackOffset = .28;
	FirstPersonBodyDownBias = .12;
	FirstPersonLookDownOffset = .18;
	FirstPersonLookUpOffset = .10;
	FirstPersonShoulderOffset = .08;
	FirstPersonShoulderLookOffset = .06;
	OTSRightOffset = .95;
	OTSUpOffset = .18;
	OTSBackOffset = -.65;
	OTSRightOffsetSlide = 1.15;
	WallRunCameraSide = .52;
	WallRunCameraDrop = -.74;
	WallRunCameraDepth = -.28;
	WallRunCameraForward = .12;
	WallRunCameraTiltBoost = .18;
	HeadAttachments = {
		FaceCenterAttachment = true;
		FaceFrontAttachment = true;
		HairAttachment = true;
		HatAttachment = true;
	};
}
CameraController.__index = CameraController

local index: typeof(CameraController)
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local Janitor = require("@game/ReplicatedStorage/Packages/Shared/Janitor")
local advents = require("@game/ReplicatedStorage/Modules/Shared/utils/advents")
local MovementConfigs = require("@game/ReplicatedStorage/Modules/Client/Controllers/Movement/configs")
local StateManagerClient = require("@game/ReplicatedStorage/Modules/Client/Systems/StateManagerClient")
local CameraShake = require("@game/ReplicatedStorage/Modules/Client/Systems/CameraShake")
local FpsCamera = require("./FpsCamera")
local LevelBoostEffects = require("./LevelBoostEffects")

function CameraController.new()
	if index then return index end
	FpsCamera:Start()

	local self = setmetatable({}, CameraController)
	self.Character = nil :: Model?
	self.yOffset = 1.5
	self.zOffset = 0
	self.Janitor = Janitor.new()
	self.CurrentOffset = advents.vector.yAxis * 1.5
	self.SpringBaseSpeeds = {
		RollSpring = 15;
		OffsetSpringX = 14;
		OffsetSpringY = 14;
		OffsetSpringZ = 14;
		ExternalRollSpring = 15;
		FovSpring = 11;
		AirSpringX = 7;
		AirSpringY = 7;
		ImpulseSpringY = 18;
		ImpulseSpringZ = 14;
		ShoulderSpring = 12;
		BreathSpringX = 9;
		BreathSpringY = 10;
		BreathSpringZ = 8;
		BreathRollSpring = 9;
	}
	self.RollSpring = advents.spring.new(0)
	self.RollSpring.d = .84
	self.RollSpring.s = self.SpringBaseSpeeds.RollSpring
	self.OffsetSpringX = advents.spring.new(0)
	self.OffsetSpringY = advents.spring.new(self.yOffset)
	self.OffsetSpringZ = advents.spring.new(0)
	self.OffsetSpringX.d = .86
	self.OffsetSpringY.d = .86
	self.OffsetSpringZ.d = .86
	self.OffsetSpringX.s = self.SpringBaseSpeeds.OffsetSpringX
	self.OffsetSpringY.s = self.SpringBaseSpeeds.OffsetSpringY
	self.OffsetSpringZ.s = self.SpringBaseSpeeds.OffsetSpringZ
	self.ExternalRoll = 0
	self.ExternalRollSpring = advents.spring.new(0)
	self.ExternalRollSpring.d = .82
	self.ExternalRollSpring.s = self.SpringBaseSpeeds.ExternalRollSpring
	self.FovSpring = advents.spring.new(Camera.FieldOfView)
	self.FovSpring.d = .9
	self.FovSpring.s = self.SpringBaseSpeeds.FovSpring
	self.AirSpringX = advents.spring.new(0)
	self.AirSpringY = advents.spring.new(0)
	self.AirSpringX.d = .74
	self.AirSpringY.d = .74
	self.AirSpringX.s = self.SpringBaseSpeeds.AirSpringX
	self.AirSpringY.s = self.SpringBaseSpeeds.AirSpringY
	self.ImpulseSpringY = advents.spring.new(0)
	self.ImpulseSpringZ = advents.spring.new(0)
	self.ImpulseSpringY.d = .72
	self.ImpulseSpringZ.d = .74
	self.ImpulseSpringY.s = self.SpringBaseSpeeds.ImpulseSpringY
	self.ImpulseSpringZ.s = self.SpringBaseSpeeds.ImpulseSpringZ
	self.ShoulderSpring = advents.spring.new(0)
	self.ShoulderSpring.d = .8
	self.ShoulderSpring.s = self.SpringBaseSpeeds.ShoulderSpring
	self.BreathSpringX = advents.spring.new(0)
	self.BreathSpringY = advents.spring.new(0)
	self.BreathSpringZ = advents.spring.new(0)
	self.BreathRollSpring = advents.spring.new(0)
	self.BreathSpringX.d = .84
	self.BreathSpringY.d = .82
	self.BreathSpringZ.d = .86
	self.BreathRollSpring.d = .84
	self.BreathSpringX.s = self.SpringBaseSpeeds.BreathSpringX
	self.BreathSpringY.s = self.SpringBaseSpeeds.BreathSpringY
	self.BreathSpringZ.s = self.SpringBaseSpeeds.BreathSpringZ
	self.BreathRollSpring.s = self.SpringBaseSpeeds.BreathRollSpring
	self.BaseFov = CameraController.Default_FoV or Camera.FieldOfView
	self.SprintFovAdd = CameraController.Sprint_FoV_Add or 20
	self.SprintThreshold = CameraController.SprintSpeedThreshold or ((MovementConfigs.DefaultSpeed or 16) + 1.5)
	self.LastHRPPosition = nil :: vector?
	self.LastLookVector = nil :: vector?
	self.HeadLocalBase = nil :: vector?
	self.TorsoLocalBase = nil :: vector?
	self.LastBreathGrounded = false
	self.InFirstPerson = false
	self.BobTime = 0
	self.LastStepWave = 0
	self.DefaultRunningSoundSuppressed = false
	self.CameraShakeOffset = CFrame.identity
	self.CameraShakeFovOffset = 0
	self.CameraShakePosition = vector.zero
	self.CameraShakeRotation = vector.zero
	self.CameraShake = CameraShake.new(function(Delta: CFrame, FovOffset: number, PositionOffset: vector, RotationOffset: vector)
		self.CameraShakeOffset = Delta
		self.CameraShakeFovOffset = FovOffset
		self.CameraShakePosition = PositionOffset
		self.CameraShakeRotation = RotationOffset
	end); CameraController.CameraShake = self.CameraShake
	self.LevelBoostEffects = LevelBoostEffects.new(Player, Camera, self.CameraShake, CameraController)

	local function reset(NewChar: Model?)
		self.Character = NewChar
		if Player.CameraMinZoomDistance > .5 then
			Player.CameraMinZoomDistance = .5
		end
		self.LastHRPPosition = nil
		self.LastLookVector = nil
		self.HeadLocalBase = nil
		self.TorsoLocalBase = nil
		self.LastBreathGrounded = false
		self.CurrentOffset = vector.create(0, self.yOffset, 0)
		self.BobTime = 0
		self.LastStepWave = 0
		self.DefaultRunningSoundSuppressed = false
		self.InFirstPerson = false
		self.RollSpring.p = 0
		self.RollSpring.t = 0
		self.OffsetSpringX.p = 0
		self.OffsetSpringY.p = self.yOffset
		self.OffsetSpringZ.p = 0
		self.OffsetSpringX.t = 0
		self.OffsetSpringY.t = self.yOffset
		self.OffsetSpringZ.t = 0
		self.AirSpringX.p = 0
		self.AirSpringX.t = 0
		self.AirSpringY.p = 0
		self.AirSpringY.t = 0
		self.ImpulseSpringY.p = 0
		self.ImpulseSpringY.t = 0
		self.ImpulseSpringZ.p = 0
		self.ImpulseSpringZ.t = 0
		self.ShoulderSpring.p = 0
		self.ShoulderSpring.t = 0
		self.BreathSpringX.p = 0
		self.BreathSpringX.t = 0
		self.BreathSpringY.p = 0
		self.BreathSpringY.t = 0
		self.BreathSpringZ.p = 0
		self.BreathSpringZ.t = 0
		self.BreathRollSpring.p = 0
		self.BreathRollSpring.t = 0
		self.ExternalRoll = 0
		self.ExternalRollSpring.p = 0
		self.ExternalRollSpring.t = 0
		self.FovSpring.p = self.BaseFov
		self.FovSpring.t = self.BaseFov
		self.CameraShake:Stop(true):Start()
		self.CameraShakeOffset = CFrame.identity
		self.CameraShakeFovOffset = 0
		self.CameraShakePosition = vector.zero
		self.CameraShakeRotation = vector.zero
		self:ApplyMovementSpringScale(0, false)
		CameraController.TargetFoV = self.BaseFov
		if self.LevelBoostEffects then
			self.LevelBoostEffects:Reset()
		end
		local blur = Camera:FindFirstChildOfClass("BlurEffect")
		if blur then
			blur.Size = 0
		end
	end

	if Player.Character then
		reset(Player.Character)
	end

	Player.CharacterAdded:Connect(reset)
	index = self
	return self
end

function CameraController:ApplyMovementSpringScale(horizontalSpeed: number, isSliding: boolean?)
	self.RollSpring.s = self.SpringBaseSpeeds.RollSpring
	self.OffsetSpringX.s = self.SpringBaseSpeeds.OffsetSpringX
	self.OffsetSpringY.s = self.SpringBaseSpeeds.OffsetSpringY
	self.OffsetSpringZ.s = self.SpringBaseSpeeds.OffsetSpringZ
	self.ExternalRollSpring.s = self.SpringBaseSpeeds.ExternalRollSpring
	self.FovSpring.s = self.SpringBaseSpeeds.FovSpring
	self.AirSpringX.s = self.SpringBaseSpeeds.AirSpringX
	self.AirSpringY.s = self.SpringBaseSpeeds.AirSpringY
	self.ImpulseSpringY.s = self.SpringBaseSpeeds.ImpulseSpringY
	self.ImpulseSpringZ.s = self.SpringBaseSpeeds.ImpulseSpringZ
	self.ShoulderSpring.s = self.SpringBaseSpeeds.ShoulderSpring
	self.BreathSpringX.s = self.SpringBaseSpeeds.BreathSpringX
	self.BreathSpringY.s = self.SpringBaseSpeeds.BreathSpringY
	self.BreathSpringZ.s = self.SpringBaseSpeeds.BreathSpringZ
	self.BreathRollSpring.s = self.SpringBaseSpeeds.BreathRollSpring
end

function CameraController:GetLevelUpPulseAlpha(): number
	return self.LevelBoostEffects and self.LevelBoostEffects:GetPulseAlpha() or 0
end

function CameraController:GetLevelUpPowerAlpha(): number
	return self.LevelBoostEffects and self.LevelBoostEffects:GetPowerAlpha() or 0
end

function CameraController:GetLevelUpShakeAlpha(): number
	return self.LevelBoostEffects and self.LevelBoostEffects:GetShakeAlpha() or 0
end

function CameraController:UpdateLevelUpPulseEffect(pulseAlpha: number, powerAlpha: number?)
	if self.LevelBoostEffects then
		self.LevelBoostEffects:UpdateVisuals(pulseAlpha, powerAlpha)
	end
end

function CameraController:PlayLevelUpPulse(levelsGained: number?, boostStrength: number?, boostDuration: number?)
	self:ApplyLevelBoost({
		LevelsGained = levelsGained;
		BoostStrength = boostStrength;
		BoostDuration = boostDuration;
	})
end

function CameraController:ApplyLevelBoost(payload)
	if self.LevelBoostEffects then
		self.LevelBoostEffects:Play(
			payload and payload.LevelsGained,
			payload and payload.BoostStrength,
			payload and payload.BoostDuration
		)
	end
end

function CameraController:ClearLevelUpPulse()
	if self.LevelBoostEffects then
		self.LevelBoostEffects:Clear()
	end
end

function CameraController:SuppressDefaultRunningSound(rootPart: BasePart)
	if self.DefaultRunningSoundSuppressed then
		return
	end

	local runningSound = rootPart:FindFirstChild("Running")
	if not runningSound or not runningSound:IsA("Sound") then
		return
	end

	runningSound.Volume = 0
	runningSound.SoundId = ""
	self.DefaultRunningSoundSuppressed = true
end

function CameraController:EnableCameraOffset(offset: vector)
	offset = offset or vector.create(0, self.yOffset, 0)
	if offset and type(offset) ~= "vector" then return end
	self.Janitor:Remove("CameraOffset")

	local baseX = offset.X
	local baseZ = offset.Z
	local swaySideMultiplier = 1.5
	local swayForwardMultiplier = .45
	local moveDirSideMultiplier = .4
	local moveDirForwardMultiplier = .18
	local maxVelocityForSway = 42
	local inputRollDeg = .7
	local lookRollMultiplier = 1.35
	local lookSwaySideMultiplier = 1.35
	local lookSwayForwardMultiplier = .45
	local stepImpulseY = .16
	local stepImpulseZ = .11
	local slideBaseRoll = 5.25
	local slideSteerRoll = 8.5
	local slideFovAdd = 7.5
	local sprintCloseZ = .2
	local sprintCloseY = .05
	local slideCloseZ = .38
	local slideCloseY = .32
	local sprintBobSpeed = 8.8
	local walkBobSpeed = 4.2
	local strafeVelocityRollDeg = 2.4
	local firstPersonStrafeRollMultiplier = 1.18

	self.Janitor:Add(RunService.PreRender:Connect(function(dt)
		if not self.Character then return end

		local HRP = self.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local Humanoid = self.Character:FindFirstChild("Humanoid") :: Humanoid?
		local Head = self.Character:FindFirstChild("Head") :: BasePart?
		local UpperTorso = self.Character:FindFirstChild("UpperTorso") :: BasePart?
		local LowerTorso = self.Character:FindFirstChild("LowerTorso") :: BasePart?
		local Torso = (UpperTorso or self.Character:FindFirstChild("Torso") or LowerTorso or HRP) :: BasePart?
		if not HRP or not Humanoid or not Head or not Torso then return end

		self:SuppressDefaultRunningSound(HRP)

		local nextIsFirstPerson = self:IsFirstPerson()
		if nextIsFirstPerson ~= self.InFirstPerson then
			self.InFirstPerson = nextIsFirstPerson
		end

		local currentState = StateManagerClient.GetEntityState(Player.UserId)
		local isSliding = currentState == "Sliding"
		local isWallRunning = currentState == "WallRunLeft" or currentState == "WallRunRight"
		local wallRunSide = currentState == "WallRunLeft" and -1 or (currentState == "WallRunRight" and 1 or 0)
		local shiftLocked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
			and self.Character:GetAttribute("ShiftLockSuspend") ~= true
			and not self.InFirstPerson

		local currentPosition = HRP.Position :: vector
		local previousPosition = self.LastHRPPosition
		local frameDisplacement = vector.zero
		local frameVelocity = vector.zero
		if previousPosition then
			frameDisplacement = currentPosition - previousPosition
			frameVelocity = dt > 0 and (frameDisplacement / dt) or vector.zero
		end
		self.LastHRPPosition = currentPosition

		local localFrameVelocity = HRP.CFrame:VectorToObjectSpace(frameVelocity)
		local localVelocity = HRP.CFrame:VectorToObjectSpace(HRP.AssemblyLinearVelocity)
		local horizontalSpeed = vector.magnitude(HRP.AssemblyLinearVelocity * advents.vector.flat)
		local moveDir = Humanoid.MoveDirection
		local moveX = 0
		local moveZ = 0
		if vector.magnitude(moveDir) > .001 then
			local localMove = HRP.CFrame:VectorToObjectSpace(moveDir)
			moveX = localMove.X
			moveZ = -localMove.Z
		end

		local grounded = Humanoid.FloorMaterial ~= Enum.Material.Air
		self:ApplyMovementSpringScale(horizontalSpeed, isSliding)
		local levelBoostFrame = nil
		local levelUpPulseAlpha = 0
		local levelUpPowerAlpha = 0
		local levelUpFovAdd = 0
		local levelUpOffsetY = 0
		local levelUpOffsetZ = 0
		local levelUpWaveX = 0
		local levelUpWaveZ = 0
		local levelUpBlurAdd = 0
		local baseWalkSpeed = math.max(MovementConfigs.DefaultSpeed or 16, 1)
		local speedAlpha = math.clamp(horizontalSpeed / math.max(baseWalkSpeed * 1.55, 1), 0, 1)
		local strideSpeed = walkBobSpeed + ((sprintBobSpeed - walkBobSpeed) * speedAlpha)
		self.BobTime += dt * strideSpeed
		if self.LevelBoostEffects then
			levelBoostFrame = self.LevelBoostEffects:GetFrameState(self.BobTime)
			levelUpPulseAlpha = levelBoostFrame.PulseAlpha or 0
			levelUpPowerAlpha = levelBoostFrame.PowerAlpha or 0
			levelUpFovAdd = levelBoostFrame.FovAdd or 0
			levelUpOffsetY = levelBoostFrame.OffsetY or 0
			levelUpOffsetZ = levelBoostFrame.OffsetZ or 0
			levelUpWaveX = levelBoostFrame.WaveX or 0
			levelUpWaveZ = levelBoostFrame.WaveZ or 0
			levelUpBlurAdd = levelBoostFrame.BlurAdd or 0
			if levelUpPowerAlpha > .001 then
				local springScale = levelBoostFrame.SpringScale or 1
				self.RollSpring.s *= springScale
				self.OffsetSpringX.s *= springScale
				self.OffsetSpringY.s *= springScale
				self.OffsetSpringZ.s *= springScale
				self.FovSpring.s *= springScale
				self.ImpulseSpringY.s *= springScale
				self.ImpulseSpringZ.s *= springScale
			end
		end
		local bobWave = math.sin(self.BobTime)
		local bobSide = math.sin(self.BobTime * .5)
		if grounded and speedAlpha > .16 and bobWave > .72 and self.LastStepWave <= .72 then
			self.ImpulseSpringY.p -= stepImpulseY * (.55 + (.45 * speedAlpha))
			self.ImpulseSpringY.v -= 1.4 + (speedAlpha * 1.8)
			self.ImpulseSpringZ.p += stepImpulseZ * (.45 + (.55 * speedAlpha))
			self.ImpulseSpringZ.v += .7 + (speedAlpha * .9)
		end
		self.LastStepWave = bobWave

		local bobY = bobWave * ((.02) + (.08 * speedAlpha))
		local bobX = bobSide * ((.012) + (.04 * speedAlpha))
		local stepPulse = math.max(0, bobWave)
		local justLanded = grounded and not self.LastBreathGrounded
		local headLocal = HRP.CFrame:PointToObjectSpace(Head.Position)
		local torsoLocal = HRP.CFrame:PointToObjectSpace(Torso.Position)
		if not self.HeadLocalBase then
			self.HeadLocalBase = headLocal
		end
		if not self.TorsoLocalBase then
			self.TorsoLocalBase = torsoLocal
		end
		local rigFollow = 1 - math.exp(-(((justLanded and 11.5) or (grounded and (3.8 + (speedAlpha * 4.2)) or .8)) * dt))
		self.HeadLocalBase = vector.lerp(self.HeadLocalBase, headLocal, rigFollow)
		self.TorsoLocalBase = vector.lerp(self.TorsoLocalBase, torsoLocal, rigFollow)
		local headDelta = headLocal - self.HeadLocalBase
		local torsoDelta = torsoLocal - self.TorsoLocalBase
		local idleBreathAlpha = math.clamp((1 - speedAlpha) * (grounded and 1 or .35), 0, 1)
		local breathScale = .9 + (idleBreathAlpha * .95)
		local breathTarget = vector.create(
			((headDelta.X * .65) + (torsoDelta.X * .35)) * .85 * breathScale,
			((headDelta.Y * .9) + (torsoDelta.Y * .24)) * 1.2 * breathScale,
			((headDelta.Z * .55) + (torsoDelta.Z * .45)) * .7 * breathScale
		)
		self.BreathSpringX.t = breathTarget.X
		self.BreathSpringY.t = breathTarget.Y
		self.BreathSpringZ.t = breathTarget.Z
		self.BreathRollSpring.t = (((-headDelta.X * 2.8) + (-torsoDelta.X * 1.2)) + (headDelta.Y * .35)) * (1.25 + (idleBreathAlpha * .95))
		if justLanded then
			self.BreathSpringX.p = breathTarget.X
			self.BreathSpringY.p = breathTarget.Y
			self.BreathSpringZ.p = breathTarget.Z
			self.BreathRollSpring.p = self.BreathRollSpring.t
		end
		self.LastBreathGrounded = grounded

		local lookSide = 0
		local lookForward = 0
		local currentLook = Camera.CFrame.LookVector :: vector
		if self.LastLookVector then
			local deltaLook = currentLook - self.LastLookVector
			lookSide = vector.dot(Camera.CFrame.RightVector :: vector, deltaLook)
			lookForward = -deltaLook.Y
		end
		self.LastLookVector = currentLook

		local airAlpha = 0
		if not grounded then
			airAlpha = math.clamp(horizontalSpeed / math.max(MovementConfigs.SprintSpeed or 46, 1), 0, 1)
		end
		self.AirSpringX.t = math.clamp(localFrameVelocity.X / 32, -1, 1) * 1.15 * airAlpha
		self.AirSpringY.t = math.clamp(localFrameVelocity.Y / 28, -1, 1) * .55 * airAlpha

		self.ShoulderSpring.t = shiftLocked and 1 or 0

		local otsRight = CameraController.OTSRightOffset or .95
		if isSliding then
			otsRight = CameraController.OTSRightOffsetSlide or 1.15
		end
		local shoulderOffsetX = otsRight * self.ShoulderSpring.p
		local shoulderOffsetY = (CameraController.OTSUpOffset or .18) * self.ShoulderSpring.p
		local shoulderOffsetZ = (CameraController.OTSBackOffset or -.65) * self.ShoulderSpring.p

		local swayX = math.clamp(localFrameVelocity.X / maxVelocityForSway, -1, 1) * swaySideMultiplier
		local swayZ = math.clamp(-localFrameVelocity.Z / maxVelocityForSway, -1, 1) * swayForwardMultiplier
		swayX += moveX * moveDirSideMultiplier
		swayZ += moveZ * moveDirForwardMultiplier
		swayX += lookSide * lookSwaySideMultiplier
		swayZ += lookForward * lookSwayForwardMultiplier

		local slideSteer = math.clamp((moveX * .6) + (math.clamp(localVelocity.X / 28, -1, 1) * .4), -1, 1)
		local slideRoll = 0
		if isSliding then
			slideRoll = slideBaseRoll + (-slideSteer * slideSteerRoll)
		end
		local wallRunAlpha = isWallRunning and math.clamp(horizontalSpeed / math.max(MovementConfigs.SprintSpeed or 46, 1), .55, 1) or 0
		local wallRunSideOffset = wallRunSide * (CameraController.WallRunCameraSide or .52) * wallRunAlpha
		local wallRunY = (CameraController.WallRunCameraDrop or -.74) * wallRunAlpha
		local wallRunZ = ((CameraController.WallRunCameraDepth or -.28) + (CameraController.WallRunCameraForward or .12) * speedAlpha) * wallRunAlpha

		local strafeVelocityRoll = -math.clamp(localVelocity.X / math.max(baseWalkSpeed * 1.2, 1), -1, 1) * strafeVelocityRollDeg
		if self.InFirstPerson then
			strafeVelocityRoll *= firstPersonStrafeRollMultiplier
		end

		self.ExternalRollSpring.t = self.ExternalRoll
		local targetRoll = (-moveX * inputRollDeg) + strafeVelocityRoll + (-lookSide * lookRollMultiplier) + slideRoll + self.ExternalRollSpring.p + self.BreathRollSpring.p + (wallRunSide * (CameraController.WallRunCameraTiltBoost or .18) * wallRunAlpha)
		self.RollSpring.t = targetRoll
		Camera.CFrame = Camera.CFrame * CFrame.Angles(0, 0, math.rad(self.RollSpring.p))

		local currentBlur = Camera:FindFirstChildOfClass("BlurEffect")
		if not currentBlur then
			local blur = Instance.new("BlurEffect")
			blur.Size = 0
			blur.Parent = Camera
			currentBlur = blur
		end
		local blurTarget = (speedAlpha * .6) + (stepPulse * speedAlpha * .8) + (airAlpha * 1) + (isSliding and (1.3 + math.abs(slideSteer) * .5) or 0) + levelUpBlurAdd
		currentBlur.Size += (blurTarget - currentBlur.Size) * math.clamp(dt * 8, 0, 1)

		self:UpdateLevelUpPulseEffect(levelUpPulseAlpha, levelUpPowerAlpha)

		local targetOffset = vector.create(
			baseX + swayX + bobX + shoulderOffsetX + wallRunSideOffset + levelUpWaveX + self.BreathSpringX.p,
			self.yOffset + bobY + shoulderOffsetY + self.ImpulseSpringY.p - (speedAlpha * sprintCloseY) - (isSliding and slideCloseY or 0) + wallRunY + levelUpOffsetY + self.BreathSpringY.p,
			baseZ + swayZ + shoulderOffsetZ + self.ImpulseSpringZ.p + (speedAlpha * sprintCloseZ) + (isSliding and slideCloseZ or 0) + wallRunZ + levelUpOffsetZ + levelUpWaveZ + self.BreathSpringZ.p
		)
		self.OffsetSpringX.t = targetOffset.X + self.AirSpringX.p
		self.OffsetSpringY.t = targetOffset.Y + self.AirSpringY.p
		self.OffsetSpringZ.t = targetOffset.Z
		self.CurrentOffset = vector.create(self.OffsetSpringX.p, self.OffsetSpringY.p, self.OffsetSpringZ.p)

		if self.InFirstPerson then
			local lookDir = Camera.CFrame.LookVector :: vector
			local rightDir = Camera.CFrame.RightVector :: vector
			local upDir = Camera.CFrame.UpVector :: vector

			local pitchAngle = math.asin(math.clamp(-lookDir.Y, -1, 1))
			local lookDownAlpha = math.clamp(-pitchAngle / (math.pi * .5), 0, 1)
			local lookUpAlpha = math.clamp(pitchAngle / (math.pi * .5), 0, 1)
			local torsoLookAlpha = math.clamp(math.abs(pitchAngle) / (math.pi * .5), 0, 1)

			local forwardPush = (CameraController.FirstPersonCameraForward or .22)
				+ (lookDownAlpha * (CameraController.FirstPersonLookDownOffset or .18))
			- (lookUpAlpha * (CameraController.FirstPersonLookUpOffset or .10))

			local slideCompensate = isSliding and ((CameraController.FirstPersonBodyDownBias or .12) + .88) or 0
			local upPush = (CameraController.FirstPersonUpOffset or .74)
			- (CameraController.FirstPersonCameraLower or .08)
			- (lookDownAlpha * (CameraController.FirstPersonDownOffset or .44))
				+ (lookUpAlpha * (CameraController.FirstPersonLookUpOffset or .10) * .5)
				+ slideCompensate

			local torsoPush = (CameraController.FirstPersonBodyBackOffset or .32)
				+ (torsoLookAlpha * (CameraController.FirstPersonTorsoLookBlend or .28))
			- (isSliding and .14 or 0)

			local shoulderPush = (CameraController.FirstPersonShoulderOffset or .08)
				+ (torsoLookAlpha * (CameraController.FirstPersonShoulderLookOffset or .06))

			local firstPersonOffset = vector.create(
				(self.CurrentOffset.X * (CameraController.FirstPersonOffsetXScale or .38)) + shoulderPush,
				(self.CurrentOffset.Y * (CameraController.FirstPersonOffsetYScale or .72)) + upPush,
				(self.CurrentOffset.Z * (CameraController.FirstPersonOffsetZScale or .52)) + forwardPush - torsoPush
			)

			local worldOffset = (rightDir * firstPersonOffset.X)
				+ (upDir * firstPersonOffset.Y)
				+ (lookDir * firstPersonOffset.Z)

			Camera.CFrame = Camera.CFrame + worldOffset
			Camera.Focus = Camera.Focus + worldOffset
			Humanoid.CameraOffset = vector.zero
		else
			Humanoid.CameraOffset = vector.lerp(Humanoid.CameraOffset, self.CurrentOffset, 1 - math.exp(-14 * dt))
		end

		Camera.CFrame *= self.CameraShakeOffset
		Camera.Focus *= self.CameraShakeOffset

		local sprintAlpha = 0
		local sprintSpeed = MovementConfigs.SprintSpeed or 46
		local sprintDenom = math.max(sprintSpeed - self.SprintThreshold, .001)
		sprintAlpha = math.clamp((horizontalSpeed - self.SprintThreshold) / sprintDenom, 0, 1)
		CameraController.TargetFoV = self.BaseFov + (self.SprintFovAdd * sprintAlpha) + (slideFovAdd * (isSliding and (.55 + (.45 * speedAlpha)) or 0)) + (stepPulse * speedAlpha * 1.35) + levelUpFovAdd + self.CameraShakeFovOffset
		self.FovSpring.t = CameraController.TargetFoV
		Camera.FieldOfView = self.FovSpring.p

	end), "Disconnect", "CameraOffset")
end

function CameraController:IsFirstPerson(): boolean
	return FpsCamera:IsInFirstPerson()
end

function CameraController:IsFirstPersonView(): boolean
	return self:IsFirstPerson()
end

function CameraController:ApplyFirstPersonVisibility(isFirstPerson: boolean)
	local Character = self.Character
	if not Character then return end

	for _, instance in next, Character:GetDescendants() do
		if instance:IsA("BasePart") then
			if not isFirstPerson then
				instance.LocalTransparencyModifier = 0
			elseif instance.Name == "Head" then
				instance.LocalTransparencyModifier = 1
			elseif instance.Parent and (instance.Parent:IsA("Accessory") or instance.Parent:IsA("Accoutrement")) then
				local hideAccessory = false
				local partToCheck = instance
				if partToCheck.Name ~= "Handle" then
					local handle = instance.Parent:FindFirstChild("Handle", true)
					if handle and handle:IsA("BasePart") then
						partToCheck = handle
					end
				end

				for _, child in next, partToCheck:GetChildren() do
					if child:IsA("Attachment") and CameraController.HeadAttachments[child.Name] then
						hideAccessory = true
						break
					end
				end

				instance.LocalTransparencyModifier = hideAccessory and 1 or 0
			else
				instance.LocalTransparencyModifier = 0
			end
		elseif instance:IsA("ParticleEmitter") then
			instance.LocalTransparencyModifier = 0
		end
	end
end

function CameraController:Destroy()
	self.Janitor:Cleanup()
	self:ApplyFirstPersonVisibility(false)
	self.InFirstPerson = false
	self.LastHRPPosition = nil
	self.LastLookVector = nil
	self.HeadLocalBase = nil
	self.TorsoLocalBase = nil
	self.LastBreathGrounded = false
	self.BobTime = 0
	self.LastStepWave = 0
	self.RollSpring.p = 0
	self.RollSpring.t = 0
	self.OffsetSpringX.p = 0
	self.OffsetSpringY.p = self.yOffset
	self.OffsetSpringZ.p = 0
	self.OffsetSpringX.t = 0
	self.OffsetSpringY.t = self.yOffset
	self.OffsetSpringZ.t = 0
	self.AirSpringX.p = 0
	self.AirSpringX.t = 0
	self.AirSpringY.p = 0
	self.AirSpringY.t = 0
	self.ImpulseSpringY.p = 0
	self.ImpulseSpringY.t = 0
	self.ImpulseSpringZ.p = 0
	self.ImpulseSpringZ.t = 0
	self.ShoulderSpring.p = 0
	self.ShoulderSpring.t = 0
	self.BreathSpringX.p = 0
	self.BreathSpringX.t = 0
	self.BreathSpringY.p = 0
	self.BreathSpringY.t = 0
	self.BreathSpringZ.p = 0
	self.BreathSpringZ.t = 0
	self.BreathRollSpring.p = 0
	self.BreathRollSpring.t = 0
	self.ExternalRoll = 0
	self.ExternalRollSpring.p = 0
	self.ExternalRollSpring.t = 0
	self.FovSpring.p = self.BaseFov
	self.FovSpring.t = self.BaseFov
	self.CameraShake:Destroy()
	self.CameraShakeOffset = CFrame.identity
	self.CameraShakeFovOffset = 0
	self.CameraShakePosition = vector.zero
	self.CameraShakeRotation = vector.zero
	self:ApplyMovementSpringScale(0, false)
	self:ClearLevelUpPulse()
	Camera.FieldOfView = self.BaseFov
	local blur = Camera:FindFirstChildOfClass("BlurEffect")
	if blur then blur.Size = 0 end
	if self.Character then
		local Humanoid = self.Character:FindFirstChild("Humanoid")
		if Humanoid then
			Humanoid.CameraOffset = vector.zero
		end
	end
end

function CameraController:SetTilt(deg: number)
	self.ExternalRoll = deg or 0
end

function CameraController:ClearTilt()
	self.ExternalRoll = 0
end

return CameraController
