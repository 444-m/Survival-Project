local SmoothShiftLock = {}
SmoothShiftLock.__index = SmoothShiftLock;

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local WorkspaceService = game:GetService("Workspace");
local RunService = game:GetService("RunService");
local UserInputService = game:GetService("UserInputService");
local TweenService = game:GetService("TweenService");

local UtilsFolder = script:WaitForChild("MoreHere");

local Maid = require(UtilsFolder:WaitForChild("Maid"));
local Signal = require(UtilsFolder:WaitForChild("Signal"));
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents);
local Tools = require(ReplicatedStorage.Modules.Shared.Storage.Tools);

local LocalPlayer = Players.LocalPlayer;

local ToggleEvent = script:WaitForChild("ToggleShiftLock");
local EditConfig = script:WaitForChild("EditConfig");

local config = {
	["CHARACTER_SMOOTH_ROTATION"]   = true,
	["MANUALLY_TOGGLEABLE"]         = true,
	["CHARACTER_ROTATION_SPEED"]    = 5,
	["TRANSITION_SPRING_DAMPER"]    = 0.78,
	["CAMERA_TRANSITION_IN_SPEED"]  = 14,
	["CAMERA_TRANSITION_OUT_SPEED"] = 16,
	["LOCKED_CAMERA_OFFSET"]        = Vector3.new(2.05, 0.25, -1.1),
	["LOCKED_MOUSE_ICON"]           = "rbxasset://4727466026",
	["SHIFT_LOCK_KEYBINDS"]         = {Enum.KeyCode.LeftControl, Enum.KeyCode.RightControl},
	["AUTO_DISABLE_NO_TOOL"]        = true,
}

local ENABLED = false;

local maid = Maid.new();
local function toV3(v)
	if typeof(v) == "Vector3" then return v end
	if typeof(v) == "vector" then return Vector3.new(v.x, v.y, v.z) end
	if type(v) == "table" and v.X and v.Y and v.Z then return Vector3.new(v.X, v.Y, v.Z) end
	if type(v) == "table" and v.x and v.y and v.z then return Vector3.new(v.x, v.y, v.z) end
	return nil
end

function SmoothShiftLock:Init()
	local _managerMaid = Maid.new();
	SmoothShiftLock.ShiftLockToggled = Signal.new();

	if LocalPlayer.Character then
		coroutine.wrap(function()
			self:CharacterAdded();
		end)();
	end;

	_managerMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
		coroutine.wrap(function()
			self:CharacterAdded();
		end)();
	end));
end;

function SmoothShiftLock:CharacterAdded()
	local self = setmetatable({}, SmoothShiftLock);
	self.Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait();
	self.RootPart = self.Character:WaitForChild("HumanoidRootPart");
	self.Humanoid = self.Character:WaitForChild("Humanoid");
	self.Head = self.Character:WaitForChild("Head");
	self.Camera = WorkspaceService.CurrentCamera;
	self._connectionsMaid = Maid.new();
	self.camOffsetSpring = advents.spring.new(Vector3.new(0, 0, 0));
	self.camOffsetSpring.damper = config.TRANSITION_SPRING_DAMPER;
	self.DefaultOffset = config.LOCKED_CAMERA_OFFSET;
	self.CurrentLockOffset = self.DefaultOffset;
	self.ToolForced = false;

	self._connectionsMaid:GiveTask(UserInputService.InputBegan:Connect(function(input, gpe)
		if (gpe) or not config.MANUALLY_TOGGLEABLE then return end;

		for _, keyBind in pairs(config.SHIFT_LOCK_KEYBINDS) do
			if (input.KeyCode == keyBind) and (self.Humanoid and self.Humanoid.Health ~= 0) then
				self:ToggleShiftLock(not ENABLED);
			end;
		end;

		if input.UserInputType == Enum.UserInputType.MouseButton3 then
			self:ToggleShiftLock(not ENABLED);
		end
	end));

	self._connectionsMaid:GiveTask(RunService.RenderStepped:Connect(function()
		if self.Head.LocalTransparencyModifier > 0.6 then return end;

		local camCF = self.Camera.CoordinateFrame;
		local distance = (self.Head.Position - camCF.Position).magnitude;

		if (distance > 1) then	
			self.Camera.CFrame = (self.Camera.CFrame * CFrame.new(self.camOffsetSpring.position)); 

			if (ENABLED) and (UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter) then
				self:SetMouseState(ENABLED);
			end;
		end;
	end));

	self._connectionsMaid:GiveTask(ToggleEvent.Event:Connect(function(toggle: boolean)
		if (self.Humanoid and self.Humanoid.Health ~= 0) then
			self:ToggleShiftLock(toggle);
		end;
	end));

	self._connectionsMaid:GiveTask(EditConfig.Event:Connect(function(toChange, value)
		if config[toChange] ~= nil then
			config[toChange] = value;
		end;
	end));

	self._connectionsMaid:GiveTask(self.Humanoid.Died:Connect(function()
		self:CharacterDiedOrRemoved();
		return;
	end));

	self._connectionsMaid:GiveTask(LocalPlayer.CharacterRemoving:Connect(function()
		self:CharacterDiedOrRemoved();
		return;
	end));

	self._connectionsMaid:GiveTask(self.Character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			self:ApplyToolSettings(child)
		end
	end))
	self._connectionsMaid:GiveTask(self.Character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			self:RefreshToolState()
		end
	end))

	self:RefreshToolState()

	return self;
