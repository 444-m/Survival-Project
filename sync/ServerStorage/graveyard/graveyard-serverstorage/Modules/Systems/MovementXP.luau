--!strict
local Leveling = require(script.Parent.Leveling)
local RunService = game:GetService("RunService")
local advents = require("@game/ReplicatedStorage/Modules/Shared/utils/advents")

local MovementXP = {}

local easing = advents.easing

local stepInterval = .10
local minSpeed = 8
local studsPerXp = 40
local comboWindow = 3.5
local fallbackXp = 1

local noFallbackStates: {[string]: true} = {
	Idling = true;
	Running = true;
	Jumping = true;
	Falling = true;
	Landing = true;
}

local movementMultiplier: {[string]: number} = {
	Running = 1;
	Sliding = 1.15;
	Vaulting = 1.2;
	Mantling = 1.25;
	WallRunLeft = 1.5;
	WallRunRight = 1.5;
	WallJump = 1.1;
	WallFlipping = 1.2;
	DoubleJump = 1.05;
}

local actionAlias: {[string]: string} = {
	Sliding = "Sliding";
	Vaulting = "Vaulting";
	Mantling = "Mantling";
	WallRunLeft = "WallRun";
	WallRunRight = "WallRun";
	WallJump = "WallJump";
	WallFlipping = "WallFlip";
	DoubleJump = "DoubleJump";
}

local actionXp: {[string]: number} = {
	Sliding = 1;
	Vaulting = 2;
	Mantling = 3;
	WallRun = 4;
	WallJump = 4;
	WallFlip = 5;
	DoubleJump = 1;
}

type Tracker = {
	player: Player;
	character: Model?;
	humanoid: Humanoid?;
	rootPart: BasePart?;
	state: string;
	sampleAccumulator: number;
	xpAccumulator: number;
	lastActionAt: number;
	lastActionKey: string?;
	comboCount: number;
	comboUnique: {[string]: true};
	streakTicks: number;
}

local trackers = {} :: {[Player]: Tracker}

local function getTracker(player: Player): Tracker
	local tracker = trackers[player]
	if tracker then
		return tracker
	end

	tracker = {
		player = player;
		character = nil;
		humanoid = nil;
		rootPart = nil;
		state = "Idling";
		sampleAccumulator = 0;
		xpAccumulator = 0;
		lastActionAt = 0;
		lastActionKey = nil;
		comboCount = 0;
		comboUnique = {};
		streakTicks = 0;
	}

	trackers[player] = tracker
	return tracker
end

local function resetCombo(tracker: Tracker)
	tracker.lastActionAt = 0
	tracker.lastActionKey = nil
	tracker.comboCount = 0
	table.clear(tracker.comboUnique)
end

local function countComboUnique(tracker: Tracker): number
	local total = 0
	for _ in next, tracker.comboUnique do
		total += 1
	end
	return total
end

local function getLevelScale(player: Player): number
	local leveler = Leveling.GetLeveler(player)
	if not leveler then return 1 end
	local level = math.max(1, leveler.level or 1)
	local t = math.clamp((level - 1) / 99, 0, 1)
	return 1 + t * .35
end

local function awardXP(player: Player, amount: number)
	if Leveling.GetLeveler(player) == nil then return end
	local rounded = math.max(0, math.floor(amount * getLevelScale(player) + .5))
	if rounded <= 0 then return end
	Leveling.AddXP(player, rounded)
end

local function canAwardMovementXP(tracker: Tracker): boolean
	local character = tracker.character
	local humanoid = tracker.humanoid
	local rootPart = tracker.rootPart
	if not character or not humanoid or not rootPart then
		return false
	end

	if humanoid.Health <= 0 or rootPart.Anchored then
		return false
	end

	if not rootPart:IsDescendantOf(workspace) or not character:IsDescendantOf(workspace) then
		return false
	end

	local hs = humanoid:GetState()
	if hs == Enum.HumanoidStateType.Dead
		or hs == Enum.HumanoidStateType.Climbing
		or hs == Enum.HumanoidStateType.Seated
		or hs == Enum.HumanoidStateType.Swimming
	then
		return false
	end

	if tracker.state == "Stunned" then
		return false
	end

	return true
end

