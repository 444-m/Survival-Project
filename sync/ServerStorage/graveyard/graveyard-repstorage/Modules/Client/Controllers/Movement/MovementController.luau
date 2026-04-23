local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local MovementController = {}
MovementController.__index = MovementController

local Player = Players.LocalPlayer

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local Helper = require(script.Parent.Helper)
local BlinkClient = require(SharedPackages.Blink.Client)

local Physics = require("./Physics")

local Janitor = require(SharedPackages.Janitor)
local Animations = require(ReplicatedStorage.Modules.Client.Animations)
local CentralHeartbeat = require(ReplicatedStorage.Modules.Client.CentralHeartbeat)

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local grounded = require("./grounded")

local CameraController = require(ReplicatedStorage.Modules.Client.Controllers.Camera.CameraController)

local DEFAULT_WALKSPEED = game:GetService("StarterPlayer").CharacterWalkSpeed

local StateManagerClient = require(ReplicatedStorage.Modules.Client.Systems.StateManagerClient)
local animator = require(ReplicatedStorage.Modules.Shared.utils.advents.animator)
local Globals = require(ReplicatedStorage.Modules.Shared.Globals)

function MovementController.new(Character: Model, Options: typeof(require("./configs")), Animator: typeof(ReplicatedStorage.Packages.Shared.BetterAnimate))
	local self = setmetatable({}, MovementController)

	self.Physics = Physics.new(Character, Options)
	self.Character = Character
	self.Janitor = Janitor.new()
	self.Options = Options
	self.CameraController = CameraController.new()

	self.LastMantled = 0
	self.LastJumped = 0
	self.LastSlid = 0
	self.LastWallFlipped = 0
	self.WallFlipUntil = 0
	self.LastVaulted = 0
	self.WallFlipHoldActive = false
	self.WallRunHoldActive = false
	self.JumpsUsed = 0
	self.ExternalMoveDirection = nil :: vector?
	self.MantleTrack = nil
	self.VaultTrack = nil
	self.SlideTrack = nil
	self.RunSuppressUntil = 0

	self.StrafeEnabled = false
	self.LerpAlpha = .145
	self.DotThreshold = .6
	self.LastStrafeUpdate = 0
	self.StrafeTickRate = 1/120

	local Torso = Character:WaitForChild("Torso")
	local HRP = Character:WaitForChild("HumanoidRootPart")

	self.Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	self.RootPart = HRP

	self.RootJoint = HRP:WaitForChild("RootJoint") :: Motor6D
	self.NeckJoint = Torso:WaitForChild("Neck") :: Motor6D
	self.RightShoulder = Torso:WaitForChild("Right Shoulder") :: Motor6D
	self.LeftShoulder = Torso:WaitForChild("Left Shoulder") :: Motor6D
	self.RightHip = Torso:WaitForChild("Right Hip") :: Motor6D
	self.LeftHip = Torso:WaitForChild("Left Hip") :: Motor6D

	self.OriginalRoot = self.RootJoint.C0
	self.OriginalNeck = self.NeckJoint.C0
	self.OriginalRightShoulder = self.RightShoulder.C0
	self.OriginalLeftShoulder = self.LeftShoulder.C0
	self.OriginalRightHip = self.RightHip.C0
	self.OriginalLeftHip = self.LeftHip.C0

	local Joints = {
		RootJoint = self.RootJoint;
		NeckJoint = self.NeckJoint;
		RightShoulder = self.RightShoulder;
		LeftShoulder = self.LeftShoulder;
		RightHip = self.RightHip;
		LeftHip = self.LeftHip;
	}

	for i, v in next, Joints do
		v.Enabled = false
		self[i] = v:Clone()
		self[i].Enabled = true
		self[i].Parent = v.Parent
	end

	self.RootTilt = CFrame.identity
	self.NeckTilt = CFrame.identity
	self.RightShoulderTilt = CFrame.identity
	self.LeftShoulderTilt = CFrame.identity
	self.RightHipTilt = CFrame.identity
	self.LeftHipTilt = CFrame.identity

	DEFAULT_WALKSPEED = Options.DefaultSpeed or 16

	local RunningConnection = self.Physics.States.Running:Connect(function()
		self:StartSprintTrack()
	end)

	local WalkingConnection = self.Physics.States.Walking:Connect(function(RunningAirborne: boolean)
		local CurrentState = StateManagerClient.GetEntityState(Player.UserId)
		if CurrentState == "Mantling" or CurrentState == "Vaulting" then return end
		self:StopSprintTrack(RunningAirborne)
	end)

	local SlideStartConnection = self.Physics.States.SlideStart:Connect(function()
		if self.SlideTrack then
			self.SlideTrack:Stop(.08)
			self.SlideTrack = nil
		end
		local Track = advents.animator.playAnim(self.Physics.Humanoid.Animator, Animations.LoadedAnimations.Movement.Slide.loaded, .12)
		Track.Priority = Enum.AnimationPriority.Action4
		Track.Looped = true
		self.SlideTrack = Track

		StateManagerClient.BruteChangeState(Player.UserId, "Sliding")
	end)

	local SlideStopConnection = self.Physics.States.SlideStop:Connect(function()
		if self.SlideTrack then
			self.SlideTrack:Stop(.18)
			self.SlideTrack = nil
		else
			advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Slide.loaded, .18)
		end

		if StateManagerClient.GetEntityState(Player.UserId) == "Sliding" then
			StateManagerClient.BruteChangeState(Player.UserId, "Idling")
		end

		self.LastSlid = os.clock()
	end)

	local SlideCancelConnection = self.Physics.States.SlideCancel:Connect(function()
		if self.SlideTrack then
			self.SlideTrack:Stop(.18)
			self.SlideTrack = nil
		end

		self.SlideCancelTrack = advents.animator.playAnim(self.Physics.Humanoid.Animator, Animations.LoadedAnimations.Movement.SlideCancel.loaded, .18)
		self.SlideCancelTrack.Priority = Enum.AnimationPriority.Action4
	end)

	local VaultStartConnection = self.Physics.States.VaultStart:Connect(function(LandY: number, LedgeY: number)
		if not StateManagerClient.CanTransition(Player.UserId, "Vaulting") then return end
		if os.clock() - (self.LastVaulted or 0) < self.Options.VaultCooldown then return end
		self.LastVaulted = os.clock()
		self.RunSuppressUntil = os.clock() + (self.Options.VaultDuration or .18) + .18
		self.JumpsUsed = 0
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Run.loaded, .12)
		self.SprintTrack = nil

		local AnimKey = Helper.GetRandomFromDict(Animations.LoadedAnimations.Movement.Vaulting)
		if self.VaultTrack then
			self.VaultTrack:Stop(.12)
			self.VaultTrack = nil
		end
		local Track = Animations.LoadedAnimations.Movement.Vaulting[AnimKey].loaded
		Track.Priority = Enum.AnimationPriority.Action4
		Track.Looped = false
		Track:Play(.08)
		Track:AdjustWeight(1, .05)
		self.VaultTrack = Track

		self.Physics:Vault(LandY, LedgeY * 1.25)

		StateManagerClient.BruteChangeState(Player.UserId, "Vaulting")
		local StopAfter = math.max(self.Options.VaultDuration, Track.Length > 0 and Track.Length or self.Options.VaultDuration)
		task.delay(StopAfter, function()
			if not getmetatable(self) then return end
			if self.VaultTrack == Track then
				Track:Stop(.12)
				self.VaultTrack = nil
			end
			if StateManagerClient.GetEntityState(Player.UserId) == "Vaulting" then
				StateManagerClient.BruteChangeState(Player.UserId, "Idling")
			end
		end)
	end)

	local MantleStartConnection = self.Physics.States.MantleStart:Connect(function(Duration: number)
		if not StateManagerClient.CanTransition(Player.UserId, "Mantling") then return end
		if os.clock() - self.LastMantled < self.Options.MantleCooldown then return end
		self.LastMantled = os.clock()
		self.RunSuppressUntil = os.clock() + Duration + .15
		self.JumpsUsed = 0
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Run.loaded, .12)
		self.SprintTrack = nil

		local AnimKey = Helper.GetRandomFromDict(Animations.LoadedAnimations.Movement.Mantling)
		if self.MantleTrack then
			self.MantleTrack:Stop(.12)
			self.MantleTrack = nil
		end
		local Track = Animations.LoadedAnimations.Movement.Mantling[AnimKey].loaded
		Track.Priority = Enum.AnimationPriority.Action4
		Track.Looped = false
		Track:Play(.08)
		Track:AdjustWeight(1, .05)
		self.MantleTrack = Track

		StateManagerClient.BruteChangeState(Player.UserId, "Mantling")
		local StopAfter = math.max(Duration, Track.Length > 0 and Track.Length or Duration)
		task.delay(StopAfter, function()
			if not getmetatable(self) then return end
			if self.MantleTrack == Track then
				Track:Stop(.12)
				self.MantleTrack = nil
			end
			if StateManagerClient.GetEntityState(Player.UserId) == "Mantling" then
				StateManagerClient.BruteChangeState(Player.UserId, "Idling")
			end
		end)
	end)

	local function stopWallRun()
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallRunLeft.loaded, .12)
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallRunRight.loaded, .12)
		local current = StateManagerClient.GetEntityState(Player.UserId)
		if current == "WallRunLeft" or current == "WallRunRight" then
			StateManagerClient.BruteChangeState(Player.UserId, "Idling")
		end
		if self.CameraController then
			self.CameraController:SetTilt(0)
		end
		self.JumpsUsed = 0
	end

	local WallRunLeftConnection = self.Physics.States.WallRunLeft:Connect(function()
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallJumpLeft.loaded, .08)
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallJumpRight.loaded, .08)
		local Track = advents.animator.playAnim(self.Physics.Humanoid.Animator, Animations.LoadedAnimations.Movement.Wall.WallRunLeft.loaded, .12)
		Track.Priority = Enum.AnimationPriority.Action4
		Track.Looped = true
		StateManagerClient.BruteChangeState(Player.UserId, "WallRunLeft")
		if self.CameraController then
			self.CameraController:SetTilt(-(self.Options.WallRunCameraTilt or 12))
		end
	end)

	local WallRunRightConnection = self.Physics.States.WallRunRight:Connect(function()
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallJumpLeft.loaded, .08)
		advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallJumpRight.loaded, .08)
		local Track = advents.animator.playAnim(self.Physics.Humanoid.Animator, Animations.LoadedAnimations.Movement.Wall.WallRunRight.loaded, .12)
		Track.Priority = Enum.AnimationPriority.Action4
		Track.Looped = true
		StateManagerClient.BruteChangeState(Player.UserId, "WallRunRight")
		if self.CameraController then
			self.CameraController:SetTilt(self.Options.WallRunCameraTilt or 12)
		end
	end)

	local WallRunStopConnection = self.Physics.States.WallRunStop:Connect(function()
		stopWallRun()
	end)

	local WallJumpLeftConnection = self.Physics.States.WallJumpLeft:Connect(function()
		stopWallRun()
		self.JumpsUsed = 0
		local Track = advents.animator.playAnim(self.Humanoid.Animator, Animations.LoadedAnimations.Movement.Wall.WallJumpLeft.loaded, .08)
		Track.Priority = Enum.AnimationPriority.Action4
		StateManagerClient.BruteChangeState(Player.UserId, "WallJump")
		local Duration = Track.Length > 0 and Track.Length or (self.Options.WallJumpDuration or .26)
		task.delay(Duration, function()
			if not getmetatable(self) then return end
			if StateManagerClient.GetEntityState(Player.UserId) == "WallJump" then
				StateManagerClient.BruteChangeState(Player.UserId, "Idling")
			end
		end)
	end)

	local WallJumpRightConnection = self.Physics.States.WallJumpRight:Connect(function()
		stopWallRun()
		self.JumpsUsed = 0
		local Track = advents.animator.playAnim(self.Humanoid.Animator, Animations.LoadedAnimations.Movement.Wall.WallJumpRight.loaded, .08)
		Track.Priority = Enum.AnimationPriority.Action4
		StateManagerClient.BruteChangeState(Player.UserId, "WallJump")
		local Duration = Track.Length > 0 and Track.Length or (self.Options.WallJumpDuration or .26)
		task.delay(Duration, function()
			if not getmetatable(self) then return end
			if StateManagerClient.GetEntityState(Player.UserId) == "WallJump" then
				StateManagerClient.BruteChangeState(Player.UserId, "Idling")
			end
		end)
	end)

	self.Janitor:Add(SlideStartConnection, "Disconnect", "SlideState")
	self.Janitor:Add(SlideStopConnection, "Disconnect", "SlideStateStop")
	self.Janitor:Add(SlideCancelConnection, "Disconnect", "SlideStateCancel")
	self.Janitor:Add(RunningConnection, "Disconnect", "RunningState")
	self.Janitor:Add(WalkingConnection, "Disconnect", "WalkingState")
	self.Janitor:Add(VaultStartConnection, "Disconnect", "VaultStart")
	self.Janitor:Add(MantleStartConnection, "Disconnect", "MantleStart")
	self.Janitor:Add(WallRunLeftConnection, "Disconnect", "WallRunLeft")
	self.Janitor:Add(WallRunRightConnection, "Disconnect", "WallRunRight")
	self.Janitor:Add(WallRunStopConnection, "Disconnect", "WallRunStop")
	self.Janitor:Add(WallJumpLeftConnection, "Disconnect", "WallJumpLeft")
	self.Janitor:Add(WallJumpRightConnection, "Disconnect", "WallJumpRight")

	self.Janitor:Add(
		self.Humanoid.StateChanged:Connect(function(_, New)
			if New == Enum.HumanoidStateType.Jumping
				or New == Enum.HumanoidStateType.Freefall
				or New == Enum.HumanoidStateType.FallingDown
			then
				if self.SprintTrack then
					self:StopSprintTrack(true)
				end
				return
			end

			if New == Enum.HumanoidStateType.Landed then
				local Hum = self.Character:FindFirstChild("Humanoid")
				if not Hum then return end

				if vector.magnitude(Hum.MoveDirection) == 0 then
					local AnimatorInst = Hum:FindFirstChild("Animator")
					if not AnimatorInst then return end

					local Track = advents.animator.playAnim(AnimatorInst, Animations.LoadedAnimations.Movement.Land.loaded, .12)
					local TrackLength = Track.Length
					local Elapsed = 0

					while true do
						Elapsed += task.wait()

						local HumCheck = self.Character:FindFirstChild("Humanoid")
						if not HumCheck then break end

						if vector.magnitude(HumCheck.MoveDirection * advents.vector.flat) ~= 0 then
							advents.animator.stopAnim(Track, .12)
							break
						end

						if Elapsed >= TrackLength then break end
					end
				end

				task.defer(function()
					if not getmetatable(self) then return end
					if self:ShouldPlaySprintTrack(StateManagerClient.GetEntityState(Player.UserId)) then
						self:StartSprintTrack()
					end
				end)
			end
		end), "Disconnect", "Land"
	)

	if self.Options.StrafingEnabled then
		self:EnableStrafing()
	end

	return self
