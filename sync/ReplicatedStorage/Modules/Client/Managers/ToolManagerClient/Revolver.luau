local Revolver = {}
local player = game.Players.LocalPlayer
local advents = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
local Animations = require "@game/ReplicatedStorage/Modules/Shared/Animations"
local GunManager = require "@game/ReplicatedStorage/Modules/Client/Systems/Guns/GunManager"
local ProjectileClient = require "@game/ReplicatedStorage/Modules/Client/Managers/ProjectileClient"
local ProjectileShared = require "@game/ReplicatedStorage/Modules/Shared/Systems/Guns/ProjectileShared"

local RAYCAST_DISTANCE = 1000
local RAYCAST_PARAMS = RaycastParams.new()
RAYCAST_PARAMS.FilterType = Enum.RaycastFilterType.Include
RAYCAST_PARAMS.FilterDescendantsInstances = {workspace:WaitForChild("objects"):WaitForChild("map"), workspace.Terrain, workspace:WaitForChild("objects"):WaitForChild("entities")}

local function getMouseRay(): (Vector3, Vector3)
	local camera = workspace.CurrentCamera
	local mouse = player:GetMouse()
	local ray = camera:ScreenPointToRay(mouse.X, mouse.Y)
	return ray.Origin, ray.Direction
end

function Revolver:Use()
	local character = player.Character
	if not character then return end
	local manager = GunManager.Get()
	manager:SetCurrent("Revolver")
	local ok, reason = manager:Shoot("Revolver")
	if not ok then
		return { Cancel = true; Reason = reason; DryRecoil = true }
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	local Track = advents.animator.playAnim(animator, Animations.LoadedAnimations.Weapons.Revolver.Shoot.loaded)
	Track.Priority = Enum.AnimationPriority.Action4
	Revolver.track = Track
	local def = ProjectileShared.Revolver
	local barrelPart: BasePart?
	if def and def.BarrelName then
		for _, desc in next, character:GetDescendants() do
			if desc:IsA("BasePart") and desc.Name == def.BarrelName then
				barrelPart = desc :: BasePart
				break
			end
		end
	end
	local camera = workspace.CurrentCamera
	local rayOrigin, rayDir = getMouseRay()
	local result = workspace:Raycast(rayOrigin, rayDir * RAYCAST_DISTANCE, RAYCAST_PARAMS)
	local worldTarget: Vector3 = result and result.Position or (rayOrigin + rayDir * RAYCAST_DISTANCE)
	local origin: Vector3 = barrelPart and barrelPart.Position or camera.CFrame.Position
	local direction: Vector3 = (worldTarget - origin)
	ProjectileClient.Fire({
		Name = "Revolver";
		Origin = origin;
		Direction = direction;
		Speed = def and def.Speed or 600;
	})
	return {
		Action = "Fire";
		origin = origin;
		mouseHit = worldTarget;
	}
end

function Revolver:Cancel()
	if Revolver.track then
		advents.animator.stopAnim(Revolver.track, .15)
	end
end

return Revolver