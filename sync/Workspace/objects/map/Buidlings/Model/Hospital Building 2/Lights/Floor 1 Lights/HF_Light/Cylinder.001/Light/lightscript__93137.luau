while true do
	local Light = script.Parent
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
	task.wait(math.random(3, 7))
end

