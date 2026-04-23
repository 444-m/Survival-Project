--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)
local BlinkServer = require(game.ReplicatedStorage.Packages.Shared.Blink.Server)
local movementConfig = require(ReplicatedStorage.Modules.Client.Controllers.Movement.configs)

local numberKeys = {}
local boolKeys = {}
local allKeys = {}

for key, value in next, (movementConfig :: any) do
	local valueType = type(value)
	if valueType == "number" or valueType == "boolean" then
		table.insert(allKeys, key)
	end
	if valueType == "number" then
		table.insert(numberKeys, key)
	elseif valueType == "boolean" then
		table.insert(boolKeys, key)
	end
end

table.sort(numberKeys)
table.sort(boolKeys)
table.sort(allKeys)

local numberKeyArg = conch.register_type("config-key-number", conch.args.enum_new(numberKeys))
local boolKeyArg = conch.register_type("config-key-bool", conch.args.enum_new(boolKeys))
local allKeyArg = conch.register_type("config-key", conch.args.enum_new(allKeys))

conch.register("setconfig", {
	description = "Sets a number movement config value for one player at runtime.";
	permissions = {"set-config"};
	arguments = function()
		return
			conch.args.player("player", "the player to change the config for"),
			numberKeyArg("key", "the config key to change"),
		conch.args.number("value", "the value to set")
	end;
	callback = function(player: Player, key: string, value: number)
		BlinkServer.MovementConfigSync.Fire(player, {
			Key = key;
			Reset = false;
			IsBool = false;
			NumberValue = value;
			BoolValue = nil;
		})
		print(`{player.Name} {key} set to {value}`)
	end;
})

conch.register("setconfigbool", {
	description = "Sets a boolean movement config value for one player at runtime.";
	permissions = {"set-config"};
	arguments = function()
		return
			conch.args.player("player", "the player to change the config for"),
			boolKeyArg("key", "the config key to change"),
		conch.args.boolean("value", "the value to set")
	end;
	callback = function(player: Player, key: string, value: boolean)
		BlinkServer.MovementConfigSync.Fire(player, {
			Key = key;
			Reset = false;
			IsBool = true;
			NumberValue = nil;
			BoolValue = value;
		})
		print(`{player.Name} {key} set to {value}`)
	end;
})

conch.register("setconfigall", {
	description = "Sets a number movement config value for every player at runtime.";
	permissions = {"set-config"};
	arguments = function()
		return
			numberKeyArg("key", "the config key to change"),
		conch.args.number("value", "the value to set")
	end;
	callback = function(key: string, value: number)
		BlinkServer.MovementConfigSync.FireAll({
			Key = key;
			Reset = false;
			IsBool = false;
			NumberValue = value;
			BoolValue = nil;
		})
		print(`all players {key} set to {value}`)
	end;
})

conch.register("setconfigboolall", {
	description = "Sets a boolean movement config value for every player at runtime.";
	permissions = {"set-config"};
	arguments = function()
		return
			boolKeyArg("key", "the config key to change"),
		conch.args.boolean("value", "the value to set")
	end;
	callback = function(key: string, value: boolean)
		BlinkServer.MovementConfigSync.FireAll({
			Key = key;
			Reset = false;
			IsBool = true;
			NumberValue = nil;
			BoolValue = value;
		})
		print(`all players {key} set to {value}`)
	end;
})

conch.register("getconfig", {
	description = "Gets the default value of a movement config key for reference.";
	permissions = {"set-config"};
	arguments = function()
		return
			conch.args.player("player", "the player whose config you are checking"),
			allKeyArg("key", "the config key to read")
	end;
	callback = function(player: Player, key: string)
		print(`{player.Name} {key} default is {tostring((movementConfig :: any)[key])}; runtime override is client-side`)
	end;
})

conch.register("resetconfig", {
	description = "Resets a player's runtime config overrides back to defaults.";
	permissions = {"set-config"};
	arguments = function()
		return conch.args.player("player", "the player to reset")
	end;
	callback = function(player: Player)
		BlinkServer.MovementConfigSync.Fire(player, {
			Key = "__reset__";
			Reset = true;
			IsBool = true;
			NumberValue = nil;
			BoolValue = true;
		})
		print(`{player.Name} config reset to defaults`)
	end;
})

conch.register("resetconfigall", {
	description = "Resets all runtime config overrides back to defaults for every player.";
	permissions = {"set-config"};
	arguments = function() return end;
	callback = function()
		BlinkServer.MovementConfigSync.FireAll({
			Key = "__reset__";
			Reset = true;
			IsBool = true;
			NumberValue = nil;
			BoolValue = true;
		})
		print("all player configs reset to defaults")
	end;
})

return nil
