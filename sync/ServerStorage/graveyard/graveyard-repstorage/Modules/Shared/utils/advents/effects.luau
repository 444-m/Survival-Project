--!strict
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local emitModule = require(replicatedStorage.Packages.Client.EmitModule)

type fxType = "enable" | "disable" | "emit"

type fxData = {
	container: Instance;
	type: fxType;
	extra: {duration: number?; target: BasePart?; cframe: CFrame?}?;
	destroyAfter: number?;
}

type activeEntry = {
	started: number;
	data: fxData;
	duration: number;
	token: any?;
}

local effects = {
	rep = script.rep;
	listener = nil :: RBXScriptConnection?;
	fxUtil = require("@self/fxUtil");
	active = {} :: {[number]: activeEntry};
	currentId = 0;
}

local effectContainer = workspace:WaitForChild("objects"):WaitForChild("debris"):WaitForChild("effects")

local function isMeshVFX(container: Instance): boolean
	local start = container:FindFirstChild("Start")
	return start ~= nil and start:IsA("BasePart")
end

local function getMaxParticleLifetime(container: Instance): number
	local max = 0

	for _, particle in next, container:GetDescendants() do
		if particle:IsA("ParticleEmitter") then
			max = math.max(max, (particle :: ParticleEmitter).Lifetime.Max)
		end
	end

	return max
end

local function computeEffectDuration(data: fxData): number
	local destroyAfter = data.destroyAfter or (data.type == "emit" and getMaxParticleLifetime(data.container) + .5) or 0
	local enableDuration = data.type == "enable" and data.extra and data.extra.duration
	if data.type == "enable" and not enableDuration then return math.huge end
	return (enableDuration or destroyAfter) :: number
end

local function prepareContainer(container: Instance)
	for _, part in next, container:GetDescendants() do
		if part:IsA("BasePart") then
			(part :: BasePart).CanCollide = false
			(part :: BasePart).CanTouch = false
			(part :: BasePart).CanQuery = false
			(part :: BasePart).Massless = true
			(part :: BasePart).Anchored = false
		end
	end

	if container:IsA("BasePart") then
		container.CanCollide = false
		container.CanTouch = false
		container.CanQuery = false
		container.Massless = true
		container.Anchored = false
	end
end

local function applyFx(container: Instance, data: fxData, timeOffset: number?): number?
	local offset = timeOffset or 0
	local fxType = data.type

	prepareContainer(container)

	if data.extra and data.extra.target then
		local target = data.extra.target :: BasePart
		if container:IsA("BasePart") then
			local part = container :: BasePart
			part.CFrame = data.extra.cframe or target.CFrame
			container.Parent = target
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = target
			weld.Part1 = part
			weld.Parent = container
		else
			(container :: Model):PivotTo(data.extra.cframe or target.CFrame)
			container.Parent = target
		end
	elseif data.extra and data.extra.cframe then
		if container:IsA("BasePart") then
			(container :: BasePart).CFrame = data.extra.cframe
		else
			(container :: Model):PivotTo(data.extra.cframe)
		end
		container.Parent = effectContainer
	else
		container.Parent = effectContainer
	end

	if isMeshVFX(container) then
		emitModule.emit(container)
	else
		effects.fxUtil[fxType](container, "desc")
	end

	local duration = data.extra and data.extra.duration
	if fxType == "enable" and duration and not isMeshVFX(container) then
		local remaining = math.max(duration - offset, 0)
		if remaining > 0 then
			task.delay(remaining, function()
				if container.Parent then effects.fxUtil.disable(container, "desc") end
			end)
		else
			effects.fxUtil.disable(container, "desc")
		end
	end

	local destroyAfter = data.destroyAfter
	if fxType == "emit" and not destroyAfter then
		destroyAfter = getMaxParticleLifetime(container) + .5
	end
	if fxType == "enable" and duration and not destroyAfter then
		destroyAfter = duration + getMaxParticleLifetime(container) + .5
	end

	if destroyAfter then
		local remaining = math.max(destroyAfter - offset, 0)
		if remaining > 0 then
			task.delay(remaining, function()
				if container.Parent then container:Destroy() end
			end)
		else
			container:Destroy()
		end
	end

	return destroyAfter