end

function MovementController:GetMaxJumps(): number
	return math.max(1, math.floor((self.Options.Jumps or 1) + .5))
end

function MovementController:GrantLevelUpJumpBonus(BonusJumps: number?)
	local grantedJumps = math.max(0, math.floor((BonusJumps or 0) + .5))
	if grantedJumps <= 0 then
		return
	end
	self.JumpsUsed = math.clamp(self.JumpsUsed, 0, math.max(self:GetMaxJumps() - grantedJumps, 0))
end

function MovementController:SetExternalMoveDirection(MoveDirection: vector?)
	self.ExternalMoveDirection = MoveDirection
end

function MovementController:QueueSlide()
	if os.clock() - (self.LastSlid or 0) <= (self.Options.SlideCooldown or 0.55) then return end
	if self.Physics and self.Physics.IsSliding then return end
	if self.SlidePending then return end
	if StateManagerClient.GetEntityState(Player.UserId) == "Sliding" then return end

	if grounded.isGrounded(self.Character, self.Options) and StateManagerClient.CanTransition(Player.UserId, "Sliding") then
		self.LastSlid = os.clock()
		self.Physics:Slide()
		return
	end

	self.SlidePending = true

	CentralHeartbeat:Bind(function()
		if grounded.isGrounded(self.Character, self.Options) and StateManagerClient.CanTransition(Player.UserId, "Sliding") then
			self.SlidePending = false
			self.LastSlid = os.clock()
			self.Physics:Slide()

			CentralHeartbeat:Unbind(nil, "SlidePending")
			self.Janitor:Remove("SlidePending")
		end
	end, "SlidePending")

	self.Janitor:Add(function()
		CentralHeartbeat:Unbind(nil, "SlidePending")
		self.SlidePending = false
	end, nil, "SlidePending")

	task.delay(self.Options.SlidePendingDuration or .9, function()
		if self.SlidePending then
			self.SlidePending = false
			CentralHeartbeat:Unbind(nil, "SlidePending")
			self.Janitor:Remove("SlidePending")
		end
	end)
