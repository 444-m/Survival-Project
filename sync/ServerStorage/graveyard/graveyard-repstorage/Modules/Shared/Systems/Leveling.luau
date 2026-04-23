--!strict
local SharedLeveling = {}
SharedLeveling.MaxLevel = require("@game/ReplicatedStorage/Modules/Shared/Globals").MaxLevel

local BASE_XP = 48
local SCALE = 1.026
local EXPONENT = 1.65

local cache = {} :: {[number]: number}

local function requiredXp(level: number): number
	if cache[level] then return cache[level] end
	local result = math.floor(BASE_XP * (level ^ EXPONENT) * (SCALE ^ level))
	cache[level] = result
	return result
end

function SharedLeveling.GetRequiredXP(currentLevel: number, targetLevel: number?): number
	local target = targetLevel or (currentLevel + 1)
	local total = 0
	for i = currentLevel, target - 1 do
		total += requiredXp(i)
	end
	return total
end

function SharedLeveling.CanLevelUp(currentLevel: number?): boolean
	if not currentLevel then return false end
	return currentLevel < SharedLeveling.MaxLevel
end

function SharedLeveling.GetProgressAlpha(currentXP: number, currentLevel: number): number
	if not SharedLeveling.CanLevelUp(currentLevel) then return 1 end
	local needed = requiredXp(currentLevel)
	if needed <= 0 then return 1 end
	return math.clamp(currentXP / needed, 0, 1)
end

return SharedLeveling
