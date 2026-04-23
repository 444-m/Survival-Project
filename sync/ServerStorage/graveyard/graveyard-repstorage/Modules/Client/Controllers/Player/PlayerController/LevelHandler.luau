local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local Janitor = require(SharedPackages.Janitor)
local Signal = require(SharedPackages.Signal)
local BlinkClient = require(SharedPackages.Blink.Client)
local SharedLeveling = require(ReplicatedStorage.Modules.Shared.Systems.Leveling)

local LevelHandler = {}
LevelHandler.__index = LevelHandler

function LevelHandler.new(Player: Player)
	local self = setmetatable({}, LevelHandler)
	self.Player = Player
	self.Janitor = Janitor.new()
	self.level = 1
	self.currentXP = 0
	self.oldLevel = 1
	self.maxLevel = SharedLeveling.MaxLevel
	self.canLevelUp = true
	self.requiredXPForNextLevel = 0
	self.remainingXPForNextLevel = 0
	self.progressAlpha = 0
	self.HasReceivedInitialSync = false
	self.Changed = Signal()
	self.LeveledUp = Signal()

	self.Janitor:Add(self.Changed, "Destroy")
	self.Janitor:Add(self.LeveledUp, "Destroy")

	self:RefreshDerived()
	return self
end

function LevelHandler:RefreshDerived()
	self.maxLevel = SharedLeveling.MaxLevel
	self.canLevelUp = SharedLeveling.CanLevelUp(self.level)
	self.requiredXPForNextLevel = self.canLevelUp and SharedLeveling.GetRequiredXP(self.level) or 0
	self.remainingXPForNextLevel = math.max(0, self.requiredXPForNextLevel - self.currentXP)
	self.progressAlpha = SharedLeveling.GetProgressAlpha(self.currentXP, self.level)
end

function LevelHandler:ApplySync(Payload)
	if not Payload or Payload.Player ~= self.Player then
		return
	end

	local previousLevel = self.level
	local previousXP = self.currentXP
	local wasInitialized = self.HasReceivedInitialSync
	self.oldLevel = Payload.OldLevel or previousLevel
	self.level = Payload.NewLevel or self.level
	self.currentXP = Payload.CurrentXP or self.currentXP
	self:RefreshDerived()
	self.HasReceivedInitialSync = true

	self.Changed:Fire(self, Payload, previousLevel, previousXP)

	local oldLevel = Payload.OldLevel or previousLevel
	local newLevel = Payload.NewLevel or previousLevel
	if wasInitialized and newLevel > oldLevel then
		self.LeveledUp:Fire(self, Payload)
	end
end

function LevelHandler:Start()
	if self.Started then
		return self
	end

	self.Started = true
	self.Janitor:Add(BlinkClient.LevelUpSync.On(function(Payload)
		self:ApplySync(Payload)
	end), true, "BlinkLevelUpSync")

	return self
end

function LevelHandler:GetRequiredXPForLevel(TargetLevel: number): number
	return SharedLeveling.GetRequiredXP(self.level, TargetLevel)
end

function LevelHandler:GetProgressAlpha(): number
	return self.progressAlpha
end

function LevelHandler:Destroy()
	self.Janitor:Cleanup()
	setmetatable(self, nil)
end

return LevelHandler
