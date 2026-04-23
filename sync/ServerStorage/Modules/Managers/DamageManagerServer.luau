local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Shared.Signal)

const DRAIN_RATE = 20

export type DamageInfo = {
	Amount: number;
	Type: string?;
	DrainRate: number?;
	Delayed: boolean?;
	Modifiers: {[string]: number}?;
}

export type DamageEvent = {
	Amount: number;
	Applied: number;
	HP: number;
	From: Player?;
	To: Player?;
	ToModel: Model?;
	Type: string?;
}

type State = {
	Dead: boolean;
	Modifiers: {[string]: number};
	_queue: {DamageInfo & {From: Player?}};
	_processing: boolean;
	_drainConnection: RBXScriptConnection?;
}

local DamageManagerServer = {}

DamageManagerServer.OnDamage = Signal()
DamageManagerServer.OnDeath = Signal()
DamageManagerServer.OnHeal = Signal()

local _playerStates: {[Player]: State} = {}
local _npcStates: {[Model]: State} = {}

local function getHumanoidFromTarget(target: Player | Model): Humanoid?
	if typeof(target) == "Instance" and target:IsA("Model") then
		return target:FindFirstChildOfClass("Humanoid")
	end
	local player = target :: Player
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function isPlayer(target): boolean
	return typeof(target) == "Instance" and target.ClassName == "Player" or Players:GetPlayerFromCharacter(target) ~= nil
end

local function ensureState(target: Player | Model): State
	local states = isPlayer(target) and _playerStates or _npcStates
	if states[target] then return states[target] end
	states[target] = {
		Dead = false;
		Modifiers = {};
		_queue = {};
		_processing = false;
		_drainConnection = nil;
	}
	return states[target]
end

local function getState(target: Player | Model): State?
	return _playerStates[target] or _npcStates[target]
end

function DamageManagerServer.GetHP(target: Player | Model): number
	local humanoid = getHumanoidFromTarget(target)
	return humanoid and humanoid.Health or 0
end

function DamageManagerServer.GetMaxHP(target: Player | Model): number
	local humanoid = getHumanoidFromTarget(target)
	return humanoid and humanoid.MaxHealth or 100
end

function DamageManagerServer.IsDead(target: Player | Model): boolean
	local s = getState(target)
	return s and s.Dead or false
end

local function resolveModifiers(s: State, info: DamageInfo): number
	local amount = info.Amount
	for _, mult in next, s.Modifiers do
		amount *= mult
	end
	if info.Modifiers then
		for _, mult in next, info.Modifiers do
			amount *= mult
		end
	end
	return amount
end

local function applyCreatorTag(from: Player?, target: Player | Model)
	if not from then return end
	local humanoid = getHumanoidFromTarget(target)
	if not humanoid then return end
	local tag = Instance.new("ObjectValue")
	tag.Name = "creator"
	tag.Value = from
	tag.Parent = humanoid
	task.delay(2, function()
		if tag and tag.Parent then tag:Destroy() end
	end)
end

local function applyHP(target: Player | Model, amount: number)
	local humanoid = getHumanoidFromTarget(target)
	if not humanoid then return end
	humanoid.Health = math.clamp(humanoid.Health - amount, 0, humanoid.MaxHealth)
end

local function startDrain(s: State, target: Player | Model, amount: number, rate: number)
	if s._drainConnection then
		s._drainConnection:Disconnect()
		s._drainConnection = nil
	end
	local remaining = amount
	local lastTime = os.clock()
	s._drainConnection = RunService.Heartbeat:Connect(function()
		if s.Dead or remaining <= 0 then
			if s._drainConnection then
				s._drainConnection:Disconnect()
				s._drainConnection = nil
			end
			return
		end
		local now = os.clock()
		local dt = now - lastTime
		lastTime = now
		local tick = math.min(rate * dt, remaining)
		remaining -= tick
		applyHP(target, tick)
	end)
end

local function processQueue(target: Player | Model)
	local s = getState(target)
	if not s or s._processing or #s._queue == 0 then return end
	s._processing = true
	task.spawn(function()
		while #s._queue > 0 do
			if s.Dead then break end
			local humanoid = getHumanoidFromTarget(target)
			if not humanoid then break end
			local entry = table.remove(s._queue, 1)
			local amount = resolveModifiers(s, entry)
			local before = humanoid.Health
			local applied = math.min(amount, before)

			if entry.Delayed then
				startDrain(s, target, amount, entry.DrainRate or DRAIN_RATE)
			else
				applyHP(target, amount)
			end

			local toPlayer = isPlayer(target) and target :: Player or nil
			local toModel = not isPlayer(target) and target :: Model or nil

			DamageManagerServer.OnDamage:Fire({
				Amount = amount;
				Applied = applied;
				HP = humanoid.Health;
				From = entry.From;
				To = toPlayer;
				ToModel = toModel;
				Type = entry.Type;
			})

			applyCreatorTag(entry.From, target)

			if humanoid.Health <= 0 and not s.Dead then
				s.Dead = true
				DamageManagerServer.OnDeath:Fire({
					Amount = amount;
					Applied = applied;
					HP = 0;
					From = entry.From;
					To = toPlayer;
					ToModel = toModel;
					Type = entry.Type;
				})
			end

			task.wait()
		end
		s._processing = false
	end)
end

function DamageManagerServer.Damage(from: Player?, to: Player | Model, info: DamageInfo)
	local s = ensureState(to)
	if s.Dead then return end
	table.insert(s._queue, {
		From = from;
		Amount = info.Amount;
		Type = info.Type;
		DrainRate = info.DrainRate;
		Delayed = info.Delayed;
		Modifiers = info.Modifiers;
	})
	processQueue(to)
end

function DamageManagerServer.Heal(to: Player | Model, amount: number)
	local s = ensureState(to)
	if s.Dead then return end
	local humanoid = getHumanoidFromTarget(to)
	if not humanoid then return end
	local before = humanoid.Health
	humanoid.Health = math.clamp(humanoid.Health + amount, 0, humanoid.MaxHealth)
	DamageManagerServer.OnHeal:Fire({ To = to; Amount = humanoid.Health - before; HP = humanoid.Health })
end

function DamageManagerServer.SetModifier(to: Player | Model, key: string, mult: number)
	ensureState(to).Modifiers[key] = mult
end

function DamageManagerServer.RemoveModifier(to: Player | Model, key: string)
	ensureState(to).Modifiers[key] = nil
end

function DamageManagerServer.Revive(to: Player | Model, hp: number?)
	local s = ensureState(to)
	local humanoid = getHumanoidFromTarget(to)
	if not humanoid then return end
	s.Dead = false
	s._queue = {}
	s._processing = false
	if s._drainConnection then
		s._drainConnection:Disconnect()
		s._drainConnection = nil
	end
	humanoid.Health = math.clamp(hp or humanoid.MaxHealth, 0, humanoid.MaxHealth)
end

Players.PlayerRemoving:Connect(function(player)
	local s = _playerStates[player]
	if s and s._drainConnection then s._drainConnection:Disconnect() end
	_playerStates[player] = nil
end)

return DamageManagerServer