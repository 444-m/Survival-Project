local BuildTrackerClient = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage");

local Remotes = ReplicatedStorage:WaitForChild("Remotes").BuildSystem;
local Placeables = require(script.Parent.PlaceablesClient)

local BuildSystemTypes = require(ReplicatedStorage.Modules.Shared.BuildSystem.BuildSystemTypes);

type Object = BuildSystemTypes.Object;
type Placeable = BuildSystemTypes.Placeable;

function BuildTrackerClient.init()
	local self = setmetatable({}, {
		__index = BuildTrackerClient
	});
	return self;
end

function BuildTrackerClient:GetObjectFromModel(model: Model): Object?
	local object: BuildSystemTypes.Object = Remotes.GetObjectFromModel:InvokeServer(model);
	return object;
end

function BuildTrackerClient:DeleteObject(object: Object)
	Remotes.DeleteObject:InvokeServer(object);
	return;
end

-- Placeable is a template
-- Place a Placeable --> Create an Object
function BuildTrackerClient:PlacePlaceable(placeable: Placeable, CFrame: CFrame): (boolean, Object)
	local success, objectOrOverlap = Remotes.PlacePlaceable:InvokeServer(placeable, CFrame);
	return success, objectOrOverlap;
end

return BuildTrackerClient
