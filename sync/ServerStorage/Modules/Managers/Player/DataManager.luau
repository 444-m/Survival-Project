local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Globals = require(ReplicatedStorage.Modules.Shared.Globals)
local Signal = require(ReplicatedStorage.Packages.Shared.Signal)
local Lyra = require(ServerStorage.Packages.Lyra.Lyra)

local Template = require "@self/Template"

export type TemplateData = typeof(Template)
export type PlayerData = {[string]: any}
type LoadPromise = {
	await: (self: LoadPromise) -> (boolean, ...any);
	expect: (self: LoadPromise) -> ...any;
	andThen: (self: LoadPromise, Callback: (...any) -> ...any) -> LoadPromise;
}

const STORE_NAME = "PlayerData4"
const MAX_OVERCAP_XP = 1000000000000

local function CopyDeep(Value: any, Seen: {[any]: any}?): any
	if type(Value) ~= "table" then
		return Value
	end

	Seen = Seen or {}
	if Seen[Value] ~= nil then
		return Seen[Value]
	end

	local NewValue = table.clone(Value)
	Seen[Value] = NewValue

	for Key, NestedValue in next, NewValue do
		NewValue[Key] = CopyDeep(NestedValue, Seen)
	end

	return NewValue
end

local function MergeMissingFields(Target: any, Defaults: any): boolean
	if type(Target) ~= "table" or type(Defaults) ~= "table" then
		return false
	end

	local Changed = false

	for Key, DefaultValue in next, Defaults do
		local CurrentValue = Target[Key]

		if CurrentValue == nil then
			Target[Key] = CopyDeep(DefaultValue)
			Changed = true
		elseif type(CurrentValue) == "table" and type(DefaultValue) == "table" then
			if MergeMissingFields(CurrentValue, DefaultValue) then
				Changed = true
			end
		end
	end

	return Changed
end

local function ValidateAgainstTemplate(TemplateValue: any, Value: any, Path: string): (boolean, string?)
	if Value == nil then
		return true
	end

	local TemplateType = typeof(TemplateValue)
	local ValueType = typeof(Value)

	if TemplateType ~= ValueType then
		return false, `{Path} expected {TemplateType}, got {ValueType}`
	end

	if TemplateType ~= "table" then
		return true
	end

	for Key, NestedTemplate in next, TemplateValue do
		local Ok, ErrorMessage = ValidateAgainstTemplate(NestedTemplate, Value[Key], `{Path}.{tostring(Key)}`)
		if not Ok then
			return false, ErrorMessage
		end
	end

	return true
end

local DataManager = {
	StoreName = STORE_NAME;
	Template = Template;
	Started = false;
	Closed = false;
	BoundToClose = false;
	Loaded = Signal();
	Unloaded = Signal();
	Changed = Signal();
	LoadedPlayers = {} :: {[Player]: true};
	LoadPromises = {} :: {[Player]: LoadPromise};
	PlayerAddedConnection = nil :: RBXScriptConnection?;
	PlayerRemovingConnection = nil :: RBXScriptConnection?;
}

DataManager.Store = Lyra.createPlayerStore({
	name = STORE_NAME;
	template = CopyDeep(Template);
	schema = function(Value)
		return ValidateAgainstTemplate(Template, Value, "Data")
	end;
	changedCallbacks = {
		function(Key: string, NewData: PlayerData, OldData: PlayerData?)
			local UserId = tonumber(Key)
			local Player = if UserId then Players:GetPlayerByUserId(UserId) else nil
			DataManager.Changed:Fire(Player, NewData, OldData, UserId)
		end;
	};
})

function DataManager:ShouldForceNewPlayerData(): boolean
	return RunService:IsStudio() and Globals.MarkAsNewPlayer == true
end

function DataManager:CreateNewPlayerData(): PlayerData
	local NewData = CopyDeep(self.Template)
	NewData.NewPlayer = true
	return NewData
end

function DataManager:IsLoaded(Player: Player): boolean
	return self.LoadedPlayers[Player] == true
end

function DataManager:Normalize(Player: Player): ()
	if self:ShouldForceNewPlayerData() then
		self.Store:updateImmutableAsync(Player, function()
			return self:CreateNewPlayerData()
		end)
		return
	end

	self.Store:updateAsync(Player, function(Data: PlayerData)
		return MergeMissingFields(Data, self.Template)
	end)
end

function DataManager:Load(Player: Player): PlayerData
	if self.Closed then
		error("[DataManager] Cannot load player data after the store has been closed.")
	end

	if self.LoadedPlayers[Player] then
		return self.Store:getAsync(Player)
	end

	local ExistingPromise = self.LoadPromises[Player]
	if ExistingPromise then
		ExistingPromise:expect()
		return self.Store:getAsync(Player)
	end

	local Promise = (self.Store:load(Player):andThen(function()
		self:Normalize(Player)
	end) :: any) :: LoadPromise

	self.LoadPromises[Player] = Promise

	local Success, ErrorMessage = Promise:await()
	if self.LoadPromises[Player] == Promise then
		self.LoadPromises[Player] = nil
	end

	if not Success then
		error(ErrorMessage)
	end

	self.LoadedPlayers[Player] = true

	local Data = self.Store:getAsync(Player)
	self.Loaded:Fire(Player, Data)
	return Data
