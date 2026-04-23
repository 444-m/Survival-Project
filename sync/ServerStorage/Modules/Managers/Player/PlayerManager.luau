local PlayerManager = {}
PlayerManager.__index = PlayerManager

PlayerManager.Managers = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local Janitor = require(SharedPackages.Janitor)
local BlinkServer = require(SharedPackages.Blink.Server)

local Modules = ReplicatedStorage.Modules
local SharedModules = Modules.Shared

local Globals = require(SharedModules.Globals)
local utils = SharedModules.utils
local getRankInGroup = require(utils.getRankInGroup)

local ToolManagerServer = require(script.Parent.ToolManagerServer)
local BetterAnimate = require(SharedPackages.BetterAnimate)

type PlayerManager = typeof(PlayerManager.new())

local lookAnglesConnection
local setLookAnglesEvent

local function bindLookAngleReplication()
	if lookAnglesConnection then
		return
	end

	lookAnglesConnection = BlinkServer.LookAngles.On(function(player: Player, payload)
		if type(payload) ~= "table" then
			return
		end

		local pitch = tonumber(payload.Pitch)
		local yaw = tonumber(payload.Yaw)

		if not pitch or not yaw then
			return
		end

		pitch = math.clamp(pitch, -1, 1)
		yaw = math.clamp(yaw, -1, 1)

		BlinkServer.LookAngles.FireExcept(player, {
			UserId = player.UserId,
			Pitch = pitch,
			Yaw = yaw,
		})
	end)
end

local function setupSetLookAnglesEvent()
	if setLookAnglesEvent then
		return
	end

	local evt = ReplicatedStorage:FindFirstChild("SetLookAngles")
	if not evt or not evt:IsA("RemoteEvent") then
		evt = Instance.new("RemoteEvent")
		evt.Name = "SetLookAngles"
		evt.Parent = ReplicatedStorage
	end

	setLookAnglesEvent = evt

	setLookAnglesEvent.OnServerEvent:Connect(function(player, pitch, yaw)
		if typeof(pitch) ~= "number" or typeof(yaw) ~= "number" then
			return
		end
		setLookAnglesEvent:FireAllClients(player, pitch, yaw)
	end)
end

function PlayerManager.new(Player: Player): PlayerManager
	if PlayerManager.get(Player.UserId) then
		return PlayerManager.get(Player.UserId)
	end

	local self = setmetatable({}, PlayerManager)
	self.Player = Player
	self.PlayerJanitor = Janitor.new()
	self.Character = nil
	self.ToolManager = ToolManagerServer.new(Player)
	self.IdleAnimation = nil

	self:Setup()
	PlayerManager.Managers[self.Player.UserId] = self
	return self
end

function PlayerManager:Setup()
	if not getmetatable(self) then return end
	bindLookAngleReplication()
	setupSetLookAnglesEvent()

	if getRankInGroup.getRank(self.Player.UserId, Globals.GroupId).rank >= Globals.MinAdminRank then
		pcall(function()
			require("@self/admin").setup(self.Player)
		end)
	end

	self.PlayerJanitor:Add(self.Player.CharacterAdded:Connect(function(char)
		self:BindCharacter(char)
	end), "Disconnect", "CharacterAdded")

	if self.Player.Character then
		self:BindCharacter(self.Player.Character)
	end
end

function PlayerManager:BindCharacter(char: Model)
	if self.PlayerJanitor:Get("CharRemoving") then
		self.PlayerJanitor:Remove("CharRemoving")
	end

	self.Character = char

	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid and not CollectionService:HasTag(humanoid, "RealismHook") then
		CollectionService:AddTag(humanoid, "RealismHook")
	end

	self.PlayerJanitor:Add(char.Destroying:Connect(function()
		self.Character = nil
	end), "Disconnect", "CharRemoving")
end

function PlayerManager:Cleanup()
	if not getmetatable(self) then return end

	if self.ToolManager then
		self.ToolManager:Destroy()
		self.ToolManager = nil
	end

	self.PlayerJanitor:Destroy()
	setmetatable(self, nil)
	PlayerManager.Managers[self.Player.UserId] = nil
end

function PlayerManager.get(id: number): PlayerManager
	return PlayerManager.Managers[id]
end

return PlayerManager
