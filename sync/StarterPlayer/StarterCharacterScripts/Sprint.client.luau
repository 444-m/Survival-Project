local UserInputService = game:GetService("UserInputService");
local RunService = game:GetService("RunService");

local character = script.Parent;

local normalSpeed = 11;
local sprintSpeed = 18;
local isSprinting = false;

local interpolationDuration = 0.3;
local elapsed = 0;
local startSpeed = normalSpeed;
local targetSpeed = normalSpeed;

local function quadInOut(t)
	if t < 0.5 then
		return 2 * t * t;
	else
		return 1 - math.pow(-2 * t + 2, 2) / 2;
	end;
end;

RunService.Heartbeat:Connect(function(dt)
	local humanoid = character:FindFirstChild("Humanoid");
	if not humanoid then return end;

	if elapsed < interpolationDuration then
		elapsed = math.min(elapsed + dt, interpolationDuration);
		local t = elapsed / interpolationDuration;
		local easedT = quadInOut(t);
		humanoid.WalkSpeed = startSpeed + (targetSpeed - startSpeed) * easedT;
	end;
end);

local function setTargetSpeed(speed)
	local humanoid = character:FindFirstChild("Humanoid");
	if not humanoid then return end;

	startSpeed = humanoid.WalkSpeed;
	targetSpeed = speed;
	elapsed = 0;
end;

UserInputService.InputBegan:Connect(function(key)
	if key.KeyCode == Enum.KeyCode.LeftShift or key.KeyCode == Enum.KeyCode.RightShift then
		isSprinting = true;
		setTargetSpeed(sprintSpeed);
	end;
end);

UserInputService.InputEnded:Connect(function(key)
	if key.KeyCode == Enum.KeyCode.LeftShift or key.KeyCode == Enum.KeyCode.RightShift then
		isSprinting = false;
		setTargetSpeed(normalSpeed);
	end;
end);