local function stepTracker(tracker: Tracker, dt: number)
	if not canAwardMovementXP(tracker) then
		tracker.streakTicks = 0
		return
	end

	local humanoid = tracker.humanoid :: Humanoid
	local rootPart = tracker.rootPart :: BasePart
	local now = os.clock()

	if tracker.lastActionAt > 0 and (now - tracker.lastActionAt) > comboWindow then
		resetCombo(tracker)
	end

	local horizontalSpeed = vector.magnitude(rootPart.AssemblyLinearVelocity * advents.vector.flat)
	if horizontalSpeed < minSpeed then
		tracker.streakTicks = 0
		return
	end

	local isStyleMovement = movementMultiplier[tracker.state] ~= nil
	local hs = humanoid:GetState()
	local airborne = hs == Enum.HumanoidStateType.Freefall
		or hs == Enum.HumanoidStateType.Jumping

	if airborne and not isStyleMovement then
		tracker.streakTicks = 0
		return
	end

	local multiplier = movementMultiplier[tracker.state] or 1
	tracker.streakTicks += 1

	local streakT = math.min(tracker.streakTicks / 120, 1)
	local streakBonus = 1 + easing.smootherstep(streakT) * .25

	local rawXp = (horizontalSpeed * dt * multiplier / studsPerXp) * streakBonus
	tracker.xpAccumulator += rawXp

	local earned = math.floor(tracker.xpAccumulator)
	if earned <= 0 then
		return
	end

	tracker.xpAccumulator -= earned
	awardXP(tracker.player, earned)
end

RunService.Heartbeat:Connect(function(dt)
	for player, tracker in pairs(trackers) do
		if player.Parent == nil then
			trackers[player] = nil
			continue
		end

		tracker.sampleAccumulator += dt
		if tracker.sampleAccumulator < stepInterval then
			continue
		end

		local sampleDt = tracker.sampleAccumulator
		tracker.sampleAccumulator = 0
		stepTracker(tracker, sampleDt)
	end
end)

function MovementXP.Attach(player: Player)
	return getTracker(player)
end

function MovementXP.SetCharacter(player: Player, character: Model?)
	local tracker = getTracker(player)
	tracker.character = character
	tracker.humanoid = nil
	tracker.rootPart = nil
	tracker.state = "Idling"
	tracker.sampleAccumulator = 0
	tracker.xpAccumulator = 0
	tracker.streakTicks = 0
	resetCombo(tracker)

	if not character then
		return tracker
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid:IsA("Humanoid") and rootPart and rootPart:IsA("BasePart") then
		tracker.humanoid = humanoid
		tracker.rootPart = rootPart
	end

	return tracker
end

function MovementXP.HandleStateChange(player: Player, currentState: string, _previousState: string?)
	local tracker = getTracker(player)
	tracker.state = currentState

	local actionKey = actionAlias[currentState]
	if actionKey == nil then
		if not noFallbackStates[currentState] then
			awardXP(player, fallbackXp)
		end
		return
	end

	local now = os.clock()
	local continuingCombo = tracker.lastActionKey ~= nil
		and tracker.lastActionKey ~= actionKey
		and (now - tracker.lastActionAt) <= comboWindow

	if continuingCombo then
		tracker.comboCount += 1
	else
		tracker.comboCount = 1
		table.clear(tracker.comboUnique)
	end

	tracker.comboUnique[actionKey] = true
	tracker.lastActionAt = now
	tracker.lastActionKey = actionKey

	local baseXP = actionXp[actionKey] or fallbackXp
	local uniqueCount = countComboUnique(tracker)

	local comboBonus = 0
	if tracker.comboCount > 1 then
		local comboT = math.min((tracker.comboCount - 1) / 7, 1)
		local comboScale = easing.sigmoid(comboT, "in") * 0.9
		comboBonus += math.floor(baseXP * comboScale + .5)
		if uniqueCount >= 2 then
			comboBonus += (uniqueCount - 1) * 1
		end
	end

	local speedBonus = 0
	local rootPart = tracker.rootPart
	if rootPart then
		local horizontalSpeed = vector.magnitude(rootPart.AssemblyLinearVelocity * advents.vector.flat)
		local speedT = math.clamp((horizontalSpeed - 20) / 40, 0, 1)
		speedBonus = math.floor(easing.sigmoid(speedT, "out") * 2)
	end

	awardXP(tracker.player, baseXP + comboBonus + speedBonus)
end

function MovementXP.Detach(player: Player)
	trackers[player] = nil
end

return MovementXP