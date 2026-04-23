local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Spring = require(ReplicatedStorage.Modules.Shared.utils.advents).spring

const CastSize = vector.create(1, 1.2, 1)
const CastMargin = .05
const MaxPen = .55
const TiltScale = .04

local CastParams = RaycastParams.new()
CastParams.CollisionGroup = "Default"
CastParams.FilterType = Enum.RaycastFilterType.Exclude

local SpringX = Spring.new(0)
local SpringY = Spring.new(0)
local SpringZ = Spring.new(0)

SpringX.s = 22; SpringX.d = .8
SpringY.s = 22; SpringY.d = .8
SpringZ.s = 22; SpringZ.d = .8

local Axes = {
	{Dir = "X"; Vec = function(S) return vector.create(S, 0, 0) end};
	{Dir = "Y"; Vec = function(S) return vector.create(0, S, 0) end};
	{Dir = "Z"; Vec = function(S) return vector.create(0, 0, S) end};
}

local function SolveArm(DesiredCF: CFrame, FilterList: {Instance})
	local Centre = DesiredCF.Position
	CastParams.FilterDescendantsInstances = FilterList
	local Raw = {X=0; Y=0; Z=0}
	for _, Axis in next, Axes do
		local Best = {Pen = math.huge; N = 1}
		for _, Sign in next, {-1, 1} do
			local Hit = workspace:Blockcast(CFrame.new(Centre), CastSize, Axis.Vec(Sign) * 2, CastParams)
			if Hit then
				local Pen = math.min((2 - Hit.Distance) * .35, MaxPen)
				if Pen < Best.Pen then Best = {Pen = Pen; N = -Sign} end
			end
		end
		if Best.Pen < math.huge then
			Raw[Axis.Dir] = (Best.Pen + CastMargin) * Best.N
		end
	end
	return vector.create(Raw.X, Raw.Y, Raw.Z)
end

local function GetTilt(Correction: vector, DesiredCF: CFrame): CFrame
	local Local = DesiredCF:VectorToObjectSpace(Correction :: any)
	return CFrame.Angles(Local.Z * TiltScale, 0, -Local.X * TiltScale)
end

local ViewportCollisions = {}

function ViewportCollisions.ResolveCFrame(Arms: {LeftArm: BasePart; RightArm: BasePart}, OldCF: CFrame, DesiredCF: CFrame, FilterList: {Instance})
	local Mid = (Arms.LeftArm.CFrame.Position + Arms.RightArm.CFrame.Position) * .5
	local MidCF = CFrame.new(Mid, Mid + DesiredCF.LookVector)
	local Raw = SolveArm(MidCF, FilterList or {})

	SpringX.t = Raw.x
	SpringY.t = Raw.y
	SpringZ.t = Raw.z

	local Smooth = vector.create(SpringX.p, SpringY.p, SpringZ.p)
	local Tilt = GetTilt(Smooth, DesiredCF)
	local Offset = CFrame.new(Smooth.x, Smooth.y, Smooth.z)

	return DesiredCF * Offset * Tilt
end

function ViewportCollisions.Reset()
	SpringX.p = 0; SpringX.v = 0; SpringX.t = 0
	SpringY.p = 0; SpringY.v = 0; SpringY.t = 0
	SpringZ.p = 0; SpringZ.v = 0; SpringZ.t = 0
end

return ViewportCollisions