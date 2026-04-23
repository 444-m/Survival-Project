local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local Helper = require("./Helper")
local Grounded = require("./grounded")
local CentralHeartbeat = require(ReplicatedStorage.Modules.Client.CentralHeartbeat)
local StateManagerClient = require(ReplicatedStorage.Modules.Client.Systems.StateManagerClient)

local Janitor = require(ReplicatedStorage.Packages.Shared.Janitor)
local Signal = require(ReplicatedStorage.Packages.Shared.Signal)

local MapRoot = workspace:WaitForChild("objects")
local MapContainer = MapRoot:WaitForChild("map")

local Physics = {}; Physics.__index = Physics

local function loopFunction(callback, fpsCount)
	local dt = 1 / (fpsCount or 60)
	local cur = 0
	local dw = 0
	local on = true

	local function stop()
		on = false
	end

	task.spawn(function()
		while on do
			cur = cur + dw
			while dt <= cur do
				callback(stop)
				cur = cur - dt
				if not on then break end
			end
			dw = RunService.RenderStepped:Wait()
		end
	end)

	return stop
end

local function bezierAlpha(t: number): number
	return advents.easing.bezier_inout(math.clamp(t, 0, 1), 0, .18, .82, 1)
end

function Physics.new(Character: Model, Options: typeof(require("./configs")))
	local self = setmetatable({}, Physics)

	self.Options = Options
	self.Player = Players:GetPlayerFromCharacter(Character)
	self.Character = Character
	self.Humanoid = Character:WaitForChild("Humanoid") :: Humanoid
	self.RootPart = Character:WaitForChild("HumanoidRootPart") :: BasePart
	self.Janitor = Janitor.new()

	self.CurrentSpeed = self.Options.DefaultSpeed or 16
	self.BaseCurrentSpeed = self.Options.DefaultSpeed or 16
	self.MoveDirection = vector.zero
	self.CurrentMoveVector = vector.zero
	self.StopCarryVelocity = vector.zero
	self.StopCarryStartedAt = nil :: number?
	self.LastHorizontalVelocity = vector.zero
	self.LastInputDirection = vector.zero
	self.WasInputActive = false
	self.WasGrounded = true
	self.AirbornePeakHorizontalSpeed = 0
	self.AirbornePeakHorizontalVelocity = vector.zero
	self.PendingMomentumStartAt = nil :: number?
	self.WaitingForMomentumLanding = false
	self.MomentumBlockedUntil = nil :: number?
	self.MomentumInputGraceUntil = nil :: number?
	self.WallRunSide = nil :: string?
	self.WallRunNormal = vector.zero
	self.WallRunDir = vector.zero
	self.WallRunStartedAt = nil :: number?
	self.LastWallRunEndedAt = 0
	self.WallRunFacing = nil :: CFrame?
	self.WallRunHoldActive = false
	self.WallRunHoldUntil = 0
	self.WallRunWalkSpeed = nil :: number?
	self.WallRunResumeUntil = 0
	self.WallRunEntryPrimedUntil = 0
	self.WallRunChainTargetSide = nil :: string?
	self.WallRunChainTargetUntil = 0
	self.WallRunHitInstance = nil :: BasePart?
	self.WallRunJumpPrimedUntil = 0
	self.LastWallRunInputAt = 0
	self.WallRunEntrySpeed = 0
	self.WallRunSideInputBeganAt = 0
	self.WallRunLastValidHitAt = 0
	self.SlideCancelPropelDir = nil :: vector?
	self.SlideCancelPropelSpeed = nil :: number?
	self.SlideStartSpeed = nil :: number?
	self.PendingVelocityQueue = {} :: {{horizontal: vector?; horizontalMode: string?; vertical: number?; verticalMode: string?}}
	self.VelocityQueueScheduled = false
	self.TemporarySpeedBoost = 0
	self.TemporarySpeedBoostDir = vector.zero
	self.TemporarySpeedBoostHoldUntil = 0
	self.TemporarySpeedBoostDecel = 0

	self.States = {
		Running = Signal();
		Walking = Signal();
		SlideStart = Signal();
		SlideStop = Signal();
		SlideCancel = Signal();
		VaultStart = Signal();
		MantleStart = Signal();
		WallRunLeft = Signal();
		WallRunRight = Signal();
		WallRunStop = Signal();
		WallJumpLeft = Signal();
		WallJumpRight = Signal();
	}

	self.RunWalkState = nil

	self.Janitor:Add(function()
		for _, s in next, self.States do
			s:Destroy()
		end
	end, true, "PhysicsSignals")

	self:Setup()
	return self
end

function Physics:Setup()
	if not getmetatable(self) then return end

	self.Humanoid.UseJumpPower = true
	self.Humanoid.JumpPower = self.Options.JumpPower or 56
	self.Humanoid.WalkSpeed = self.Options.DefaultSpeed or 16
	self.BaseCurrentSpeed = self.Options.DefaultSpeed or 16
	self.CurrentSpeed = self.Options.DefaultSpeed or 16
	self.LastJumpedAt = 0
	self.AutoRotateValue = self.Humanoid.AutoRotate

	self.Janitor:Add(self.Humanoid.StateChanged:Connect(function(_, New)
		if New == Enum.HumanoidStateType.Jumping or New == Enum.HumanoidStateType.Freefall then
			self.LastJumpedAt = os.clock()
		end
	end), "Disconnect", "JumpTrack")
end

function Physics:SetAutoRotate(Value: boolean)
	self.AutoRotateValue = Value == true
	self.Humanoid.AutoRotate = self.AutoRotateValue
	self.Character:SetAttribute("AutoRotate", self.AutoRotateValue)
end

function Physics:Destroy()
	self:StopStopMover()
	self.Janitor:Cleanup()
	setmetatable(self, nil)
end

function Physics:GetAutoRotateValue(): boolean
	if self.AutoRotateValue == nil then
		self.AutoRotateValue = self.Humanoid.AutoRotate
	end
	return self.AutoRotateValue
end

local function mergeHorizontalVelocity(Current: vector, Requested: vector, Mode: string?): vector
	local FlatRequested = Requested * advents.vector.flat

	if Mode == "add" then
		return Current + FlatRequested
	end

	if Mode == "max" then
		local CurrentSpeed = vector.magnitude(Current)
		local RequestedSpeed = vector.magnitude(FlatRequested)
		if RequestedSpeed > CurrentSpeed then
			return FlatRequested
		end
		return Current
	end

	return FlatRequested
end

local function mergeVerticalVelocity(Current: number, Requested: number, Mode: string?): number
	if Mode == "add" then
		return Current + Requested
	end

	if Mode == "max" then
		return math.max(Current, Requested)
	end

	if Mode == "min" then
		return math.min(Current, Requested)
	end

	if Mode == "maxabs" then
		if math.abs(Requested) > math.abs(Current) then
			return Requested
		end
		return Current
	end

	return Requested
end

function Physics:ApplyManagedVelocity(Update: {horizontal: vector?; horizontalMode: string?; vertical: number?; verticalMode: string?})
	if not getmetatable(self) then return end

	local AV = self.RootPart.AssemblyLinearVelocity
	local Horizontal = vector.create(AV.X, 0, AV.Z)
	local Vertical = AV.Y

	if Update.horizontal ~= nil then
		Horizontal = mergeHorizontalVelocity(Horizontal, Update.horizontal, Update.horizontalMode)
	end

	if Update.vertical ~= nil then
		Vertical = mergeVerticalVelocity(Vertical, Update.vertical, Update.verticalMode)
	end

	self.RootPart.AssemblyLinearVelocity = vector.create(Horizontal.X, Vertical, Horizontal.Z)
end

function Physics:FlushVelocityQueue()
	self.VelocityQueueScheduled = false
	if #self.PendingVelocityQueue == 0 then return end

	local Queue = self.PendingVelocityQueue
	self.PendingVelocityQueue = {}

	local AV = self.RootPart.AssemblyLinearVelocity
	local Horizontal = vector.create(AV.X, 0, AV.Z)
	local Vertical = AV.Y

	for _, Update in next, Queue do
		if Update.horizontal ~= nil then
			Horizontal = mergeHorizontalVelocity(Horizontal, Update.horizontal, Update.horizontalMode)
		end

		if Update.vertical ~= nil then
			Vertical = mergeVerticalVelocity(Vertical, Update.vertical, Update.verticalMode)
		end
	end

	self.RootPart.AssemblyLinearVelocity = vector.create(Horizontal.X, Vertical, Horizontal.Z)
end

function Physics:QueueManagedVelocity(Update: {horizontal: vector?; horizontalMode: string?; vertical: number?; verticalMode: string?})
	if not getmetatable(self) then return end

	table.insert(self.PendingVelocityQueue, Update)
	if self.VelocityQueueScheduled then
		return
	end

	self.VelocityQueueScheduled = true
	task.defer(function()
		if not getmetatable(self) then return end
		self:FlushVelocityQueue()
	end)
end

function Physics:ClearMovementVelocityStack()
	self.PendingVelocityQueue = {}
	self.VelocityQueueScheduled = false
	self.StopCarryVelocity = vector.zero
	self.StopCarryStartedAt = nil
	self.LastHorizontalVelocity = vector.zero
	self.SlideCancelPropelDir = nil
	self.SlideCancelPropelSpeed = nil
	self.SlideStartSpeed = nil
	self.TemporarySpeedBoost = 0
	self.TemporarySpeedBoostDir = vector.zero
	self.TemporarySpeedBoostHoldUntil = 0
	self.TemporarySpeedBoostDecel = 0
end

function Physics:BeginExclusiveMovement(Kind: string)
	if not getmetatable(self) then return end

	self:ClearMovementVelocityStack()
	self:StopStopMover()
	self.PendingMomentumStartAt = nil
	self.WaitingForMomentumLanding = false

	if Kind ~= "WallRun" and (self:GetWallRunMover() or self.WallRunSide) then
		self:StopWallRun()
	end

	if Kind ~= "Slide" and self.IsSliding then
		self:StopSlide()
	end

	if Kind ~= "Mantle" and self.Janitor:Get("MantleMove") then
		self.Janitor:Remove("MantleMove")
		self.Humanoid.JumpPower = self.Options.JumpPower or 56
	end

	if Kind ~= "Vault" and self.Janitor:Get("VaultMove") then
		self.Janitor:Remove("VaultMove")
		self.Humanoid.JumpPower = self.Options.JumpPower or 56
	end

	if Kind ~= "WallFlip" and self.Janitor:Get("WallFlipMove") then
		self.Janitor:Remove("WallFlipMove")
		self.Janitor:Remove("WallFlipDash")
		self.Janitor:Remove("WallFlipDashAtt")
		self.Janitor:Remove("WallFlipDown")
		self.Janitor:Remove("WallFlipDownConn")
		self.Humanoid.JumpPower = self.Options.JumpPower or 56
	end
end

function Physics:StartTemporarySpeedBoost(Amount: number, Direction: vector?, HoldDuration: number?, DecelRate: number?)
	if not getmetatable(self) then return end
	if Amount <= 0 then return end

	self.TemporarySpeedBoost = math.max(self.TemporarySpeedBoost or 0, Amount)
	self.TemporarySpeedBoostHoldUntil = math.max(self.TemporarySpeedBoostHoldUntil or 0, os.clock() + math.max(HoldDuration or 0, 0))
	self.TemporarySpeedBoostDecel = math.max(DecelRate or 0, self.TemporarySpeedBoostDecel or 0)

	local FlatDirection = (Direction or vector.zero) * advents.vector.flat
	if vector.magnitude(FlatDirection) > .001 then
		self.TemporarySpeedBoostDir = vector.normalize(FlatDirection)
	end
end

function Physics:UpdateTemporarySpeedBoost(Dt: number, MoveVector: vector): number
	local Boost = self.TemporarySpeedBoost or 0
	if Boost <= .01 then
		self.TemporarySpeedBoost = 0
		self.TemporarySpeedBoostDir = vector.zero
		return 0
	end

	local Now = os.clock()
	local DecelRate = self.TemporarySpeedBoostDecel or 0
	local InputFlat = MoveVector * advents.vector.flat
	local BoostDir = self.TemporarySpeedBoostDir or vector.zero
	local DecayScale = 1

	if vector.magnitude(InputFlat) > .001 and vector.magnitude(BoostDir) > .001 then
		local Alignment = vector.dot(vector.normalize(InputFlat), BoostDir)
		if Alignment < .15 then
			DecayScale += (0.15 - Alignment) * 1.7
		elseif Alignment > .8 then
			DecayScale *= .85
		end
	elseif vector.magnitude(InputFlat) <= .001 then
		DecayScale = 1.35
	end

	if Now >= (self.TemporarySpeedBoostHoldUntil or 0) then
		self.TemporarySpeedBoost = math.max(0, Boost - (DecelRate * DecayScale * Dt))
	else
		if vector.magnitude(InputFlat) > .001 and vector.magnitude(BoostDir) > .001 then
			local HoldAlignment = vector.dot(vector.normalize(InputFlat), BoostDir)
			if HoldAlignment < -.2 then
				self.TemporarySpeedBoost = math.max(0, Boost - (DecelRate * 1.25 * Dt))
			end
		end
	end

	if self.TemporarySpeedBoost <= .01 then
		self.TemporarySpeedBoost = 0
		self.TemporarySpeedBoostDir = vector.zero
	end

	return self.TemporarySpeedBoost
end

function Physics:UpdateSpeed(Dt: number, InputMagnitude: number, MoveVector: vector, SkipState: boolean?)
	local TargetSpeed = self.Options.SprintSpeed or 46
	local MinSpeed = self.Options.DefaultSpeed or 16
	local SpeedAcceleration = self.Options.SpeedAcceleration or 58
	local SpeedDecceleration = self.Options.SpeedDecceleration or 52

	local CanRun = StateManagerClient.CanTransition(self.Player.UserId, "Running")
	local CurrentState = StateManagerClient.GetEntityState(self.Player.UserId)
	local StateStopFlags = {"Sliding"}
	local ShouldStop = table.find(StateStopFlags, CurrentState) ~= nil

	if InputMagnitude > .01 and vector.magnitude(MoveVector) > .001 then
		local BackwardMultiplier = self.Options.BackwardSpeedMultiplier or .65
		local BackwardCurve = self.Options.BackwardSpeedCurve or 1.45
		local Forward = self.RootPart.CFrame.LookVector * advents.vector.flat
		local fmag = vector.magnitude(Forward)
		if fmag > .001 then
			local FDir = Forward / fmag
			local MDir = vector.normalize(MoveVector)
			local Dot = vector.dot(MDir, FDir)
			local BInfluence = math.max(0, -Dot) ^ BackwardCurve
			local BPenalty = BInfluence * (1 - BackwardMultiplier)
			TargetSpeed *= (1 - BPenalty)
		end
	end

	local Base = self.BaseCurrentSpeed or MinSpeed
	local TempBoost = self:UpdateTemporarySpeedBoost(Dt, MoveVector)
	if ShouldStop then
		Base = math.max(0, Base - (SpeedDecceleration * 3.5 * Dt))
	elseif InputMagnitude > .01 and CanRun then
		Base = math.min(TargetSpeed, Base + (SpeedAcceleration * Dt))
	else
		local Ratio = Base / TargetSpeed
		local Decel = CanRun and SpeedDecceleration or (SpeedDecceleration * 3.5 * Ratio)
		Base = math.max(MinSpeed, Base - (Decel * Dt))
	end

	local HumanoidState = self.Humanoid:GetState()
	local VerticalVelocity = self.RootPart.AssemblyLinearVelocity.Y
	local IsGrounded = Grounded.isGrounded(self.Character, self.Options)
	if self.Humanoid.FloorMaterial == Enum.Material.Air
		or HumanoidState == Enum.HumanoidStateType.Jumping
		or HumanoidState == Enum.HumanoidStateType.Freefall
		or HumanoidState == Enum.HumanoidStateType.FallingDown
		or (CurrentState == "Running" and VerticalVelocity > (self.Options.RunAirborneVerticalThreshold or 3))
	then
		IsGrounded = false
	end
	local CurHorizSpeed = vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat)
	local MomentumSpeed = self:GetMomentumSpeed()
	local MovementSpeed = math.max(CurHorizSpeed, MomentumSpeed)

	if vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat) <= .01 then
		if StateManagerClient.GetEntityState(self.Player.UserId) == "Running" then
			StateManagerClient.BruteChangeState(self.Player.UserId, "Idling")
		end
	end

	self.BaseCurrentSpeed = Base
	local MomentumKeepThreshold = math.max(self.Options.MomentumStopThreshold or .4, MinSpeed * .02)
	local Target
	if ShouldStop then
		Target = math.max(0, (Base + MomentumSpeed + TempBoost) - (SpeedDecceleration * 3.5 * Dt))
		if MomentumSpeed <= MomentumKeepThreshold then
			self:StopStopMover()
		end
	elseif not CanRun then
		Target = math.max(MinSpeed, (Base + MomentumSpeed + TempBoost) - (SpeedDecceleration * 3.5 * Dt))
		if MomentumSpeed <= MomentumKeepThreshold then
			self:StopStopMover()
		end
	else
		Target = Base + MomentumSpeed + TempBoost
	end

	local Blend = self.Options.SpeedBlend or 0
	if Blend > 0 then
		local Alpha = Helper.ExpDecayAlpha(Blend, Dt)
		self.CurrentSpeed = (self.CurrentSpeed or Target) + ((Target - (self.CurrentSpeed or Target)) * Alpha)
	else
		self.CurrentSpeed = Target
	end

	local RunThreshold = math.min(self.Options.SprintSpeed, self.Options.DefaultSpeed * (self.Options.RunThresholdMultiplier or 1.5))
	local RunAlpha = (MovementSpeed - self.Options.DefaultSpeed) / math.max(RunThreshold - self.Options.DefaultSpeed, 1)
	RunAlpha = math.clamp(RunAlpha, 0, 1)

	if not SkipState then
		if not IsGrounded then
			if self.RunWalkState == "Running" then
				self.RunWalkState = "Walking"
				self.States.Walking:Fire(true)
			end
		end

		if RunAlpha >= (self.Options.RunStateAlphaThreshold or .38) then
			if self.RunWalkState ~= "Running" and IsGrounded and InputMagnitude > .1 then
				self.RunWalkState = "Running"
				self.States.Running:Fire()
			end
		else
			if self.RunWalkState ~= "Walking" then
				self.RunWalkState = "Walking"
				self.States.Walking:Fire()
			end
		end
	end

	self.Humanoid.WalkSpeed = self.CurrentSpeed
