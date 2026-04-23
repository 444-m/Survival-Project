local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PhysicalProfile = PhysicalProperties.new(.6, .3, .9, 1, 1)
local XZ_VECTOR3 = vector.create(1, 0, 1)

local PlayerLeveler = require(ServerStorage.Modules.Systems.Leveling)
local DataManager = require(ServerStorage.Modules.Managers.Player.DataManager)
local MovementXP = require(ServerStorage.Modules.Systems.MovementXP)

local Trails = ReplicatedStorage.Assets.Effects.Player.Movement.Trails
local ArmTrails = {
	["Right Arm"] = Trails["Right Arm"];
	["Left Arm"] = Trails["Left Arm"];
}

local FootstepSounds = {
	Dirt = 178054124;
	Wood = 177940988;
	Concrete = 277067660;
	Grass = 4776173570;
	Metal = 4790537991;
	Sand = 4777003964;
	Fabric = 4776951843;
	Gravel = 4776998555;
	Marble = 4776962643;
}

local FootstepMaterialMap = {
	Mud = "Dirt";
	Pebble = "Dirt";
	Ground = "Dirt";

	Sand = "Sand";
	Snow = "Sand";
	Sandstone = "Sand";

	Rock = "Gravel";
	Basalt = "Gravel";
	Asphalt = "Gravel";
	Glacier = "Gravel";
	Slate = "Gravel";

	WoodPlanks = "Wood";
	LeafyGrass = "Grass";

	Ice = "Marble";
	Salt = "Marble";
	Marble = "Marble";
	Pavement = "Marble";
	Limestone = "Marble";

	Foil = "Metal";
	DiamondPlate = "Metal";
	CorrodedMetal = "Metal";
}

local SharedPackages = ReplicatedStorage.Packages.Shared
local BlinkServer = require(SharedPackages.Blink.Server)
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local StateManager = require(ServerStorage.Modules.Systems.StateManager)
local Trace = require(ServerStorage.Modules.Systems.misc.adm.trace)
local Conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
local GetRankInGroup = require(ReplicatedStorage.Modules.Shared.utils.getRankInGroup)
local Globals = require(ReplicatedStorage.Modules.Shared.Globals)

local HasBlinkStateEvents = BlinkServer.StateUpdate ~= nil and BlinkServer.StateSync ~= nil
if not HasBlinkStateEvents then
	warn("[PlayerHandler] Blink StateUpdate/StateSync is missing; server state replication is disabled.")
end

type TiltSet = {
	Root: CFrame;
	Neck: CFrame;
	RShoulder: CFrame;
	LShoulder: CFrame;
	RHip: CFrame;
	LHip: CFrame;
}

type StateUpdatePayload = {
	Id: number;
	NewState: string;
	Brute: boolean?;
}

type SoundReplicatorPayload = {
	SoundId: string;
	X: number;
	Y: number;
	Z: number;
	MaxDistance: number?;
	Volume: number?;
	Pitch: number?;
	EmitterSize: number?;
	StopAfter: number?;
}

type LevelUpSyncPayload = {
	Player: Player;
	NewLevel: number;
	OldLevel: number;
	CurrentXP: number;
}

local PlayerHandlerModule = {}
PlayerHandlerModule.Handlers = {} :: {[Player]: any}
PlayerHandlerModule.PlayerHandlers = PlayerHandlerModule.Handlers

local StateCallbacks = {} :: {[string]: any}
for _, module in next, script:WaitForChild("StateCallbacks"):GetChildren() do
	if module:IsA("ModuleScript") then
		pcall(function()
			StateCallbacks[module.Name] = require(module)
		end)
	end
end
PlayerHandlerModule.StateCallbacks = StateCallbacks

local PlayerHandler = {}
PlayerHandler.__index = PlayerHandler

local function getFootstepSoundId(material: Enum.Material)
	local materialName = material.Name
	local soundId = FootstepSounds[materialName]

	if not soundId then
		local mapped = FootstepMaterialMap[materialName]
		if mapped then
			soundId = FootstepSounds[mapped]
		end
	end

	return "rbxassetid://" .. tostring(soundId or FootstepSounds.Concrete)
end

local function collectNearbyPlayers(origin: Vector3, radius: number, ignorePlayer: Player)
	local nearby = {}

	for _, otherPlayer in next, Players:GetPlayers() do
		if otherPlayer == ignorePlayer then
			continue
		end

		local character = otherPlayer.Character
		local hrp = character and character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") and (hrp.Position - origin).Magnitude <= radius then
			table.insert(nearby, otherPlayer)
		end
	end

	return nearby
