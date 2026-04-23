local LevelBoosts = {}
LevelBoosts.__index = LevelBoosts

function LevelBoosts.new()
	return setmetatable({
		Token = 0;
		ActiveUntil = 0;
		Strength = 1;
		StackCount = 0;
	}, LevelBoosts)
end

function LevelBoosts:IsActive(): boolean
	return os.clock() < (self.ActiveUntil or 0)
end

function LevelBoosts:GetStrength(): number
	return math.max(self.Strength or 1, 1)
end

function LevelBoosts:Clear(onChanged)
	self.ActiveUntil = 0
	self.Strength = 1
	self.StackCount = 0
	if onChanged then
		onChanged()
	end
end

function LevelBoosts:Apply(levelsGained: number?, baseValues, getStrengthForLevels, onChanged): (number, number)
	local duration = baseValues.LevelUpBoostDuration or 0
	if duration <= 0 then
		return 1, 0
	end

	local now = os.clock()
	local maxExtraStacks = math.max(0, math.floor((baseValues.LevelUpBoostMaxExtraStacks or 6) + .5))
	local wasActive = now < (self.ActiveUntil or 0)
	if wasActive then
		local oldStackCount = self.StackCount or 0
		local newStackCount = math.min(oldStackCount + 1, maxExtraStacks)
		if newStackCount > oldStackCount then
			self.ActiveUntil = math.max(self.ActiveUntil or now, now) + duration
		end
		self.StackCount = newStackCount
	else
		self.ActiveUntil = now + duration
		self.StackCount = 0
	end

	self.Token += 1
	local token = self.Token
	self.Strength = math.max(self.Strength or 1, getStrengthForLevels(levelsGained))
	local remainingDuration = math.max(0, (self.ActiveUntil or now) - now)
	if onChanged then
		onChanged()
	end

	task.delay(remainingDuration + .05, function()
		if token ~= self.Token then
			return
		end

		if os.clock() < (self.ActiveUntil or 0) then
			return
		end

		self:Clear(onChanged)
	end)

	return self:GetStrength(), remainingDuration
end

return LevelBoosts
