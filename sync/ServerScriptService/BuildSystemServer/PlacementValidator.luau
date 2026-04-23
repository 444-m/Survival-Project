local PlacementValidator = {};

function PlacementValidator.new(gridPart: Part)
	local self = setmetatable({
		gridPart = gridPart;
	}, { __index = PlacementValidator });
	return self;
end

function PlacementValidator:ValidatePlacement(pos: Vector3)
	local gridPart: Part = self.gridPart;
	local gridCFrame = gridPart.CFrame;
	local gridSize = gridPart.Size;

	local localPos = gridCFrame:PointToObjectSpace(pos);

	local halfX = gridSize.X / 2;
	local halfZ = gridSize.Z / 2;

	if (pos.Y < gridPart.Position.Y) or (pos.Y >= gridPart.Position.Y + 20) then
		return false;
	end

	if localPos.X < -halfX or localPos.X > halfX then
		return false;
	end

	if localPos.Z < -halfZ or localPos.Z > halfZ then
		return false;
	end

	return true;
end




return PlacementValidator;
