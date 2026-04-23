system = script.Parent
model = system.Station --
backup = model:Clone()
regen = system.Regen

function checkRegen()
	if regen.Value == 1 then
		wait(1)
		model = backup:Clone()
		model.Parent = system
		model:MakeJoints()
	end
end

regen.Changed:connect(checkRegen)

-- Green_Bromine wuz here