local Grid = {};

local Util = require(script.Parent.Util);

local gridLineTemplate = script.GridLine:Clone();

export type Grid = {
	gridLines: {Frame};
	gridSpacing: number;
	gridThickness: number;
	surfaceGui: SurfaceGui;
	gridOffset: Vector3; -- offset in studs
	isVisible: boolean;
};

function Grid.new(
	gridSpacing: number, -- in studs
	gridThickness: number, -- in pixels
	surfaceGui: SurfaceGui
): Grid
	local self = setmetatable({
		gridLines = {} :: {Frame};
		gridSpacing = gridSpacing;
		gridThickness = gridThickness;
		surfaceGui = surfaceGui;
		gridOffset = nil;
		isVisible = true;
	}, {
		__index = Grid;
	});
	return self;
end

function Grid:Place(Container: Frame): Vector3
	local function createGridLine(position, isHorizontal)
		local line = gridLineTemplate:Clone();
		line.Position = position;
		line.Parent = Container;
		if isHorizontal then
			line.Size = UDim2.new(1, 0, 0, self.gridThickness);
			line.AnchorPoint = Vector2.new(0, 0.5);
		else
			line.Size = UDim2.new(0, self.gridThickness, 1, 0);
			line.AnchorPoint = Vector2.new(0.5, 0);
		end
		table.insert(self.gridLines, line);
	end
	
	local x, z;

	local pixelsPerStud = self.surfaceGui.PixelsPerStud;
	for i = 1, math.ceil(self.surfaceGui.AbsoluteSize.X / pixelsPerStud), self.gridSpacing do
		createGridLine(UDim2.new(0, i * pixelsPerStud, 0, 0), false);
		if not x then
			x = i;
		end
	end
	for i = 1, math.ceil(self.surfaceGui.AbsoluteSize.Y / pixelsPerStud), self.gridSpacing do
		createGridLine(UDim2.new(0, 0, 0, i * pixelsPerStud), true);
		if not z then
			z = i;
		end
	end
	-- returns grid corner in object space
	self.gridOffset = Vector3.new(x, 0, z);
end

function Grid:SetVisible(visible: boolean, tweenTime: number)
	coroutine.wrap(function()
		self.isVisible = visible;
		Util.tweenCallbackAsync(tweenTime or 0.5, function(tweenTime)
			if self.isVisible ~= visible then
				return true;
			end
			for _, line in pairs(self.gridLines) do
				if line:IsA("Frame") then
					line.BackgroundTransparency = Util.lerp(
						if visible then 1 else 0, 
						if visible then 0 else 1,
						tweenTime
					);
				end
			end
		end)
	end)();
end

return Grid