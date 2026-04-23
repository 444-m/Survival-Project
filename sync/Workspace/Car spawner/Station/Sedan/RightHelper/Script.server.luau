script.Parent.Transparency = 2
script.Parent.Touched:connect(function(otherPart)
	local player = game.Players:GetPlayerFromCharacter(otherPart.Parent)
	if player then
	end
end)