end

function Physics:StartStopMover(InitialVelocity: vector)
	if self.Janitor:Get("StopMover") then return end

	local Att = Instance.new("Attachment")
	Att.Parent = self.RootPart
	self.Janitor:Add(Att, "Destroy", "StopAttachment")

	local Mover = Instance.new("LinearVelocity")
	Mover.Attachment0 = Att
	Mover.RelativeTo = Enum.ActuatorRelativeTo.World
	Mover.ForceLimitsEnabled = true
	Mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	Mover.MaxAxesForce = advents.vector.flat * 1.5e5
	Mover.MaxForce = 1.5e5
	Mover.VectorVelocity = InitialVelocity * advents.vector.flat
	Mover.Parent = self.RootPart
	self.Janitor:Add(Mover, "Destroy", "StopMover")
end

function Physics:StopStopMover()
	self.Janitor:Remove("StopMover")
	self.Janitor:Remove("StopAttachment")
	self.StopCarryVelocity = vector.zero
	self.StopCarryStartedAt = nil
	self:RefreshCurrentSpeedFromMomentum()
end

function Physics:GetStopMover()
	return self.Janitor:Get("StopMover")
end

function Physics:GetMomentumSpeed(): number
	return vector.magnitude(self.StopCarryVelocity)
end

function Physics:RefreshCurrentSpeedFromMomentum()
	local Base = self.BaseCurrentSpeed or (self.Options.DefaultSpeed or 16)
	self.CurrentSpeed = Base + self:GetMomentumSpeed() + (self.TemporarySpeedBoost or 0)
	self.Humanoid.WalkSpeed = self.CurrentSpeed
end

function Physics:GetWallRunMover()
	return self.Janitor:Get("WallRunVelocity")
end

function Physics:SetWallRunHoldActive(Active: boolean)
	self.WallRunHoldActive = Active == true
	if self.WallRunHoldActive then
		if not self.WallRunHoldStartedAt then
			self.WallRunHoldStartedAt = os.clock()
		end
		self.WallRunHoldUntil = 0
		self:PrimeWallRunEntry()
	else
		self.WallRunHoldStartedAt = nil
		self.WallRunHoldUntil = 0
	end
end

function Physics:QueueWallRunResume(Duration: number)
	self.WallRunResumeUntil = os.clock() + (Duration or 0)
	if self.WallRunHoldActive then return end
	self.WallRunHoldUntil = 0
end

function Physics:PrimeWallRunEntry(Duration: number?)
	self.WallRunEntryPrimedUntil = os.clock() + (Duration or self.Options.WallRunEntryPrimeWindow or .32)
end

function Physics:IsWallRunEntryPrimed(): boolean
	if (self.WallRunEntryPrimedUntil or 0) <= 0 then
		return false
	end
	if os.clock() > self.WallRunEntryPrimedUntil then
		self.WallRunEntryPrimedUntil = 0
		return false
	end
	return true
end

function Physics:GetWallRunChainTargetSide(): string?
	if not self.WallRunChainTargetSide then
		return nil
	end
	if os.clock() > (self.WallRunChainTargetUntil or 0) then
		self.WallRunChainTargetSide = nil
		self.WallRunChainTargetUntil = 0
		return nil
	end

	local HeldRight = self:GetWallRunSideInputOk("Right")
	local HeldLeft = self:GetWallRunSideInputOk("Left")
	if HeldRight ~= HeldLeft then
		self.WallRunChainTargetSide = HeldRight and "Right" or "Left"
	end

	return self.WallRunChainTargetSide
end

function Physics:IsWallRunning(): boolean
	return self:GetWallRunMover() ~= nil
end

function Physics:PrimeWallRunJump()
	self.WallRunJumpPrimedUntil = os.clock() + (self.Options.WallJumpPrimeWindow or .32)
end

function Physics:GetWallRunElapsed(): number
	if not self.WallRunStartedAt then return 0 end
	return os.clock() - self.WallRunStartedAt
end

function Physics:GetWallRunInputOk(): boolean
	local Deadzone = self.Options.WallRunInputDeadzone or .04
	local Flat = self.MoveDirection * advents.vector.flat
	if vector.magnitude(Flat) <= Deadzone then return false end

	local MoveDir = vector.normalize(Flat)
	local Forward = self.RootPart.CFrame.LookVector * advents.vector.flat
	local fmag = vector.magnitude(Forward)
	if fmag <= .001 then return false end

	local FDir = Forward / fmag
	if vector.dot(MoveDir, FDir) < (self.Options.WallRunForwardDot or .08) then
		return false
	end

	return true
end

function Physics:GetWallRunSideInputOk(side: string?): boolean
	local Flat = self.MoveDirection * advents.vector.flat
	if vector.magnitude(Flat) <= (self.Options.WallRunInputDeadzone or .04) then
		return false
	end

	local Right = self.RootPart.CFrame.RightVector * advents.vector.flat
	if vector.magnitude(Right) <= .001 then
		return false
	end

	local SideInput = vector.dot(vector.normalize(Flat), vector.normalize(Right))
	local Threshold = self.Options.WallRunDirInputThreshold or .08
	if side == "Left" then
		return SideInput <= -Threshold
	end
	if side == "Right" then
		return SideInput >= Threshold
	end
	return math.abs(SideInput) >= Threshold
end

function Physics:GetWallRunHit(side: string, Distance: number?, OriginOffset: vector?)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {MapContainer}

	local Origin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunCastOrigin or 1.2))
	if OriginOffset then
		Origin += OriginOffset
	end

	local Right
	local Dir
	if self:IsWallRunning() and vector.magnitude(self.WallRunNormal) > .001 then
		local WallNorm = vector.normalize(self.WallRunNormal)
		Dir = -WallNorm
		local WallFwd = vector.normalize(vector.cross(advents.vector.yAxis, WallNorm))
		Right = vector.normalize(vector.cross(WallFwd, advents.vector.yAxis))
	else
		Right = self.RootPart.CFrame.RightVector * advents.vector.flat
		if vector.magnitude(Right) <= .001 then return nil, Origin, Right end
		Right = vector.normalize(Right)
		Dir = side == "Left" and -Right or Right
	end

	local Dist = Distance or self.Options.WallRunDetectDistance or self.Options.WallRunCastDistance or 2.6
	local Offsets = self.Options.WallRunDetectOffsets or {0, 2, -2}

	local Forward
	if self:IsWallRunning() and vector.magnitude(self.WallRunDir) > .001 then
		Forward = self.WallRunDir
	else
		Forward = self.RootPart.CFrame.LookVector * advents.vector.flat
		if vector.magnitude(Forward) > .001 then
			Forward = vector.normalize(Forward)
		end
	end

	for _, z in next, Offsets do
		local OffOrigin = Origin
		if z ~= 0 and vector.magnitude(Forward) > .001 then
			OffOrigin = Origin + (Forward * z)
		end
		local Hit = workspace:Raycast(OffOrigin, Dir * Dist, Params)
		if Hit and self:IsValidWallRunHit(Hit, Dir) then
			return Hit, OffOrigin, Right
		end
	end

	local Hit = workspace:Raycast(Origin, Dir * Dist, Params)
	if Hit and self:IsValidWallRunHit(Hit, Dir) then
		return Hit, Origin, Right
	end

	if not self:IsWallRunning() then
		return Hit, Origin, Right
	end

	local OParams = OverlapParams.new()
	OParams.FilterType = Enum.RaycastFilterType.Include
	OParams.FilterDescendantsInstances = {MapContainer}
	local SpatialRadius = math.min(self.Options.WallRunSpatialRadius or 2.2, (self.Options.WallRunSnapDistance or .55) + .85)
	local Parts = workspace:GetPartBoundsInRadius(Origin, SpatialRadius, OParams)
	for _, Part in next, Parts do
		if Part.CanCollide then
			local ToCenter = vector.create(
				Part.Position.X - Origin.X,
				0,
				Part.Position.Z - Origin.Z
			)
			if vector.magnitude(ToCenter) > .001 then
				local Toward = vector.normalize(ToCenter)
				if vector.dot(Toward, Dir) > .35 then
					local SpatialHit = workspace:Raycast(Origin, Toward * (SpatialRadius + .45), Params)
					if SpatialHit and SpatialHit.Instance == Part and self:IsValidWallRunHit(SpatialHit, Dir) then
						return SpatialHit, Origin, Right
					end
				end
			end
		end
	end

	return Hit, Origin, Right
end

function Physics:GetWallRunHitDir(Dir: vector, Distance: number?)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {MapContainer}

	local Origin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunCastOrigin or 1.2))
	if vector.magnitude(Dir) <= .001 then return nil, Origin end
	local DirUnit = vector.normalize(Dir)
	local Dist = Distance or self.Options.WallRunCastDistance or 2.6
	local Hit = workspace:Raycast(Origin, DirUnit * Dist, Params)
	return Hit, Origin
end

function Physics:GetWallRunCornerHitDir(sideDir: vector, wallDir: vector)
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {MapContainer}

	local BaseOrigin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunCastOrigin or 1.2))
	if vector.magnitude(sideDir) <= .001 then return nil end
	local SDir = vector.normalize(sideDir)

	local Fwd = wallDir
	if vector.magnitude(Fwd) <= .001 then
		Fwd = self.RootPart.CFrame.LookVector * advents.vector.flat
		if vector.magnitude(Fwd) <= .001 then return nil end
	end
	Fwd = vector.normalize(Fwd)

	local SideDist = self.Options.WallRunCornerSide or 8.0
	local HeightOffsets = {0, 1.2, -1.2, 2.2, -2.2}
	local FwdOffsets = {4, 6, 8, 2.5, 1}
	local AngleOffsets = {0, 15, 30, -15, -30}

	for _, FwdDist in next, FwdOffsets do
		for _, AngleDeg in next, AngleOffsets do
			for _, HeightOff in next, HeightOffsets do
				local Origin = BaseOrigin + (advents.vector.yAxis * HeightOff) + (Fwd * FwdDist)
				local Rad = math.rad(AngleDeg)
				local Cos = math.cos(Rad)
				local Sin = math.sin(Rad)
				local Perp = vector.normalize(vector.cross(SDir, advents.vector.yAxis))
				local SweptDir = vector.normalize(SDir * Cos + Perp * Sin)
				local Hit = workspace:Raycast(Origin, SweptDir * SideDist, Params)
				if Hit and Hit.Instance and Hit.Instance.CanCollide and self:IsValidWallRunHit(Hit, SDir) then
					return Hit
				end
			end
		end
	end

	return nil
end

function Physics:IsValidWallRunHit(hit, sideDir: vector): boolean
	if not hit then return false end
	if not self:IsWallRunHitTallEnough(hit) then return false end
	local NFlat = hit.Normal * advents.vector.flat
	if vector.magnitude(NFlat) <= .001 then return false end
	if hit.Normal.Y > (self.Options.WallRunNormalYMax or .25) then return false end
	local Dist = hit.Distance
	if Dist and Dist > (self.Options.WallRunDetectDistance or 3.4) * 1.2 then
		return false
	end

	local NDir = vector.normalize(NFlat)
	if vector.magnitude(sideDir) > .001 then
		local SD = vector.normalize(sideDir)
		local SideDotMin = self.Options.WallRunSideDotMin or .5
		if vector.dot(NDir, -SD) < SideDotMin then
			return false
		end
	end
	local ToChar = vector.create(
		self.RootPart.Position.X - hit.Position.X,
		0,
		self.RootPart.Position.Z - hit.Position.Z
	)
	if vector.magnitude(ToChar) > .001 then
		ToChar = vector.normalize(ToChar)
		if vector.dot(NDir, ToChar) < .05 then
			return false
		end
	end

	return true
end

function Physics:ComputeWallRunDir(wallNormalFlat: vector, moveDirFlat: vector): vector
	local WDir = vector.normalize(vector.cross(advents.vector.yAxis, wallNormalFlat))
	if vector.dot(WDir, moveDirFlat) < 0 then
		WDir = -WDir
	end
	return WDir
end

function Physics:GetWallRunSideDir(side: string, wallNormalFlat: vector?): vector
	local Normal = wallNormalFlat or self.WallRunNormal
	local NFlat = Normal and (Normal * advents.vector.flat) or vector.zero
	if vector.magnitude(NFlat) > .001 then
		return -vector.normalize(NFlat)
	end

	local Right = self.RootPart.CFrame.RightVector * advents.vector.flat
	if vector.magnitude(Right) <= .001 then
		return vector.zero
	end

	Right = vector.normalize(Right)
	return side == "Left" and -Right or Right
end

function Physics:IsWallRunHitTallEnough(hit): boolean
	if not hit or not hit.Instance or not hit.Instance:IsA("BasePart") then
		return false
	end

	local Part = hit.Instance
	local TopY = Part.Position.Y + (Part.Size.Y * .5)
	local MinTopY = self.RootPart.Position.Y + (self.Options.WallRunMinTopHeight or .9)
	return TopY >= MinTopY
end

function Physics:GetWallRunGapFromHit(hit, wallNormalFlat: vector?): number
	if not hit then
		return math.huge
	end

	local NFlat = wallNormalFlat or (hit.Normal * advents.vector.flat)
	if vector.magnitude(NFlat) <= .001 then
		return math.huge
	end

	NFlat = vector.normalize(NFlat)
	local Offset = (self.RootPart.Position - hit.Position) * advents.vector.flat
	return math.abs(vector.dot(Offset, NFlat))
end

function Physics:GetWallRunSideInputAligned(side: string, moveDirection: vector, wallNormalFlat: vector?): boolean
	local MFlat = moveDirection * advents.vector.flat
	if vector.magnitude(MFlat) <= (self.Options.WallRunInputDeadzone or .04) then
		return false
	end

	local Normal = wallNormalFlat or self.WallRunNormal
	local NFlat = Normal and (Normal * advents.vector.flat) or vector.zero
	if vector.magnitude(NFlat) <= .001 then
		return true
	end

	local Dot = vector.dot(vector.normalize(MFlat), vector.normalize(NFlat))
	local AwayLimit = -(self.Options.WallRunAwayDotThreshold or .16)
	return Dot >= AwayLimit
