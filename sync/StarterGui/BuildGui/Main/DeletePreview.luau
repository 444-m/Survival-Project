local DeletePreview = {};

local ReplicatedStorage = game:GetService("ReplicatedStorage");
local UserInputService = game:GetService("UserInputService");

local Maid = require(ReplicatedStorage:WaitForChild("Modules").Client.Util.Maid);
local Util = require(script.Parent.Util);
local BuildSystemTypes = require(ReplicatedStorage.Modules.Shared.BuildSystem.BuildSystemTypes);

type Object = BuildSystemTypes.Object;

function DeletePreview.new(objectFolder: Folder, buildTrackerInst)
	local self = setmetatable({
		deleteHighlight = script.DeleteHighlight;
		enabled = false;
		
		objectParams = Util.CreateParamsInclude(objectFolder);
		buildTracker = buildTrackerInst;
		previewObject = nil :: Object?;
		maid = Maid.new();
	}, {
		__index = DeletePreview
	});
	
	self.maid:GiveTask(
		UserInputService.InputChanged:Connect(function(inputObject, gpe)
			if not gpe then
				if inputObject.UserInputType == Enum.UserInputType.MouseMovement then
					if self.enabled then
						self:_updateCFrameToMouse()
					end
				end
			end
		end)
	);
	
	return self;
end

function DeletePreview:_updateCFrameToMouse()
	local cast = Util.RaycastMousePos(self.objectParams);
	if cast then
		local objectModel = cast.Instance:FindFirstAncestorWhichIsA("Model");
		if objectModel then
			local object = self.buildTracker:GetObjectFromModel(objectModel);
			if object then
				self.previewObject = object;
				self.deleteHighlight.Adornee = objectModel;
			end
		end
	else
		self.previewObject = nil;
		self.deleteHighlight.Adornee = nil;
	end
end

function DeletePreview:SetEnabled(enabled)
	self.enabled = enabled;
	self.deleteHighlight.Adornee =
		if (enabled and self.previewObject and self.previewObject.Model) then 
		self.previewObject.Model 
		else nil;
	if enabled then
		self:_updateCFrameToMouse()
	end
end

return DeletePreview
