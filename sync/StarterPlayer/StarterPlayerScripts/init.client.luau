local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage.Modules
local ClientModules = Modules.Client
local ClientSystems = ClientModules.Systems

local PlayerManager = require(ReplicatedStorage.Modules.Client.Managers.PlayerManager)

local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local Animations = require(ReplicatedStorage.Modules.Shared.Animations)
local Sounds = require(ReplicatedStorage.Modules.Shared.Sounds)

local Player = Players.LocalPlayer
PlayerManager.new(Player)

Sounds.init()

local DayNightClient = require(ClientModules.Controllers.LightingClient)
DayNightClient.Init()

Networking.Client.ConchInit.On(function(payload)
	if not payload.Active then
		return
	end
	local Conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
	local ConchUI = require(ReplicatedStorage.Packages.Shared.conch_standalone.roblox_packages.ui)

	local ClientConchCommands = ReplicatedStorage.Modules.Client.misc.conch_commands

	for _, module in next, ClientConchCommands:GetChildren() do
		if module:IsA("ModuleScript") then
			require(module)
		end
	end
	
	Conch.initiate_default_lifecycle(); ConchUI.bind_to(Enum.KeyCode.F2)
end)
