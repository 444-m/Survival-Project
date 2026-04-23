local ReplicatedStorage = game:GetService("ReplicatedStorage");
local PlaceablesFolder = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("PlaceableModels");

local BuildSystemTypes = require(ReplicatedStorage.Modules.Shared.BuildSystem.BuildSystemTypes);

export type Placeable = BuildSystemTypes.Placeable;

local Placeables = {};

Placeables.Placeables = {
	{
		Name = "Large Wall";
		Model = PlaceablesFolder.LargeWall;
		Health = 200;
	};
	{
		Name = "Wall";
		Model = PlaceablesFolder.Wall;
		Health = 100;
	};
	{
		Name = "Small Wall";
		Model = PlaceablesFolder.SmallWall;
		Health = 50;
	};
	{
		Name = "Shelf";
		Model = PlaceablesFolder.Shelf;
		Health = 40;
	};
	{
		Name = "Garden Bed";
		Model = PlaceablesFolder.GardenBed;
		Health = 120;
	};
	{
		Name = "Oven";
		Model = PlaceablesFolder.Oven;
		Health = 70;
	};
	{
		Name = "Pot";
		Model = PlaceablesFolder.Pot;
		Health = 70;
	};
} :: {Placeable};

function Placeables.PrepareTemplatesServer()
	for _, placeable in Placeables.Placeables do
		local boundPart = placeable.Model:FindFirstChild("Bounds") :: BasePart?;
		if boundPart then
			boundPart.Transparency = 1;
		end
	end
end

return Placeables;