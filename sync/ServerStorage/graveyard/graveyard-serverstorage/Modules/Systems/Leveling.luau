--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local Signal = require(SharedPackages.Signal)
local Janitor = require(SharedPackages.Janitor)
local SharedLeveling = require(ReplicatedStorage.Modules.Shared.Systems.Leveling)

local Leveling = {}
Leveling.MaxLevel = SharedLeveling.MaxLevel
local BATCH_INTERVAL = .05
local MIN_BATCH_INTERVAL = .008
local SOFT_BATCHED_LEVELUPS = 24
local MAX_BATCHED_LEVELUPS = 220
local FAST_FORWARD_XP_THRESHOLD = 10000000000
local MAX_OVERCAP_XP = 1000000000000

type levelerState = {
	level: number;
	xp: number;
	janitor: typeof(Janitor.new());
	levelUp: typeof(Signal());
	changed: typeof(Signal());
}

local states = {} :: {[Player]: levelerState}

function Leveling.GetRequiredXP(currentLevel: number, targetLevel: number?): number
	return SharedLeveling.GetRequiredXP(currentLevel, targetLevel)
end

function Leveling.CanLevelUp(currentLevel: number?): boolean
	return SharedLeveling.CanLevelUp(currentLevel)
end

function Leveling.GetLeveler(player: Player): levelerState?
	return states[player]
end

function Leveling.AddLeveler(player: Player): levelerState
	if states[player] then return states[player] end

	local jan = Janitor.new()
	local state: levelerState = {
		level = 1;
		xp = 0;
		janitor = jan;
		levelUp = Signal();
		changed = Signal();
	}

	jan:Add(state.levelUp, "Destroy")
	jan:Add(state.changed, "Destroy")
	states[player] = state
	return state
end

function Leveling.RemoveLeveler(player: Player)
	local state = states[player]
	if not state then return end
	state.janitor:Cleanup()
	states[player] = nil
end

local function sanitizeLevel(level: number, xp: number, brute: boolean?): (number, number)
	local targetLevel = math.max(1, math.floor(level + .5))
	if brute ~= true then
		targetLevel = math.min(targetLevel, Leveling.MaxLevel)
	end

	local targetXP = math.max(0, math.floor(xp + .5))
	if targetLevel > Leveling.MaxLevel then
		return targetLevel, math.min(targetXP, MAX_OVERCAP_XP)
	end
	if not Leveling.CanLevelUp(targetLevel) then
		return targetLevel, math.min(targetXP, MAX_OVERCAP_XP)
	end

	while Leveling.CanLevelUp(targetLevel) do
		local needed = Leveling.GetRequiredXP(targetLevel)
		if targetXP < needed then
			break
		end

		targetXP -= needed
		targetLevel += 1
	end

	return targetLevel, targetXP
end

local function projectXP(level: number, xp: number, amount: number): (number, number, number)
	local targetLevel = level
	local targetXP = math.max(0, math.floor(xp + .5))
	local remaining = math.max(0, math.floor(amount + .5))
	local gainedLevels = 0

	while true do
		if targetLevel > Leveling.MaxLevel then
			targetXP = math.min(targetXP + remaining, MAX_OVERCAP_XP)
			break
		end

		if not Leveling.CanLevelUp(targetLevel) then
			targetXP = math.min(targetXP, MAX_OVERCAP_XP)
			break
		end

		local needed = Leveling.GetRequiredXP(targetLevel)
		local available = targetXP + remaining
		if available < needed then
			targetXP = available
			remaining = 0
			break
		end

		local leftover = available - needed
		targetLevel += 1
		gainedLevels += 1

		if not Leveling.CanLevelUp(targetLevel) then
			targetXP = math.min(leftover, MAX_OVERCAP_XP)
			remaining = 0
			break
		end

		targetXP = 0
		remaining = leftover
		if remaining <= 0 then
			break
		end
	end

	return targetLevel, targetXP, gainedLevels
end

local function getBatchInterval(projectedLevelUps: number, amount: number): number
	if projectedLevelUps <= SOFT_BATCHED_LEVELUPS and amount < 100000 then
		return BATCH_INTERVAL
	end

	local levelAlpha = math.clamp(
		(projectedLevelUps - SOFT_BATCHED_LEVELUPS) / math.max(MAX_BATCHED_LEVELUPS - SOFT_BATCHED_LEVELUPS, 1),
		0,
		1
	)
	local xpAlpha = math.clamp((math.log10(math.max(amount, 1)) - 5) / 5, 0, 1)
	local alpha = math.max(levelAlpha, xpAlpha * .85)

	return BATCH_INTERVAL + ((MIN_BATCH_INTERVAL - BATCH_INTERVAL) * alpha)
end

function Leveling.SetLevel(player: Player, level: number, xp: number, brute: boolean?)
	local state = states[player]
	if not state then return end

	local targetLevel, targetXP = sanitizeLevel(level, xp, brute)

	if state.level == targetLevel and state.xp == targetXP then
		return
	end

	local old = state.level
	state.level = targetLevel
	state.xp = targetXP

	if targetLevel > old then
		state.levelUp:Fire(targetLevel, old, targetXP)
	end

	state.changed:Fire(targetLevel, old, targetXP)
end

function Leveling.AddXP(player: Player, amount: number)
	local state = states[player]
	if not state then return end

	local roundedAmount = math.max(0, math.floor(amount + .5))
	if roundedAmount <= 0 then
		return
	end
	if state.level <= Leveling.MaxLevel and not Leveling.CanLevelUp(state.level) then
		return
	end

	local projectedLevel, projectedXP, projectedLevelUps = projectXP(state.level, state.xp, roundedAmount)
	local batchInterval = getBatchInterval(projectedLevelUps, roundedAmount)
	if roundedAmount >= FAST_FORWARD_XP_THRESHOLD or projectedLevelUps > MAX_BATCHED_LEVELUPS then
		local old = state.level
		state.level = projectedLevel
		state.xp = projectedXP

		if projectedLevel > old then
			state.levelUp:Fire(projectedLevel, old, projectedXP)
		end

		state.changed:Fire(projectedLevel, old, projectedXP)
		return
	end

	local remaining = roundedAmount

	local function step()
		if remaining <= 0 or not states[player] then return end

		if state.level > Leveling.MaxLevel then
			state.xp = math.min(state.xp + remaining, MAX_OVERCAP_XP)
			state.changed:Fire(state.level, state.level, state.xp)
			return
		end

		if not Leveling.CanLevelUp(state.level) then
			return
		end

		local needed = Leveling.GetRequiredXP(state.level)
		local available = state.xp + remaining
		if available >= needed then
			local leftover = available - needed
			local old = state.level

			state.level += 1
			if not Leveling.CanLevelUp(state.level) then
				state.xp = math.min(leftover, MAX_OVERCAP_XP)
				remaining = 0
			else
				state.xp = 0
				remaining = leftover
			end

			state.levelUp:Fire(state.level, old, state.xp)
			state.changed:Fire(state.level, old, state.xp)

			if remaining > 0 then
				task.delay(batchInterval, step)
			end
		else
			state.xp = available
			remaining = 0
			state.changed:Fire(state.level, state.level, state.xp)
		end
	end

	step()
end

return Leveling
