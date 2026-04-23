--!strict
local players = game:GetService("Players")
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)
local BlinkServer = require(game.ReplicatedStorage.Packages.Shared.Blink.Server)

local noclipping = {} :: {[Player]: boolean}

conch.register("noclip", {
	description = "Toggles noclip for a player.";
	permissions = {"noclip"};
	arguments = function()
		return conch.args.player("player", "the player to toggle noclip for")
	end;
	callback = function(player: Player)
		noclipping[player] = not noclipping[player]
		BlinkServer.NoclipToggle.Fire(player, {
			Enabled = noclipping[player];
		})
	end;
})

conch.register("clip", {
	description = "Removes noclip from a player.";
	permissions = {"clip"};
	arguments = function()
		return conch.args.player("player", "the player to remove noclip from")
	end;
	callback = function(player: Player)
		if not noclipping[player] then return end
		noclipping[player] = false
		BlinkServer.NoclipToggle.Fire(player, {
			Enabled = false;
		})
	end;
})

players.PlayerRemoving:Connect(function(player)
	noclipping[player] = nil
end)

return nil