end

local function broadcastState(id: number)
	if not HasBlinkStateEvents then
		return
	end

	local entity = StateManager.GetEntity(id)
	if not entity then
		return
	end

	BlinkServer.StateSync.FireAll({
		Id = id;
		NewState = entity.State;
		PreviousState = entity.PreviousState;
	})
end

local function sendStateSnapshot(toPlayer: Player)
	if not HasBlinkStateEvents then
		return
	end

	for id in next, StateManager.Entities do
		local entity = StateManager.GetEntity(id)
		if entity then
			BlinkServer.StateSync.Fire(toPlayer, {
				Id = id;
				NewState = entity.State;
				PreviousState = entity.PreviousState;
			})
		end
	end
end

local function resolveStateUpdate(idOrPayload: StateUpdatePayload | number, newState: string?, brute: boolean?)
	if type(idOrPayload) == "table" then
		return idOrPayload.Id, idOrPayload.NewState, idOrPayload.Brute == true
	end

	return idOrPayload, newState, brute == true
end

function PlayerHandler.new(player: Player)
	local self = setmetatable({}, PlayerHandler)
	self.Player = player
	self.Character = player.Character
	self.Started = false
	self.Destroyed = false
	self.StateEntity = nil
	self.StateChangedConnection = nil
	self.CharacterAddedConnection = nil
	self.LevelChangedConnection = nil
	self.DataLoadedConnection = nil
	self.DataChangedConnection = nil
	self.FootstepSound = nil
	self.FootstepRootPart = nil
	self.FootstepHumanoid = nil
	self.FootstepConnections = {}
	self.TiltData = nil
	self.TraceData = nil
	self.GroupRank = nil
	self.RoleEntry = nil
	self.SyncingLevelData = false
	self.Leveler = PlayerLeveler.AddLeveler(player)
	MovementXP.Attach(player)

	return self
end

function PlayerHandler:ApplyPhysics(character: Model)
	for _, part in next, character:GetDescendants() do
		if part:IsA("BasePart") then
			part.CollisionGroup = "Player"
			part.CustomPhysicalProperties = PhysicalProfile
		end
	end
end

function PlayerHandler:ApplySavedLeveling(Data: {[string]: any}?)
	if self.Destroyed or not self.Leveler or type(Data) ~= "table" then
		return
	end

	local Stats = Data.Stats
	if type(Stats) ~= "table" then
		return
	end

	local Level = Stats.Level
	local CurrentXP = Stats.CurrentXP

	if type(Level) ~= "number" then
		Level = 1
	end
	if type(CurrentXP) ~= "number" then
		CurrentXP = 0
	end

	local rawLevel = Level
	local rawXP = CurrentXP
	local bruteLevel = rawLevel > PlayerLeveler.MaxLevel

	self.SyncingLevelData = true
	PlayerLeveler.SetLevel(self.Player, Level, CurrentXP, bruteLevel)
	self.SyncingLevelData = false

	if self.Leveler.level ~= rawLevel or self.Leveler.xp ~= rawXP then
		self:PersistLeveling()
	end
end

function PlayerHandler:PersistLeveling()
	if self.Destroyed or self.SyncingLevelData or not self.Leveler then
		return
	end

	if not DataManager:IsLoaded(self.Player) then
		return
	end

	local Success, ErrorMessage = pcall(function()
		DataManager:SetLeveling(self.Player, self.Leveler.level, self.Leveler.xp, self.Leveler.level > PlayerLeveler.MaxLevel)
	end)

	if not Success then
		warn(`[PlayerHandler] Failed to persist leveling for {self.Player.Name}: {ErrorMessage}`)
	end
end

function PlayerHandler:CleanupFootsteps()
	for _, connection in next, self.FootstepConnections do
		connection:Disconnect()
	end
	table.clear(self.FootstepConnections)

	local sound = self.FootstepSound
	if sound and sound.Parent then
		sound:Destroy()
	end

	self.FootstepSound = nil
	self.FootstepRootPart = nil
	self.FootstepHumanoid = nil
end

