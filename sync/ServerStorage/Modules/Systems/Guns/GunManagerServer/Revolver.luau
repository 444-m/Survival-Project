const TRACE_DURATION = .5
local thread: thread?

local advents = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
local replicatedStorage = game:GetService("ReplicatedStorage")
local shotAsset = replicatedStorage.Assets.Effects.Weapons.Revolver.Shot

local revolver = {}

const RAYCAST_DISTANCE = 1000
const RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Include
RAYCAST_PARAMS.FilterDescendantsInstances = {
	workspace:WaitForChild("objects"):WaitForChild("map");
	workspace.Terrain;
	workspace:WaitForChild("objects"):WaitForChild("entities");
}

local function getMaxParticleLifetime(container: Instance?): number
	if not container then return 0 end
	local max = 0
	for _, v in next, container:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			local lifetime = v.Lifetime.Max
			if lifetime > max then max = lifetime end
		end
	end
	return max
end

local cachedLifetime = getMaxParticleLifetime(shotAsset)

revolver.fireCallback = function(player: Player, data)
	if type(data) ~= "table" then return end
	local equipModel: Model = data.EquipModel
	if not equipModel then return end
	local revolverBarrel: BasePart? = equipModel:FindFirstChild("Barrel") :: BasePart?
	local revolverBody: BasePart? = equipModel:FindFirstChild("Revolver_Body") :: BasePart?
	if not revolverBody then return end
	if not revolverBarrel then return end

	local barrelCFrame = (revolverBarrel :: BasePart).CFrame * CFrame.new(0, 0, -(revolverBarrel :: BasePart).Size.Z / 2)
	local origin = barrelCFrame.Position
	local direction = vector.normalize(data.mouseHit - origin) * RAYCAST_DISTANCE
	local result = workspace:Raycast(origin, direction, RAYCAST_PARAMS)
	local hitPosition = result and result.Position or (origin + direction)
	local hitNormal = result and result.Normal or vector.create(0, 1, 0)

	if thread then
		task.cancel(thread)
		thread = nil
	end
	
	advents.sounds.play({
		soundId = "Tools/Revolver/Fired";
		mode = "position";
		position = vector.create(origin.X, origin.Y, origin.Z);
	})

	advents.effects.replicate({
		container = Instance.new("Part");
		type = "forge";
		assetPath = "Assets.Effects.Weapons.Revolver.Shot";
		extra = {
			cframe = barrelCFrame;
			hitPosition = hitPosition;
			hitNormal = hitNormal;
			duration = TRACE_DURATION;
			target = revolverBarrel :: BasePart;
			targetOffset = CFrame.new(0, 0, -(revolverBarrel :: BasePart).Size.Z / 2);
		};
		destroyAfter = TRACE_DURATION + cachedLifetime + 1;
	})

	thread = task.delay(TRACE_DURATION, function()
		thread = nil
	end)
end

return revolver
