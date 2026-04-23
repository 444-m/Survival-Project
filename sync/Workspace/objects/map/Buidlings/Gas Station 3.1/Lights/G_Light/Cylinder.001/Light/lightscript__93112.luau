local lightPart = script.Parent.Parent;

while true do
	local timeOfDay = game.Lighting:GetMinutesAfterMidnight() / 60
	local isNight = timeOfDay >= 18 or timeOfDay < 6
	if isNight then
		lightPart.Color = Color3.fromRGB(231, 231, 236);
		lightPart.Material = Enum.Material.Neon;
		local Light = script.Parent
		Light.Enabled = true;
		local tsinfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0)
		Light.Brightness = 1.5
		Light.Range = 36
		local ts = game:GetService("TweenService")
		local tween = ts:Create(Light, tsinfo, { Brightness = 0, Range = 0})
		tween:Play()
		task.wait(0.5)
		local Light = script.Parent
		local tsinfo = TweenInfo.new(0.7, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0)
		Light.Brightness = 1.5
		Light.Range = 36
		local ts = game:GetService("TweenService")
		local tween = ts:Create(Light, tsinfo, { Brightness = 2,Range = 33})
		tween:Play()
	else -- disable lights
		lightPart.Color = Color3.fromRGB(152, 152, 152);
		lightPart.Material = Enum.Material.SmoothPlastic;
		local Light = script.Parent
		Light.Enabled = false;
	end

	task.wait(math.random(3, 7))
end

