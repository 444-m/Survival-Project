local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)

conch.register("re", {
	description = "Reloads the player's character.";
	permissions = {"re"};
	
	arguments = function()
		return
		conch.args.player("player", "the player to reload")
	end;
	
	callback = function(player)
		local character = player.Character
		local previousPosition = character and character:GetPivot()

		local connection
		connection = player.CharacterAdded:Connect(function(newCharacter)
			connection:Disconnect()
			if previousPosition then
				newCharacter:PivotTo(previousPosition)
			end
		end)

		player:LoadCharacterAsync()
	end;
})

return nil