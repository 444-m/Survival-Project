------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- CloneTrooper1019, 2020 
-- Util Module
------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

local Util = {}
local RunService = game:GetService("RunService")

function Util:Round(number, factor)
	local mult = 10 ^ (factor or 0)
	return math.floor((number * mult) + 0.5) / mult
end

function Util:RoundNearestInterval(number, factor)
	return Util:Round(number / factor) * factor
end

function Util:StepTowards(value, goal, rate)
	if math.abs(value - goal) < rate then
		return goal
	elseif value > goal then
		return value - rate
	elseif value < goal then
		return value + rate
	end
end

function Util:PromiseChild(object, name, andThen, ...)
	task.spawn(function (...)
		local child = object:WaitForChild(name, 10)
		
		if child then
			andThen(child, ...)
		end
	end, ...)
end

function Util:PromiseValue(object, prop, andThen, ...)
	task.spawn(function (...)
		local timeOut = os.clock() + 10
		
		while not object[prop] do
			local now = os.clock()
			
			if (timeOut - now) < 0 then
				return
			end
			
			task.wait()
		end
		
		andThen(object[prop], ...)
	end, ...)
end

return Util

------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------