--!strict
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)
local BlinkClient = require(game.ReplicatedStorage.Packages.Shared.Blink.Client)
local movementConfig = require("@game/ReplicatedStorage/Modules/Client/Controllers/Movement/configs")

local numberKeys = {}
local boolKeys = {}
local allKeys = {}

for k, v in next, (movementConfig :: any) do
	local valueType = type(v)
	if valueType == "number" or valueType == "boolean" then
		table.insert(allKeys, k)
	end
	if valueType == "number" then
		table.insert(numberKeys, k)
	elseif valueType == "boolean" then
		table.insert(boolKeys, k)
	end
end

table.sort(allKeys)
table.sort(numberKeys)
table.sort(boolKeys)

local numberKeyArg = conch.register_type("config-key-number", conch.args.enum_new(numberKeys))
local boolKeyArg = conch.register_type("config-key-bool", conch.args.enum_new(boolKeys))
local allKeyArg = conch.register_type("config-key", conch.args.enum_new(allKeys))

BlinkClient.MovementConfigSync.On(function(payload)
	if payload.Reset or payload.Key == "__reset__" then
		if movementConfig.ResetBase then
			movementConfig.ResetBase()
		else
			for k, v in next, (movementConfig :: any) do
				if type(v) == "number" or type(v) == "boolean" then
					(movementConfig :: any)[k] = v
				end
			end
		end
		return
	end

	if movementConfig.SetBaseValue then
		movementConfig.SetBaseValue(payload.Key, if payload.IsBool then payload.BoolValue == true else payload.NumberValue)
	else
		(movementConfig :: any)[payload.Key] = if payload.IsBool then payload.BoolValue == true else payload.NumberValue
	end
end)

return nil