end

function MovementController:TryMantle()
	local CurrentState = StateManagerClient.GetEntityState(Player.UserId)
	if CurrentState ~= "WallJump" and CurrentState ~= "DoubleJump" and not StateManagerClient.CanTransition(Player.UserId, "Mantling") then return false end
	if os.clock() - self.LastMantled < self.Options.MantleCooldown then return false end

	local CanMantle, FloorEstimate, HeadRoom = Helper.CheckHighRise(self.Character, self.Options.MantleMinCheck or 3, self.Options)
	if not CanMantle then return false end

	local Duration = self.Physics:Mantle(FloorEstimate, HeadRoom)
	if not Duration then return false end

	self.Physics.States.MantleStart:Fire(Duration)

	return true
end

function MovementController:QueueWallKick(PreventReattach: boolean?)
	if not self.Physics or not self.Physics:IsWallRunning() then return end
	local CurrentState = StateManagerClient.GetEntityState(Player.UserId)
	if CurrentState ~= "WallRunLeft"
		and CurrentState ~= "WallRunRight"
		and not StateManagerClient.CanTransition(Player.UserId, "WallJump")
	then
		return
	end

	local Side = self.Physics.WallRunSide
	local KickDuration = self.Physics:WallKick()
	if not KickDuration then return end

	advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallRunLeft.loaded, .12)
	advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Wall.WallRunRight.loaded, .12)
	local current = StateManagerClient.GetEntityState(Player.UserId)
	if current == "WallRunLeft" or current == "WallRunRight" then
		StateManagerClient.BruteChangeState(Player.UserId, "Idling")
	end
	if self.CameraController then
		self.CameraController:SetTilt(0)
	end

	self.JumpsUsed = self:GetMaxJumps()

	local AnimTrack = Side == "Left"
		and advents.animator.playAnim(self.Humanoid.Animator, Animations.LoadedAnimations.Movement.Wall.WallJumpLeft.loaded, .08)
		or advents.animator.playAnim(self.Humanoid.Animator, Animations.LoadedAnimations.Movement.Wall.WallJumpRight.loaded, .08)
	AnimTrack.Priority = Enum.AnimationPriority.Action4

	local AnimDuration = (AnimTrack.Length > 0 and AnimTrack.Length) or KickDuration or .4

	StateManagerClient.BruteChangeState(Player.UserId, "WallJump")
	task.delay(AnimDuration, function()
		if not getmetatable(self) then return end
		self.JumpsUsed = 0
		if StateManagerClient.GetEntityState(Player.UserId) == "WallJump" then
			StateManagerClient.BruteChangeState(Player.UserId, "Idling")
		end
	end)