function PlayerHandler:UpdateFootsteps()
	local sound = self.FootstepSound
	local rootPart = self.FootstepRootPart
	local humanoid = self.FootstepHumanoid
	if not sound or not rootPart or not humanoid then
		return
	end

	if humanoid.Health <= 0 or not rootPart:IsDescendantOf(game) then
		if sound.Playing then
			sound:Stop()
		end
		return
	end

	local horizontalSpeed = (rootPart.AssemblyLinearVelocity * XZ_VECTOR3).Magnitude
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local state = humanoid:GetState()
	local shouldPlay = grounded
		and horizontalSpeed > 2
		and not humanoid.PlatformStand
		and state ~= Enum.HumanoidStateType.Climbing
		and state ~= Enum.HumanoidStateType.Swimming
		and state ~= Enum.HumanoidStateType.Freefall
		and state ~= Enum.HumanoidStateType.Jumping

	local soundId = getFootstepSoundId(humanoid.FloorMaterial)
	if sound.SoundId ~= soundId then
		sound.SoundId = soundId
	end

	local hipHeight = humanoid.HipHeight
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		hipHeight = 2.8
	end
	local scale = math.max(hipHeight / 3, .8)
	local volume = math.clamp(((horizontalSpeed - 3) / 12) * scale, 0, .9)
	local playback = math.clamp(.9 + ((horizontalSpeed / math.max((16 * scale), 1)) * .2), .85, 1.35)

	sound.Volume = volume
	sound.PlaybackSpeed = playback

	if shouldPlay then
		if not sound.Playing then
			sound:Play()
		end
	elseif sound.Playing then
		sound:Stop()
	end
end

function PlayerHandler:SetupFootsteps(character: Model)
	self:CleanupFootsteps()

	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid or not rootPart:IsA("BasePart") or not humanoid:IsA("Humanoid") then
		return
	end

	local sound = Instance.new("Sound")
	sound.Name = "MovementFootsteps"
	sound.Looped = true
	sound.SoundId = getFootstepSoundId(humanoid.FloorMaterial)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 1
	sound.RollOffMaxDistance = 55
	sound.Volume = 0
	sound.Parent = rootPart

	self.FootstepSound = sound
	self.FootstepRootPart = rootPart
	self.FootstepHumanoid = humanoid

	local function update()
		self:UpdateFootsteps()
	end

	table.insert(self.FootstepConnections, humanoid:GetPropertyChangedSignal("FloorMaterial"):Connect(update))
	table.insert(self.FootstepConnections, humanoid.StateChanged:Connect(function()
		update()
	end))
	table.insert(self.FootstepConnections, character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			self:CleanupFootsteps()
		end
	end))

	update()
end

function PlayerHandler:StopBodyTilt()
	if self.TiltData then
		self:ApplyBodyTilt(nil, true)
	end
end

function PlayerHandler:ApplyBodyTilt(tilts: TiltSet?, stop: boolean?)
	local character = self.Player.Character or self.Character
	if not character then
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso")
	if not hrp or not torso or not hrp:IsA("BasePart") or not torso:IsA("BasePart") then
		return
	end

	local rootJoint = hrp:FindFirstChild("RootJoint")
	local neckJoint = torso:FindFirstChild("Neck")
	local rightShoulder = torso:FindFirstChild("Right Shoulder")
	local leftShoulder = torso:FindFirstChild("Left Shoulder")
	local rightHip = torso:FindFirstChild("Right Hip")
	local leftHip = torso:FindFirstChild("Left Hip")

	if not rootJoint or not neckJoint or not rightShoulder or not leftShoulder or not rightHip or not leftHip then
		return
	end

	if not self.TiltData then
		self.TiltData = {
			RootOriginal = rootJoint.C0;
			NeckOriginal = neckJoint.C0;
			RShoulderOriginal = rightShoulder.C0;
			LShoulderOriginal = leftShoulder.C0;
			RHipOriginal = rightHip.C0;
			LHipOriginal = leftHip.C0;
			Connection = nil;
			CurrentTilts = nil;
			LastUpdate = os.clock();
		}
	end

	local playerData = self.TiltData

	if stop then
		if playerData.Connection then
			playerData.Connection:Disconnect()
			playerData.Connection = nil
		end
		rootJoint.C0 = playerData.RootOriginal
		neckJoint.C0 = playerData.NeckOriginal
		rightShoulder.C0 = playerData.RShoulderOriginal
		leftShoulder.C0 = playerData.LShoulderOriginal
		rightHip.C0 = playerData.RHipOriginal
		leftHip.C0 = playerData.LHipOriginal
		playerData.CurrentTilts = nil
		playerData.LastUpdate = os.clock()
		return
	end

	playerData.LastUpdate = os.clock()
	playerData.CurrentTilts = tilts

	if not playerData.Connection then
		playerData.Connection = RunService.Heartbeat:Connect(function(dt)
			if self.Destroyed or not character.Parent or not rootJoint.Parent then
				if playerData.Connection then
					playerData.Connection:Disconnect()
					playerData.Connection = nil
				end
				self.TiltData = nil
				return
			end

			local currentTilts = playerData.CurrentTilts
			local now = os.clock()
			if playerData.LastUpdate and (now - playerData.LastUpdate) > .35 then
				rootJoint.C0 = playerData.RootOriginal
				neckJoint.C0 = playerData.NeckOriginal
				rightShoulder.C0 = playerData.RShoulderOriginal
				leftShoulder.C0 = playerData.LShoulderOriginal
				rightHip.C0 = playerData.RHipOriginal
				leftHip.C0 = playerData.LHipOriginal
				return
			end
			if not currentTilts then
				return
			end

			local alpha = dt * 10
			rootJoint.C0 = rootJoint.C0:Lerp(playerData.RootOriginal * currentTilts.Root, alpha)
			neckJoint.C0 = neckJoint.C0:Lerp(playerData.NeckOriginal * currentTilts.Neck, alpha)
			rightShoulder.C0 = rightShoulder.C0:Lerp(playerData.RShoulderOriginal * currentTilts.RShoulder, alpha)
			leftShoulder.C0 = leftShoulder.C0:Lerp(playerData.LShoulderOriginal * currentTilts.LShoulder, alpha)
			rightHip.C0 = rightHip.C0:Lerp(playerData.RHipOriginal * currentTilts.RHip, alpha)
			leftHip.C0 = leftHip.C0:Lerp(playerData.LHipOriginal * currentTilts.LHip, alpha)
		end)
	end