end

function Physics:TryWallRunObstacleAction(): boolean
	if self.Janitor:Get("VaultMove") or self.Janitor:Get("MantleMove") then
		self:StopWallRun()
		return true
	end

	local CanVault, LandY, LedgeY = Helper.CheckLowRise(self.Character, self.Options)
	if CanVault then
		self:StopWallRun()
		self:QueueWallRunResume((self.Options.VaultDuration or .18) + .08)

		local Dot = vector.dot(self.Humanoid.MoveDirection * advents.vector.flat, self.RootPart.CFrame.LookVector)

		if Dot > 0 then	
			self.States.VaultStart:Fire(LandY, LedgeY)
		end
		return true
	end

	local CanMantle, FloorEstimate, HeadRoom = Helper.CheckHighRise(self.Character, self.Options.MantleMinCheck or 3, self.Options)
	if CanMantle then
		self:StopWallRun()
		local Duration = self:Mantle(FloorEstimate, HeadRoom)
		if Duration then
			self:QueueWallRunResume(Duration + .08)
			self.States.MantleStart:Fire(Duration)
			return true
		end
	end

	return false
end

function Physics:StartWallRun(side: string, wallNormalFlat: vector, wallDir: vector)
	if self:GetWallRunMover() then return end
	local Cooldown = self.Options.WallRunCooldown or .28
	if os.clock() - (self.LastWallRunEndedAt or 0) < Cooldown then return end
	self:BeginExclusiveMovement("WallRun")
	self.Janitor:Remove("WallKickVelocity")

	self.WallRunSide = side
	self.WallRunNormal = wallNormalFlat
	self.WallRunDir = wallDir
	self.WallRunStartedAt = os.clock()
	self.WallRunMissedChecks = 0
	self.WallRunHardMissChecks = 0
	self.WallRunPrevNormal = wallNormalFlat
	self.WallRunSideInputBeganAt = 0
	self.WallRunLastValidHitAt = os.clock()
	self.WallRunEntryPrimedUntil = 0

	local EntryHorizSpeed = vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat)
	self.WallRunEntrySpeed = EntryHorizSpeed

	local WRV = Instance.new("BodyVelocity")
	WRV.MaxForce = vector.create(1, 1, 1) * 5e4
	WRV.Name = "WallRunVelocity"
	WRV.Parent = self.RootPart
	self.Janitor:Add(WRV, "Destroy", "WallRunVelocity")

	local WRG = Instance.new("BodyGyro")
	WRG.MaxTorque = vector.create(1, 1, 1) * 5e4
	WRG.D = 200
	WRG.P = 8000
	WRG.Name = "WallRunGyro"
	WRG.Parent = self.RootPart
	self.Janitor:Add(WRG, "Destroy", "WallRunGyro")

	self.Humanoid.JumpPower = 0
	self.WallRunWalkSpeed = self.Humanoid.WalkSpeed
	self.Humanoid.WalkSpeed = 0
	self.Character:SetAttribute("AutoRotate", false)
	self.Humanoid.AutoRotate = false
	self.AutoRotateValue = false
	self.Humanoid.PlatformStand = true

	local SnapDist = self.Options.WallRunSnapDistance or .55
	local WallNorm = vector.magnitude(wallNormalFlat) > .001 and vector.normalize(wallNormalFlat) or wallNormalFlat
	local LookDir = self.RootPart.CFrame.LookVector

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {MapContainer}
	local WallCheck = workspace:Raycast(
		self.RootPart.Position + advents.vector.yAxis * (self.Options.WallRunCastOrigin or 1.2),
		-WallNorm * (self.Options.WallRunCastDistanceActive or 5.0),
		Params
	)

	if WallCheck then
		local SnapPos = WallCheck.Position + (WallNorm * SnapDist)
		SnapPos = vector.create(SnapPos.X, self.RootPart.Position.Y, SnapPos.Z)
		local SnapCF = CFrame.new(SnapPos, SnapPos + vector.create(LookDir.X, 0, LookDir.Z))
		self.RootPart.CFrame = SnapCF
	end

	local EntrySpeedBoost = math.max(EntryHorizSpeed, self.Options.WallRunSpeed or 44)
	local BoostVel = wallDir * EntrySpeedBoost
	local EntryBlend = self.Options.WallRunEntryBlend or .55
	local CurHV = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local ReattachedFromWallJump = self.WallJumpedAt
		and (os.clock() - self.WallJumpedAt) <= ((self.Options.WallJumpReattachWindow or .32) + .08)
	if ReattachedFromWallJump then
		EntryBlend = math.max(EntryBlend, self.Options.WallRunPostJumpEntryBlend or .82)
		local AlongWallSpeed = math.max(0, vector.dot(CurHV, wallDir))
		CurHV = wallDir * AlongWallSpeed
	end
	local EntryHV = CurHV + ((BoostVel - CurHV) * EntryBlend)
	self:ApplyManagedVelocity({
		horizontal = EntryHV;
		horizontalMode = "set";
		vertical = 2;
		verticalMode = "max";
	})

	if side == "Left" then
		self.States.WallRunLeft:Fire()
	else
		self.States.WallRunRight:Fire()
	end

	local BlockParams = RaycastParams.new()
	BlockParams.FilterType = Enum.RaycastFilterType.Include
	BlockParams.FilterDescendantsInstances = {MapContainer}

	local SmoothDir = wallDir
	local SmoothNormal = wallNormalFlat
	local CurrentRunSpeed = math.max(vector.magnitude(EntryHV), EntryHorizSpeed)

	local StopLoop
	StopLoop = loopFunction(function()
		if not getmetatable(self) then
			if StopLoop then StopLoop() end
			return
		end
		if not self:IsWallRunning() then
			if StopLoop then StopLoop() end
			return
		end

		local MaxDuration = self.Options.WallRunDuration or 7
		if self.WallRunStartedAt and (os.clock() - self.WallRunStartedAt) >= MaxDuration then
			self:WallJump()
			if StopLoop then StopLoop() end
			return
		end

		local CurSideDir = self:GetWallRunSideDir(self.WallRunSide or side, SmoothNormal)
		if vector.magnitude(CurSideDir) <= .001 then
			CurSideDir = self.RootPart.CFrame.RightVector * advents.vector.flat
			if vector.magnitude(CurSideDir) > .001 then
				CurSideDir = vector.normalize(CurSideDir)
			end
			if (self.WallRunSide or side) == "Left" then
				CurSideDir = -CurSideDir
			end
		end

		local ActiveDist = self.Options.WallRunCastDistanceActive or 3.4
		local EntryGrace = self.Options.WallRunEntryGrace or .3
		local InGrace = self.WallRunStartedAt and (os.clock() - self.WallRunStartedAt) < EntryGrace

		local Hit = self:GetWallRunHit(self.WallRunSide or side, ActiveDist)
		local UsedCornerHit = false
		if not Hit or not Hit.Instance or not Hit.Instance.CanCollide then
			local PrevN = self.WallRunPrevNormal
			local CornerHit = nil
			if vector.magnitude(PrevN) > .001 and vector.magnitude(CurSideDir) > .001 then
				local PrevDir = vector.normalize(vector.cross(advents.vector.yAxis, PrevN))
				if (self.WallRunSide or side) == "Left" then
					PrevDir = -PrevDir
				end
				CornerHit = self:GetWallRunCornerHitDir(CurSideDir, PrevDir)
			end

			if CornerHit and CornerHit.Instance and CornerHit.Instance.CanCollide and self:IsValidWallRunHit(CornerHit, CurSideDir) then
				Hit = CornerHit
				UsedCornerHit = true
				self.WallRunHardMissChecks = 0
				self.WallRunMissedChecks = 0
				self.WallRunHitInstance = CornerHit.Instance
				self.WallRunPrevNormal = CornerHit.Normal
				self.WallRunLastValidHitAt = os.clock()
			else
				if not InGrace then
					self.WallRunHardMissChecks = (self.WallRunHardMissChecks or 0) + 1
					if self.WallRunHardMissChecks >= (self.Options.WallRunHardMissMax or 6) then
						self:StopWallRun()
						if StopLoop then StopLoop() end
						return
					end
				end
				if not InGrace and (os.clock() - (self.WallRunLastValidHitAt or 0)) >= (self.Options.WallRunDetachGrace or .065) then
					self:StopWallRun()
					if StopLoop then StopLoop() end
					return
				end
				if not InGrace then
					self.WallRunMissedChecks = (self.WallRunMissedChecks or 0) + 1
				end
				return
			end
		else
			self.WallRunHardMissChecks = 0
		end

		if Hit.Instance and math.abs(Hit.Normal.Y) >= (self.Options.WallRunNormalYMax or .25) then
			if not InGrace then
				self.WallRunMissedChecks = (self.WallRunMissedChecks or 0) + 1
				if self.WallRunMissedChecks >= (self.Options.WallRunMaxMissedChecks or 14) then
					self:StopWallRun()
					if StopLoop then StopLoop() end
					return
				end
			end
		end

		if Hit.Instance then
			if not self:IsValidWallRunHit(Hit, CurSideDir) then
				local PrevN = self.WallRunPrevNormal
				if vector.magnitude(PrevN) > .001 then
					local PrevDir = vector.normalize(vector.cross(advents.vector.yAxis, PrevN))
					if (self.WallRunSide or side) == "Left" then PrevDir = -PrevDir end
					local CornerHit = self:GetWallRunCornerHitDir(CurSideDir, PrevDir)
					if CornerHit and CornerHit.Instance and CornerHit.Instance.CanCollide and self:IsValidWallRunHit(CornerHit, CurSideDir) then
						Hit = CornerHit
						UsedCornerHit = true
						self.WallRunMissedChecks = 0
						self.WallRunHitInstance = CornerHit.Instance
						self.WallRunPrevNormal = CornerHit.Normal
						self.WallRunLastValidHitAt = os.clock()
					else
						if not InGrace then
							self.WallRunMissedChecks = (self.WallRunMissedChecks or 0) + 1
						end
					end
				else
					if not InGrace then
						self.WallRunMissedChecks = (self.WallRunMissedChecks or 0) + 1
					end
				end
				if not InGrace and self.WallRunMissedChecks >= (self.Options.WallRunMaxMissedChecks or 14) then
					self:StopWallRun()
					if StopLoop then StopLoop() end
					return
				end
			else
				self.WallRunMissedChecks = 0
				self.WallRunHitInstance = Hit.Instance
				self.WallRunPrevNormal = Hit.Normal
				self.WallRunLastValidHitAt = os.clock()
			end
		end

		local RearHitTolerance = self.Options.WallRunRearHitTolerance or .85
		if Hit and Hit.Position and vector.magnitude(SmoothDir) > .001 then
			local HitOffset = (Hit.Position - self.RootPart.Position) * advents.vector.flat
			if not UsedCornerHit
				and Hit.Instance == self.WallRunHitInstance
				and vector.dot(HitOffset, SmoothDir) < -RearHitTolerance then
				self:StopWallRun()
				if StopLoop then StopLoop() end
				return
			end
		end

		local RawNormal = self.WallRunPrevNormal or Hit.Normal
		local NFlat = RawNormal * advents.vector.flat
		if vector.magnitude(NFlat) > .001 then
			NFlat = vector.normalize(NFlat)
		else
			NFlat = SmoothNormal
		end

		local TurnBlend = self.Options.WallRunTurnBlend or .48
		SmoothNormal = vector.normalize(SmoothNormal:Lerp(NFlat, math.clamp(TurnBlend, 0, 1)))

		local RawDir = vector.cross(SmoothNormal, advents.vector.yAxis)
		if vector.magnitude(RawDir) <= .001 then
			self:StopWallRun()
			if StopLoop then StopLoop() end
			return
		end
		RawDir = vector.normalize(RawDir)
		if (self.WallRunSide or side) == "Left" then
			RawDir = -RawDir
		end

		SmoothDir = vector.normalize(SmoothDir:Lerp(RawDir, math.clamp(TurnBlend, 0, 1)))
		self.WallRunDir = SmoothDir
		self.WallRunNormal = SmoothNormal

		local WallGap = self:GetWallRunGapFromHit(Hit, SmoothNormal)
		if not InGrace and WallGap > math.max((self.Options.WallRunSnapDistance or .55) + .82, 1.3) then
			self:StopWallRun()
			if StopLoop then StopLoop() end
			return
		end

		local TargetSpeed = self.Options.WallRunSpeed or 44
		local SpeedLerp = .18
		CurrentRunSpeed = CurrentRunSpeed + ((TargetSpeed - CurrentRunSpeed) * SpeedLerp)

		local DownSpeed = self.Options.WallRunDownwardSpeed or -.5
		local NormalPush = self.Options.WallRunNormalPush or 3.2
		local VertSpeed = 0
		local RawLY = 0

		local Cam = workspace.CurrentCamera
		if Cam then
			local LY = Cam.CFrame.LookVector.Y
			local Dz = self.Options.WallRunLookDeadzone or .08
			if math.abs(LY) >= Dz then
				RawLY = LY
				local Sign = LY > 0 and 1 or -1
				local Curved = Sign * (math.abs(LY) ^ .6)
				VertSpeed = Curved * (self.Options.WallRunVerticalSpeed or 14) * 1.5
			end
		end

		local BlockDist = self.Options.WallRunForwardBlockDistance or 3
		local DidObstacle = false
		if BlockDist > 0 then
			local LowOrigin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunForwardBlockLow or .6))
			local HighOrigin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunForwardBlockHigh or 2.6))
			local LowHit = workspace:Raycast(LowOrigin, SmoothDir * BlockDist, BlockParams)
			local HighHit = workspace:Raycast(HighOrigin, SmoothDir * BlockDist, BlockParams)

			local function IsBlocking(h)
				if not h or not h.Instance or not h.Instance.CanCollide then return false end
				if h.Instance == self.WallRunHitInstance then
					local HitNormalFlat = h.Normal * advents.vector.flat
					if vector.magnitude(HitNormalFlat) > .001 then
						HitNormalFlat = vector.normalize(HitNormalFlat)
						if vector.dot(HitNormalFlat, SmoothNormal) > .85 then
							return false
						end
					end
				end
				if vector.dot(h.Normal, SmoothNormal) > .85 then return false end
				return true
			end

			local LowBlock = IsBlocking(LowHit)
			local HighBlock = IsBlocking(HighHit)

			if LowBlock or HighBlock then
				if self:TryWallRunObstacleAction() then
					DidObstacle = true
					if StopLoop then StopLoop() end
					return
				end
				self:StopWallRun()
				if StopLoop then StopLoop() end
				return
			end
		end

		if not DidObstacle then
			local StickDist = self.Options.WallRunSnapDistance or 1.4
			local WallPos = Hit.Position or (self.RootPart.Position - (SmoothNormal * StickDist))
			local TargetStickPos = WallPos + (SmoothNormal * StickDist)
			local LateralError = vector.create(
				TargetStickPos.X - self.RootPart.Position.X,
				0,
				TargetStickPos.Z - self.RootPart.Position.Z
			)
			local LateralCorrection = LateralError * (self.Options.WallRunLateralCorrectionSpeed or 12)

			WRV.MaxForce = vector.create(5e4, 5e4, 5e4)
			WRV.Velocity = (SmoothDir * CurrentRunSpeed) + (-SmoothNormal * NormalPush) + vector.create(0, DownSpeed + VertSpeed, 0) + LateralCorrection

			local LookAt = self.RootPart.Position + SmoothDir * 10
			local MaxPitch = self.Options.WallRunMaxPitch or 28
			local PitchAngle = math.rad(math.clamp(RawLY * MaxPitch * 1.8, -MaxPitch, MaxPitch))
			local FlatCF = CFrame.lookAt(
				self.RootPart.Position,
				vector.create(LookAt.X, self.RootPart.Position.Y, LookAt.Z)
			)
			WRG.CFrame = FlatCF * CFrame.Angles(PitchAngle, 0, 0)
		end
	end, 60)

	self.Janitor:Add(StopLoop, nil, "WallRunLoop")