end

function MovementController:SetWallRunHold(Active: boolean)
	self.WallRunHoldActive = Active
	if self.Physics then
		self.Physics:SetWallRunHoldActive(Active)
	end
end

function MovementController:SetWallFlipHold(Active: boolean)
	self.WallFlipHoldActive = Active
end

function MovementController:QueueWallFlip()
	if grounded.isGrounded(self.Character, self.Options) then return end
	if not StateManagerClient.CanTransition(Player.UserId, "WallFlipping") then return end
	local Now = os.clock()
	if Now - self.LastWallFlipped < self.Options.WallFlipCooldown then return end
	if Now < self.WallFlipUntil then return end

	local WallFlipDuration = self.Physics:WallFlip()
	if not WallFlipDuration then return end

	self.LastWallFlipped = Now
	self.WallFlipUntil = Now + WallFlipDuration
	self.JumpsUsed = 0

	local Track = advents.animator.playAnim(self.Humanoid.Animator, Animations.LoadedAnimations.Movement.WallFlip.loaded, .12)
	Track.Priority = Enum.AnimationPriority.Action4

	StateManagerClient.BruteChangeState(Player.UserId, "WallFlipping")
	task.delay(WallFlipDuration, function()
		if not getmetatable(self) then return end
		if StateManagerClient.GetEntityState(Player.UserId) == "WallFlipping" then
			StateManagerClient.BruteChangeState(Player.UserId, "Idling")
		end
	end)
