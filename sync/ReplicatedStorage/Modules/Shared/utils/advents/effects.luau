--!strict
local runService = game:GetService("RunService")
local players = game:GetService("Players")
local replicatedStorage = game:GetService("ReplicatedStorage")

local emitModule = require(replicatedStorage.Packages.Client.EmitModule)

type fxTypes = {
	enable: nil;
	disable: nil;
	emit: nil;
	forge: nil;
}

type fxType = keyof<fxTypes>

type fxData = {
	container: Instance | {Instance};
	type: fxType;
	extra: {duration: number?; target: BasePart?; cframe: CFrame?; hitPosition: Vector3?; forgeType: ("emit" | "enable")?}?;
	destroyAfter: number?;
	attachment: Attachment?;
	assetPath: string?;
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
	fxUtil = require "@self/fxUtil";
	active = {} :: {activeEntry};
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
	local topContainer = if type(data.container) == "table"
		then (data.container :: {Instance})[1]
		else data.container :: Instance
	local destroyAfter = data.destroyAfter or (data.type == "emit" and getMaxParticleLifetime(topContainer) + .5) or 0
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
			(part :: BasePart).Anchored = true
		end
	end
	if container:IsA("BasePart") then
		container.CanCollide = false
		container.CanTouch = false
		container.CanQuery = false
		container.Massless = true
		container.Anchored = true
	end
end

local function resolveAssetPath(path: string): Instance?
	local parts = string.split(path, ".")
	local current: Instance = replicatedStorage
	for _, part in next, parts do
		local child = current:FindFirstChild(part)
		if not child then return nil end
		current = child
	end
	return current
end

local function disableParticles(parent: Instance)
	for _, v in next, parent:GetDescendants() do
		if v:IsA("ParticleEmitter") then
			(v :: ParticleEmitter).Enabled = false
		elseif v:IsA("Beam") then
			(v :: Beam).Enabled = false
		end
	end
end

local function applyForge(data: fxData, timeOffset: number?)
	local assetPath = data.assetPath
	if not assetPath then return end

	local asset = resolveAssetPath(assetPath)
	if not asset then return end

	local offset = timeOffset or 0

	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Massless = true
	holder.Transparency = 1
	holder.Size = vector.one / 10
	holder.CFrame = data.extra and data.extra.cframe or CFrame.identity
	holder.Parent = effectContainer

	local shotAtt: Attachment = asset:Clone()
	shotAtt.Parent = holder

	local endHit: Attachment? = shotAtt:FindFirstChild("EndHit")
	local beam: Beam? = shotAtt:FindFirstChild("Beam") :: Beam?

	if endHit and data.extra and data.extra.hitPosition then
		endHit.WorldPosition = data.extra.hitPosition
	end

	if beam and endHit then
		(beam :: Beam).Attachment0 = shotAtt
		;(beam :: Beam).Attachment1 = endHit
	end

	emitModule.emit(shotAtt)

	if endHit then
		local duration = data.extra and data.extra.duration or TRACE_DURATION
		local remaining = math.max(duration - offset, 0)
		task.delay(remaining, function()
			disableParticles(endHit)
			if beam then
				(beam :: Beam).Enabled = false
			end
		end)
	end

	local destroyAfter = data.destroyAfter or 2
	local remaining = math.max(destroyAfter - offset, 0)
	task.delay(remaining, function()
		if holder.Parent then holder:Destroy() end
	end)
end

local function applyFxSingle(container: Instance, data: fxData, timeOffset: number?): number?
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
			if container:IsA("Model") then
				(container :: Model):PivotTo(data.extra.cframe)
			end
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

local function applyFxAttachment(attachment: Attachment, data: fxData, timeOffset: number?)
	local offset = timeOffset or 0
	local fxType = data.type

	if data.extra and data.extra.cframe then
		attachment.WorldCFrame = data.extra.cframe
	end

	if fxType == "emit" then
		for _, child in attachment:GetChildren() do
			if child:IsA("Beam") then
				emitModule.emit(child)
			end
		end
	end

	effects.fxUtil[fxType](attachment, "child")

	if fxType == "enable" then
		local duration = data.extra and data.extra.duration
		if duration then
			local remaining = math.max(duration - offset, 0)
			if remaining > 0 then
				task.delay(remaining, function()
					if attachment.Parent then effects.fxUtil.disable(attachment, "child") end
				end)
			else
				effects.fxUtil.disable(attachment, "child")
			end
		end
	end
end

local function containerAlive(data: fxData): boolean
	if type(data.container) == "table" then
		for _, c in next, data.container :: {Instance} do
			if not c.Parent then return false end
		end
		return true
	end
	return (data.container :: Instance).Parent ~= nil
end

local TRACE_DURATION = .5

function effects.replicate(data: fxData): number?
	assert(runService:IsServer(), "server-only")

	if data.type == "forge" then
		assert(data.assetPath, "forge type requires assetPath")
		effects.currentId += 1
		local uid = effects.currentId
		effects.rep:FireAllClients(data, 0, uid, nil)
		return nil
	end

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
			if not containerAlive(entry.data) then continue end

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

	local clientActive = {} :: {[number]: {Instance}}
	local cancelTokens = {} :: {[number]: any}

	effects.listener = effects.rep.OnClientEvent:Connect(function(data: fxData?, timeOffset: number?, uid: number?, destroyDelay: number?)
		if not data and uid then
			local containers = clientActive[uid]
			if not containers then return end

			if destroyDelay == -1 then
				cancelTokens[uid] = nil
				for _, c in next, containers do
					effects.fxUtil.enable(c, "desc")
				end
				return
			end

			for _, c in next, containers do
				effects.fxUtil.disable(c, "desc")
			end

			local token = {}
			cancelTokens[uid] = token

			task.delay(destroyDelay or 2, function()
				if cancelTokens[uid] ~= token then return end
				cancelTokens[uid] = nil
				clientActive[uid] = nil
				for _, c in next, containers do
					if c.Parent then c:Destroy() end
				end
			end)

			return
		end

		if not data then return end

		if data.type == "forge" then
			applyForge(data, timeOffset)
			return
		end

		if not data.container then return end

		if data.attachment then
			for _, child in data.attachment:GetChildren() do
				if child:IsA("Beam") then
					emitModule.emit(child)
				end
			end
			applyFxAttachment(data.attachment, data, timeOffset)
			return
		end

		local cloned: {Instance} = {}
		if type(data.container) == "table" then
			for _, c in next, data.container :: {Instance} do
				local wrap = Instance.new("Part")
				wrap.CanCollide = false
				wrap.CanQuery = false
				wrap.CanTouch = false
				wrap.Transparency = 1
				wrap.Size = vector.one / 10
				c:Clone().Parent = wrap
				table.insert(cloned, wrap)
			end
		else
			local c = data.container :: Instance
			if c:IsA("ParticleEmitter") then
				local wrap = Instance.new("Part")
				wrap.CanCollide = false
				wrap.CanQuery = false
				wrap.CanTouch = false
				wrap.Transparency = 1
				wrap.Size = vector.one / 10
				c:Clone().Parent = wrap
				table.insert(cloned, wrap)
			else
				table.insert(cloned, c:Clone())
			end
		end

		local maxDestroy: number? = nil
		for _, c in next, cloned do
			local d = applyFxSingle(c, data, timeOffset)
			if d and (not maxDestroy or d > maxDestroy) then maxDestroy = d end
		end

		if uid and data.type == "enable" then
			clientActive[uid] = cloned
			local destroyAfter = maxDestroy
			if destroyAfter then
				local remaining = math.max(destroyAfter - (timeOffset or 0), 0)
				if remaining > 0 then
					local token = {}
					cancelTokens[uid] = token
					task.delay(remaining, function()
						if cancelTokens[uid] ~= token then return end
						cancelTokens[uid] = nil
						clientActive[uid] = nil
					end)
				else
					clientActive[uid] = nil
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