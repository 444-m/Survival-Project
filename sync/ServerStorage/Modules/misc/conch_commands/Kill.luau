local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)

conch.register("kill", {
	description = "Kill the target player";
	permissions = {"kill"};
	
	arguments = function()
		return
		conch.args.player("target player", "the player to kill")	
	end;
	
	callback = function(player)
		local character = player.Character
		if not character then
			return
		end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		
		humanoid.Health = 0
	end;
})

return 0