end

function MovementController:QueueJump()
	local IsWallRunning = self.Physics and self.Physics:IsWallRunning()

	if IsWallRunning then
		if not self.Physics:GetWallRunSideInputAligned(
			self.Physics.WallRunSide or "Right",
			self.Physics.MoveDirection,
			self.Physics.WallRunNormal
			) then
			self.Physics:StopWallRun()
			return
		end
		if self.Physics.WallRunJumpPrimedUntil > 0 then
			return
		end
		if self.Physics:GetWallRunElapsed() < (self.Options.WallJumpMinElapsed or .1) then
			return
		end
		self.Physics:PrimeWallRunJump()
		task.defer(function()
			if not getmetatable(self) then return end
			if self.Physics and not self.Physics:IsWallRunning() and self.WallRunHoldActive then
				self.Physics:SnapToWallRun()
			end
		end)
		return
	end

	local ToSet = os.clock() - self.LastJumped >= (self.Options.JumpCooldown or .22)
	if ToSet then
		self.LastJumped = os.clock()
	end

	if self.Physics and self.Physics.IsSliding then
		local slopeBonus = (self.Physics.LastSlideSlope or 0) < -.15
		local MaxJumps = self:GetMaxJumps()
		local GroundedNow = grounded.getGroundInfo(self.Character, self.Options)
		local Predicted = grounded.getGroundInfoPredicted(self.Character, self.Options, self.Options.GroundPredictionTime or .08)
		local IsGrounded = GroundedNow.IsGrounded
		if not IsGrounded and Predicted.IsGrounded then
			IsGrounded = true
		elseif IsGrounded and not Predicted.IsGrounded and self.RootPart.AssemblyLinearVelocity.Y > 2 then
			IsGrounded = false
		end

		if IsGrounded then
			self.JumpsUsed = math.max(self.JumpsUsed, 1)
		else
			self.JumpsUsed = math.min(MaxJumps, math.max(1, self.JumpsUsed + 1))
		end

		self.Physics.ExpectSlideCancelLandMomentum = true
		self.Physics.ApplySlopeJumpBonus = slopeBonus

		if ToSet then
			task.defer(function()
				if not getmetatable(self) then return end
				if not self.Humanoid or self.Humanoid.Health <= 0 then return end
				self.Humanoid:SetStateEnabled("Jumping", true)
				self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)

				if slopeBonus then
					local vel = self.RootPart.AssemblyLinearVelocity
					local flatLook = vector.normalize(self.RootPart.CFrame.LookVector * advents.vector.flat)
					self.Physics:QueueManagedVelocity({
						horizontal = flatLook * 15;
						horizontalMode = "add";
						vertical = math.max(vel.Y, (self.Options.JumpPower or 56) * 1.25);
						verticalMode = "set";
					})
				end
			end)
		end
		return
	end

	if self:TryMantle() then return end

	if not ToSet then return end

	local Now = os.clock()
	if Now < self.WallFlipUntil then return end

	if self.WallFlipHoldActive and not grounded.isGrounded(self.Character, self.Options) then
		self:QueueWallFlip()
		return
	end

	local MaxJumps = self:GetMaxJumps()
	local GroundedNow = grounded.getGroundInfo(self.Character, self.Options)
	local Predicted = grounded.getGroundInfoPredicted(self.Character, self.Options, self.Options.GroundPredictionTime or .08)
	local IsGrounded = GroundedNow.IsGrounded
	if not IsGrounded and Predicted.IsGrounded then
		IsGrounded = true
	elseif IsGrounded and not Predicted.IsGrounded and self.RootPart.AssemblyLinearVelocity.Y > 2 then
		IsGrounded = false
	end

	if IsGrounded then
		self.JumpsUsed = 0
	end

	local NextJumpCount = self.JumpsUsed + 1
	local IsCycleDoubleJump = advents.num.cycle(NextJumpCount, 2) == 2
	local CanForceAirDoubleJump = not IsGrounded and IsCycleDoubleJump
	if self.JumpsUsed >= MaxJumps and not CanForceAirDoubleJump then return end

	self.JumpsUsed = NextJumpCount

	if IsWallRunning then return end

	self.Humanoid:SetStateEnabled("Jumping", true)
	task.defer(function()
		if not getmetatable(self) then return end
		if not self.Humanoid or self.Humanoid.Health <= 0 then return end
		if self.Physics and self.Physics:IsWallRunning() then return end
		self.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end)

	if not IsGrounded and advents.num.cycle(self.JumpsUsed, 2) == 2 then
		if self.Physics ~= nil then
			self.Physics:PrimeWallRunEntry()
		end

		local ExtraJumpTrack = advents.animator.playAnim(self.Humanoid.Animator, Animations.LoadedAnimations.Movement.ExtraJump.loaded)
		ExtraJumpTrack.Priority = Enum.AnimationPriority.Movement

		StateManagerClient.BruteChangeState(Player.UserId, "DoubleJump")
		task.delay(.01, function()
			if not getmetatable(self) then return end
			if StateManagerClient.GetEntityState(Player.UserId) == "DoubleJump" then
				StateManagerClient.BruteChangeState(Player.UserId, "Idling")
			end
		end)
	else
		StateManagerClient.BruteChangeState(Player.UserId, "Jumping")
		task.delay(.01, function()
			if not getmetatable(self) then return end
			if StateManagerClient.GetEntityState(Player.UserId) == "Jumping" then
				StateManagerClient.BruteChangeState(Player.UserId, "Idling")
			end
		end)
	end
