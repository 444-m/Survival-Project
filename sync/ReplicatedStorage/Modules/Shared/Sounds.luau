--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local ContentProvider = game:GetService("ContentProvider");
local RunService = game:GetService("RunService");
local SoundService = game:GetService("SoundService");

type SoundEntry = {
	sound: Sound;
	lastPlayed: number?;
}

type LoadedSounds = {
	[string]: SoundEntry | LoadedSounds;
}

export type SoundPlayback = {
	sound: Sound;
	attachment: Attachment?;
	Stop: (self: SoundPlayback) -> ();
}

local SoundsFolder = ReplicatedStorage.Assets.Sounds;

local Sounds = {
	Initialized = false;
};

Sounds.LoadedSounds = setmetatable({}, {
	__index = function(self, index: string)
		if not Sounds.Initialized then
			error("Attempted to access LoadedSounds before initialization!");
		end;
		return rawget(self, index);
	end;
}) :: LoadedSounds;

local function scanFolder(folder: Folder): (LoadedSounds, { Sound })
	local folderTable: LoadedSounds = {};
	local allSounds: { Sound } = {};

	for _, obj in next, folder:GetChildren() do
		if obj:IsA("Sound") then
			if obj.SoundId == "" then continue end;
			folderTable[obj.Name] = { sound = obj } :: SoundEntry;
			table.insert(allSounds, obj);
		elseif obj:IsA("Folder") then
			local sub, subSounds = scanFolder(obj);
			folderTable[obj.Name] = sub;
			for _, s in next, subSounds do
				table.insert(allSounds, s);
			end;
		end;
	end;

	return folderTable, allSounds;
end;

function Sounds.init()
	if Sounds.Initialized then return end;
	Sounds.Initialized = true;
	table.clear(Sounds.LoadedSounds);

	local allSounds: { Sound } = {};

	for _, obj in next, SoundsFolder:GetChildren() do
		if obj:IsA("Sound") then
			if obj.SoundId == "" then continue end;
			Sounds.LoadedSounds[obj.Name] = { sound = obj } :: SoundEntry;
			table.insert(allSounds, obj);
		elseif obj:IsA("Folder") then
			local sub, subSounds = scanFolder(obj);
			Sounds.LoadedSounds[obj.Name] = sub;
			for _, s in next, subSounds do
				table.insert(allSounds, s);
			end;
		end;
	end;

	if RunService:IsClient() then
		ContentProvider:PreloadAsync(allSounds);
	end;
end;

local function createPlayback(sound: Sound, attachment: Attachment?): SoundPlayback
	return {
		sound = sound;
		attachment = attachment;
		Stop = function(self: SoundPlayback)
			self.sound:Stop();
			self.sound:Destroy();
			if self.attachment then
				self.attachment:Destroy();
			end;
		end;
	};
end;

local function playSound(
	entry: SoundEntry,
	minInterval: number?,
	restart: boolean?,
	position: Vector3?
): SoundPlayback
	local now = os.clock();
	if minInterval and entry.lastPlayed and (now - entry.lastPlayed) < minInterval then
		return {
			sound = entry.sound;
			attachment = nil;
			Stop = function() end;
		} :: SoundPlayback;
	end;
	entry.lastPlayed = now;

	if position then
		local attachment = Instance.new("Attachment");
		attachment.WorldPosition = position;
		attachment.Parent = workspace.Terrain;

		local clonedSound = entry.sound:Clone();
		clonedSound.RollOffMode = Enum.RollOffMode.LinearSquare;
		clonedSound.Parent = attachment;

		if restart then
			clonedSound.TimePosition = 0;
		end;
		clonedSound:Play();

		local playback = createPlayback(clonedSound, attachment);

		clonedSound.Ended:Connect(function()
			if clonedSound.Parent then clonedSound:Destroy() end;
			if attachment.Parent then attachment:Destroy() end;
		end);

		return playback;
	else
		local clonedSound = entry.sound:Clone();
		clonedSound.Parent = SoundService;

		if restart then
			clonedSound.TimePosition = 0;
		end;

		if RunService:IsClient() then
			SoundService:PlayLocalSound(clonedSound);
		else
			clonedSound:Play();
		end;

		local playback = createPlayback(clonedSound, nil);

		clonedSound.Ended:Connect(function()
			if clonedSound.Parent then clonedSound:Destroy() end;
		end);

		return playback;
	end;
end;

function Sounds.play(
	entryOrPlayback: SoundEntry | SoundPlayback,
	minInterval: number?,
	restart: boolean?,
	position: Vector3?
): SoundPlayback
	if not Sounds.Initialized then
		warn("Sounds module has not been initialized. Call Sounds.init() before using.");
		return { sound = Instance.new("Sound"); attachment = nil; Stop = function() end } :: SoundPlayback;
	end;

	local entry: SoundEntry;
	if (entryOrPlayback :: any).Stop ~= nil then
		local pb = entryOrPlayback :: SoundPlayback;
		entry = { sound = pb.sound; lastPlayed = nil };
	else
		entry = entryOrPlayback :: SoundEntry;
	end;

	if not entry or not entry.sound then
		warn("Sounds.play: invalid entry.");
		return { sound = Instance.new("Sound"); attachment = nil; Stop = function() end } :: SoundPlayback;
	end;

	return playSound(entry, minInterval, restart, position);
end;

function Sounds.stop(entryOrPlayback: SoundEntry | SoundPlayback)
	if (entryOrPlayback :: any).Stop ~= nil then
		local playBack = entryOrPlayback :: SoundPlayback;
		playBack:Stop();
	else
		local entry = entryOrPlayback :: SoundEntry;
		if not entry or not entry.sound then return end;
		entry.sound:Stop();
		entry.sound.TimePosition = 0;
	end;
end;

return Sounds;