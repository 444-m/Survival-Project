--!strict
local contentProvider = game:GetService("ContentProvider")
local runService = game:GetService("RunService")
local players = game:GetService("Players")

type soundMode = "position" | "part" | "global"
type soundIdValue = string | number

type soundData = {
	soundId: soundIdValue;
	mode: soundMode;
	target: BasePart?;
	position: vector?;
	volume: number?;
	pitch: number?;
	looped: boolean?;
	minDistance: number?;
	maxDistance: number?;
	emitterSize: number?;
	stopAfter: number?;
}

type activeEntry = {
	started: number;
	data: soundData;
	uid: number;
}

local sounds = {
	rep = script.rep;
	listener = nil :: RBXScriptConnection?;
	active = {} :: {[number]: activeEntry};
	currentId = 0;
}

local soundContainer = workspace:WaitForChild("objects"):WaitForChild("debris"):WaitForChild("sounds")

local LoadedSounds = nil
local SoundsModule = nil
local DirectSoundTemplates = {} :: {[string]: Sound}
local DirectSoundPreloads = {} :: {[string]: boolean}

local function normalizeDirectSoundId(soundId: soundIdValue): string?
	if type(soundId) == "number" then
		return "rbxassetid://" .. tostring(soundId)
	end

	if type(soundId) ~= "string" or soundId == "" then
		return nil
	end

	if string.find(soundId, "rbxassetid://", 1, true) == 1 or string.find(soundId, "rbxasset://", 1, true) == 1 then
		return soundId
	end

	if tonumber(soundId) ~= nil then
		return "rbxassetid://" .. soundId
	end

	return nil
end

local function getDirectTemplate(soundId: soundIdValue): Sound?
	local DirectId = normalizeDirectSoundId(soundId)
	if not DirectId then
		return nil
	end

	local Cached = DirectSoundTemplates[DirectId]
	if Cached then
		return Cached
	end

	local Sound = Instance.new("Sound")
	Sound.Name = "DynamicSound"
	Sound.SoundId = DirectId
	Sound.RollOffMode = Enum.RollOffMode.InverseTapered
	Sound.RollOffMinDistance = 5
	Sound.RollOffMaxDistance = 70
	DirectSoundTemplates[DirectId] = Sound

	if runService:IsClient() and not DirectSoundPreloads[DirectId] then
		DirectSoundPreloads[DirectId] = true
		task.spawn(function()
			contentProvider:PreloadAsync({Sound})
		end)
	end

	return Sound
end

local function resolvePath(soundId: soundIdValue): Sound?
	local Direct = getDirectTemplate(soundId)
	if Direct then
		return Direct
	end

	if not SoundsModule then
		SoundsModule = require(game:GetService("ReplicatedStorage").Modules.Client.Sounds)
	end
	if not LoadedSounds or next(LoadedSounds) == nil then
		SoundsModule.init()
		LoadedSounds = SoundsModule.LoadedSounds
	end

	if type(soundId) ~= "string" then
		return nil
	end

	local parts = soundId:split("/")
	local current: any = LoadedSounds
	for _, key in next, parts do
		current = current[key]
		if not current then return nil end
	end
	return current and (current :: any).sound or nil
end

local function createSoundInstance(sound: Sound, data: soundData): (Sound, Instance)
	local clone = sound:Clone()
	clone.Volume = data.volume or sound.Volume
	clone.PlaybackSpeed = data.pitch or sound.PlaybackSpeed
	if data.looped ~= nil then
		clone.Looped = data.looped
	else
		clone.Looped = sound.Looped
	end
	if data.minDistance then
		clone.RollOffMinDistance = data.minDistance
	end
	if data.maxDistance then
		clone.RollOffMaxDistance = data.maxDistance
	end
	if data.emitterSize then
		clone.EmitterSize = data.emitterSize
	end

	local parent: Instance

	if data.mode == "part" and data.target then
		parent = data.target
	elseif data.mode == "position" and data.position then
		local att = Instance.new("Attachment")
		att.WorldPosition = Vector3.new(data.position.X, data.position.Y, data.position.Z)
		att.Parent = soundContainer
		parent = att
	else
		parent = soundContainer
	end

	clone.Parent = parent
	return clone, parent
end

local function playSound(data: soundData, timeOffset: number?): (Sound?, Instance?, boolean)
	local sound = resolvePath(data.soundId)
	if not sound then
		warn("SoundHandler: could not resolve path '" .. tostring(data.soundId) .. "'")
		return nil, nil, false
	end

	local clone, parent = createSoundInstance(sound, data)
	local isLooped = clone.Looped

	if timeOffset and timeOffset > 0 and clone.TimeLength > 0 then
		clone.TimePosition = math.min(timeOffset, clone.TimeLength - 0.01)
	end

	clone:Play()

	return clone, parent, isLooped