end

function MovementController:BindSprint()
	local Track = self.SprintTrack; if not Track then return end

	local CurrentSpeed = vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat)
	local RunAlpha = (CurrentSpeed / self.Options.DefaultSpeed) / 2

	local moveDirection = self.Humanoid.MoveDirection
	local isMovingBackward = false
	if vector.magnitude(moveDirection) > .001 then
		local forward = self.RootPart.CFrame.LookVector * advents.vector.flat
		local fmag = vector.magnitude(forward)
		if fmag > .001 then
			local fdir = forward / fmag
			isMovingBackward = vector.dot(moveDirection, fdir) < -.1
		end
	end

	local animSpeed = math.max(.05, math.abs(RunAlpha))
	Track:AdjustSpeed(isMovingBackward and -animSpeed or animSpeed)
end

function MovementController:GetSprintVisualThreshold(): number
	local DefaultSpeed = self.Options.DefaultSpeed or 16
	local RunThreshold = math.min(self.Options.SprintSpeed or 46, DefaultSpeed * (self.Options.RunThresholdMultiplier or 1.5))
	return self.Options.RunAnimationStartSpeed or math.max(DefaultSpeed * 1.03, RunThreshold * .92)
end

function MovementController:ShouldPlaySprintTrack(CurrentState: string?): boolean
	local Humanoid = self.Humanoid
	local RootPart = self.RootPart
	if not Humanoid or not RootPart then
		return false
	end

	if CurrentState == "Mantling" or CurrentState == "Vaulting" or CurrentState == "Sliding" then
		return false
	end

	if os.clock() < (self.RunSuppressUntil or 0) then
		return false
	end

	if self:IsAirborneForSprint() then
		return false
	end

	local HSpeed = vector.magnitude(RootPart.AssemblyLinearVelocity * advents.vector.flat)
	if CurrentState == "Running" then
		return HSpeed >= math.max((self.Options.DefaultSpeed or 16) * .95, 2)
	end

	local MoveMagnitude = vector.magnitude(Humanoid.MoveDirection * advents.vector.flat)
	if MoveMagnitude <= .1 then
		return false
	end

	return HSpeed >= self:GetSprintVisualThreshold()
end

function MovementController:IsAirborneForSprint(): boolean
	local Humanoid = self.Humanoid
	local RootPart = self.RootPart
	if not Humanoid or not RootPart then
		return false
	end

	local groundedInfo = grounded.getGroundInfo(self.Character, self.Options)
	local isGrounded = groundedInfo.IsGrounded or Humanoid.FloorMaterial ~= Enum.Material.Air
	local verticalVelocity = RootPart.AssemblyLinearVelocity.Y
	local runVerticalThreshold = self.Options.RunAirborneVerticalThreshold or 5.5
	local slopeVerticalThreshold = self.Options.RunSlopeAirborneVerticalThreshold or math.max(runVerticalThreshold, 12)
	local State = Humanoid:GetState()
	if State == Enum.HumanoidStateType.Jumping
		or State == Enum.HumanoidStateType.Freefall
		or State == Enum.HumanoidStateType.FallingDown
	then
		if not isGrounded then
			return true
		end
		if verticalVelocity > slopeVerticalThreshold then
			return true
		end
	end

	if Humanoid.FloorMaterial == Enum.Material.Air and not groundedInfo.IsGrounded then
		return true
	end

	if verticalVelocity > runVerticalThreshold and not isGrounded then
		return true
	end

	return not isGrounded
end

function MovementController:StartSprintTrack()
	local CurrentState = StateManagerClient.GetEntityState(Player.UserId)
	if CurrentState == "Mantling" or CurrentState == "Vaulting" or CurrentState == "Sliding" then return end
	if os.clock() < (self.RunSuppressUntil or 0) then return end
	if self:IsAirborneForSprint() then return end
	if not self.RootPart then return end

	local HSpeed = vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat)
	if CurrentState ~= "Running" and HSpeed < self:GetSprintVisualThreshold() then return end
	if self.SprintTrack and self.SprintTrack.IsPlaying then return end

	local Track = advents.animator.playAnim(self.Physics.Humanoid.Animator, Animations.LoadedAnimations.Movement.Run.loaded, .35)
	self.SprintTrack = Track
	Track.Priority = Enum.AnimationPriority.Movement

	CentralHeartbeat:Bind(function()
		if not getmetatable(self) then
			CentralHeartbeat:Unbind(nil, "SprintBind")
			return
		end
		self:BindSprint()
	end, "SprintBind")

	if CurrentState ~= "Running" then
		StateManagerClient.BruteChangeState(Player.UserId, "Running")
	end
end

function MovementController:StopSprintTrack(RunningAirborne: boolean?)
	advents.animator.stopAnim(Animations.LoadedAnimations.Movement.Run.loaded, .35)
	self.SprintTrack = nil

	CentralHeartbeat:Unbind(nil, "SprintBind")

	if not RunningAirborne then
		if StateManagerClient.GetEntityState(Player.UserId) == "Running" then
			StateManagerClient.BruteChangeState(Player.UserId, "Idling")
		end
	end
