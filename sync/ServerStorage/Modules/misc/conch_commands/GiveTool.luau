--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
local ToolManagerServer = require(ServerStorage.Modules.Managers.Player.ToolManagerServer)

conch.register("givetool", {
	description = "Give a tool to a player (into hotbar/inventory)";
	permissions = {"givetool"};
	arguments = function()
		return conch.args.player("player", "target player"),
		conch.args.string("tool", "tool name in storage.tools"),
		conch.args.number("qty", "quantity")
	end;
	callback = function(player: Player, toolName: string, qty: number)
		if not toolName or toolName == "" then return end
		ToolManagerServer.AddToInventory(player, toolName, nil, qty)
	end;
})

return nil