end

function Physics:StopWallRun()
	if not self:GetWallRunMover() and not self.WallRunSide then return end

	local ExitDir = vector.magnitude(self.WallRunDir) > .001 and self.WallRunDir or nil
	local ExitSpeed = self.Options.WallRunSpeed or 44

	self.Janitor:Remove("WallRunVelocity")
	self.Janitor:Remove("WallRunGyro")
	self.Janitor:Remove("WallRunLoop")
	self.Humanoid.JumpPower = self.Options.JumpPower or 56
	if self.WallRunWalkSpeed ~= nil then
		self.Humanoid.WalkSpeed = self.WallRunWalkSpeed
		self.WallRunWalkSpeed = nil
	end
	self.Character:SetAttribute("AutoRotate", true)
	self.Humanoid.AutoRotate = true
	self.AutoRotateValue = true
	self.Humanoid.PlatformStand = false
	self.LastWallRunEndedAt = os.clock()
	self.States.WallRunStop:Fire(self.WallRunSide)
	self.WallRunSide = nil
	self.WallRunNormal = vector.zero
	self.WallRunDir = vector.zero
	self.WallRunStartedAt = nil
	self.WallRunFacing = nil
	self.WallRunMissedChecks = 0
	self.WallRunHardMissChecks = 0
	self.WallRunPrevNormal = vector.zero
	self.WallRunHoldStartedAt = nil
	self.WallRunHoldUntil = 0
	self.WallRunEntryPrimedUntil = 0
	self.WallRunHitInstance = nil
	self.WallRunJumpPrimedUntil = 0
	self.LastWallRunInputAt = 0
	self.WallRunEntrySpeed = 0
	self.WallRunSideInputBeganAt = 0
	self.WallRunLastValidHitAt = 0

	if ExitDir and vector.magnitude(ExitDir) > .001 then
		local MV = ExitDir * ExitSpeed
		self.LastHorizontalVelocity = MV
		self.BaseCurrentSpeed = math.max(self.BaseCurrentSpeed or 0, ExitSpeed * .72)
		self.CurrentSpeed = math.max(self.CurrentSpeed or 0, ExitSpeed * .72)
		self:ApplyManagedVelocity({
			horizontal = MV;
			horizontalMode = "max";
		})
	end
end

function Physics:UpdateWallRun(Dt: number, MoveDirection: vector, InputActive: boolean, GroundedInfo, HorizontalSpeed: number): boolean
	local CurrentState = StateManagerClient.GetEntityState(self.Player.UserId)
	if CurrentState == "Mantling" or CurrentState == "Vaulting" then
		if self:GetWallRunMover() then
			self:StopWallRun()
		end
		return false
	end
	local IsGrounded = GroundedInfo and GroundedInfo.IsGrounded
	local GroundDist = GroundedInfo and GroundedInfo.Distance or math.huge
	local ResumeActive = self.WallRunResumeUntil and os.clock() <= self.WallRunResumeUntil
	if not ResumeActive then
		self.WallRunResumeUntil = 0
	end
	local HoldRequested = self.WallRunHoldActive
		or (self.WallRunHoldUntil and os.clock() <= self.WallRunHoldUntil)
	local HoldActive = HoldRequested or ResumeActive

	if self:GetWallRunMover() then
		self.Humanoid.AutoRotate = self:GetAutoRotateValue()
		if self.IsSliding or self.Janitor:Get("VaultMove") or self.Janitor:Get("MantleMove") or self.Janitor:Get("WallFlipMove") then
			self:StopWallRun()
			return false
		end
		if self.WallRunJumpPrimedUntil > 0 and os.clock() <= self.WallRunJumpPrimedUntil and self.WallRunHoldActive then
			self.WallRunJumpPrimedUntil = 0
			self:WallJump()
			return false
		end
		if self.WallRunJumpPrimedUntil > 0 and os.clock() > self.WallRunJumpPrimedUntil then
			self.WallRunJumpPrimedUntil = 0
		end
		if not HoldActive then
			self:StopWallRun()
			return false
		end
		self.WallRunSideInputBeganAt = 0
		if IsGrounded and GroundDist <= (self.Options.WallRunGroundStopDistance or .3) then
			self:StopWallRun()
			return false
		end
		local ContinueInputOk = self:GetWallRunSideInputAligned(
			self.WallRunSide or "Right",
			self.MoveDirection,
			self.WallRunNormal
		)
		if not ContinueInputOk then
			local Grace = self.Options.WallRunInputGrace or .25
			if os.clock() - (self.LastWallRunInputAt or 0) >= Grace then
				self:StopWallRun()
				return false
			end
		end
		return true
	end

	if IsGrounded and GroundDist <= (self.Options.WallRunGroundStopDistance or .3) then return false end

	local MinHeight = self.Options.WallRunMinHeight or 3.5
	if GroundDist < MinHeight then return false end

	if not ResumeActive then
		if not HoldRequested then return false end
		if not self:IsWallRunEntryPrimed() then return false end
	end
	if ResumeActive and HoldRequested and self:GetWallRunChainTargetSide() then
		self:SnapToWallRun()
		if self:GetWallRunMover() then
			return true
		end
	end

	local HoldDuration = self.Options.WallRunHoldDuration or .5
	if self.WallRunHoldStartedAt and (os.clock() - self.WallRunHoldStartedAt) < HoldDuration then return false end

	local MFlat = MoveDirection * advents.vector.flat
	if vector.magnitude(MFlat) < (self.Options.WallRunInputDeadzone or .04) then
		if (HorizontalSpeed or 0) < (self.Options.WallRunMinSpeed or 8) then
			return false
		end
	end
	if vector.magnitude(MFlat) > .001 then
		local Fwd = self.RootPart.CFrame.LookVector * advents.vector.flat
		if vector.magnitude(Fwd) > .001 then
			Fwd = vector.normalize(Fwd)
			local MDir = vector.normalize(MFlat)
			if vector.dot(MDir, Fwd) < (self.Options.WallRunForwardDot or .12) then
				return false
			end
		end
	end

	local Cooldown = self.Options.WallRunCooldown or .28
	if os.clock() - (self.LastWallRunEndedAt or 0) < Cooldown then return false end

	local WallJumpBlock = self.Options.WallRunPostJumpBlock or .45
	if not ResumeActive and self.WallJumpedAt and (os.clock() - self.WallJumpedAt) < WallJumpBlock then return false end

	local Fwd = self.RootPart.CFrame.LookVector * advents.vector.flat
	if vector.magnitude(Fwd) > .001 then
		Fwd = vector.normalize(Fwd)
		local BlockDist = self.Options.WallRunForwardBlockDistance or 3
		local Params = RaycastParams.new()
		Params.FilterType = Enum.RaycastFilterType.Include
		Params.FilterDescendantsInstances = {MapContainer}
		local LowOrigin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunForwardBlockLow or .6))
		local HighOrigin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunForwardBlockHigh or 2.6))
		local LowHit = workspace:Raycast(LowOrigin, Fwd * BlockDist, Params)
		local HighHit = workspace:Raycast(HighOrigin, Fwd * BlockDist, Params)
		if (LowHit and LowHit.Instance and LowHit.Instance.CanCollide)
			or (HighHit and HighHit.Instance and HighHit.Instance.CanCollide) then
			return false
		end
	end

	local HitR, Origin, Right = self:GetWallRunHit("Right")
	local HitL = nil
	if vector.magnitude(Right) > .001 then
		HitL = select(1, self:GetWallRunHit("Left"))
	end

	local RightDir = vector.magnitude(Right) > .001 and vector.normalize(Right) or vector.create(1, 0, 0)
	local LeftDir = -RightDir

	local RValid = HitR and HitR.Instance and HitR.Instance.CanCollide and self:IsValidWallRunHit(HitR, RightDir)
	local LValid = HitL and HitL.Instance and HitL.Instance.CanCollide and self:IsValidWallRunHit(HitL, LeftDir)

	if not RValid and not LValid then
		local Fwd = self.RootPart.CFrame.LookVector * advents.vector.flat
		if vector.magnitude(Fwd) > .001 then
			Fwd = vector.normalize(Fwd)
			local Params = RaycastParams.new()
			Params.FilterType = Enum.RaycastFilterType.Include
			Params.FilterDescendantsInstances = {MapContainer}
			local CastOrigin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunCastOrigin or 1.2))
			local ScanDist = self.Options.WallRunCastDistanceActive or 5.0
			local Angles = {25, 45, 65, 15, 35, 55}
			for _, Deg in next, Angles do
				local Rad = math.rad(Deg)
				local Cos = math.cos(Rad)
				local Sin = math.sin(Rad)
				local DR = vector.normalize(Fwd * Cos + RightDir * Sin)
				local DL = vector.normalize(Fwd * Cos + LeftDir * Sin)
				local HR = workspace:Raycast(CastOrigin, DR * ScanDist, Params)
				local HL = workspace:Raycast(CastOrigin, DL * ScanDist, Params)
				if HR and HR.Instance and HR.Instance.CanCollide and self:IsValidWallRunHit(HR, RightDir) then
					HitR = HR; RValid = true; break
				end
				if HL and HL.Instance and HL.Instance.CanCollide and self:IsValidWallRunHit(HL, LeftDir) then
					HitL = HL; LValid = true; break
				end
			end
		end
	end

	local Side = nil
	local Hit = nil

	if RValid and LValid then
		local Dr = vector.magnitude(vector.create(HitR.Position.X, HitR.Position.Y, HitR.Position.Z) - Origin)
		local Dl = vector.magnitude(vector.create(HitL.Position.X, HitL.Position.Y, HitL.Position.Z) - Origin)
		if Dr <= Dl then
			Side = "Right"; Hit = HitR
		else
			Side = "Left"; Hit = HitL
		end
	elseif RValid then
		Side = "Right"; Hit = HitR
	elseif LValid then
		Side = "Left"; Hit = HitL
	end

	if not Side or not Hit then return false end
	if not self:GetWallRunSideInputOk(Side) then return false end

	local NFlat = vector.normalize(Hit.Normal * advents.vector.flat)
	local WDir = vector.normalize(vector.cross(NFlat, advents.vector.yAxis))
	if Side == "Left" then WDir = -WDir end

	self:StartWallRun(Side, NFlat, WDir)
	return true
end

function Physics:SnapToWallRun()
	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {MapContainer}

	local Origin = self.RootPart.Position + (advents.vector.yAxis * (self.Options.WallRunCastOrigin or 1.2))
	local Right = self.RootPart.CFrame.RightVector * advents.vector.flat
	if vector.magnitude(Right) <= .001 then return end
	Right = vector.normalize(Right)

	local BestHit = nil
	local BestSide = nil
	local BestDist = math.huge
	local SnapDist = self.Options.WallRunSnapDistance or 1.4
	local ScanDist = self.Options.WallRunCastDistanceActive or 3.4
	local PreferredSide = self:GetWallRunChainTargetSide()

	local Dirs = {}
	local function addDir(Dir, Side)
		table.insert(Dirs, {Dir = Dir; Side = Side; Preferred = PreferredSide ~= nil and Side == PreferredSide})
	end
	if PreferredSide == "Right" then
		addDir(Right, "Right")
		addDir(vector.normalize(Right + self.RootPart.CFrame.LookVector * advents.vector.flat), "Right")
		addDir(-Right, "Left")
		addDir(vector.normalize(-Right + self.RootPart.CFrame.LookVector * advents.vector.flat), "Left")
	elseif PreferredSide == "Left" then
		addDir(-Right, "Left")
		addDir(vector.normalize(-Right + self.RootPart.CFrame.LookVector * advents.vector.flat), "Left")
		addDir(Right, "Right")
		addDir(vector.normalize(Right + self.RootPart.CFrame.LookVector * advents.vector.flat), "Right")
	else
		addDir(Right, "Right")
		addDir(-Right, "Left")
		addDir(vector.normalize(Right + self.RootPart.CFrame.LookVector * advents.vector.flat), "Right")
		addDir(vector.normalize(-Right + self.RootPart.CFrame.LookVector * advents.vector.flat), "Left")
	end

	for _, Entry in next, Dirs do
		if vector.magnitude(Entry.Dir) > .001 then
			local D = vector.normalize(Entry.Dir)
			local Hit = workspace:Raycast(Origin, D * ScanDist, Params)
			if Hit and Hit.Instance and Hit.Instance.CanCollide and self:IsValidWallRunHit(Hit, D) then
				local Dist = vector.magnitude(Hit.Position - self.RootPart.Position)
				if PreferredSide and Entry.Side ~= PreferredSide and BestSide == PreferredSide then
					continue
				end
				if Dist < BestDist or (PreferredSide and Entry.Side == PreferredSide and BestSide ~= PreferredSide) then
					BestDist = Dist
					BestHit = Hit
					BestSide = Entry.Side
				end
			end
		end
	end

	if not BestHit then return end

	local NFlat = vector.normalize(BestHit.Normal * advents.vector.flat)
	local WDir = vector.normalize(vector.cross(NFlat, advents.vector.yAxis))
	if BestSide == "Left" then WDir = -WDir end

	local CurrentHoriz = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local SnapCarrySpeed = math.max(
		vector.magnitude(CurrentHoriz),
		(self.Options.WallJumpForwardVelocity or 0),
		(self.Options.WallRunSpeed or 44) * .45
	)
	local SnapHoriz = WDir * SnapCarrySpeed
	self:ApplyManagedVelocity({
		horizontal = SnapHoriz;
		horizontalMode = "set";
		vertical = 2;
		verticalMode = "max";
	})

	local SnapPos = BestHit.Position + (NFlat * SnapDist)
	local LookAt = SnapPos + WDir
	self.RootPart.CFrame = CFrame.new(
		vector.create(SnapPos.X, self.RootPart.Position.Y, SnapPos.Z),
		vector.create(LookAt.X, self.RootPart.Position.Y, LookAt.Z)
	)

	self.LastWallRunEndedAt = 0
	self.WallJumpedAt = 0
	self.WallRunHoldStartedAt = os.clock() - (self.Options.WallRunHoldDuration or .5) - .1
	self.WallRunChainTargetSide = nil
	self.WallRunChainTargetUntil = 0

	self:StartWallRun(BestSide, NFlat, WDir)
end

function Physics:WallKick(): number?
	if not self:GetWallRunMover() then return nil end

	local WallNorm = self.WallRunNormal
	local Side = self.WallRunSide or "Right"
	local WallDir = self.WallRunDir
	self:StopWallRun()

	local KickSpeed = self.Options.WallKickSideVelocity or 62
	local KickUp = self.Options.WallKickUpVelocity or 28
	local Duration = self.Options.WallKickDuration or .38

	local KickDir = vector.magnitude(WallNorm) > .001 and vector.normalize(WallNorm) or
		(Side == "Left" and self.RootPart.CFrame.RightVector or -self.RootPart.CFrame.RightVector)

	local FwdBoost = vector.magnitude(WallDir) > .001 and WallDir * (KickSpeed * .3) or vector.zero

	local KV = Instance.new("BodyVelocity")
	KV.MaxForce = vector.create(1, 1, 1) * 8e4
	KV.Velocity = vector.create(
		KickDir.X * KickSpeed + FwdBoost.X,
		KickUp,
		KickDir.Z * KickSpeed + FwdBoost.Z
	)
	KV.Parent = self.RootPart
	self.Janitor:Remove("WallKickVelocity")
	self.Janitor:Add(KV, "Destroy", "WallKickVelocity")

	self.WaitingForMomentumLanding = true
	self.LastHorizontalVelocity = vector.create(KV.Velocity.X, 0, KV.Velocity.Z)
	self.WallJumpedAt = os.clock()
	local ReattachWindow = self.Options.WallJumpReattachWindow or .32
	self:QueueWallRunResume(ReattachWindow)
	local HeldChainSide = nil
	if self:GetWallRunSideInputOk("Right") then
		HeldChainSide = "Right"
	elseif self:GetWallRunSideInputOk("Left") then
		HeldChainSide = "Left"
	end
	self.WallRunChainTargetSide = HeldChainSide or (Side == "Left" and "Right" or "Left")
	self.WallRunChainTargetUntil = os.clock() + ReattachWindow + .08

	task.delay(Duration, function()
		if not getmetatable(self) then return end
		self.Janitor:Remove("WallKickVelocity")
	end)

	return Duration