end

function DataManager:Get(Player: Player): PlayerData
	local ExistingPromise = self.LoadPromises[Player]
	if ExistingPromise then
		ExistingPromise:expect()
	end

	if not self.LoadedPlayers[Player] then
		return self:Load(Player)
	end

	return self.Store:getAsync(Player)
end

function DataManager:GetData(Player: Player): PlayerData
	return self:Get(Player)
end

function DataManager:GetStats(Player: Player): {[string]: any}
	local Data = self:Get(Player)
	local Stats = Data.Stats

	if type(Stats) ~= "table" then
		Stats = CopyDeep(self.Template.Stats)
		Data.Stats = Stats
	end

	return Stats
end

function DataManager:GetField(Player: Player, FieldName: string, DefaultValue: any?): any
	local Data = self:Get(Player)
	local Value = Data[FieldName]

	if Value == nil then
		return DefaultValue
	end

	return Value
end

function DataManager:SetField(Player: Player, FieldName: string, Value: any): PlayerData
	return self:Update(Player, function(Data)
		Data[FieldName] = Value
	end)
end

function DataManager:SetNewPlayer(Player: Player, IsNewPlayer: boolean): PlayerData
	return self:SetField(Player, "NewPlayer", IsNewPlayer)
end

function DataManager:Update(Player: Player, Transform: (Data: PlayerData) -> boolean?): PlayerData
	self:Get(Player)

	self.Store:updateAsync(Player, function(Data: PlayerData)
		local Result = Transform(Data)
		return Result ~= false
	end)

	return self.Store:getAsync(Player)
end

function DataManager:Replace(Player: Player, NewData: PlayerData): PlayerData
	self:Get(Player)

	self.Store:updateImmutableAsync(Player, function()
		return CopyDeep(NewData)
	end)

	return self.Store:getAsync(Player)
end

function DataManager:ResetToNewPlayerData(Player: Player): PlayerData
	return self:Replace(Player, self:CreateNewPlayerData())
end

function DataManager:Save(Player: Player): PlayerData
	local Data = self:Get(Player)
	self.Store:saveAsync(Player)
	return Data
end

function DataManager:Peek(UserId: number): PlayerData?
	return self.Store:peekAsync(UserId)
end

function DataManager:Unload(Player: Player): ()
	local ExistingPromise = self.LoadPromises[Player]
	if ExistingPromise then
		ExistingPromise:expect()
		self.LoadPromises[Player] = nil
	end

	if not self.LoadedPlayers[Player] then
		return
	end

	local Data = self.Store:getAsync(Player)
	self.Store:unloadAsync(Player)
	self.LoadedPlayers[Player] = nil
	self.Unloaded:Fire(Player, Data)
end

function DataManager:Start()
	if self.Started then
		return self
	end

	if self.Closed then
		error("[DataManager] Cannot restart a closed data manager.")
	end

	self.Started = true

	self.PlayerAddedConnection = Players.PlayerAdded:Connect(function(Player)
		task.spawn(function()
			local Success, ErrorMessage = pcall(function()
				self:Load(Player)
			end)

			if not Success then
				warn(`[DataManager] Failed to load data for {Player.Name}: {ErrorMessage}`)
			end
		end)
	end)

	self.PlayerRemovingConnection = Players.PlayerRemoving:Connect(function(Player)
		local Success, ErrorMessage = pcall(function()
			self:Unload(Player)
		end)

		if not Success then
			warn(`[DataManager] Failed to unload data for {Player.Name}: {ErrorMessage}`)
		end
	end)

	if not self.BoundToClose then
		self.BoundToClose = true
		game:BindToClose(function()
			local Success, ErrorMessage = pcall(function()
				self:Close()
			end)

			if not Success then
				warn(`[DataManager] Failed to close: {ErrorMessage}`)
			end
		end)
	end

	for _, Player in next, Players:GetPlayers() do
		task.spawn(function()
			local Success, ErrorMessage = pcall(function()
				self:Load(Player)
			end)

			if not Success then
				warn(`[DataManager] Failed to load data for {Player.Name}: {ErrorMessage}`)
			end
		end)
	end

	return self
end

function DataManager:Close(): ()
	if self.Closed then
		return
	end

	self.Closed = true
	self.Started = false

	if self.PlayerAddedConnection then
		self.PlayerAddedConnection:Disconnect()
		self.PlayerAddedConnection = nil
	end

	if self.PlayerRemovingConnection then
		self.PlayerRemovingConnection:Disconnect()
		self.PlayerRemovingConnection = nil
	end

	self.Store:closeAsync()
	table.clear(self.LoadPromises)
	table.clear(self.LoadedPlayers)
end

return DataManager
