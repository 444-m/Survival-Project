--!nocheck
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _ = require(script.Parent.configs)
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local Grounded = require("./grounded")

local Player = Players.LocalPlayer

local Helper = {
	Runners = {};
	CurrentHeartBeat = nil;
}

function Helper.OnHeartBeat()
	if Helper.CurrentHeartBeat then return end

	Helper.CurrentHeartBeat = RunService.Heartbeat:Connect(function(dt)
		for _,runners in next, Helper.Runners do
			runners(dt)
		end
	end)
end; Helper.OnHeartBeat()

function Helper.AddToHeartBeat(fn: (dt: number) -> ())
	table.insert(Helper.Runners, fn)
end

function Helper.RemoveFromHeartBeat(fn: () -> ())
	for i, runners in next, Helper.Runners do
		if runners == fn then
			table.remove(Helper.Runners, i)
			break
		end
	end
end

function Helper.ClearHeartBeat()
	if Helper.CurrentHeartBeat then
		Helper.CurrentHeartBeat:Disconnect()
		Helper.CurrentHeartBeat = nil
	end

	Helper.Runners = {}
end

function Helper.Accelerate(CurrentVelocity: vector, TargetVelocity: vector, Acceleration: number, dt: number)
	local delta = TargetVelocity - CurrentVelocity
	local distance = vector.magnitude(delta)

	if distance <= 0 then
		return TargetVelocity
	end

	local maxStep = Acceleration * dt
	if distance <= maxStep then
		return TargetVelocity
	end

	return CurrentVelocity + (vector.normalize(delta) * maxStep)
end

function Helper.Deccelerate(CurrentVelocity: vector, Decceleration: number, dt: number)
	local speed = vector.magnitude(CurrentVelocity)
	if speed <= 0 then
		return vector.zero
	end

	local drop = Decceleration * dt
	if speed <= drop then
		return vector.zero
	end

	return CurrentVelocity - (vector.normalize(CurrentVelocity) * drop)
end

function Helper.GetSlopeAngle(Normal: vector)
	local up = vector.create(0, 1, 0)
	local dot = vector.dot(Normal, up)
	return math.acos(dot)
end

function Helper.GetSlopeDirection(Normal: vector, MoveDirection: vector)
	local right = vector.cross(Normal, MoveDirection)
	local slopeDir = vector.cross(right, Normal)
	return vector.normalize(slopeDir)
end

function Helper.GetSlopeMove(MoveDirection: vector, SlopeNormal: vector)
	local slopeDir = Helper.GetSlopeDirection(SlopeNormal, MoveDirection)
	local slopeAngle = Helper.GetSlopeAngle(SlopeNormal)

	local slopeMove = MoveDirection * math.cos(slopeAngle) + slopeDir * math.sin(slopeAngle)
	return slopeMove
end

function Helper.ExpDecayAlpha(Rate: number, dt: number): number
	return 1 - math.exp(-Rate * dt)
end

function Helper.SpringDamp(Vel: number, Error: number, Stiffness: number, Damping: number, dt: number): (number, number)
	local accel = (Error * Stiffness) - (Vel * Damping)
	local newVel = Vel + accel * dt
	local displacement = newVel * dt
	return newVel, displacement
end

function Helper.SmoothDamp(Current: number, Target: number, CurrentVelocity: number, SmoothTime: number, dt: number, MaxSpeed: number?): (number, number)
	SmoothTime = math.max(SmoothTime, .0001)
	local omega = 2 / SmoothTime
	local x = omega * dt
	local exp = 1 / (1 + x + .48 * x * x + .235 * x * x * x)
	local delta = Current - Target
	local maxDelta = (MaxSpeed or math.huge) * SmoothTime
	delta = math.clamp(delta, -maxDelta, maxDelta)
	local temp = (CurrentVelocity + omega * delta) * dt
	local newVelocity = (CurrentVelocity - omega * temp) * exp
	local newValue = (Current - delta) + (delta + temp) * exp
	return newValue, newVelocity
end

local function isFlatEnoughAt(Position: vector, Forward: vector, Right: vector, MaxSlope: number, Filter: RaycastParams, ForwardDepth: number?, SideDepth: number?)
	local MinNormalY = 1 - MaxSlope
	local SampleDepth = 4.5
	local Up = advents.vector.yAxis * 1.25
	local FDepth = ForwardDepth or .65
	local SDepth = SideDepth or .65

	for _, offset in next, {
		vector.zero;
		Forward * FDepth;
		-Forward * (FDepth * .35);
		Right * SDepth;
		-Right * SDepth;
	} do
		local Result = workspace:Raycast(Position + offset + Up, -advents.vector.yAxis * SampleDepth, Filter)
		if not Result or Result.Normal.Y < MinNormalY then
			return false
		end
	end

	return true
