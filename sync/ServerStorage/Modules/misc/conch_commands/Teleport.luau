--!strict
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)

conch.register("tp", {
	description = "Teleports a player to another player.";
	permissions = {"teleport"};
	arguments = function()
		return
			conch.args.player("from", "the player to teleport"),
		conch.args.player("to", "the destination player")
	end;
	callback = function(from: Player, to: Player)
		local fromChar = from.Character
		local toChar = to.Character

		if not fromChar then error(`{from.Name} has no character`) end
		if not toChar then error(`{to.Name} has no character`) end

		fromChar:PivotTo(toChar:GetPivot())
	end;
})

return nil