end

function MovementController:EnableStrafing()
	if self.StrafeEnabled then return end
	self.StrafeEnabled = true

	local TiltMultipliersOld = {
		ForwardZ = 1.5;
		ForwardRoll = 4.5;
		ForwardNeck = 3;
		DiagonalZ = 12;
		DiagonalRoll = 12.5;
		DiagonalNeck = 12.5;
		DiagonalLimb = 5;
		StraightZ = 2;
		SideRoll = 25;
		SideNeck = 30;
		SideLimb = 12;
	}

	local TiltMultipliers: typeof(TiltMultipliersOld) = {}

	local ZeroTilt = {
		Root = CFrame.Angles(0, 0, 0);
		Neck = CFrame.Angles(0, 0, 0);
		RShoulder = CFrame.Angles(0, 0, 0);
		LShoulder = CFrame.Angles(0, 0, 0);
		RHip = CFrame.Angles(0, 0, 0);
		LHip = CFrame.Angles(0, 0, 0);
	}

	self.Janitor:Add(RunService.Heartbeat:Connect(function(dt)
		if not getmetatable(self) then return end

		if not self.Options.StrafingEnabled then self:DisableStrafing() return end
		if StateManagerClient.GetEntityState(Player.UserId) == "Sliding" then return end

		local HRP = self.Character:FindFirstChild("HumanoidRootPart")
		if not HRP then return end
		if HRP.Anchored then return end

		local HumCheck = self.Character:FindFirstChild("Humanoid")
		if not HumCheck then return end

		for i, v in next, TiltMultipliersOld do
			TiltMultipliers[i] = v * math.min(HumCheck.WalkSpeed, 50) / (math.min(DEFAULT_WALKSPEED, 50) / (math.min(DEFAULT_WALKSPEED, 50) / 16))
		end

		local MoveDirection = HRP.CFrame:VectorToObjectSpace(HumCheck.MoveDirection)

		local Directions = {
			{Name = "FW_R"; Dir = vector.normalize(vector.create(1, 0, -1)); Weight = 1; Tilts = function(md, speedMult)
				local s = math.clamp(speedMult, 0, 0.8)
				local neckS = math.clamp(speedMult, 0, 0.15)
				return {
					Root = CFrame.Angles(math.rad(12) * s, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .5);
					Neck = CFrame.Angles(math.rad(-4) * neckS, 0, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .25);
					RShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
					LShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
					RHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
					LHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
				}
			end};

			{Name = "BW_R"; Dir = vector.normalize(vector.create(1, 0, 1)); Weight = 1; Tilts = function(md, speedMult)
				local s = math.clamp(speedMult, 0, 0.8)
				local neckS = math.clamp(speedMult, 0, 0.15)
				return {
					Root = CFrame.Angles(math.rad(-12) * s, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .55);
					Neck = CFrame.Angles(math.rad(4) * neckS, 0, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .2);
					RShoulder = CFrame.Angles(math.rad(3) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LShoulder = CFrame.Angles(math.rad(3) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					RHip = CFrame.Angles(math.rad(-2.5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LHip = CFrame.Angles(math.rad(-2.5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				}
			end};

			{Name = "BW_L"; Dir = vector.normalize(vector.create(-1, 0, 1)); Weight = 1; Tilts = function(md, speedMult)
				local s = math.clamp(speedMult, 0, 0.8)
				local neckS = math.clamp(speedMult, 0, 0.15)
				return {
					Root = CFrame.Angles(math.rad(-12) * s, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .55);
					Neck = CFrame.Angles(math.rad(4) * neckS, 0, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .2);
					RShoulder = CFrame.Angles(math.rad(3) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LShoulder = CFrame.Angles(math.rad(3) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					RHip = CFrame.Angles(math.rad(-2.5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LHip = CFrame.Angles(math.rad(-2.5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				}
			end};

			{Name = "FW_L"; Dir = vector.normalize(vector.create(-1, 0, -1)); Weight = 1; Tilts = function(md, speedMult)
				local s = math.clamp(speedMult, 0, 0.8)
				local neckS = math.clamp(speedMult, 0, 0.15)
				return {
					Root = CFrame.Angles(math.rad(12) * s, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .5);
					Neck = CFrame.Angles(math.rad(-4) * neckS, 0, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .25);
					RShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
					LShoulder = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
					RHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
					LHip = CFrame.Angles(0, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .45, 0);
				}
			end};

			{Name = "R"; Dir = vector.create(1, 0, 0); Weight = 1.28; Tilts = function(md, speedMult)
				local s = math.clamp(speedMult, 0, 0.95)
				local neckS = math.clamp(speedMult, 0, 0.2)
				return {
					Root = CFrame.Angles(math.rad(-5) * s, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .7);
					Neck = CFrame.Angles(math.rad(1.5) * neckS, 0, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .18);
					RShoulder = CFrame.Angles(math.rad(-5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LShoulder = CFrame.Angles(math.rad(5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					RHip = CFrame.Angles(math.rad(4) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LHip = CFrame.Angles(math.rad(-4) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				}
			end};

			{Name = "L"; Dir = vector.create(-1, 0, 0); Weight = 1.28; Tilts = function(md, speedMult)
				local s = math.clamp(speedMult, 0, 0.95)
				local neckS = math.clamp(speedMult, 0, 0.2)
				return {
					Root = CFrame.Angles(math.rad(-5) * s, 0, math.rad(-md.X) * TiltMultipliers.SideRoll * s * .7);
					Neck = CFrame.Angles(math.rad(1.5) * neckS, 0, math.rad(md.X) * TiltMultipliers.SideNeck * neckS * .18);
					RShoulder = CFrame.Angles(math.rad(5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LShoulder = CFrame.Angles(math.rad(-5) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					RHip = CFrame.Angles(math.rad(-4) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
					LHip = CFrame.Angles(math.rad(4) * s, math.rad(-md.X) * TiltMultipliers.SideLimb * s * .5, 0);
				}
			end};
		}

		self.LerpAlpha = dt * 10

		if not self.StrafeEnabled then return end

		local Now = workspace:GetServerTimeNow()
		if Now - self.LastStrafeUpdate < self.StrafeTickRate then return end
		self.LastStrafeUpdate = Now

		local CurrentTilts = ZeroTilt

		local Velocity = HRP.AssemblyLinearVelocity
		local HorizontalSpeed = vector.magnitude(Velocity * vector.create(1, 0, 1))
		local SpeedMult = math.clamp(HorizontalSpeed / 16, 0, 2)

		if MoveDirection ~= vector.zero then
			local bestDirection = nil
			local bestScore = self.DotThreshold

			for _, data in next, Directions do
				local score = vector.dot(MoveDirection, data.Dir) * (data.Weight or 1)
				if score > bestScore then
					bestScore = score
					bestDirection = data
				end
			end

			if bestDirection then
				CurrentTilts = bestDirection.Tilts(MoveDirection, SpeedMult)
			end
		end

		self.RootTilt = self.RootTilt:Lerp(CurrentTilts.Root, self.LerpAlpha)
		self.NeckTilt = self.NeckTilt:Lerp(CurrentTilts.Neck, self.LerpAlpha)
		self.RightShoulderTilt = self.RightShoulderTilt:Lerp(CurrentTilts.RShoulder, self.LerpAlpha)
		self.LeftShoulderTilt = self.LeftShoulderTilt:Lerp(CurrentTilts.LShoulder, self.LerpAlpha)
		self.RightHipTilt = self.RightHipTilt:Lerp(CurrentTilts.RHip, self.LerpAlpha)
		self.LeftHipTilt = self.LeftHipTilt:Lerp(CurrentTilts.LHip, self.LerpAlpha)

		self.RootJoint.C0 = self.OriginalRoot * self.RootTilt
		self.NeckJoint.C0 = self.OriginalNeck * self.NeckTilt
		self.RightShoulder.C0 = self.OriginalRightShoulder * self.RightShoulderTilt
		self.LeftShoulder.C0 = self.OriginalLeftShoulder * self.LeftShoulderTilt
		self.RightHip.C0 = self.OriginalRightHip * self.RightHipTilt
		self.LeftHip.C0 = self.OriginalLeftHip * self.LeftHipTilt

		BlinkClient.JointReplicator.Fire(CurrentTilts)
	end), "Disconnect", "Strafe")
end

function MovementController:DisableStrafing()
	self.StrafeEnabled = false
	self.Janitor:Remove("Strafe")

	self.RootJoint.C0 = self.OriginalRoot
	self.NeckJoint.C0 = self.OriginalNeck
	self.RightShoulder.C0 = self.OriginalRightShoulder
	self.LeftShoulder.C0 = self.OriginalLeftShoulder
	self.RightHip.C0 = self.OriginalRightHip
	self.LeftHip.C0 = self.OriginalLeftHip

	BlinkClient.JointReplicator.Fire({
		Root = CFrame.Angles(0, 0, 0);
		Neck = CFrame.Angles(0, 0, 0);
		RShoulder = CFrame.Angles(0, 0, 0);
		LShoulder = CFrame.Angles(0, 0, 0);
		RHip = CFrame.Angles(0, 0, 0);
		LHip = CFrame.Angles(0, 0, 0);
	})
end

function MovementController:Step(dt: number, MoveDirection: vector)
	local EffectiveMoveDirection = self.ExternalMoveDirection
	if EffectiveMoveDirection == nil then
		EffectiveMoveDirection = MoveDirection
	else
		self.Humanoid:Move(Vector3.new(EffectiveMoveDirection.X, EffectiveMoveDirection.Y, EffectiveMoveDirection.Z), false)
	end

	self.Physics.MoveDirection = EffectiveMoveDirection
	self.Physics:Update(dt, EffectiveMoveDirection)

	local CurrentState = StateManagerClient.GetEntityState(Player.UserId)
	if self:IsAirborneForSprint() then
		if self.SprintTrack then
			self:StopSprintTrack(true)
		end
		return
	end

	if self:ShouldPlaySprintTrack(CurrentState) then
		self:StartSprintTrack()
	elseif self.SprintTrack then
		self:StopSprintTrack(false)
	end
end

function MovementController:Destroy()
	self:DisableStrafing()
	self.Janitor:Cleanup()

	if self.Physics then
		self.Physics:Destroy()
		self.Physics = nil
	end

	if self.CameraController then
		self.CameraController:SetTilt(0)
	end

	setmetatable(self, nil)
end

return MovementController
