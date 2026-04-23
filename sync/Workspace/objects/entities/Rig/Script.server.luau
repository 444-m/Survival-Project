const respawnTime = 1
local template = script.Parent:Clone()

script.Parent.Humanoid.Died:Once(function()
	task.wait(respawnTime)
	template.Parent = script.Parent.Parent
	template:MakeJoints()
	template.Humanoid.MaxHealth = template.Humanoid.Health
	script.Parent:Destroy()
end)