end

function Physics:PerformWallJump(Side: string, WallNorm: vector): string?
	local UpVel = self.Options.WallJumpUpVelocity or 38
	local SideVel = self.Options.WallJumpSideVelocity or 26
	local SnapBlend = self.Options.WallJumpSnapBlend or .7

	if self:GetWallRunMover() then
		self:StopWallRun()
	end

	self.WaitingForMomentumLanding = false
	self.LastHorizontalVelocity = vector.zero

	local SForce = vector.zero
	if vector.magnitude(WallNorm) > .001 then
		SForce = vector.normalize(WallNorm) * SideVel
	elseif Side == "Left" then
		SForce = self.RootPart.CFrame.RightVector * SideVel
	else
		SForce = -self.RootPart.CFrame.RightVector * SideVel
	end

	local TotalHoriz = SForce
	local CurHoriz = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	TotalHoriz = CurHoriz + ((TotalHoriz - CurHoriz) * SnapBlend)

	self:StopStopMover()
	self:ApplyManagedVelocity({
		horizontal = TotalHoriz;
		horizontalMode = "set";
		vertical = UpVel;
		verticalMode = "set";
	})

	self.MomentumBlockedUntil = os.clock() + 1.2
	self.WaitingForMomentumLanding = false
	self.LastHorizontalVelocity = vector.zero
	self.WallJumpedAt = os.clock()
	local ReattachWindow = self.Options.WallJumpReattachWindow or .32
	self:QueueWallRunResume(ReattachWindow)
	local HeldChainSide = nil
	if self:GetWallRunSideInputOk("Right") then
		HeldChainSide = "Right"
	elseif self:GetWallRunSideInputOk("Left") then
		HeldChainSide = "Left"
	end
	self.WallRunChainTargetSide = HeldChainSide or (Side == "Left" and "Right" or "Left")
	self.WallRunChainTargetUntil = os.clock() + ReattachWindow + .08

	if Side == "Left" then
		self.States.WallJumpLeft:Fire()
	else
		self.States.WallJumpRight:Fire()
	end

	return Side
end

function Physics:WallJump(): string?
	if not self:GetWallRunMover() then return nil end

	local Side = self.WallRunSide or "Right"
	local WallNorm = self.WallRunNormal

	local SideInputThreshold = self.Options.WallJumpSideInputThreshold or .2

	local InputFlat = self.MoveDirection * advents.vector.flat
	if vector.magnitude(InputFlat) <= .001 then
		return nil
	end

	local Right = self.RootPart.CFrame.RightVector * advents.vector.flat
	if vector.magnitude(Right) > .001 then
		Right = vector.normalize(Right)
	end
	local InputDir = vector.normalize(InputFlat)
	local SideDot = vector.dot(InputDir, Right)
	if Side == "Left" then
		if SideDot < SideInputThreshold then
			return nil
		end
	else
		if SideDot > -SideInputThreshold then
			return nil
		end
	end

	return self:PerformWallJump(Side, WallNorm)
end

function Physics:GetSlopeInfluence(GroundNormal: vector, HorizontalVelocity: vector): number
	if vector.magnitude(HorizontalVelocity) <= .001 then return 0 end
	if vector.magnitude(GroundNormal) <= .001 then return 0 end

	local TG = advents.vector.projectOntoPlane(-advents.vector.yAxis, GroundNormal)
	local TM = vector.magnitude(TG)
	if TM <= .001 then return 0 end

	local DD = TG / TM
	local MD = vector.normalize(HorizontalVelocity)
	return math.clamp(vector.dot(MD, DD), -1, 1)
end

function Physics:FireRunFromMomentumIfNeeded(IsGrounded: boolean, MomentumSpeed: number)
	if not IsGrounded then return end
	local RunThreshold = math.min(self.Options.SprintSpeed, self.Options.DefaultSpeed * (self.Options.RunThresholdMultiplier or 1.5))
	if MomentumSpeed >= RunThreshold and self.RunWalkState ~= "Running" then
		self.RunWalkState = "Running"
		self.States.Running:Fire()

		local boostAmount = math.min(
			self.Options.MomentumRunBoostCap or 8,
			math.max(0, MomentumSpeed - RunThreshold) * (self.Options.MomentumRunBoostScale or .45)
		)
		local boostDir = self.StopCarryVelocity or vector.zero
		local vecSmall = self.Options.MomentumVecSmall or .02

		if vector.magnitude(boostDir) <= vecSmall then
			boostDir = self.LastHorizontalVelocity or vector.zero
		end

		if vector.magnitude(boostDir) <= vecSmall and vector.magnitude(self.LastInputDirection or vector.zero) > .001 then
			boostDir = self.LastInputDirection
		end

		self:StartTemporarySpeedBoost(
			boostAmount,
			boostDir,
			self.Options.MomentumBoostHold or .4,
			self.Options.MomentumBoostDecel or 10
		)
	end
end

function Physics:StartStopMomentum(GroundedInfo, SourceHorizontal: vector?)
	if self.Options.MomentumEnabled == false then return end
	if self:GetStopMover() then return end

	local AV = self.RootPart.AssemblyLinearVelocity
	local Horizontal = vector.create(AV.X, 0, AV.Z)
	if SourceHorizontal and vector.magnitude(SourceHorizontal) > vector.magnitude(Horizontal) then
		Horizontal = SourceHorizontal
	end
	if vector.magnitude(Horizontal) <= (self.Options.MomentumVecSmall or .05) then
		Horizontal = SourceHorizontal or self.LastHorizontalVelocity
	end

	local IIS = self.Options.MomentumInputInfluence or 0
	if IIS > 0 then
		local HS = vector.magnitude(Horizontal)
		local BV = Horizontal + (self.LastInputDirection * HS * IIS)
		if vector.magnitude(BV) > (self.Options.MomentumVecSmall or .05) then
			Horizontal = BV
		end
	end

	local Speed = vector.magnitude(Horizontal)
	local MaxStart = self.Options.MomentumMaxStartSpeed or 38
	local StartScale = self.Options.MomentumStartScale or .88
	local CarryScale = self.Options.MomentumCarryScale or .58
	local MinStart = self.Options.MomentumMinStartSpeed or 5
	local GN = (GroundedInfo and GroundedInfo.Normal) or vector.create(0, 1, 0)
	local SI = self:GetSlopeInfluence(GN, Horizontal)
	local SS = math.clamp(1 + (SI * (self.Options.MomentumSlopeStartBoost or .3)), self.Options.MomentumSlopeMinScale or .6, self.Options.MomentumSlopeMaxScale or 1.3)
	local StartMultiplier = StartScale * CarryScale
	local MV = Horizontal * (StartMultiplier * SS)
	local MS = vector.magnitude(MV)

	if MS <= MinStart and Speed > MinStart and vector.magnitude(Horizontal) > .001 then
		local FallbackMultiplier = math.max(StartScale, CarryScale)
		MV = vector.normalize(Horizontal) * (Speed * FallbackMultiplier * SS)
		MS = vector.magnitude(MV)
	end

	if MS <= MinStart then return end
	if MaxStart > 0 and MS > MaxStart then
		MV = vector.normalize(MV) * MaxStart
	end

	self.StopCarryVelocity = MV
	self.StopCarryStartedAt = os.clock()
	self:StartStopMover(self.StopCarryVelocity)
	self:RefreshCurrentSpeedFromMomentum()
	self:FireRunFromMomentumIfNeeded(GroundedInfo and GroundedInfo.IsGrounded, MS)
end

function Physics:DelayMomentumStart(Duration: number?)
	local Delay = math.max(Duration or 0, 0)
	if Delay <= 0 then return end
	local BU = os.clock() + Delay
	if not self.MomentumBlockedUntil or BU > self.MomentumBlockedUntil then
		self.MomentumBlockedUntil = BU
	end
end

function Physics:UpdateStopMover(Dt: number, CancelInputActive: boolean, IsGrounded: boolean, GroundedInfo)
	if not self:GetStopMover() then return end
	if self.MomentumInputGraceUntil and os.clock() < self.MomentumInputGraceUntil then
		CancelInputActive = false
	end

	local Speed = vector.magnitude(self.StopCarryVelocity)
	if Speed <= .001 then
		self:StopStopMover()
		return
	end

	local LS = self.StopCarryStartedAt
	if LS and (os.clock() - LS) >= (self.Options.MomentumMaxLifetime or .6) then
		self:StopStopMover()
		return
	end

	local Look = self.RootPart.CFrame.LookVector
	local Facing = vector.create(Look.X, 0, Look.Z)
	local FM = vector.magnitude(Facing)
	local HV = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local HS = vector.magnitude(HV)
	local DD = nil
	if HS > (self.Options.MomentumDirectionVelocityMin or .9) then
		DD = vector.normalize(HV)
	elseif CancelInputActive and FM > .001 then
		DD = Facing / FM
	end

	local DefSpeed = self.Options.DefaultSpeed or 16
	local DynDrag = ((self.Options.MomentumSpeedDrag or .2) * Speed) + ((self.Options.MomentumSpeedDragCurve or .01) * Speed * Speed)
	local StopD = (self.Options.MomentumDecel or 20) + DynDrag
	if CancelInputActive then
		StopD *= (self.Options.MomentumInputDecelBoost or 2.6)
	end
	if IsGrounded then
		local N = (GroundedInfo and vector.magnitude(GroundedInfo.Normal) > .001) and GroundedInfo.Normal or vector.create(0, 1, 0)
		local SI = self:GetSlopeInfluence(N, self.StopCarryVelocity)
		StopD *= math.clamp(1 - (SI * (self.Options.MomentumSlopeDecelInfluence or .28)), .55, 1.55)
	end
	if not IsGrounded then
		StopD *= (self.Options.MomentumAirDeccelMultiplier or 1.1)
	end
	if Speed <= DefSpeed * (self.Options.MomentumEndSpeedThreshold or .1) then
		StopD *= (self.Options.MomentumEndDeccel or 5.5)
	end

	local MDir = vector.magnitude(self.StopCarryVelocity) > .001 and vector.normalize(self.StopCarryVelocity) or vector.zero
	if DD then MDir = DD end

	local MV = Helper.Deccelerate(MDir * Speed, StopD, Dt)
	if CancelInputActive then
		MV = Helper.Deccelerate(MV, StopD * (self.Options.MomentumInputExtraDecelScale or .8), Dt)
	end

	local NS = vector.magnitude(MV)
	if NS <= .001 or MDir == vector.zero then
		self.StopCarryVelocity = vector.zero
	else
		self.StopCarryVelocity = vector.normalize(MV) * NS
	end

	if vector.magnitude(self.StopCarryVelocity) <= math.max(self.Options.MomentumStopThreshold or .4, DefSpeed * .02) then
		self:StopStopMover()
		return
	end

	self:GetStopMover().VectorVelocity = self.StopCarryVelocity * advents.vector.flat
	self:RefreshCurrentSpeedFromMomentum()
	self:FireRunFromMomentumIfNeeded(IsGrounded, vector.magnitude(self.StopCarryVelocity))
end

function Physics:Update(Dt: number, MoveDirection: vector)
	self.MoveDirection = MoveDirection

	local GroundedInfo = Grounded.getGroundInfo(self.Character, self.Options)
	local IsGrounded = GroundedInfo.IsGrounded or (self.Humanoid.FloorMaterial ~= Enum.Material.Air)
	local AV = self.RootPart.AssemblyLinearVelocity
	local HV = vector.create(AV.X, 0, AV.Z)
	local HS = vector.magnitude(HV)
	local JustLanded = IsGrounded and not self.WasGrounded
	local Now = os.clock()

	local InputMag = vector.magnitude(MoveDirection)
	local InputActive = InputMag > .05
	local MomentumInputActive = InputMag > (self.Options.MomentumCancelInputThreshold or .12)
	if InputActive then
		self.LastWallRunInputAt = Now
	end
	local WallRunActive = self:UpdateWallRun(Dt, MoveDirection, InputActive, GroundedInfo, HS)
	if WallRunActive then
		if self:IsWallRunning() and not self:GetWallRunMover() then
			self:StopWallRun()
			return
		end
		self.WasInputActive = InputActive
		self.WasGrounded = IsGrounded
		self.Humanoid:Move(vector.zero, false)
		return
	end

	if self.IsSliding and not self.Janitor:Get("SlideMover") then
		self:StopSlide()
	end

	if self.IsSliding then
		self:UpdateSpeed(Dt, 0, vector.zero, true)
		self.Humanoid.WalkSpeed = 0
		self.WasInputActive = InputActive
		self.WasGrounded = IsGrounded
		self.Humanoid:Move(vector.zero, false)
		return
	end

	if self.Janitor:Get("VaultMove") or self.Janitor:Get("MantleMove") then
		local CarrySpeed = math.max(
			self.BaseCurrentSpeed or 0,
			self.CurrentSpeed or 0,
			vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat)
		)
		self.BaseCurrentSpeed = CarrySpeed
		self.CurrentSpeed = CarrySpeed
		self.Humanoid.WalkSpeed = CarrySpeed
		self.WasInputActive = InputActive
		self.WasGrounded = IsGrounded
		self.Humanoid:Move(vector.zero, false)
		return
	end

	if self.Humanoid.PlatformStand then
		self.Humanoid.PlatformStand = false
	end
	if self.Character:GetAttribute("ShiftLockSuspend") ~= false then
		self.Character:SetAttribute("ShiftLockSuspend", false)
	end
	local desiredAutoRotate = self:GetAutoRotateValue()
	if self.Humanoid.AutoRotate ~= desiredAutoRotate then
		self.Humanoid.AutoRotate = desiredAutoRotate
	end
	if self.Character:GetAttribute("AutoRotate") ~= desiredAutoRotate then
		self.Character:SetAttribute("AutoRotate", desiredAutoRotate)
	end

	if not IsGrounded then
		if HS > self.AirbornePeakHorizontalSpeed then
			self.AirbornePeakHorizontalSpeed = HS
			self.AirbornePeakHorizontalVelocity = HV
		end
	elseif JustLanded then
		local BLV = HS > (self.Options.MomentumVecSmall or .02) and HV or (self.AirbornePeakHorizontalVelocity or vector.zero)
		local BLS = math.max(HS, self.AirbornePeakHorizontalSpeed or 0)
		local LMS = self.Options.MomentumLandMinSpeed or ((self.Options.DefaultSpeed or 16) * .85)
		local vecSmall = self.Options.MomentumVecSmall or .02
		if BLS >= LMS and vector.magnitude(BLV) > vecSmall then
			if InputActive then
				local boostDir = BLV
				local moveFlat = MoveDirection * advents.vector.flat
				if vector.magnitude(moveFlat) > .001 then
					local inputDir = vector.normalize(moveFlat)
					local blendedDir = (BLV * .35) + (inputDir * BLS * .65)
					if vector.magnitude(blendedDir) > .001 then
						boostDir = blendedDir
					else
						boostDir = inputDir
					end
				end

				local landBoost = math.min(
					self.Options.MomentumLandBoostCap or 12,
					math.max(0, BLS - LMS) * (self.Options.MomentumLandBoostScale or .65)
				)
				self:StartTemporarySpeedBoost(
					landBoost,
					boostDir,
					self.Options.MomentumBoostHold or .4,
					self.Options.MomentumBoostDecel or 10
				)
			else
				self.LastHorizontalVelocity = BLV
				self:StartStopMomentum(GroundedInfo, BLV)
			end
		end
		self.AirbornePeakHorizontalSpeed = 0
		self.AirbornePeakHorizontalVelocity = vector.zero
	end

	if InputActive then
		local DMD = vector.normalize(MoveDirection)
		self.LastInputDirection = DMD
		self.LastHorizontalVelocity = HV

		local Accel = IsGrounded and (self.Options.InputAcceleration or 18) or (self.Options.AirInputAcceleration or 28)
		local TurnBoost = IsGrounded and (self.Options.InputTurnBoost or 2.4) or (self.Options.AirTurnBoost or 2.8)
		local Align = 1
		if vector.magnitude(self.CurrentMoveVector) > .001 then
			Align = vector.dot(vector.normalize(self.CurrentMoveVector), DMD)
		end
		local TF = 1 + (math.max(0, 1 - Align) * (TurnBoost - 1))
		local PrevMV = self.CurrentMoveVector
		self.CurrentMoveVector = Helper.Accelerate(self.CurrentMoveVector, DMD, Accel * TF, Dt)

		if not IsGrounded then
			local PrevSpd = vector.magnitude(PrevMV)
			local NewSpd = vector.magnitude(self.CurrentMoveVector)
			local SpeedFloor = self.Options.AirSpeedPreserve or .92
			if PrevSpd > .001 and NewSpd < PrevSpd * SpeedFloor then
				self.CurrentMoveVector = vector.normalize(self.CurrentMoveVector) * (PrevSpd * SpeedFloor)
				NewSpd = vector.magnitude(self.CurrentMoveVector)
			end

			if NewSpd > .001 then
				local CurrentDir = vector.normalize(self.CurrentMoveVector)
				local AirTurnT = math.clamp((1 - math.clamp(vector.dot(CurrentDir, DMD), -1, 1)) * .5, 0, 1)
				local AirEase = bezierAlpha(Helper.ExpDecayAlpha(self.Options.AirControlEase or 12, Dt))
				local AirAlpha = math.clamp(
					((self.Options.AirControl or .24) + (AirTurnT * (self.Options.AirControlTurnBoost or .34))) * AirEase,
					0,
					1
				)
				local SteeredDir = CurrentDir:Lerp(DMD, AirAlpha)
				if vector.magnitude(SteeredDir) > .001 then
					self.CurrentMoveVector = vector.normalize(SteeredDir) * NewSpd
				end
			end
		end
	else
		local Deccel = IsGrounded and (self.Options.InputDecceleration or 14) or (self.Options.AirInputDecceleration or 4)
		self.CurrentMoveVector = Helper.Deccelerate(self.CurrentMoveVector, Deccel, Dt)
	end

	if vector.magnitude(self.CurrentMoveVector) <= (self.Options.MoveVectorDeadzone or .012) then
		self.CurrentMoveVector = vector.zero
	end

	local MM = vector.magnitude(self.CurrentMoveVector)
	if MM > 1 then
		self.CurrentMoveVector = vector.normalize(self.CurrentMoveVector)
		MM = 1
	end

	self:UpdateSpeed(Dt, MM, self.CurrentMoveVector)
	self.Humanoid:Move(self.CurrentMoveVector, false)

	if IsGrounded and InputActive and not self.Janitor:Get("VaultMove") then
		local CanVault, LandY, LedgeY = Helper.CheckLowRise(self.Character, self.Options)
		if CanVault then

			local Dot = vector.dot(self.Humanoid.MoveDirection * advents.vector.flat, self.RootPart.CFrame.LookVector)

			if Dot > 0 then 
				self.States.VaultStart:Fire(LandY, LedgeY)
			end
		end
	end

	if MomentumInputActive then
		self.PendingMomentumStartAt = nil
		self.WaitingForMomentumLanding = false
		self.MomentumBlockedUntil = nil
	elseif self.WasInputActive and not InputActive then
		if IsGrounded then
			self.PendingMomentumStartAt = Now + (self.Options.MomentumStartDelay or 0)
			self.WaitingForMomentumLanding = false
		else
			self.PendingMomentumStartAt = nil
			self.WaitingForMomentumLanding = true
		end
	end

	if not InputActive and self.WaitingForMomentumLanding and IsGrounded then
		self.WaitingForMomentumLanding = false
		self.PendingMomentumStartAt = Now + (self.Options.MomentumLandingDelay or 0)
	end

	if not InputActive and self.PendingMomentumStartAt and Now >= self.PendingMomentumStartAt then
		if self.Options.MomentumGroundOnly and not IsGrounded then
			self.PendingMomentumStartAt = nil
			self.WaitingForMomentumLanding = true
		else
			local BU = self.MomentumBlockedUntil
			if BU and Now < BU then
				self.PendingMomentumStartAt = BU
			else
				self.MomentumBlockedUntil = nil
				self.PendingMomentumStartAt = nil
				self:StartStopMomentum(GroundedInfo)
			end
		end
	end

	self.WasInputActive = InputActive
	self.WasGrounded = IsGrounded

	self:UpdateStopMover(Dt, MomentumInputActive, IsGrounded, GroundedInfo)
