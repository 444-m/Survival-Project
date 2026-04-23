local Light = script.Parent.Light.Light.Attachment.SpotLight;
local LightParts = script.Parent.LightParts;

local TweenService = game:GetService("TweenService");
local tweenInfo = TweenInfo.new(1 / 20, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, 1, true, 0);

local function flicker()
	TweenService:Create(Light, tweenInfo, { Brightness = 0, Range = 0}):Play();
	for _, part in LightParts:GetChildren() do
		TweenService:Create(part, tweenInfo, { Transparency = 1}):Play();
		TweenService:Create(part.Attachment.Glow, tweenInfo, { Brightness = 0}):Play();
	end
end

while true do
	flicker()
	task.wait(math.random(6, 30) / 10);
	flicker()
	task.wait(math.random(3, 15));
end

