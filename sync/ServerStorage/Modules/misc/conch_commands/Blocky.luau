--!strict
local players = game:GetService("Players")
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)

conch.register("blocky", {
	description = "Toggles blocky character for a player.";
	permissions = {"blocky"};
	arguments = function()
		return conch.args.player("player", "the player to toggle blocky for")
	end;
	callback = function(player: Player)
		local desc = players:GetHumanoidDescriptionFromUserId(player.UserId)
		desc.Torso = 0
		desc.LeftArm = 0
		desc.RightArm = 0
		desc.LeftLeg = 0
		desc.RightLeg = 0

		local character = player.Character
		if not character then return end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end

		humanoid:ApplyDescription(desc)
	end;
})

players.PlayerRemoving:Connect(function(player)
end)

return nil