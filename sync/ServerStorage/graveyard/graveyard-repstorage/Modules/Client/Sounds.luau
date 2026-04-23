--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

type SoundEntry = {
	sound: Sound;
	lastPlayed: number?;
}

type LoadedSounds = {
	[string]: SoundEntry | LoadedSounds;
}

local SoundsFolder = ReplicatedStorage.Assets.Sounds

local Sounds = {
	LoadedSounds = {} :: LoadedSounds;
	Initialized = false;
}

local function scanFolder(folder: Folder): (LoadedSounds, {Sound})
	local folderTable: LoadedSounds = {}
	local allSounds: {Sound} = {}

	for _, obj in next, folder:GetChildren() do
		if obj:IsA("Sound") then
			if obj.SoundId == "" then continue end
			folderTable[obj.Name] = {sound = obj} :: SoundEntry
			table.insert(allSounds, obj)
		elseif obj:IsA("Folder") then
			local sub, subSounds = scanFolder(obj)
			folderTable[obj.Name] = sub
			for _, s in next, subSounds do
				table.insert(allSounds, s)
			end
		end
	end

	return folderTable, allSounds
end

function Sounds.init()
	if Sounds.Initialized then
		return
	end

	Sounds.Initialized = true
	table.clear(Sounds.LoadedSounds)

	local allSounds: {Sound} = {}

	for _, obj in next, SoundsFolder:GetChildren() do
		if obj:IsA("Sound") then
			if obj.SoundId == "" then continue end
			Sounds.LoadedSounds[obj.Name] = {sound = obj} :: SoundEntry
			table.insert(allSounds, obj)
		elseif obj:IsA("Folder") then
			local sub, subSounds = scanFolder(obj)
			Sounds.LoadedSounds[obj.Name] = sub
			for _, s in next, subSounds do
				table.insert(allSounds, s)
			end
		end
	end

	if RunService:IsClient() then
		ContentProvider:PreloadAsync(allSounds)
	end
end

function Sounds.play(Entry: SoundEntry, MinInterval: number?, Restart: boolean?)
	if not Entry or not Entry.sound then return end
	local Now = os.clock()
	if MinInterval and Entry.lastPlayed and (Now - Entry.lastPlayed) < MinInterval then
		return
	end
	Entry.lastPlayed = Now

	if Restart then
		Entry.sound.TimePosition = 0
	end

	SoundService:PlayLocalSound(Entry.sound)
end

function Sounds.stop(Entry: SoundEntry)
	if not Entry or not Entry.sound then return end
	Entry.sound:Stop()
	Entry.sound.TimePosition = 0
end

return Sounds
