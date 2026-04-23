local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local PlayerManagers = ServerStorage.Modules.Managers.Player
local PlayerManagerServer = require(PlayerManagers.PlayerManager)

Players.PlayerAdded:Connect(@native function(Player)
	local PlayerManager = PlayerManagerServer.new(Player)
end)

Players.PlayerRemoving:Connect(@native function(Player)
	local Manager = PlayerManagerServer.get(Player.UserId)
	if Manager then 
		Manager:Cleanup()
	end
end)

for _,Player in next, Players:GetPlayers() do
	task.spawn(function()
		local Manager = PlayerManagerServer.get(Player.UserId)
		if not Manager then
			local PlayerManager = PlayerManagerServer.new(Player)
		end
	end)
end