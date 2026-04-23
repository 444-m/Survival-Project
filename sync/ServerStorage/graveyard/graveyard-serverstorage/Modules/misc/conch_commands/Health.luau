local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)

conch.register("health", {
	description = "Sets the health of the target player(s).";
	permissions = {"set-health"};
	
	arguments = function()
		return 
		conch.args.player("player", "the player to set health of"),
		conch.args.number("health", "the health to set the player to")
	end;
	
	callback = function(player, health)
		if not player then return end
		
		local character = player.Character
		if not character then return end
		
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid then return end
		
		if health > humanoid.MaxHealth then
			humanoid.MaxHealth = health
		end
		
		humanoid.Health = health
	end;
})

return nil