end

local function scheduleCleanup(clone: Sound, parent: Instance, timeOffset: number?, stopAfter: number?)
	local cleaned = false
	local function cleanup()
		if cleaned then
			return
		end
		cleaned = true

		clone:Stop()
		if clone.Parent then
			clone:Destroy()
		end
		if parent:IsA("Attachment") and parent.Parent then
			parent:Destroy()
		end
	end

	local remaining: number
	if stopAfter and stopAfter > 0 then
		remaining = math.max(stopAfter - (timeOffset or 0), .05)
	else
		local duration = clone.TimeLength
		remaining = math.max((duration > 0 and duration or 2.25) - (timeOffset or 0), .1) + .35
	end

	clone.Ended:Connect(cleanup)
	task.delay(remaining, cleanup)
end

function sounds.play(data: soundData): number?
	assert(runService:IsServer(), "server-only")
	if data.soundId == nil or tostring(data.soundId) == "" then return nil end

	sounds.currentId += 1
	local uid = sounds.currentId

	sounds.rep:FireAllClients("play", data, 0, uid)

	if data.looped then
		sounds.active[uid] = {
			started = os.clock();
			data = data;
			uid = uid;
		}
		return uid
	end

	return nil
end

function sounds.preload(soundIds: {soundIdValue})
	assert(runService:IsClient(), "client-only")

	local toPreload = {}
	for _, soundId in next, soundIds do
		local template = resolvePath(soundId)
		if template then
			table.insert(toPreload, template)
		end
	end

	if #toPreload > 0 then
		task.spawn(function()
			contentProvider:PreloadAsync(toPreload)
		end)
	end
end

function sounds.playForPlayers(playersList: {Player}, data: soundData)
	assert(runService:IsServer(), "server-only")
	if data.soundId == nil or tostring(data.soundId) == "" then return end

	for _, player in next, playersList do
		sounds.rep:FireClient(player, "play", data, 0, nil)
	end
end

function sounds.stop(uid: number)
	assert(runService:IsServer(), "server-only")
	if not sounds.active[uid] then return end

	sounds.rep:FireAllClients("stop", nil, nil, uid)
	sounds.active[uid] = nil
end

if runService:IsServer() then
	players.PlayerAdded:Connect(function(player)
		local now = os.clock()

		for uid, entry in next, sounds.active do
			local offset = now - entry.started
			sounds.rep:FireClient(player, "play", entry.data, offset, uid)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(30)
			local now = os.clock()
			for id, entry in next, sounds.active do
				if not entry.data.looped and now - entry.started >= 30 then
					sounds.active[id] = nil
				end
			end
		end
	end)
end

function sounds.listen()
	if sounds.listener then return end
	assert(runService:IsClient(), "client-only")

	local clientActive = {} :: {[number]: {sound: Sound; parent: Instance}}

	sounds.listener = sounds.rep.OnClientEvent:Connect(function(action: string, data: soundData?, timeOffset: number?, uid: number?)
		if action == "stop" and uid then
			local entry = clientActive[uid]
			if not entry then return end

			entry.sound:Stop()

			task.delay(.5, function()
				if entry.sound.Parent then entry.sound:Destroy() end
				if entry.parent:IsA("Attachment") and entry.parent.Parent then
					entry.parent:Destroy()
				end
			end)

			clientActive[uid] = nil
			return
		end

		if action == "play" and data then
			local clone, parent, isLooped = playSound(data, timeOffset)
			if not clone or not parent then return end

			if uid and isLooped then
				clientActive[uid] = {sound = clone; parent = parent}
			else
				scheduleCleanup(clone, parent, timeOffset, data.stopAfter)
			end
		end
	end)
end

function sounds.playLocal(data: soundData): Sound?
	assert(runService:IsClient(), "client-only")
	if data.soundId == nil or tostring(data.soundId) == "" then return nil end

	local clone, parent = playSound(data, 0)
	if not clone or not parent then
		return nil
	end

	if not clone.Looped or (data.stopAfter and data.stopAfter > 0) then
		scheduleCleanup(clone, parent, 0, data.stopAfter)
	end

	return clone
end

function sounds.unlisten()
	if sounds.listener then
		sounds.listener:Disconnect()
		sounds.listener = nil
	end
end

return sounds
