local Util = {};

local UserInputService = game:GetService("UserInputService")

function Util.quadOut<T>(t: T): T
	return 1 - (1 - t) * (1 - t);
end

function Util.lerp<T>(a: T, b: T, t: T): T
	return a + (b - a) * t;
end

function Util.CreateParamsInclude(include: Instance | {Instance})
	local params = RaycastParams.new();
	params.FilterType = Enum.RaycastFilterType.Include;
	params.FilterDescendantsInstances = if typeof(include) == "Instance" then {include} else include;
	return params;
end

function Util.RaycastMousePos(rayCastParams: RaycastParams?, dist: number?): RaycastResult?
	local mousePos = UserInputService:GetMouseLocation();
	local Ray = workspace.CurrentCamera:ScreenPointToRay(mousePos.X, mousePos.Y);
	local Raycast = workspace:Raycast(Ray.Origin, Ray.Direction * (dist or 1000), rayCastParams);
	return Raycast;
end

function Util.tweenCallbackAsync(length: number, callback: (number) -> (boolean))
	if length == 0 then
		callback(1);
		return;
	end
	local length = length or 0.5;
	local t = length;
	while t > 0 do
		local k = Util.quadOut((length - t) / length);
		if callback(k) then
			return;
		end
		t -= task.wait();
	end
end

return Util;