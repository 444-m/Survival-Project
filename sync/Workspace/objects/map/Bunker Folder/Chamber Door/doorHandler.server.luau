local doorPart = script.Parent.DoorPart;
local door = doorPart.Parent;
local proximityPrompt = doorPart.Handle.ProximityPrompt :: ProximityPrompt;

local speed = 0.25;

local function quadInOut(t)
	if t < 0.5 then
		return 2 * t * t;
	else
		return 1 - math.pow(-2 * t + 2, 2) / 2;
	end;
end

local doorOpen = false;
local startCf = doorPart:GetPivot();
proximityPrompt.Triggered:Connect(function()
	doorOpen = not doorOpen;
	proximityPrompt.Enabled = false;
	if doorOpen then
		doorPart.main_door["Door Open"]:Play();
		local t = 0
		while t < 1 do
			t += task.wait() * speed;
			local a = quadInOut(t);
			doorPart:PivotTo(startCf * CFrame.Angles(0, a * math.pi * (3 / 5), 0))
		end
		proximityPrompt.ActionText = "Close";
	else
		doorPart.main_door["Door Close"]:Play();
		local t = 1;
		while t > 0 do
			t -= task.wait() * speed;
			local a = quadInOut(t);
			doorPart:PivotTo(startCf * CFrame.Angles(0, a * math.pi * (3 / 5), 0))
		end
		proximityPrompt.ActionText = "Open";
	end
	proximityPrompt.Enabled = true;
end);