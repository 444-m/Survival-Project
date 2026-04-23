local Lighting = game:GetService("Lighting");

local secondsInADay = 500;

while true do
	local delta = task.wait();
	local clockTime = Lighting.ClockTime + ((delta * 24) / secondsInADay);
	Lighting.ClockTime = clockTime % 24;
end