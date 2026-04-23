--!nonstrict
local UserInputService = game:GetService("UserInputService");
local RunService = game:GetService("RunService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local TweenService = game:GetService("TweenService");

local gridSnap = 2; -- in studs
local primaryGridSpacing = 4; -- in studs

local buildSystemFolder = workspace:WaitForChild("systems"):WaitForChild("BuildSystem");
local objectsFolder = workspace:WaitForChild("objects").placed;

local gridPart = buildSystemFolder:WaitForChild("GridPart");
gridPart.Parent = workspace;
gridPart.Transparency = 1;
local gridGui = script.GridGui :: SurfaceGui;
gridGui.Parent = gridPart;

local Grid = require(script.Grid);

local primaryGrid, subGrid, setGridVisible do
	primaryGrid = Grid.new(primaryGridSpacing, 15, gridGui);
	primaryGrid:Place(gridGui.GridContainer);
	subGrid = Grid.new(primaryGridSpacing // 2, 5, gridGui)
	subGrid:Place(gridGui.GridContainer);
	function setGridVisible(visible: boolean, tweenTime: number)
		coroutine.wrap(function()
			gridGui.Enabled = true;
			for _, grid in {primaryGrid, subGrid} do
				grid:SetVisible(visible, tweenTime);
			end
			task.wait(tweenTime);
			if not visible then
				gridGui.Enabled = false;
			end
		end)();
	end
end

local Util = require(script.Util);
local Placeables = require(script.PlaceablesClient).init();
local BuildTrackerClient = require(script.BuildTrackerClient).init();
local PlaceablePreview = require(script.PlaceablePreview).new(objectsFolder, gridSnap, primaryGrid, gridPart);
local DeletePreview = require(script.DeletePreview).new(objectsFolder, BuildTrackerClient);

local function quickHighlight(model: Model, fillColor: Color3)
	coroutine.wrap(function()
		local existingHighlight = model:FindFirstChildOfClass("Highlight");
		if existingHighlight and existingHighlight.Enabled then
			warn("Existing highlight found, disabling")
			existingHighlight.Enabled = false;
		end
		local highlight = Instance.new("Highlight");
		highlight.Parent = model;
		highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop;
		highlight.Adornee = model;
		highlight.FillColor = fillColor;
		highlight.OutlineColor = Color3.new(0.74902, 0.74902, 0.74902);
		Util.tweenCallbackAsync(0.65, function(t)
			if highlight.Parent then
				highlight.FillTransparency = Util.lerp(0.15, 1, t);
				highlight.OutlineTransparency = Util.lerp(0.1, 1, t);
			else
				return true;
			end
		end)
		if highlight.Parent then
			highlight:Destroy();
		end
		if existingHighlight then
			existingHighlight.Enabled = true;
		end
	end)();
end

local gridPartParams = Util.CreateParamsInclude({gridPart});
local function userPerformPlace()
	--[[ -- optional
	if not Util.RaycastMousePos(gridPartParams) then
		return;
	end
	]]
	local previewPlaceable = PlaceablePreview:GetPreviewPlaceable();
	if previewPlaceable and previewPlaceable.CFrame then
		local success, objectOrOverlap = BuildTrackerClient:PlacePlaceable(previewPlaceable.Placeable, previewPlaceable.CFrame);
		if success then
			script.PlaceObject.TimePosition = 0.01;
			script.PlaceObject:Play();
			print(`Placed object: {objectOrOverlap.Template.Name}`)

			local previewHighlight = previewPlaceable.Highlight;
			local pFt, pOt = previewHighlight.FillTransparency, previewHighlight.OutlineTransparency;
			Util.tweenCallbackAsync(0.65, function(t)
				if previewPlaceable then
					previewHighlight.FillTransparency = Util.lerp(0.15, pFt, t);
					previewHighlight.OutlineTransparency = Util.lerp(0.1, pOt, t);
				else
					return true;
				end
			end)
		else
			quickHighlight(objectOrOverlap.Model, Color3.new(1, 0.207843, 0.207843));
		end
	end
end

local objectsParams = Util.CreateParamsInclude({objectsFolder});
local function userPerformDelete()
	local objectCast = Util.RaycastMousePos(objectsParams);
	if objectCast then
		local objectModel = objectCast.Instance:FindFirstAncestorWhichIsA("Model");
		if objectModel then
			local object = BuildTrackerClient:GetObjectFromModel(objectModel);
			if object then
				BuildTrackerClient:DeleteObject(object);
			end 
		end
	end
end

local currentIndex = 0;
local function changePlaceableIndex(indexChange: number)
	currentIndex += indexChange;
	if currentIndex > #Placeables.Placeables then
		currentIndex = 1;
	elseif currentIndex < 1 then
		currentIndex = #Placeables.Placeables;
	end
	local debugPlaceable = Placeables.Placeables[currentIndex];
	PlaceablePreview:SetPreviewPlaceable(debugPlaceable);
end

local buildEnabled = false;
local deleteMode = false;

local modeText = script.modeText;
modeText.Parent = script.Parent;
local function tweenModeTest(showMode)
	if showMode then
		TweenService:Create(modeText, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, 0, 0.02, 0);
		}):Play();
	else
		TweenService:Create(modeText, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
			Position = UDim2.new(0.5, 0, -0.1, 0);
		}):Play();
	end
end

local function updateModes()
	if deleteMode then
		modeText.Text = "DELETE MODE";
		modeText.TextColor3 = Color3.fromRGB(199, 22, 22);
	else
		modeText.Text = "BUILD MODE";
		modeText.TextColor3 = Color3.fromRGB(206, 206, 206);
	end
	PlaceablePreview:SetEnabled((not deleteMode) and buildEnabled);
	DeletePreview:SetEnabled(deleteMode and buildEnabled);
end

UserInputService.InputBegan:Connect(function(inputObject, gpe)
	if not gpe then
		if buildEnabled then
			if inputObject.UserInputType == Enum.UserInputType.MouseButton1 and PlaceablePreview:GetPreviewPlaceable() then
				if deleteMode then
					userPerformDelete()
				else
					userPerformPlace();
				end
			elseif inputObject.UserInputType == Enum.UserInputType.Keyboard then
				if inputObject.KeyCode == Enum.KeyCode.F then
					deleteMode = not deleteMode;
					updateModes();
				elseif inputObject.KeyCode == Enum.KeyCode.E then
					PlaceablePreview:RotatePreview(-1);
				elseif inputObject.KeyCode == Enum.KeyCode.Q then
					PlaceablePreview:RotatePreview(1);
				elseif inputObject.KeyCode == Enum.KeyCode.C then
					changePlaceableIndex(1);
				elseif inputObject.KeyCode == Enum.KeyCode.Z then
					changePlaceableIndex(-1);
				end
			end
		end
		if inputObject.UserInputType == Enum.UserInputType.Keyboard then
			if inputObject.KeyCode == Enum.KeyCode.X then
				buildEnabled = not buildEnabled;
				setGridVisible(buildEnabled, 0.1);
				tweenModeTest(buildEnabled);
				updateModes();
				if buildEnabled then -- initial placeable
					if currentIndex == 0 then
						changePlaceableIndex(1);
					end
				else
					deleteMode = false;
				end
			end
		end
	end
end)

setGridVisible(buildEnabled, 0);