end

function PlayerHandler:ClearTrace()
	Trace.Clear(self)
end

function PlayerHandler:ApplyTrace(character: Model)
	Trace.Bind(self, character)
end

function PlayerHandler:AddTrails(character: Model)
	for name, trail in next, ArmTrails do
		local limb = character:FindFirstChild(name)
		if not limb then continue end

		local attachments = {}

		for _, attachment in next, trail:GetChildren() do
			local clone = attachment:Clone()
			clone.Parent = limb
			attachments[tonumber(clone.Name)] = clone
		end
		
		local a0 = attachments[1]
		local a1 = attachments[2]
		if not a0 or not a1 then continue end

		for _, trailInst in next, a0:GetChildren() do
			if trailInst:IsA("Trail") then
				trailInst.Attachment0 = a0
				trailInst.Attachment1 = a1
			end
		end
	end
end

function PlayerHandler:OnCharacterAdded(character: Model)
	if self.Destroyed then
		return
	end

	self.Character = character
	character.PrimaryPart = character:WaitForChild("HumanoidRootPart")
	character.Parent = Globals.BuildContainer["not-alive"]

	local spawns = Globals.LobbyContainer.spawns:GetChildren()
	local spawn = spawns[math.random(1, #spawns)]

	if spawn then
		local halfX = spawn.Size.X / 2
		local halfZ = spawn.Size.Z / 2
		local randomOffset = vector.create(
			math.random(-halfX * 100, halfX * 100) / 100,
			spawn.Size.Y / 2,
			math.random(-halfZ * 100, halfZ * 100) / 100
		)
		character:PivotTo(CFrame.new(spawn.CFrame * randomOffset) * (character:GetPivot() - character:GetPivot().Position))
	end

	self:ApplyPhysics(character)
	self:ApplyTrace(character)
	self:AddTrails(character)
	MovementXP.SetCharacter(self.Player, character)
end

function PlayerHandler:HandleStateChanged(currentState: string, previousState: string)
	local currentStateCallback = StateCallbacks[currentState]
	local previousStateCallback = StateCallbacks[previousState]
	local character = self.Character or self.Player.Character

	if currentStateCallback and currentStateCallback.Start then
		currentStateCallback.Start(character)
	end

	if previousStateCallback and previousStateCallback.Stop then
		previousStateCallback.Stop(character)
	end

	MovementXP.HandleStateChange(self.Player, currentState, previousState)
end

function PlayerHandler:start(): any
	if self.Started or self.Destroyed then
		return self
	end

	self.Started = true

	if GetRankInGroup.isRankOrAbove(self.Player.UserId, Globals.GroupId or game.CreatorId, Globals.MinAdminRank) then
		BlinkServer.ConchInit.Fire(self.Player, {
			Active = true;
		})
	end

	local groupRank = GetRankInGroup.getRank(self.Player.UserId, Globals.GroupId or game.CreatorId)
	if groupRank then
		groupRank = groupRank.rank
	end
	self.GroupRank = groupRank
	self.RoleEntry = Globals.conch.roleMap[groupRank]

	if self.RoleEntry then
		Conch.give_roles(Conch.get_user(self.Player), self.RoleEntry.role)
	end

	self.StateEntity = StateManager.NewEntity(self.Player.UserId, "Idling")
	sendStateSnapshot(self.Player)
	broadcastState(self.Player.UserId)

	self.CharacterAddedConnection = self.Player.CharacterAdded:Connect(function(character)
		self:OnCharacterAdded(character)
	end)

	if self.Player.Character then
		task.defer(function()
			if not self.Destroyed and self.Player.Character then
				self:OnCharacterAdded(self.Player.Character)
			end
		end)
	end

	self.StateChangedConnection = self.StateEntity.StateChanged:Connect(function(currentState, previousState)
		self:HandleStateChanged(currentState, previousState)
	end)

	self.DataLoadedConnection = DataManager.Loaded:Connect(function(Player, Data)
		if Player ~= self.Player then return end
		self:ApplySavedLeveling(Data)
	end)

	self.DataChangedConnection = DataManager.Changed:Connect(function(Player, NewData)
		if Player ~= self.Player then return end
		self:ApplySavedLeveling(NewData)
	end)

	if DataManager:IsLoaded(self.Player) then
		local Success, ExistingData = pcall(function()
			return DataManager:Get(self.Player)
		end)

		if Success then
			self:ApplySavedLeveling(ExistingData)
		end
	end

	if self.Leveler and BlinkServer.LevelUpSync ~= nil then
		BlinkServer.LevelUpSync.Fire(self.Player, {
			Player = self.Player;
			NewLevel = self.Leveler.level;
			OldLevel = self.Leveler.level;
			CurrentXP = self.Leveler.xp;
		})

		if self.Leveler.changed then
			self.LevelChangedConnection = self.Leveler.changed:Connect(function(newLevel: number, oldLevel: number, currentXp: number)
				local payload: LevelUpSyncPayload = {
					Player = self.Player;
					NewLevel = newLevel;
					OldLevel = oldLevel;
					CurrentXP = currentXp;
				}

				BlinkServer.LevelUpSync.FireAll(payload)
				self:PersistLeveling()
			end)
		elseif self.Leveler.levelUp then
			self.LevelChangedConnection = self.Leveler.levelUp:Connect(function(newLevel: number, oldLevel: number, currentXp: number)
				local payload: LevelUpSyncPayload = {
					Player = self.Player;
					NewLevel = newLevel;
					OldLevel = oldLevel;
					CurrentXP = currentXp;
				}

				BlinkServer.LevelUpSync.FireAll(payload)
				self:PersistLeveling()
			end)
		end
	end

	return self
end

function PlayerHandler:destroy()
	if self.Destroyed then
		return
	end

	self.Destroyed = true
	self.Started = false

	if self.CharacterAddedConnection then
		self.CharacterAddedConnection:Disconnect()
		self.CharacterAddedConnection = nil
	end

	if self.StateChangedConnection then
		self.StateChangedConnection:Disconnect()
		self.StateChangedConnection = nil
	end

	if self.LevelChangedConnection then
		self.LevelChangedConnection:Disconnect()
		self.LevelChangedConnection = nil
	end

	if self.DataLoadedConnection then
		self.DataLoadedConnection:Disconnect()
		self.DataLoadedConnection = nil
	end

	if self.DataChangedConnection then
		self.DataChangedConnection:Disconnect()
		self.DataChangedConnection = nil
	end

	self:StopBodyTilt()
	self.TiltData = nil
	self:ClearTrace()
	self:CleanupFootsteps()
	MovementXP.Detach(self.Player)
	PlayerLeveler.RemoveLeveler(self.Player)
	self.Leveler = nil
	StateManager.RemoveEntity(self.Player.UserId)
	PlayerHandlerModule.Handlers[self.Player] = nil
	self.Character = nil
	self.StateEntity = nil
end

PlayerHandler.Start = PlayerHandler.start
PlayerHandler.Destroy = PlayerHandler.destroy

function PlayerHandlerModule.add(player: Player): any
	local existing = PlayerHandlerModule.Handlers[player]
	if existing then
		return existing
	end

	local handler = PlayerHandler.new(player)
	PlayerHandlerModule.Handlers[player] = handler
	return handler
end

function PlayerHandlerModule.get(player: Player): any
	return PlayerHandlerModule.Handlers[player]
end

function PlayerHandlerModule.destroy(selfOrHandler: any, maybeHandlerOrPlayer: any?)
	local handlerOrPlayer = maybeHandlerOrPlayer
	if handlerOrPlayer == nil then
		handlerOrPlayer = selfOrHandler
	end

	local handler = handlerOrPlayer
	if typeof(handlerOrPlayer) == "Instance" and handlerOrPlayer:IsA("Player") then
		handler = PlayerHandlerModule.Handlers[handlerOrPlayer]
	end

	if handler and handler.destroy then
		handler:destroy()
	end
end

PlayerHandlerModule.Add = PlayerHandlerModule.add
PlayerHandlerModule.Get = PlayerHandlerModule.get
PlayerHandlerModule.Destroy = PlayerHandlerModule.destroy

local function onStateUpdate(player: Player, idOrPayload: StateUpdatePayload | number, newState: string?, brute: boolean?)
	local id, nextState, isBrute = resolveStateUpdate(idOrPayload, newState, brute)
	if type(id) ~= "number" or type(nextState) ~= "string" then
		return
	end

	local entityId = player.UserId
	if id ~= entityId then
		id = entityId
	end

	local changed = false
	if isBrute then
		changed = StateManager.BruteChangeState(id, nextState)
	else
		changed = StateManager.UpdateEntityState(id, nextState)
	end

	if changed then
		broadcastState(id)
	end
end

local function onSoundReplicator(player: Player, payload: SoundReplicatorPayload)
	if type(payload) ~= "table" then
		return
	end
	if type(payload.SoundId) ~= "string" or payload.SoundId == "" then
		return
	end
	if type(payload.X) ~= "number" or type(payload.Y) ~= "number" or type(payload.Z) ~= "number" then
		return
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not hrp:IsA("BasePart") then
		return
	end

	local reportedPosition = vector.create(payload.X, payload.Y, payload.Z)
	local maxOffset = 18
	if (reportedPosition - hrp.Position).Magnitude > maxOffset then
		reportedPosition = hrp.Position
	end

	local maxDistance = type(payload.MaxDistance) == "number" and math.clamp(payload.MaxDistance, 8, 120) or 55
	local nearbyPlayers = collectNearbyPlayers(reportedPosition, maxDistance + 10, player)
	if #nearbyPlayers == 0 then
		return
	end

	local volume = type(payload.Volume) == "number" and math.clamp(payload.Volume, 0, 2) or nil
	local pitch = type(payload.Pitch) == "number" and math.clamp(payload.Pitch, .35, 2.5) or nil
	local emitterSize = type(payload.EmitterSize) == "number" and math.clamp(payload.EmitterSize, 0, 8) or nil
	local stopAfter = type(payload.StopAfter) == "number" and math.clamp(payload.StopAfter, .05, 2) or nil

	advents.sounds.playForPlayers(nearbyPlayers, {
		soundId = payload.SoundId;
		mode = "position";
		position = advents.vector.toNative(reportedPosition);
		volume = volume;
		pitch = pitch;
		looped = if stopAfter then false else nil;
		maxDistance = maxDistance;
		emitterSize = emitterSize;
		stopAfter = stopAfter;
	})
end

BlinkServer.JointReplicator.On(function(player, tilts, stop)
	local handler = PlayerHandlerModule.get(player)
	if handler then
		handler:ApplyBodyTilt(tilts, stop)
	end
end)

if BlinkServer.SoundReplicator ~= nil then
	BlinkServer.SoundReplicator.On(onSoundReplicator)
end

if HasBlinkStateEvents then
	BlinkServer.StateUpdate.On(onStateUpdate)
end

local footstepHeartbeatAccumulator = 0
RunService.Heartbeat:Connect(function(dt)
	footstepHeartbeatAccumulator += dt
	if footstepHeartbeatAccumulator < (1 / 20) then
		return
	end

	footstepHeartbeatAccumulator = 0

	for _, handler in next, PlayerHandlerModule.Handlers do
		if handler.FootstepSound then
			handler:UpdateFootsteps()
		end
	end
end)

return PlayerHandlerModule
