--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
local Trace = require(ServerStorage.Modules.Systems.misc.adm.trace)
local PlayerHandlerModule = require(ServerStorage.Modules.Handlers.PlayerHandler)

local numberKeys = {}
local boolKeys = {}
local allKeys = {}

for _, key in next, Trace.GetConfigKeys() do
	local value = Trace.GetConfig(key)
	table.insert(allKeys, key)
	if type(value) == "number" then
		table.insert(numberKeys, key)
	elseif type(value) == "boolean" then
		table.insert(boolKeys, key)
	end
end

table.sort(numberKeys)
table.sort(boolKeys)
table.sort(allKeys)

local numberKeyArg = conch.register_type("trace-key-number", conch.args.enum_new(numberKeys))
local boolKeyArg = conch.register_type("trace-key-bool", conch.args.enum_new(boolKeys))
local allKeyArg = conch.register_type("trace-key", conch.args.enum_new(allKeys))

local function refreshPlayer(player: Player)
	local handler = PlayerHandlerModule.get(player)
	if not handler then
		return
	end

	if Trace.IsEnabled(player) and handler.Character then
		handler:ApplyTrace(handler.Character)
	else
		handler:ClearTrace()
	end
end

conch.register("trace", {
	description = "Gives trace to a player.";
	permissions = {"trace"};
	arguments = function()
		return conch.args.player("player", "the player to give trace to")
	end;
	callback = function(player: Player)
		Trace.SetEnabled(player, true)
		refreshPlayer(player)
		print(`{player.Name} trace enabled`)
	end;
})

conch.register("untrace", {
	description = "Removes trace from a player.";
	permissions = {"trace"};
	arguments = function()
		return conch.args.player("player", "the player to remove trace from")
	end;
	callback = function(player: Player)
		Trace.SetEnabled(player, false)
		refreshPlayer(player)
		print(`{player.Name} trace disabled`)
	end;
})

conch.register("settrace", {
	description = "Sets a numeric trace config value at runtime.";
	permissions = {"trace"};
	arguments = function()
		return
			numberKeyArg("key", "the trace config key to change"),
			conch.args.number("value", "the numeric value to set")
	end;
	callback = function(key: string, value: number)
		if not Trace.SetConfig(key, value) then
			error(`unknown trace config key {key}`)
		end
		print(`trace {key} set to {value}`)
	end;
})

conch.register("settracebool", {
	description = "Sets a boolean trace config value at runtime.";
	permissions = {"trace"};
	arguments = function()
		return
			boolKeyArg("key", "the trace config key to change"),
			conch.args.boolean("value", "the boolean value to set")
	end;
	callback = function(key: string, value: boolean)
		if not Trace.SetConfig(key, value) then
			error(`unknown trace config key {key}`)
		end
		print(`trace {key} set to {value}`)
	end;
})

conch.register("gettrace", {
	description = "Gets a trace config value.";
	permissions = {"trace"};
	arguments = function()
		return allKeyArg("key", "the trace config key to read")
	end;
	callback = function(key: string)
		print(`trace {key} = {tostring(Trace.GetConfig(key))}`)
	end;
})

return nil
