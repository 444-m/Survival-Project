local Globals = {}

Globals.MarkAsNewPlayer = false
Globals.MaxLevel = 100;

Globals.GroupId = 36007644
Globals.MinAdminRank = 254
Globals.SuperRankId = 254

Globals.conch = {
	roleMap = {
		[254] = {role = "super-user"};
		[255] = {role = "super-user"};
	}
}

Globals.BuildContainer = workspace:WaitForChild("objects")
Globals.MapContainer = Globals.BuildContainer:WaitForChild("map")
Globals.LobbyContainer = Globals.MapContainer:WaitForChild("lobby")

return Globals