end;

function SmoothShiftLock:CharacterDiedOrRemoved()
	self:ToggleShiftLock(false);

	if self._connectionsMaid ~= nil then
		self._connectionsMaid:Destroy();
	end;

	maid:DoCleaning();
end;

function SmoothShiftLock:IsEnabled(): boolean
	return ENABLED;
end;

function SmoothShiftLock:SetMouseState(enable : boolean)
	UserInputService.MouseBehavior = (enable and Enum.MouseBehavior.LockCenter) or (Enum.MouseBehavior.Default);
end;

function SmoothShiftLock:SetMouseIcon(enable : boolean)
	UserInputService.MouseIcon = (enable and config.LOCKED_MOUSE_ICON :: string) or "";
	LocalPlayer:GetMouse().Icon = (config.LOCKED_MOUSE_ICON :: string) or "";
end;

function SmoothShiftLock:TransitionLockOffset(enable : boolean)
	local targetOffset = (self.CurrentLockOffset or self.DefaultOffset or config.LOCKED_CAMERA_OFFSET)
	if (enable) then
		self.camOffsetSpring.speed = config.CAMERA_TRANSITION_IN_SPEED;
		self.camOffsetSpring.target = targetOffset;
	else
		self.camOffsetSpring.speed = config.CAMERA_TRANSITION_OUT_SPEED;
		self.camOffsetSpring.target = Vector3.new(0, 0, 0);
	end;
end;

function SmoothShiftLock:ToggleShiftLock(enable : boolean)
	assert(typeof(enable) == typeof(false), "Enable value is not a boolean.");
	ENABLED = enable;

	self:SetMouseState(ENABLED);
	self:SetMouseIcon(ENABLED);
	self:TransitionLockOffset(ENABLED);

	if (ENABLED) then
		maid:GiveTask(RunService.RenderStepped:Connect(function(delta)
			if (self.Humanoid and self.RootPart) then 
				self.Humanoid.AutoRotate = not ENABLED;
			end;

			local ShiftSuspend = self.Character:GetAttribute("ShiftLockSuspend") == true
			if ShiftSuspend then return end

			local Rot = type(self.Character:GetAttribute("AutoRotate")) == "boolean" and self.Character:GetAttribute("AutoRotate") == false

			if (ENABLED) and not Rot then
				if not (self.Humanoid.Sit) and (config.CHARACTER_SMOOTH_ROTATION) then
					local x, y, z = self.Camera.CFrame:ToOrientation();
					self.RootPart.CFrame = self.RootPart.CFrame:Lerp(CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0), delta * 5 * config.CHARACTER_ROTATION_SPEED);
				elseif not (self.Humanoid.Sit) then
					local x, y, z = self.Camera.CFrame:ToOrientation();
					self.RootPart.CFrame = CFrame.new(self.RootPart.Position) * CFrame.Angles(0, y, 0);
				end;
			end;

			if not (ENABLED) then 
				maid:Destroy() end;
		end));
	end;

	SmoothShiftLock.ShiftLockToggled:Fire(ENABLED);

	return self;
end;

function SmoothShiftLock:ApplyToolSettings(tool: Tool?)
	local toolName = tool and tool.Name
	local conf = toolName and Tools[toolName]
	self.CurrentLockOffset = toV3(conf and conf.ShiftLockOffset) or self.DefaultOffset or config.LOCKED_CAMERA_OFFSET
	self.ToolForced = conf and conf.ForceShiftLock == true

	if ENABLED then
		self:TransitionLockOffset(true)
	elseif self.ToolForced then
		self:ToggleShiftLock(true)
	end
end

function SmoothShiftLock:RefreshToolState()
	local tool = self.Character and self.Character:FindFirstChildWhichIsA("Tool")
	if tool then
		self:ApplyToolSettings(tool)
		return
	end
	self.ToolForced = false
	self.CurrentLockOffset = self.DefaultOffset or config.LOCKED_CAMERA_OFFSET
	if config.AUTO_DISABLE_NO_TOOL and ENABLED and not config.MANUALLY_TOGGLEABLE then
		self:ToggleShiftLock(false)
	elseif ENABLED then
		self:TransitionLockOffset(true)
	end
end

return SmoothShiftLock;
