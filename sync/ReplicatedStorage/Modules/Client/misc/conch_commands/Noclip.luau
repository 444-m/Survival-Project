--!strict
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local BlinkClient = require(game.ReplicatedStorage.Packages.Shared.Blink.Client)

local player = players.LocalPlayer

local connection: RBXScriptConnection?

local function startNoclip()
	local character = player.Character
	if not character then return end

	connection = runService.Stepped:Connect(function()
		local char = player.Character
		if not char then return end
		for _, part in next, char:GetDescendants() do
			if part:IsA("BasePart") and part.CanCollide then
				part.CanCollide = false
			end
		end
	end)
end

local function stopNoclip()
	if connection then
		connection:Disconnect()
		connection = nil
	end

	local character = player.Character
	if not character then return end

	for _, part in next, character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CanCollide = true
		end
	end
end

BlinkClient.NoclipToggle.On(function(payload)
	if payload.Enabled then
		startNoclip()
	else
		stopNoclip()
	end
end)

player.CharacterAdded:Connect(function()
	stopNoclip()
end)

return nil
