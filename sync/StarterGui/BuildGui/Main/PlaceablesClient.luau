local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceablesClient = {}

local Placeables = require(ReplicatedStorage.Modules.Shared.BuildSystem.Placeables)
local BuildSystemTypes = require(ReplicatedStorage.Modules.Shared.BuildSystem.BuildSystemTypes)

export type Placeable = BuildSystemTypes.Placeable;

PlaceablesClient.Placeables = {} :: {Placeable};

function PlaceablesClient.init()
	for _, placeableServer in Placeables.Placeables do
		local template: Placeable = {
			Name = placeableServer.Name;
			Template = placeableServer.Model;
			Health = placeableServer.Health;
			BoundPart = placeableServer.Model:WaitForChild("Bounds");
		};
		template.BoundPart.Transparency = 1;

		table.insert(PlaceablesClient.Placeables, template);
	end
	return PlaceablesClient;
end

return PlaceablesClient