end

function Helper.CheckHighRise(Character: Model?, MinY: number, Options: typeof(require("./configs")))
	Options = Options or require("./configs")
	MinY = MinY or 3

	local Filter = RaycastParams.new()
	Filter.FilterDescendantsInstances = {workspace:WaitForChild("objects"):WaitForChild("map")}
	Filter.FilterType = Enum.RaycastFilterType.Include

	local RootPart: Part = Character:FindFirstChild("HumanoidRootPart")
	local Head: Part = Character:FindFirstChild("Head")
	local Humanoid: Humanoid = Character:FindFirstChild("Humanoid")
	local Forward = RootPart.CFrame.LookVector * advents.vector.flat
	if vector.magnitude(Forward) <= .001 then return false, nil, nil end
	Forward = vector.normalize(Forward)

	local Right = RootPart.CFrame.RightVector * advents.vector.flat
	if vector.magnitude(Right) > .001 then
		Right = vector.normalize(Right)
	end

	local ForwardRange = Options.MantleForwardRange or 7
	local WallDot = Options.MantleWallDot or .2
	local WaistY = (Humanoid and (RootPart.Position.Y + Humanoid.HipHeight)) or (RootPart.Position.Y + 1.4)

	local function getWallHit()
		for _, origin in next, {
			RootPart.Position + advents.vector.yAxis * .6;
			vector.create(RootPart.Position.X, WaistY, RootPart.Position.Z);
			RootPart.Position + advents.vector.yAxis * 2.2;
			Head.Position + advents.vector.yAxis * .2;
		} do
			for _, off in next, {vector.zero, Right * .6, -Right * .6, Forward * .8} do
				local result = workspace:Raycast(origin + off, Forward * ForwardRange, Filter)
				if result then
					local NFlat = result.Normal * advents.vector.flat
					if vector.magnitude(NFlat) > .001 then
						local Dot = vector.dot(vector.normalize(NFlat), -Forward)
						if Dot > WallDot then
							return result
						end
					end
				end
			end
		end
		return nil
	end

	local WallResult = getWallHit()
	if not WallResult then return false, nil, nil end
	if math.abs(WallResult.Normal.Y) > .12 then
		return false, nil, nil
	end

	local HitX = WallResult.Position.X
	local HitZ = WallResult.Position.Z

	local function getLedge()
		for _, ledgeOff in next, {
			vector.zero,
			Right * .8,
			-Right * .8,
			Forward * .6,
		} do
			local AboveHit = vector.create(HitX + ledgeOff.X, RootPart.Position.Y + MinY, HitZ + ledgeOff.Z)
			local LedgeRay = workspace:Raycast(AboveHit, -advents.vector.yAxis * (MinY + 4), Filter)
			if LedgeRay and vector.dot(LedgeRay.Normal, advents.vector.yAxis) >= .5 then
				return LedgeRay
			end
		end
		return nil
	end

	local LedgeResult = getLedge()
	if not LedgeResult then return false, nil, nil end

	local LedgeY = LedgeResult.Position.Y
	local HeightDiff = LedgeY - RootPart.Position.Y

	local MaxSlope = Options.MantleMaxSlope or .35
	if LedgeResult.Normal.Y < (1 - MaxSlope) then
		return false, nil, nil
	end

	local TopCheckPos = LedgeResult.Position + (Forward * .85)
	if not isFlatEnoughAt(TopCheckPos, Forward, Right, MaxSlope, Filter, .55, .7) then
		return false, nil, nil
	end

	local ExtraHeight = Options.MantleExtraHeight or 0
	if HeightDiff < Options.MantleMinHeight or HeightDiff > (Options.MantleMaxHeight + ExtraHeight) then
		return false, nil, nil
	end

	local CanVault = Helper.CheckLowRise(Character, Options)
	if CanVault then
		return false, nil, nil
	end

	local HeadTop = vector.create(HitX, LedgeY + Head.Size.Y, HitZ)
	local UpResult = workspace:Raycast(HeadTop, advents.vector.yAxis * Options.MantleUpRange, Filter)
	local HeadRoom = UpResult and (UpResult.Position.Y - HeadTop.Y) or Options.MantleUpRange

	local HeadOver = Head.Position.Y >= (LedgeY - .1)
	if not HeadOver and HeadRoom < Options.MantleMinHeadRoom then
		local Arm = Character:FindFirstChild("RightUpperArm") or Character:FindFirstChild("Right Arm")
		if Arm and Arm:IsA("BasePart") then
			local ArmHalf = Arm.Size.Y * .5
			local HeadOffset = Head.Position.Y - HeadTop.Y
			local AltOrigin = HeadTop + (advents.vector.yAxis * ArmHalf)
			local AltResult = workspace:Raycast(AltOrigin, advents.vector.yAxis * Options.MantleUpRange, Filter)
			local AltRoom = AltResult and (AltResult.Position.Y - AltOrigin.Y) or Options.MantleUpRange
			if (AltRoom + HeadOffset) < Options.MantleMinHeadRoom then
				return false, nil, nil
			end
		else
			return false, nil, nil
		end
	end

	local FloorEstimate = math.max(1, math.floor(LedgeY / Options.MantleFloorHeight) + 1)

	return true, FloorEstimate, HeadRoom
