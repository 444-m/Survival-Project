--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
local Leveling = require(ServerStorage.Modules.Systems.Leveling)

local function logInfo(message: string)
	conch.log("info", message)
end

local function getLeveler(player: Player)
	local leveler = Leveling.GetLeveler(player)
	if leveler then
		return leveler
	end

	return Leveling.AddLeveler(player)
end

local function setPlayerLevel(player: Player, level: number, xp: number?, brute: boolean?)
	local targetXP = xp
	if type(targetXP) ~= "number" then
		targetXP = 0
	end

	local leveler = getLeveler(player)
	Leveling.SetLevel(player, level, targetXP or 0, brute)

	if brute then
		logInfo(`{player.Name} brute level set to {leveler.level} with {leveler.xp} xp`)
	else
		logInfo(`{player.Name} level set to {leveler.level} with {leveler.xp} xp`)
	end
end

local function givePlayerXP(player: Player, amount: number)
	local roundedAmount = math.floor(amount + .5)
	if roundedAmount <= 0 then
		error("xp amount must be greater than 0")
	end

	getLeveler(player)
	Leveling.AddXP(player, roundedAmount)

	logInfo(`gave {roundedAmount} xp to {player.Name}`)
end

conch.register("level", {
	description = "Sets a player's level or gives them xp.";
	permissions = {"level"};
	arguments = function()
		return conch.args.overload({
			{
				description = "Sets a player's level. xp defaults to 0.";
				arguments = {
					conch.args.literal("set", "action", "set a player's level"),
					conch.args.player("player", "the player to set"),
					conch.args.number("level", "the level to set"),
					conch.args.optional(conch.args.number("xp", "optional xp to set on that level")),
				},
			},
			{
				description = "Force sets a player's level and bypasses the max level cap. xp defaults to 0.";
				arguments = {
					conch.args.literal("brute", "action", "force set a player's level"),
					conch.args.player("player", "the player to set"),
					conch.args.number("level", "the level to set"),
					conch.args.optional(conch.args.number("xp", "optional xp to set on that level")),
				},
			},
			{
				description = "Gives xp to a player.";
				arguments = {
					conch.args.literal("xp", "action", "give xp to a player"),
					conch.args.player("player", "the player to give xp to"),
					conch.args.number("amount", "the xp amount to give"),
				},
			},
		})
	end;
	callback = function(action: string, player: Player, value: number, extraValue: number?)
		if action == "set" then
			setPlayerLevel(player, value, extraValue, false)
			return
		end

		if action == "brute" then
			setPlayerLevel(player, value, extraValue, true)
			return
		end

		if action == "xp" then
			givePlayerXP(player, value)
			return
		end

		error(`unknown level action "{action}"`)
	end;
})

return nil
