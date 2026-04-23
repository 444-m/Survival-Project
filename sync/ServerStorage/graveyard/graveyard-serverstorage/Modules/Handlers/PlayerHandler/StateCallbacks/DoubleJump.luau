local ReplicatedStorage = game:GetService("ReplicatedStorage")
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local Globals = require(ReplicatedStorage.Modules.Shared.Globals)
local effects = advents.effects
local sounds = advents.sounds

local EffectTemplate = ReplicatedStorage.Assets.Effects.Player.Movement.DoubleJump

local HorizontalScale = .08
local PredictionTime = .035
local GroundSnapDistance = 4.5
local AirDrop = .15

local DoubleJump = {}

function DoubleJump.Start(Character: Model)
	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
	if not HRP or not Humanoid then return end

	local Vel = HRP.AssemblyLinearVelocity
	local HorizVel = vector.create(Vel.X, 0, Vel.Z)
	local Speed = vector.magnitude(HorizVel)

	local Forward = HRP.CFrame.LookVector * advents.vector.flat
	if Speed > .5 then
		Forward = vector.normalize(HorizVel)
	elseif vector.magnitude(Forward) > .001 then
		Forward = vector.normalize(Forward)
	else
		Forward = vector.zero
	end

	local PredictedPos = HRP.Position + (HorizVel * PredictionTime)
	local Offset = vector.create(
		HorizVel.X * HorizontalScale,
		0,
		HorizVel.Z * HorizontalScale
	) + (Forward * math.clamp(Speed * .02, 0, .8))

	local FootHeight = (HRP.Size.Y / 2) + Humanoid.HipHeight
	local FeetPosition = PredictedPos + Offset - vector.create(0, FootHeight, 0)

	local RayParams = RaycastParams.new()
	RayParams.FilterType = Enum.RaycastFilterType.Include
	RayParams.FilterDescendantsInstances = {Globals.MapContainer}

	local GroundHit = workspace:Raycast(
		Vector3.new(FeetPosition.X, FeetPosition.Y + 2, FeetPosition.Z),
		Vector3.new(0, -(GroundSnapDistance + 2), 0),
		RayParams
	)

	local SpawnPosition = GroundHit and (GroundHit.Position + Vector3.new(0, .05, 0))
		or Vector3.new(FeetPosition.X, FeetPosition.Y - AirDrop, FeetPosition.Z)
	local SpawnCF = CFrame.new(SpawnPosition)
	
	effects.replicate({
		container = EffectTemplate;
		type = "emit";
		extra = {
			cframe = SpawnCF;
		};
		destroyAfter = 2;
	})

	sounds.play({
		soundId = "Movement/DoubleJump";
		mode = "position";
		position = advents.vector.toNative(SpawnPosition);
	})
end

return DoubleJump
