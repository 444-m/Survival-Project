local ReplicatedStorage = game:GetService("ReplicatedStorage");

local buildSystemFolder = workspace.systems.BuildSystem;
local objectsFolder = workspace.objects.placed;

local remotes = ReplicatedStorage:WaitForChild("Remotes").BuildSystem;

local BuildSystemTypes = require(ReplicatedStorage.Modules.Shared.BuildSystem.BuildSystemTypes);
local Placeables = require(ReplicatedStorage.Modules.Shared.BuildSystem.Placeables);

type Object = BuildSystemTypes.Object;
type Placeable = BuildSystemTypes.Placeable;

local BuildTracker = require(script.BuildTracker).new(objectsFolder);
local BoundsChecker = BuildTracker.BoundsChecker;
local PlacementValidator = require(script.PlacementValidator).new(buildSystemFolder.GridPart);

Placeables.PrepareTemplatesServer();

local function ensurePlaceableValid(placeable: Placeable): Placeable
	for _, placeable2 in Placeables.Placeables do
		if placeable.Name == placeable2.Name then
			return {
				Name = placeable.Name,
				Template = placeable.Template,
				Health = placeable.Health,
				BoundPart = placeable.BoundPart,
			};
		end
	end
	print("placeable:", placeable);
	error("failed to validate placeable!");
end

local function ensureObjectValid(object: Object): Object
	local validPlaceable = ensurePlaceableValid(object.Template);
	if not object.Model:IsDescendantOf(objectsFolder) then
		return;
	end
	return BuildTracker:GetObjectFromModel(object.Model);
end

local function ensureType(object: any, typeRequire: string)
	if typeof(object) ~= typeRequire then
		error(`failed to validate object ({object}) is {typeRequire}!`);
	end
end

-- zero-trust remote architecture

remotes.GetObjectFromModel.OnServerInvoke = function(player: Player, model: Model)
	if not model:IsDescendantOf(objectsFolder) then
		return;
	end
	local object = BuildTracker:GetObjectFromModel(model);
	return object;
end

remotes.PlacePlaceable.OnServerInvoke = function(player: Player, placeable: Placeable, cframe: CFrame): (boolean, Object)
	ensureType(cframe, "CFrame");
	placeable = ensurePlaceableValid(placeable);
	
	if not PlacementValidator:ValidatePlacement(cframe.Position) then
		warn(`failed to validate placement: {cframe.Position}`);
		return;
	end
	
	local success, objectOrOverlap = BuildTracker:PlacePlaceable(placeable, cframe);
	return success, objectOrOverlap;
end

remotes.DeleteObject.OnServerInvoke = function(player: Player, object: Object)
	object = ensureObjectValid(object);

	local object = BuildTracker:DeleteObject(object);
	return object;
end