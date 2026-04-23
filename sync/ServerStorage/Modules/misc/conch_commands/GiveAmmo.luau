--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
local GunManagerServer = require(ServerStorage.Modules.Systems.Guns.GunManagerServer)

conch.register("setreserve", {
	description = "Set a player's reserve ammo for a gun";
	permissions = {"setreserve"};
	arguments = function()
		return conch.args.player("player", "target player"),
		conch.args.string("gun", "gun name"),
		conch.args.number("amount", "reserve amount")
	end;
	callback = function(player: Player, gun: string, amount: number)
		local mgr = GunManagerServer.get(player)
		if not mgr then return end
		mgr:SetReserve(gun, amount)
	end;
})

conch.register("setammo", {
	description = "Set a player's current magazine ammo for a gun";
	permissions = {"setammo"};
	arguments = function()
		return conch.args.player("player", "target player"),
		conch.args.string("gun", "gun name"),
		conch.args.number("amount", "ammo amount")
	end;
	callback = function(player: Player, gun: string, amount: number)
		local mgr = GunManagerServer.get(player)
		if not mgr then return end
		mgr:SetAmmo(gun, amount)
	end;
})

return nil