end

function Physics:Mantle(FloorEstimate: number, HeadRoom: number)
	if self.Janitor:Get("MantleMove") then return end
	self:BeginExclusiveMovement("Mantle")

	local EntryCurrentSpeed = self.CurrentSpeed or self.Options.DefaultSpeed or 16
	local EntryBaseSpeed = self.BaseCurrentSpeed or EntryCurrentSpeed
	local LedgeY = self.RootPart.Position.Y + (FloorEstimate * self.Options.MantleFloorHeight)
	local HeightNeeded = math.max(LedgeY - self.RootPart.Position.Y, 1)
	local UpSpeed = math.clamp(HeightNeeded * 3.6, 14, 28)
	local FwdSpeed = math.clamp(HeightNeeded * 1.6 + HeadRoom * .25, 16, 24)
	local Fwd = vector.normalize(self.RootPart.CFrame.LookVector * advents.vector.flat)
	local LaunchBlend = self.Options.MantleLaunchBlend or .58
	local CurHV = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local ForwardCarry = math.max(0, vector.dot(CurHV, Fwd))
	local SideCarry = CurHV - (Fwd * vector.dot(CurHV, Fwd))
	local TargetHV = (Fwd * math.max(FwdSpeed, ForwardCarry)) + (SideCarry * .18)
	local LaunchHV = CurHV + ((TargetHV - CurHV) * LaunchBlend)

	local BV = Instance.new("BodyVelocity")
	BV.MaxForce = vector.one * 1e5
	BV.P = 5e5
	BV.Velocity = LaunchHV + (advents.vector.yAxis * UpSpeed)
	BV.Parent = self.RootPart
	self.Janitor:Add(BV, "Destroy", "MantleMove")

	self.Humanoid.JumpPower = 0

	local Duration = math.clamp(HeightNeeded * .026, .1, .2)

	task.delay(Duration, function()
		if not getmetatable(self) then return end
		self.Janitor:Remove("MantleMove")
		self.Humanoid.JumpPower = self.Options.JumpPower or 56

		local CF = vector.normalize(self.RootPart.CFrame.LookVector * advents.vector.flat)
		local ExitSpeed = math.max(FwdSpeed, vector.magnitude(LaunchHV)) * (self.Options.MantleMomentumScale or .78)
		local RestoreSpeed = math.max(EntryBaseSpeed, EntryCurrentSpeed, ExitSpeed)
		local MV = CF * RestoreSpeed
		self:StopStopMover()
		self.BaseCurrentSpeed = RestoreSpeed
		self.CurrentSpeed = RestoreSpeed
		self.Humanoid.WalkSpeed = RestoreSpeed
		self:ApplyManagedVelocity({
			horizontal = MV;
			horizontalMode = "set";
		})
		self.LastHorizontalVelocity = MV
		self.PendingMomentumStartAt = nil
		self.WaitingForMomentumLanding = false
		task.defer(function()
			if not getmetatable(self) then return end
			if self.Janitor:Get("MantleMove") then return end
			self.BaseCurrentSpeed = math.max(self.BaseCurrentSpeed or 0, RestoreSpeed)
			self.CurrentSpeed = math.max(self.CurrentSpeed or 0, RestoreSpeed)
			self.Humanoid.WalkSpeed = self.CurrentSpeed
			self:ApplyManagedVelocity({
				horizontal = MV;
				horizontalMode = "max";
			})
		end)
	end)

	return Duration
end

