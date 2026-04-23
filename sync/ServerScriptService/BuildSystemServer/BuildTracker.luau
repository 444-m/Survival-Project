local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BuildTracker = {}

local Placeables = require(ReplicatedStorage.Modules.Shared.BuildSystem.Placeables)

export type Object = {
	Template: Placeables.Placeable,
	Model: Model,
	Health: number,
	BoundPart: BasePart;
}

function BuildTracker.new(objectsFolder: Folder)
	local self = setmetatable({
		placedObjects = {} :: {Object};
		objectsFolder = objectsFolder;
		BoundsChecker = require(script.BoundsChecker).new();
	}, {
		__index = BuildTracker
	});
	return self;
end

function BuildTracker:GetObjectFromModel(model: Model): Object?
	for _, object in self.placedObjects :: {Object} do
		if object.Model == model then
			return object;
		end
	end
end

function BuildTracker:DeleteObject(object: Object)
	for index, objectTest in self.placedObjects :: {Object} do
		if objectTest == object then
			table.remove(self.placedObjects, index);
			self.BoundsChecker:RemoveObjectBounds(object.Model);
			object.Model:Destroy();
			return;
		end
	end
	error("failed to find object to delete");
end

-- Placeable is a template
-- Place a Placeable --> Create an Object
function BuildTracker:PlacePlaceable(placeable: Placeables.Placeable, cframe: CFrame): (boolean, Object)
	local objectSize = placeable.BoundPart.Size;
	local overlap, objectOverlap = self.BoundsChecker:CheckBoundsOverlap(objectSize, cframe);
	if not overlap then
		local newModel = placeable.Template:Clone();
		local newObject: Object = {
			Template = placeable,
			Model = newModel,
			Health = placeable.Health,
			BoundPart = newModel:WaitForChild("Bounds");
		}; 
		newModel.Parent = self.objectsFolder;
		newModel:PivotTo(cframe);
		table.insert(self.placedObjects, newObject);
		self.BoundsChecker:AddObjectBounds(newModel, objectSize, cframe);
		return true, newObject;
	end
	return false, self:GetObjectFromModel(objectOverlap);
end

return BuildTracker