end

function effects.replicate(data: fxData): number?
	assert(runService:IsServer(), "server-only")
	if not data.container then return nil end

	effects.currentId += 1
	local uid = effects.currentId

	effects.rep:FireAllClients(data, 0, uid, nil)

	local duration = computeEffectDuration(data)
	effects.active[uid] = {
		started = os.clock();
		data = data;
		duration = duration;
	}

	if data.type == "enable" and duration ~= math.huge then
		local destroyDelay = data.destroyAfter or 2
		local token = {}
		effects.active[uid].token = token
		task.delay(duration, function()
			if effects.active[uid] and effects.active[uid].token == token then
				effects.disableEffect(uid, destroyDelay)
			end
		end)
	end

	return data.type == "enable" and uid or nil
end

function effects.disableEffect(uid: number, destroyDelay: number?)
	assert(runService:IsServer(), "server-only")
	if not effects.active[uid] then return end

	effects.rep:FireAllClients(nil, nil, uid, destroyDelay or 2)
	effects.active[uid].token = nil
	effects.active[uid] = nil
end

function effects.cancelDisable(uid: number)
	assert(runService:IsServer(), "server-only")
	effects.rep:FireAllClients(nil, nil, uid, -1)
end

if runService:IsServer() then
	players.PlayerAdded:Connect(function(player)
		local now = os.clock()

		for uid, entry in next, effects.active do
			local isInfinite = entry.duration == math.huge
			local offset = now - entry.started
			if not isInfinite and offset >= entry.duration then continue end
			if not entry.data.container or not entry.data.container.Parent then continue end

			effects.rep:FireClient(player, entry.data, offset, uid, nil)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.clock()

			for id, entry in next, effects.active do
				if entry.duration ~= math.huge and now - entry.started >= entry.duration then
					effects.active[id] = nil
				end
			end
		end
	end)
end

function effects.listen()
	if effects.listener then return end
	assert(runService:IsClient(), "client-only")

	local clientActive = {} :: {[number]: Instance}
	local cancelTokens = {} :: {[number]: any}

	effects.listener = effects.rep.OnClientEvent:Connect(function(data: fxData?, timeOffset: number?, uid: number?, destroyDelay: number?)
		if not data and uid then
			local container = clientActive[uid]
			if not container then return end

			if destroyDelay == -1 then
				cancelTokens[uid] = nil
				effects.fxUtil.enable(container, "desc")
				return
			end

			effects.fxUtil.disable(container, "desc")

			local token = {}
			cancelTokens[uid] = token

			task.delay(destroyDelay or 2, function()
				if cancelTokens[uid] ~= token then return end
				cancelTokens[uid] = nil
				clientActive[uid] = nil
				if container.Parent then container:Destroy() end
			end)

			return
		end

		if not data or not data.container then return end

		local container = data.container:Clone()

		local destroyAfter = applyFx(container, data, timeOffset)

		if uid and data.type == "enable" then
			clientActive[uid] = container
			if destroyAfter then
				local remaining = math.max(destroyAfter - (timeOffset or 0), 0)
				if remaining > 0 then
					local token = {}
					cancelTokens[uid] = token
					task.delay(remaining, function()
						if cancelTokens[uid] ~= token then return end
						cancelTokens[uid] = nil
						if clientActive[uid] == container then
							clientActive[uid] = nil
						end
					end)
				else
					if clientActive[uid] == container then
						clientActive[uid] = nil
					end
				end
			end
		end
	end)
end

function effects.unlisten()
	if effects.listener then
		effects.listener:Disconnect()
		effects.listener = nil
	end
end

return effects