function Physics:Slide()
	if not getmetatable(self) then return end
	self:BeginExclusiveMovement("Slide")

	self.IsSliding = true
	self.SlideStartedAt = os.clock()
	self.States.SlideStart:Fire()

	local hv = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local cs = vector.magnitude(hv)
	local cam = workspace.CurrentCamera

	local mf = self.MoveDirection * advents.vector.flat
	local lf = self.RootPart.CFrame.LookVector * advents.vector.flat
	local sdir = nil
	if vector.magnitude(mf) > 0.1 then
		sdir = vector.normalize(mf)
	elseif vector.magnitude(lf) > .001 then
		sdir = vector.normalize(lf)
	else
		sdir = self.RootPart.CFrame.LookVector * advents.vector.flat
	end

	if cs > 1 then
		local vd = vector.normalize(hv)
		sdir = vector.normalize(vd:Lerp(sdir, 0.4))
	end

	local boost = self.Options.SlideStartBoost or 1.65
	local speed = math.max(cs * boost, (self.Options.DefaultSpeed or 16) * 1.6)

	local att = Instance.new("Attachment")
	att.Parent = self.RootPart
	self.Janitor:Add(att, "Destroy", "SlideAttachment")

	local mover = Instance.new("LinearVelocity")
	mover.Attachment0 = att
	mover.RelativeTo = Enum.ActuatorRelativeTo.World
	mover.ForceLimitsEnabled = true
	mover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	mover.MaxAxesForce = vector.create(1.5e5, 1.5e5, 1.5e5)
	mover.MaxForce = 1.5e5
	mover.VectorVelocity = sdir * speed
	mover.Parent = self.RootPart
	self.Janitor:Add(mover, "Destroy", "SlideMover")

	local align = Instance.new("AlignOrientation")
	align.Attachment0 = att
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Enabled = true
	align.RigidityEnabled = true
	align.MaxTorque = self.Options.SlideAlignMaxTorque or 1.6e6
	align.Responsiveness = self.Options.SlideAlignResponsiveness or 20
	align.CFrame = CFrame.lookAt(vector.zero, sdir, advents.vector.yAxis)
	align.Parent = self.RootPart
	self.Janitor:Add(align, "Destroy", "SlideAlign")

	self.SlideSpeed = speed
	self.SlideStartSpeed = speed
	self.SlideDir = sdir
	self.LastSlideSlope = 0
	self.SlideAlignCFrame = nil
	self.SlideGroundNormal = nil
	self.SlideHipHeightBase = self.Humanoid.HipHeight
	self.SlideSlopeDir = nil
	self.SlideDesiredDir = sdir
	self.SlideAlignUp = nil
	self.SlideLowSpeedTime = 0
	self.SlidePrevState = self.Humanoid:GetState()
	self.SlideRunningEnabled = self.Humanoid:GetStateEnabled(Enum.HumanoidStateType.Running)
	self.SlideRunningNoPhysicsEnabled = self.Humanoid:GetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics)
	self.SlideJumpingEnabled = self.Humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping)
	self.SlidePlatformStand = self.Humanoid.PlatformStand
	self.SlideAutoRotate = self.Humanoid.AutoRotate
	self.SlideAutoRotateAttribute = self.Character:GetAttribute("AutoRotate")
	self.SlideNoGroundTime = 0
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, false)
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, false)
	self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	self.Character:SetAttribute("AutoRotate", false)
	self.Humanoid.AutoRotate = false
	self.AutoRotateValue = false
	self.Humanoid.PlatformStand = true
	self.Humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	self.Character:SetAttribute("ShiftLockSuspend", true)

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {self.Character}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local function projectOnPlane(dir: vector, normal: vector): vector?
		local projected = dir - (normal * vector.dot(dir, normal))
		local mag = vector.magnitude(projected)
		if mag <= .001 then return nil end
		return projected / mag
	end

	local function getSlideGround(sampleDir: vector)
		local hipHeight = math.max(self.SlideHipHeightBase or self.Humanoid.HipHeight, 0)
		local probeLift = self.Options.SlideGroundProbeLift or .35
		local probeStart = (self.RootPart.Size.Y * .5) + hipHeight + probeLift
		local probeDistance = probeStart + (self.Options.SlideGroundProbeDistance or 8.5)
		local origin = self.RootPart.Position + (advents.vector.yAxis * probeStart)
		local aheadDistance = self.Options.SlideGroundProbeAhead or 1.35
		local farAheadDistance = self.Options.SlideGroundProbeFarAhead or 2.2
		local sideDistance = self.Options.SlideGroundProbeSide or .95
		local backDistance = self.Options.SlideGroundProbeBack or .35
		local hits = {}
		local right = self.RootPart.CFrame.RightVector * advents.vector.flat
		if vector.magnitude(right) > .001 then
			right = vector.normalize(right)
		else
			right = vector.zero
		end
		local forward = vector.magnitude(sampleDir) > .001 and vector.normalize(sampleDir) or (self.RootPart.CFrame.LookVector * advents.vector.flat)
		if vector.magnitude(forward) > .001 then
			forward = vector.normalize(forward)
		else
			forward = advents.vector.zAxis
		end

		for _, offset in next, {
			vector.zero;
			forward * aheadDistance;
			forward * farAheadDistance;
			-forward * backDistance;
			right * sideDistance;
			-right * sideDistance;
			(forward * (aheadDistance * .85)) + (right * (sideDistance * .7));
			(forward * (aheadDistance * .85)) - (right * (sideDistance * .7));
			(forward * (farAheadDistance * .8)) + (right * (sideDistance * .55));
			(forward * (farAheadDistance * .8)) - (right * (sideDistance * .55));
			} do
			local castOrigin = origin + offset
			local castHit = workspace:Raycast(castOrigin, vector.create(0, -probeDistance, 0), params)
			if castHit then
				table.insert(hits, castHit)
			end
		end

		local gi = Grounded.getGroundInfo(self.Character, self.Options)
		local grounded = #hits > 0 or (gi and gi.IsGrounded)
		local hit = hits[1]
		local normal = advents.vector.yAxis

		if #hits > 0 then
			local normalSum = vector.zero
			local bestDistance = math.huge
			for _, castHit in next, hits do
				normalSum += castHit.Normal
				if castHit.Distance < bestDistance then
					bestDistance = castHit.Distance
					hit = castHit
				end
			end
			if vector.magnitude(normalSum) > .001 then
				normal = vector.normalize(normalSum)
			else
				normal = vector.normalize(hit.Normal)
			end
		end

		if gi and gi.IsGrounded and vector.magnitude(gi.Normal) > .001 then
			local giNormal = vector.normalize(gi.Normal)
			normal = hit and vector.normalize(normal:Lerp(giNormal, .35)) or giNormal
		end

		return grounded, hit, normal
	end

	local function hasBlockingSlideWall(dir: vector, upNormal: vector): boolean
		local castDir = dir * advents.vector.flat
		if vector.magnitude(castDir) <= .001 then
			return false
		end
		castDir = vector.normalize(castDir)

		local wallDotMin = self.Options.SlideWallDotMin or .3
		local wallNormalYMax = self.Options.SlideWallNormalYMax or .32
		local wallDistance = self.Options.SlideWallStopDistance or 2.2
		local hipBase = self.SlideHipHeightBase or self.Humanoid.HipHeight
		local lowHeight = math.max((hipBase * .45), .9)
		local midHeight = math.max((hipBase * .9), 1.6)
		local highHeight = math.max((hipBase * 1.15), 2.4)

		for _, height in next, {lowHeight, midHeight, highHeight} do
			local origin = self.RootPart.Position + (advents.vector.yAxis * height)
			local wallHit = workspace:Raycast(origin, castDir * wallDistance, params)
			if wallHit then
				local normalFlat = wallHit.Normal * advents.vector.flat
				if vector.magnitude(normalFlat) > .001
					and wallHit.Normal.Y < wallNormalYMax
					and vector.dot(vector.normalize(normalFlat), -castDir) > wallDotMin
				then
					return true
				end
			end
		end

		return false
	end

	self.Janitor:Add(self.Humanoid.StateChanged:Connect(function(_, New)
		if not self.IsSliding then return end
		if New ~= Enum.HumanoidStateType.Jumping and New ~= Enum.HumanoidStateType.Freefall then return end

		local slideDir = self.SlideSlopeDir or self.SlideDir or (self.RootPart.CFrame.LookVector * advents.vector.flat)
		local lookFlat = self.RootPart.CFrame.LookVector * advents.vector.flat
		local cancelDir = slideDir
		if vector.magnitude(slideDir) > .001 and vector.magnitude(lookFlat) > .001 then
			cancelDir = vector.normalize(slideDir:Lerp(vector.normalize(lookFlat), self.Options.SlideCancelLookBlend or .78))
		elseif vector.magnitude(lookFlat) > .001 then
			cancelDir = vector.normalize(lookFlat)
		elseif vector.magnitude(cancelDir) > .001 then
			cancelDir = vector.normalize(cancelDir)
		end

		local slideBoost = math.max(self.Options.SlideStartBoost or 1, 1)
		local matchedCancelScale = 1 + ((slideBoost - 1) * .72)
		local cancelScale = math.min(self.Options.SlideCancelPropelScale or matchedCancelScale, matchedCancelScale)
		local cancelBaseSpeed = math.max(
			self.SlideSpeed or 0,
			(self.SlideStartSpeed or 0) * .94,
			(self.Options.DefaultSpeed or 16) * slideBoost
		)
		local cancelSpeed = cancelBaseSpeed * cancelScale
		local av = self.RootPart.AssemblyLinearVelocity

		local att = Instance.new("Attachment")
		att.Parent = self.RootPart

		local propelMover = Instance.new("LinearVelocity")
		propelMover.Attachment0 = att
		propelMover.RelativeTo = Enum.ActuatorRelativeTo.World
		propelMover.ForceLimitsEnabled = true
		propelMover.ForceLimitMode = Enum.ForceLimitMode.PerAxis
		propelMover.MaxAxesForce = vector.create(1.5e5, 0, 1.5e5)
		propelMover.VectorVelocity = cancelDir * cancelSpeed
		propelMover.Parent = self.RootPart

		self:ApplyManagedVelocity({
			horizontal = cancelDir * cancelSpeed;
			horizontalMode = "set";
			vertical = av.Y;
			verticalMode = "set";
		})

		local propelDuration = self.Options.SlideCancelPropelDuration or .42
		local propelElapsed = 0
		local propelConn
		propelConn = RunService.Heartbeat:Connect(function(dt)
			if not propelMover or not propelMover.Parent then
				propelConn:Disconnect()
				return
			end
			propelElapsed += dt
			local t = math.clamp(propelElapsed / propelDuration, 0, 1)
			local alpha = 1 - bezierAlpha(math.clamp(t * .6, 0, 1))
			propelMover.VectorVelocity = cancelDir * cancelSpeed * alpha
			if t >= 1 then
				propelConn:Disconnect()
				if propelMover.Parent then propelMover:Destroy() end
				if att.Parent then att:Destroy() end
			end
		end)

		self.SlideCancelPropelDir = cancelDir
		self.SlideCancelPropelSpeed = cancelSpeed
		self.ExpectSlideCancelLandMomentum = true
		self:StopSlide()
		self.States.SlideCancel:Fire()
	end), "Disconnect", "SlideJumpConnection")

	self.SlideConnection = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if not getmetatable(self) then return end
		if not self.Janitor:Get("SlideMover") then return end

		local sampleDir = self.SlideSlopeDir or self.SlideDir or (self.RootPart.CFrame.LookVector * advents.vector.flat)
		if vector.magnitude(sampleDir) > .001 then
			sampleDir = vector.normalize(sampleDir)
		end

		local prevGroundNormal = self.SlideGroundNormal
		local grounded, hit, gn = getSlideGround(sampleDir)
		local flatNormalY = self.Options.SlideFlatNormalY or .985
		if (not grounded) and prevGroundNormal and prevGroundNormal.Y < flatNormalY then
			gn = prevGroundNormal
		end
		if (not grounded) and self.SlideGroundNormal then
			gn = self.SlideGroundNormal
		end
		local noGroundTimeout = self.Options.SlideNoGroundTimeout or .18
		if prevGroundNormal and prevGroundNormal.Y < flatNormalY then
			noGroundTimeout = self.Options.SlideSlopeNoGroundTimeout or noGroundTimeout
		end
		if grounded then
			self.SlideNoGroundTime = 0
		else
			self.SlideNoGroundTime += dt
			if self.SlideNoGroundTime >= noGroundTimeout then
				self:StopSlide()
				return
			end
		end
		if self.SlideGroundNormal then
			local gl = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideGroundLerp or 6, dt))
			gn = vector.normalize(self.SlideGroundNormal:Lerp(gn, gl))
		end
		self.SlideGroundNormal = gn

		local velocityPlane = projectOnPlane(self.RootPart.AssemblyLinearVelocity, gn)
		local lookPlane = projectOnPlane(self.RootPart.CFrame.LookVector, gn)
		local inputPlane = projectOnPlane(self.MoveDirection * advents.vector.flat, gn)
		local currentPlane = projectOnPlane(self.SlideDir, gn)
		local desired = velocityPlane or currentPlane or lookPlane or inputPlane or self.SlideDir

		local camPlane = nil
		if cam then
			local camFlat = cam.CFrame.LookVector * advents.vector.flat
			if vector.magnitude(camFlat) > .001 then
				camPlane = projectOnPlane(vector.normalize(camFlat), gn)
			end
		end

		if camPlane and desired then
			local infl = self.Options.SlideInputInfluence or .22
			local camTurnT = math.clamp((1 - math.clamp(vector.dot(desired, camPlane), -1, 1)) * .5, 0, 1)
			infl += camTurnT * (self.Options.SlideInputTurnBoost or .22)
			if gn.Y < flatNormalY then
				infl *= (self.Options.SlideSlopeInputMultiplier or .42)
			end
			infl = math.clamp(infl, 0, 1)
			local blended = desired:Lerp(camPlane, infl)
			if vector.magnitude(blended) > .001 then
				desired = vector.normalize(blended)
			end
		end

		if desired and vector.magnitude(desired) > .001 then
			desired = vector.normalize(desired)
			local desiredFrom = self.SlideDesiredDir or currentPlane or desired
			if vector.magnitude(desiredFrom) > .001 then
				desiredFrom = vector.normalize(desiredFrom)
			end
			local desiredTurnT = math.clamp((1 - math.clamp(vector.dot(desiredFrom, desired), -1, 1)) * .5, 0, 1)
			local desiredAlpha = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideDesiredLerp or 11, dt))
			desiredAlpha *= math.clamp((self.Options.SlideTurnResponse or .22) + (desiredTurnT * (self.Options.SlideTurnBoost or .68)), 0, 1)
			local smoothedDesired = desiredFrom:Lerp(desired, math.clamp(desiredAlpha, 0, 1))
			if vector.magnitude(smoothedDesired) > .001 then
				desired = vector.normalize(smoothedDesired)
			end
			self.SlideDesiredDir = desired
		end

		local steerTurnT = 1
		if currentPlane and desired then
			steerTurnT = math.clamp((1 - math.clamp(vector.dot(currentPlane, desired), -1, 1)) * .5, 0, 1)
		end
		local ss = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideSteerSpeed or 3.2, dt))
		ss *= math.clamp((self.Options.SlideTurnResponse or .22) + (steerTurnT * (self.Options.SlideTurnBoost or .68)), 0, 1)
		local nd = currentPlane and currentPlane:Lerp(desired, ss) or desired
		if vector.magnitude(nd) > .001 then
			self.SlideDir = vector.normalize(nd)
		end

		local sd = projectOnPlane(self.SlideDir, gn) or desired or self.SlideDir
		if gn.Y < flatNormalY then
			local carryFlat = (velocityPlane or currentPlane or lookPlane or self.SlideDir) * advents.vector.flat
			if vector.magnitude(carryFlat) > .001 then
				local projectedCarry = projectOnPlane(vector.normalize(carryFlat), gn)
				if projectedCarry then
					local slopeTurnBlend = self.Options.SlideSlopeTurnBlend or .48
					local carryTurnT = math.clamp((math.clamp(vector.dot(sd, projectedCarry), -1, 1) + 1) * .5, 0, 1)
					slopeTurnBlend *= (.22 + (bezierAlpha(carryTurnT) * .58))
					if inputPlane then
						slopeTurnBlend *= (self.Options.SlideSlopeTurnInputScale or .45)
					end
					if prevGroundNormal and prevGroundNormal.Y >= flatNormalY then
						slopeTurnBlend *= .55
					end
					local blendedSlope = sd:Lerp(projectedCarry, slopeTurnBlend)
					if vector.magnitude(blendedSlope) > .001 then
						sd = vector.normalize(blendedSlope)
					end
				end
			end
		end
		if self.SlideSlopeDir and vector.magnitude(sd) > .001 then
			local sl = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideSlopeDirLerp or 14, dt))
			local sn = self.SlideSlopeDir:Lerp(sd, sl)
			if vector.magnitude(sn) > .001 then
				sd = vector.normalize(sn)
			end
		end

		local fwd = velocityPlane or currentPlane or lookPlane or sd
		local fdm = self.Options.SlideForwardDotMin or .2
		if gn.Y < flatNormalY and inputPlane then
			fdm = self.Options.SlideSlopeForwardDotMin or -.08
		end
		if fwd and vector.magnitude(fwd) > .001 and vector.dot(sd, fwd) < fdm then
			sd = fwd
		end
		self.SlideSlopeDir = sd

		local wallDir = sd
		if vector.magnitude(wallDir) <= .001 then
			wallDir = fwd or sd
		end
		if hasBlockingSlideWall(wallDir, gn) then
			self:StopSlide()
			return
		end

		local downPlane = vector.create(0, -1, 0) - (gn * vector.dot(vector.create(0, -1, 0), gn))
		local slopeDir = vector.magnitude(downPlane) > .001 and vector.normalize(downPlane) or nil
		local slopeDot = 0
		if slopeDir and gn.Y < flatNormalY then
			slopeDot = vector.dot(sd, slopeDir)
		end
		self.LastSlideSlope = slopeDot

		local dz = self.Options.SlideSlopeDeadzone or .06
		if slopeDot > dz then
			self.SlideSpeed = self.SlideSpeed + (slopeDot * (self.Options.SlideDownhillAccel or 58) * dt)
		else
			local bd = self.Options.SlideDeceleration or 20
			local el = os.clock() - (self.SlideStartedAt or 0)
			if el <= (self.Options.SlideInitialDecelDuration or .12) then
				bd += (self.Options.SlideInitialDecel or 14)
			end
			if slopeDot < -dz then
				bd += (math.abs(slopeDot) * (self.Options.SlideUphillDecel or 26))
			end
			self.SlideSpeed = self.SlideSpeed - bd * dt
		end

		local ms = self.Options.SlideMinSpeed or ((self.Options.DefaultSpeed or 16) * 0.4)
		local md = self.Options.SlideMinDuration or .28
		local sse = self.Options.SlideStopSlopeEpsilon or .03
		local dst = self.Options.SlideStopDownhillThreshold or .18
		if self.SlideSpeed <= ms then
			self.SlideLowSpeedTime = (self.SlideLowSpeedTime or 0) + dt
		else
			self.SlideLowSpeedTime = 0
		end
		local lowSpeedStopTime = self.Options.SlideLowSpeedStopTime or .14
		local slopeCanStop = self.LastSlideSlope <= dst or math.abs(self.LastSlideSlope) <= sse
		if (os.clock() - (self.SlideStartedAt or 0)) >= md
			and ((self.SlideSpeed <= ms and slopeCanStop) or ((self.SlideLowSpeedTime or 0) >= lowSpeedStopTime))
		then
			self:StopSlide()
			return
		end

		local uc = gn.Y < flatNormalY and slopeDot < -dz and (self.Options.SlideUpwardVelocity or 6) or 0
		local dc = self.Options.SlideDownwardVelocity or -35
		local dv = sd * self.SlideSpeed
		dv = vector.create(dv.X, math.clamp(dv.Y, dc, uc), dv.Z)
		if grounded then
			local snapY = self.Options.SlideGroundSnapVelocity or -10
			if gn.Y < flatNormalY and slopeDot > dz then
				local slopeSnap = self.Options.SlideSlopeGroundSnapVelocity or -18
				local extraSnap = slopeDot * (self.Options.SlideSlopeSnapScale or 28)
				snapY = slopeSnap - extraSnap
			end
			dv = vector.create(dv.X, math.min(dv.Y, snapY), dv.Z)
			local avSnap = self.RootPart.AssemblyLinearVelocity
			if avSnap.Y > snapY then
				self:ApplyManagedVelocity({
					vertical = snapY;
					verticalMode = "set";
				})
			end
		end

		local vf2 = gn.Y < flatNormalY and slopeDot > dz
			and (self.Options.SlideSlopeVerticalForce or 1.5e5)
			or (self.Options.SlideVerticalForce or 4e4)
		mover.MaxAxesForce = vector.create(1.5e5, grounded and vf2 or 0, 1.5e5)
		local moverAlpha = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideVelocityBlend or 10, dt))
		local moverCurrent = mover.VectorVelocity
		local moverCurrentFlat = moverCurrent * advents.vector.flat
		local moverTargetFlat = dv * advents.vector.flat
		if vector.magnitude(moverCurrentFlat) > .001 and vector.magnitude(moverTargetFlat) > .001 then
			local moverTurnT = math.clamp((1 - math.clamp(vector.dot(vector.normalize(moverCurrentFlat), vector.normalize(moverTargetFlat)), -1, 1)) * .5, 0, 1)
			moverAlpha *= math.clamp((self.Options.SlideTurnResponse or .22) + (moverTurnT * (self.Options.SlideTurnBoost or .68)), 0, 1)
		end
		local moverVelocity = moverCurrent:Lerp(dv, math.clamp(moverAlpha, 0, 1))
		mover.VectorVelocity = vector.create(moverVelocity.X, dv.Y, moverVelocity.Z)
		self.RootPart.AssemblyAngularVelocity = vector.zero

		local hb = self.SlideHipHeightBase or self.Humanoid.HipHeight
		local baseOffset = self.Options.SlideHipHeightBaseOffset or 0
		local th = hb + baseOffset
		local dt2 = self.Options.SlideHipHeightDownThreshold or .12
		local ut = self.Options.SlideHipHeightUpThreshold or .12
		if gn.Y < flatNormalY then
			if slopeDot > dt2 then
				local downT = math.clamp((slopeDot - dt2) / math.max(1 - dt2, .001), 0, 1)
				th = hb + baseOffset + ((self.Options.SlideHipHeightDown or -0.2) * (.68 + (bezierAlpha(downT) * .32)))
			elseif slopeDot < -ut then
				local upT = math.clamp((math.abs(slopeDot) - ut) / math.max(1 - ut, .001), 0, 1)
				th = hb + baseOffset + ((self.Options.SlideHipHeightUp or 0) * (.68 + (bezierAlpha(upT) * .32)))
			end
		end
		local hl = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideHipHeightLerp or 6, dt))
		self.Humanoid.HipHeight = self.Humanoid.HipHeight + ((th - self.Humanoid.HipHeight) * hl)

		local ad = projectOnPlane(self.RootPart.AssemblyLinearVelocity, gn)
			or sd
			or fwd
			or projectOnPlane(self.RootPart.CFrame.LookVector, gn)
			or self.SlideDir
			or advents.vector.zAxis
		if fwd and vector.magnitude(fwd) > .001 and vector.dot(ad, fwd) < fdm then
			ad = fwd
		end

		if vector.magnitude(ad) > .001 then
			local tu = gn
			if self.SlideAlignUp then
				local ul = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideAlignUpLerp or 10, dt))
				tu = vector.normalize(self.SlideAlignUp:Lerp(tu, ul))
			end
			self.SlideAlignUp = tu

			local tc = CFrame.lookAt(vector.zero, ad, tu)
			if self.SlideAlignCFrame then
				local al = bezierAlpha(Helper.ExpDecayAlpha(self.Options.SlideAlignLerp or 12, dt))
				self.SlideAlignCFrame = self.SlideAlignCFrame:Lerp(tc, al)
			else
				self.SlideAlignCFrame = tc
			end
			align.CFrame = self.SlideAlignCFrame
		end
	end)

	self.Janitor:Add(self.SlideConnection, "Disconnect", "SlideConnection")
end

