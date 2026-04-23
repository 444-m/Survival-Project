--!nonstrict
local PlaceablePreview = {};

local UserInputService = game:GetService("UserInputService");
local RunService = game:GetService("RunService");
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Placeables = require(script.Parent.PlaceablesClient);
local Grid = require(script.Parent.Grid)
local Util = require(script.Parent.Util);
local Maid = require(ReplicatedStorage:WaitForChild("Modules").Client.Util.Maid);

export type PreviewPlaceable = {
	Placeable: Placeables.Placeable,
	CFrame: CFrame,
	Model: Model,
	Highlight: Highlight?
};

type ObjectsMap = {[Object]: true};

function PlaceablePreview.new(objectsFolder: Folder, gridSnap: number, grid: Grid.Grid, gridPart: BasePart)
	local self = setmetatable({
		objectsFolder = objectsFolder;
		gridPart = gridPart;
		gridSnap = gridSnap;
		grid = grid;
		
		previewPlaceable = nil :: PreviewPlaceable?;
		enabled = true;
		maid = Maid.new();
		gridPartParams = Util.CreateParamsInclude(gridPart);
	}, {
		__index = PlaceablePreview
	});

	self.maid:GiveTask(
		UserInputService.InputChanged:Connect(function(inputObject, gpe)
			if not gpe then
				if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
					self:_updateCFrameToMouse();
				end
			end
		end)
	);
	
	local interpLen = 0.1;
	local interpTime: number, interpGoal: CFrame?, interpStart: CFrame?;
	local previousCurrentPosition: CFrame;
	self.maid:GiveTask(
		RunService.RenderStepped:Connect(function(delta)
			if not self.previewPlaceable or not self.enabled then
				return;
			end
			local cframe = self.previewPlaceable.CFrame;
			if cframe and previousCurrentPosition ~= cframe then
				interpTime = 0;
				interpGoal = cframe;
				interpStart = self.previewPlaceable.Model:GetPivot();
				previousCurrentPosition = cframe;
			end
			if interpGoal and interpStart then
				local alpha = Util.quadOut(interpTime);
				self.previewPlaceable.Model:PivotTo(interpStart:Lerp(interpGoal, alpha));
				interpTime = math.min(1, interpTime + delta / interpLen);
			end
		end)
	);

	return self
end

function PlaceablePreview:_updateCFrameToMouse()
	if not self.enabled then
		return;
	end
	local cast = Util.RaycastMousePos(self.gridPartParams);
	if cast and self.previewPlaceable then
		if not self.previewPlaceable.CFrame then
			self.previewPlaceable.CFrame = CFrame.new(cast.Position);
		end
		self:UpdatePreviewPosition(cast.Position);
	end
end

function PlaceablePreview:_snapToGrid(pos: Vector3, objectSize: Vector3)
	local grid: Grid.Grid = self.grid;
	local currentCframe = self.previewPlaceable.CFrame;
	local gridPos = self.gridPart.Position;

	local gridSize = Vector3.new(self.gridPart.Size.X - grid.gridOffset.X * 2, 0, self.gridPart.Size.Z - grid.gridOffset.Z * 2)

	local cornerPos = Vector3.new(
		gridPos.X - (self.gridPart.Size.X / 2),
		0,
		gridPos.Z - (self.gridPart.Size.Z / 2)
	);

	local gridOrigin = Vector3.new(
		cornerPos.X + grid.gridOffset.X,
		0,
		cornerPos.Z + grid.gridOffset.Z
	);


	local localX = pos.X - gridOrigin.X;
	local localZ = pos.Z - gridOrigin.Z;

	local incomingRotated = math.abs(currentCframe.XVector.Z) > math.abs(currentCframe.XVector.X);
	local halfX = (incomingRotated and objectSize.Z or objectSize.X) / 2;
	local halfZ = (incomingRotated and objectSize.X or objectSize.Z) / 2;

	localX = math.clamp(localX, halfX, gridSize.X - halfX);
	localZ = math.clamp(localZ, halfZ, gridSize.Z - halfZ);

	local snappedX = math.round(localX / self.gridSnap) * self.gridSnap;
	local snappedZ = math.round(localZ / self.gridSnap) * self.gridSnap;

	snappedX = math.clamp(snappedX, halfX, gridSize.X - halfX);
	snappedZ = math.clamp(snappedZ, halfZ, gridSize.Z - halfZ);

	return Vector3.new(
		gridOrigin.X + snappedX,
		self.gridPart.Position.Y + objectSize.Y / 2,
		gridOrigin.Z + snappedZ
	);
end

function PlaceablePreview:UpdatePreviewPosition(position: Vector3)
	local grid: Grid.Grid = self.grid;
	local cframe = self.previewPlaceable.CFrame;
	local objectSize = self.previewPlaceable.Placeable.BoundPart.Size
	local newPos = self:_snapToGrid(position, objectSize, grid.gridOffset, grid)
	self.previewPlaceable.CFrame = CFrame.new(newPos) * CFrame.Angles(cframe:ToEulerAnglesXYZ())
end

function PlaceablePreview:RotatePreview(multiplier: number)
	if self.previewPlaceable and self.previewPlaceable.CFrame then
		self.previewPlaceable.CFrame *= CFrame.Angles(0, (math.pi / 2) * multiplier, 0)
		self:UpdatePreviewPosition(self.previewPlaceable.CFrame.Position);
		print(`Rotated preview`);
	end
end

function PlaceablePreview:RemovePreviewPlaceable(): PreviewPlaceable?
	local oldPreviewPlaceable = self.previewPlaceable
	if oldPreviewPlaceable then
		oldPreviewPlaceable.Model:Destroy()
	end
	self.previewPlaceable = nil
	return oldPreviewPlaceable
end

function PlaceablePreview:SetPreviewPlaceable(placeable: Placeables.Placeable): Object?
	local existingCFrame = (self.previewPlaceable and self.previewPlaceable.CFrame);
	local newPreviewPlaceable = {
		Placeable = placeable;
		Model = placeable.Template:Clone(),
		Highlight = script.PreviewHighlight:Clone();
		CFrame = if existingCFrame then existingCFrame.Rotation else nil;
	} :: PreviewPlaceable;
	
	self:RemovePreviewPlaceable();
	self.previewPlaceable = newPreviewPlaceable;

	self:_updateCFrameToMouse();
	self.previewPlaceable.Model:PivotTo(self.previewPlaceable.CFrame or CFrame.new(0, 9e9, 0));
	
	newPreviewPlaceable.Highlight.Parent = self.previewPlaceable.Model;

	for _, i in self.previewPlaceable.Model:GetDescendants() do
		if i:IsA("BasePart") then
			i.CanCollide = false;
		end
	end
	
	self.previewPlaceable.Model.Parent = workspace.systems.BuildSystem;
end

function PlaceablePreview:GetPreviewPlaceable(placeable: Placeables.Placeable): PreviewPlaceable?
	return self.previewPlaceable;
end

function PlaceablePreview:SetGridSnap(gridSnap: number)
	self.gridSnap = gridSnap;
end

function PlaceablePreview:SetEnabled(state: boolean?)
	self.enabled = if state ~= nil then state else (not self.enabled);
	if self.previewPlaceable and self.previewPlaceable.CFrame then
		if self.enabled then
			self:_updateCFrameToMouse();
			self.previewPlaceable.Model:PivotTo(self.previewPlaceable.CFrame);
		else
			self.previewPlaceable.Model:PivotTo(CFrame.new(0, 9e9, 0));
		end
	end
end


return PlaceablePreview