end

function Helper.CheckLowRise(Character: Model, Options: typeof(require("./configs")))
	local RootPart = Character.HumanoidRootPart
	local RootPos = RootPart.Position
	local LookVector = RootPart.CFrame.LookVector * advents.vector.flat
	if vector.magnitude(LookVector) <= .001 then
		return false, nil, nil
	end
	LookVector = vector.normalize(LookVector)
	local Right = RootPart.CFrame.RightVector * advents.vector.flat
	if vector.magnitude(Right) > .001 then
		Right = vector.normalize(Right)
	else
		Right = vector.zero
	end

	local VaultForwardRange = Options.VaultForwardRange or 4.2
	local VaultMinHeight = Options.VaultMinHeight or 1.8
	local VaultMaxHeight = Options.VaultMaxHeight or 3.8
	local VaultLandDepth = Options.VaultLandDepth or 3.2
	local VaultMaxSlope = Options.VaultMaxSlope or .22

	local LedgeParams = RaycastParams.new()
	LedgeParams.FilterDescendantsInstances = {workspace:WaitForChild("objects"):WaitForChild("map")}
	LedgeParams.FilterType = Enum.RaycastFilterType.Include

	local ForwardOrigin = RootPos + advents.vector.yAxis * .5
	local ForwardTarget = ForwardOrigin + LookVector * VaultForwardRange

	local LedgeRay = workspace:Raycast(
		ForwardTarget,
		advents.vector.yAxis * -(VaultMaxHeight + 1),
		LedgeParams
	)

	if not LedgeRay then
		LedgeRay = workspace:Raycast(
			ForwardTarget + LookVector * .5,
			advents.vector.yAxis * -(VaultMaxHeight + 1),
			LedgeParams
		)
	end

	if not LedgeRay then
		return false, nil, nil
	end

	local LedgeY = LedgeRay.Position.Y
	local HeightDiff = LedgeY - (RootPos.Y - 3)

	if LedgeRay.Normal.Y < (1 - VaultMaxSlope) then
		return false, nil, nil
	end

	if HeightDiff < VaultMinHeight or HeightDiff > VaultMaxHeight then
		return false, nil, nil
	end

	local TopCheckPos = LedgeRay.Position + (LookVector * .35)
	if not isFlatEnoughAt(TopCheckPos, LookVector, Right, VaultMaxSlope, LedgeParams, .35, .5) then
		return false, nil, nil
	end

	local FaceRay = workspace:Raycast(
		RootPos + advents.vector.yAxis * .5,
		LookVector * (VaultForwardRange + .5),
		LedgeParams
	)

	if FaceRay then
		local FaceNFlat = FaceRay.Normal * advents.vector.flat
		if vector.magnitude(FaceNFlat) > .001 then
			if vector.dot(vector.normalize(FaceNFlat), -LookVector) < .55 then
				return false, nil, nil
			end
		end
		if math.abs(FaceRay.Normal.Y) > .12 then
			return false, nil, nil
		end
	end

	local LandOrigin = ForwardTarget + LookVector * VaultLandDepth + advents.vector.yAxis
	local LandRay = workspace:Raycast(
		LandOrigin,
		advents.vector.yAxis * -(VaultMaxHeight + 3),
		LedgeParams
	) or workspace:Raycast(
		ForwardTarget + LookVector * (VaultLandDepth * .5) + advents.vector.yAxis,
		advents.vector.yAxis * -(VaultMaxHeight + 3),
		LedgeParams
	)

	if not LandRay then
		return false, nil, nil
	end

	local LandY = LandRay.Position.Y

	if LandY > LedgeY - .1 then
		return false, nil, nil
	end

	if not isFlatEnoughAt(LandRay.Position, LookVector, Right, VaultMaxSlope, LedgeParams, .4, .55) then
		return false, nil, nil
	end

	return true, LandY, LedgeY
end

Helper.GetRandomFromDict = function(dict)
	local keys = {}
	for key in next, dict do
		table.insert(keys, key)
	end
	return keys[math.random(1, #keys)]
end

return Helper
