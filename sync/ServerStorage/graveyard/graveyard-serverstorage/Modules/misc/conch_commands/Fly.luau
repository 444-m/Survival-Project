--!strict
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)
local BlinkServer = require(game.ReplicatedStorage.Packages.Shared.Blink.Server)

local flying = {} :: {[Player]: boolean}

conch.register("fly", {
	description = "Toggles fly for a player.";
	permissions = {"fly"};
	arguments = function()
		return conch.args.player("player", "the player to toggle fly for")
	end;
	callback = function(player: Player)
		flying[player] = not flying[player]
		BlinkServer.FlyToggle.Fire(player, {
			Enabled = flying[player];
		})
		print(`{player.Name} fly: {flying[player]}`)
	end;
})

conch.register("unfly", {
	description = "Removes fly from a player.";
	permissions = {"fly"};
	arguments = function()
		return conch.args.player("player", "the player to remove fly from")
	end;
	callback = function(player: Player)
		if not flying[player] then return end
		flying[player] = false
		BlinkServer.FlyToggle.Fire(player, {
			Enabled = false;
		})
		print(`{player.Name} fly removed`)
	end;
})

game:GetService("Players").PlayerRemoving:Connect(function(player)
	flying[player] = nil
end)

return nil