function Physics:StopSlide()
	if not getmetatable(self) then return end

	local exitSlopeDir = self.SlideSlopeDir
	local exitSlideDir = self.SlideDir
	local restoreAutoRotate = self.SlideAutoRotate
	local restoreAutoRotateAttribute = self.SlideAutoRotateAttribute
	local restorePlatformStand = self.SlidePlatformStand
	local slideStartSpeed = self.SlideStartSpeed
	local cancelDir = self.SlideCancelPropelDir
	local cancelSpeed = self.SlideCancelPropelSpeed
	local slideAlign = self.Janitor:Get("SlideAlign")
	local slideMover = self.Janitor:Get("SlideMover")
	if slideAlign and slideAlign:IsA("AlignOrientation") then
		slideAlign.Enabled = false
	end
	if slideMover and slideMover:IsA("LinearVelocity") then
		slideMover.Enabled = false
	end
	self.IsSliding = false
	self.SlideStartedAt = nil
	self.LastSlideSlope = 0
	self.SlideAlignCFrame = nil
	self.SlideGroundNormal = nil
	self.SlideSlopeDir = nil
	self.SlideDesiredDir = nil
	self.SlideAlignUp = nil
	self.SlideLowSpeedTime = 0
	self.SlideNoGroundTime = 0
	self.SlideCancelPropelDir = nil
	self.SlideCancelPropelSpeed = nil
	self.SlideStartSpeed = nil
	if self.SlideHipHeightBase then
		self.Humanoid.HipHeight = self.SlideHipHeightBase
	end
	self.SlideHipHeightBase = nil
	if self.SlideRunningEnabled ~= nil then
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Running, self.SlideRunningEnabled)
	end
	if self.SlideRunningNoPhysicsEnabled ~= nil then
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.RunningNoPhysics, self.SlideRunningNoPhysicsEnabled)
	end
	if self.SlideJumpingEnabled ~= nil then
		self.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, self.SlideJumpingEnabled)
	end
	if self.SlidePlatformStand ~= nil then
		self.Humanoid.PlatformStand = restorePlatformStand
	end
	self.Humanoid.AutoRotate = restoreAutoRotate ~= nil and restoreAutoRotate or true
	self.AutoRotateValue = self.Humanoid.AutoRotate
	self.Character:SetAttribute("AutoRotate", restoreAutoRotateAttribute ~= nil and restoreAutoRotateAttribute or self.Humanoid.AutoRotate)
	self.Character:SetAttribute("ShiftLockSuspend", false)
	self.SlidePrevState = nil
	self.SlideRunningEnabled = nil
	self.SlideRunningNoPhysicsEnabled = nil
	self.SlideJumpingEnabled = nil
	self.SlidePlatformStand = nil
	self.SlideAutoRotate = nil
	self.SlideAutoRotateAttribute = nil
	self.Janitor:Remove("SlideMover")
	self.Janitor:Remove("SlideAttachment")
	self.Janitor:Remove("SlideAlign")
	self.Janitor:Remove("SlideConnection")
	self.Janitor:Remove("SlideJumpConnection")
	self.RootPart.AssemblyAngularVelocity = vector.zero
	task.defer(function()
		if not getmetatable(self) then return end
		if not self.Humanoid or self.Humanoid.Health <= 0 then return end
		if self.Humanoid.FloorMaterial == Enum.Material.Air then
			self.Humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
		else
			self.Humanoid:ChangeState(Enum.HumanoidStateType.RunningNoPhysics)
		end
		task.delay(self.Options.SlideRotateResumeDelay or .08, function()
			if not getmetatable(self) then return end
			if not self.Humanoid or self.Humanoid.Health <= 0 then return end
			if self.IsSliding then return end
			if restoreAutoRotate ~= nil then
				self.Humanoid.AutoRotate = restoreAutoRotate
			end
			self.Character:SetAttribute("AutoRotate", restoreAutoRotateAttribute)
			self.Character:SetAttribute("ShiftLockSuspend", false)
		end)
	end)

	self.States.SlideStop:Fire()

	local slideFlatVelocity = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local cmf = self.MoveDirection * advents.vector.flat
	local clf = self.RootPart.CFrame.LookVector * advents.vector.flat
	local fwd = vector.magnitude(slideFlatVelocity) > .1 and vector.normalize(slideFlatVelocity)
		or (vector.magnitude(exitSlopeDir or vector.zero) > .001 and vector.normalize(exitSlopeDir))
		or (vector.magnitude(exitSlideDir or vector.zero) > .001 and vector.normalize(exitSlideDir))
		or (vector.magnitude(clf) > .001 and vector.normalize(clf))
		or advents.vector.zAxis
	if vector.magnitude(cmf) > .1 then
		local inputDir = vector.normalize(cmf)
		if vector.dot(fwd, inputDir) > -.1 then
			local blended = fwd:Lerp(inputDir, .38)
			if vector.magnitude(blended) > .001 then
				fwd = vector.normalize(blended)
			end
		end
	end

	if self.ExpectSlideCancelLandMomentum then
		self.ExpectSlideCancelLandMomentum = false
		self.ApplySlopeJumpBonus = false

		local facingFlat = self.RootPart.CFrame.LookVector * advents.vector.flat
		local handoffDir = cancelDir or fwd
		if vector.magnitude(facingFlat) > .001 then
			local facingDir = vector.normalize(facingFlat)
			if vector.magnitude(handoffDir) > .001 then
				handoffDir = vector.normalize(handoffDir:Lerp(facingDir, self.Options.SlideCancelFacingBlend or .82))
			else
				handoffDir = facingDir
			end
		end

		local sprintSpeed = self.Options.SprintSpeed or 46
		local boostSpeed = math.max(cancelSpeed or 0, self.SlideSpeed or 0, (slideStartSpeed or 0) * .96, (self.Options.DefaultSpeed or 16) * 2)
		local handoffSpeed = math.max(boostSpeed * (self.Options.SlideCancelMomentumScale or 1.12), sprintSpeed * 1.06)
		local mv = handoffDir * handoffSpeed
		local speedOverSprint = math.max(0, boostSpeed - sprintSpeed)
		local cancelBoost = speedOverSprint * (self.Options.SlideCancelSpeedBoostScale or .45)

		self.WaitingForMomentumLanding = false
		self.PendingMomentumStartAt = nil
		self.LastHorizontalVelocity = mv
		local boostCap = sprintSpeed * (self.Options.SlideCancelSpeedBoostCap or 1.55)
		local boostTarget = math.min(boostCap, sprintSpeed + cancelBoost)
		local boostAmount = math.max(0, boostTarget - sprintSpeed)
		local holdDuration = self.Options.SlideCancelSpeedBoostHold or .4
		local decelRate = self.Options.SlideCancelSpeedBoostDecel or 22

		task.delay(self.Options.SlideCancelMomentumDelay or .5, function()
			if not getmetatable(self) then return end
			if self.IsSliding then return end
			self:StopStopMover()
			self:StartTemporarySpeedBoost(boostAmount, handoffDir, holdDuration, decelRate)
			if self.Humanoid.FloorMaterial ~= Enum.Material.Air then
				self:StartStopMomentum(nil, mv)
			else
				self.WaitingForMomentumLanding = true
				self.LastHorizontalVelocity = mv
			end
		end)
	else
		local ExitSpeed = self.SlideSpeed or 0
		local MinHandoff = (self.Options.DefaultSpeed or 16) * 1.2
		if ExitSpeed > MinHandoff then
			local mv = fwd * ExitSpeed
			if self.Humanoid.FloorMaterial ~= Enum.Material.Air then
				self:StopStopMover()
				self:StartStopMomentum(nil, mv)
			else
				self.WaitingForMomentumLanding = true
				self.LastHorizontalVelocity = mv
			end
		end
	end

	self.SlideSpeed = nil
end

function Physics:WallFlip()
	if self.Janitor:Get("WallFlipMove") then return end
	if Grounded.isGrounded(self.Character, self.Options) then return end
	self:BeginExclusiveMovement("WallFlip")

	local Look = self.RootPart.CFrame.LookVector
	local Fwd = vector.normalize(Look * advents.vector.flat)
	local Back = -Fwd

	local Params = RaycastParams.new()
	Params.FilterType = Enum.RaycastFilterType.Include
	Params.FilterDescendantsInstances = {MapContainer}

	local CO = self.RootPart.Position + advents.vector.yAxis * self.Options.WallFlipCastOrigin
	local Hit = workspace:Raycast(CO, Fwd * self.Options.WallFlipCastDirection, Params)
	if not Hit then return end

	local WN = vector.normalize(Hit.Normal * advents.vector.flat)
	local IB = vector.magnitude(self.MoveDirection) > .001
		and vector.normalize(self.MoveDirection * advents.vector.flat)
		or Back
	local FD = vector.normalize(Back * .8 + WN * .3 + IB * .25)

	local LV = vector.create(
		FD.X * self.Options.WallFlipBackVelocity,
		self.Options.WallFlipUpVelocity,
		FD.Z * self.Options.WallFlipBackVelocity
	)
	local restoreAutoRotate = self:GetAutoRotateValue()

	self:ApplyManagedVelocity({
		horizontal = vector.create(LV.X, 0, LV.Z);
		horizontalMode = "set";
		vertical = LV.Y;
		verticalMode = "set";
	})

	self:SetAutoRotate(false)
	self.Humanoid.JumpPower = 0

	local Duration = self.Options.WallFlipDuration

	local Att = Instance.new("Attachment")
	Att.Parent = self.RootPart

	local DF = Instance.new("LinearVelocity")
	DF.Attachment0 = Att
	DF.RelativeTo = Enum.ActuatorRelativeTo.World
	DF.ForceLimitsEnabled = true
	DF.ForceLimitMode = Enum.ForceLimitMode.PerAxis
	DF.MaxAxesForce = vector.create(8e4, 0, 8e4)
	DF.VectorVelocity = vector.create(LV.X, 0, LV.Z)
	DF.Parent = self.RootPart
	self.Janitor:Add(DF, "Destroy", "WallFlipDash")
	self.Janitor:Add(Att, "Destroy", "WallFlipDashAtt")

	task.delay(Duration * .35, function()
		if not getmetatable(self) then return end
		self:SetAutoRotate(restoreAutoRotate)
		self.Janitor:Remove("WallFlipDash")
		self.Janitor:Remove("WallFlipDashAtt")
	end)

	task.delay(Duration, function()
		if not getmetatable(self) then return end
		self.Janitor:Remove("WallFlipMove")
		self.Humanoid.JumpPower = self.Options.JumpPower or 56

		local DP = Instance.new("BodyVelocity")
		DP.MaxForce = vector.create(0, 1e5, 0)
		DP.P = 2e3
		DP.Velocity = vector.create(0, -32, 0)
		DP.Parent = self.RootPart
		self.Janitor:Add(DP, "Destroy", "WallFlipDown")

		local function DownUpdate()
			if not getmetatable(self) then return end
			local IM = vector.magnitude(self.MoveDirection)
			if IM > .15 then
				local CS = math.clamp((IM - .15) / .85, 0, 1)
				DP.MaxForce = vector.create(0, 1e5 * (1 - CS * .7), 0)
				DP.Velocity = vector.create(0, -32 * (1 - CS * .85), 0)
			else
				DP.MaxForce = vector.create(0, 1e5, 0)
				DP.Velocity = vector.create(0, -32, 0)
			end
		end

		Helper.AddToHeartBeat(DownUpdate)
		self.Janitor:Add(function()
			Helper.RemoveFromHeartBeat(DownUpdate)
		end, true, "WallFlipDownConn")

		task.delay(.25, function()
			if not getmetatable(self) then return end
			Helper.RemoveFromHeartBeat(DownUpdate)
			self.Janitor:Remove("WallFlipDown")
			self.Janitor:Remove("WallFlipDownConn")
		end)

		local CIB = vector.magnitude(self.MoveDirection) > .001
			and vector.normalize(self.MoveDirection * advents.vector.flat)
			or Back

		local MD = vector.normalize(Back * .8 + WN * .3 + CIB * .25)
		local MV = MD * self.Options.WallFlipBackVelocity * self.Options.WallFlipMomentumScale

		self.MomentumInputGraceUntil = os.clock() + .18
		self.WaitingForMomentumLanding = false
		self.PendingMomentumStartAt = nil

		task.delay(.28, function()
			if not getmetatable(self) then return end
			self:StopStopMover()
			if self.Humanoid.FloorMaterial ~= Enum.Material.Air then
				self:StartStopMomentum(nil, MV)
			else
				self.WaitingForMomentumLanding = true
				self.LastHorizontalVelocity = MV
			end
		end)
	end)

	return Duration
end

function Physics:Vault(LandY: number, LedgeY: number)
	if self.Janitor:Get("VaultMove") then return end
	self:BeginExclusiveMovement("Vault")

	local EntryCurrentSpeed = self.CurrentSpeed or self.Options.DefaultSpeed or 16
	local EntryBaseSpeed = self.BaseCurrentSpeed or EntryCurrentSpeed
	local Fwd = vector.normalize(self.RootPart.CFrame.LookVector * advents.vector.flat)
	local HN = math.max((LedgeY or LandY) - self.RootPart.Position.Y, .5)
	local UV = math.clamp(HN * 4.5, self.Options.VaultUpVelocity * .55, self.Options.VaultUpVelocity)
	local PVS = vector.magnitude(self.RootPart.AssemblyLinearVelocity * advents.vector.flat)
	local CurHV = self.RootPart.AssemblyLinearVelocity * advents.vector.flat
	local ForwardCarry = math.max(0, vector.dot(CurHV, Fwd))
	local SideCarry = CurHV - (Fwd * vector.dot(CurHV, Fwd))
	local CarriedFwd = math.clamp(ForwardCarry * .95, 0, self.Options.VaultForwardVelocity * 1.2)
	local TF = math.max(self.Options.VaultForwardVelocity, CarriedFwd, self.Options.VaultMinExitSpeed or 32)
	local LaunchBlend = self.Options.VaultLaunchBlend or .62
	local TargetHV = (Fwd * TF) + (SideCarry * .2)
	local LaunchHV = CurHV + ((TargetHV - CurHV) * LaunchBlend)

	local BV = Instance.new("BodyVelocity")
	BV.MaxForce = vector.create(1e5, 1e5, 1e5)
	BV.P = 4e5
	BV.Velocity = LaunchHV + (advents.vector.yAxis * UV)
	BV.Parent = self.RootPart
	self.Janitor:Add(BV, "Destroy", "VaultMove")
	self.Humanoid.JumpPower = 0

	local HD = self.Options.VaultDuration * .65

	task.delay(HD, function()
		if not getmetatable(self) then return end
		if not self.Janitor:Get("VaultMove") then return end
		local TY = LedgeY + 2.5
		local CY = self.RootPart.Position.Y
		local DN = CY - TY
		local DV = math.clamp(DN * 5, 1, 22)
		BV.Velocity = (LaunchHV * .92) + (advents.vector.yAxis * -DV)
	end)

	task.delay(self.Options.VaultDuration, function()
		if not getmetatable(self) then return end
		self.Janitor:Remove("VaultMove")
		self.Humanoid.JumpPower = self.Options.JumpPower or 56
		self:StopStopMover()
		local ExitSpeed = math.max(TF * self.Options.VaultMomentumScale, self.Options.VaultMinExitSpeed or 32, PVS)
		local RestoreSpeed = math.max(EntryBaseSpeed, EntryCurrentSpeed, ExitSpeed)
		self.BaseCurrentSpeed = RestoreSpeed
		self.CurrentSpeed = RestoreSpeed
		self.Humanoid.WalkSpeed = RestoreSpeed
		local CF2 = vector.normalize(self.RootPart.CFrame.LookVector * advents.vector.flat)
		local MV = CF2 * RestoreSpeed
		self:ApplyManagedVelocity({
			horizontal = MV;
			horizontalMode = "set";
		})
		self.LastHorizontalVelocity = MV
		self.PendingMomentumStartAt = nil
		self.WaitingForMomentumLanding = false
		task.defer(function()
			if not getmetatable(self) then return end
			if self.Janitor:Get("VaultMove") then return end
			self.BaseCurrentSpeed = math.max(self.BaseCurrentSpeed or 0, RestoreSpeed)
			self.CurrentSpeed = math.max(self.CurrentSpeed or 0, RestoreSpeed)
			self.Humanoid.WalkSpeed = self.CurrentSpeed
			self:ApplyManagedVelocity({
				horizontal = MV;
				horizontalMode = "max";
			})
		end)
	end)

	return self.Options.VaultDuration
end

return Physics
