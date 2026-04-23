local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local PlayerController = {}
PlayerController.__index = PlayerController

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local ClientModules = ReplicatedStorage.Modules.Client

local Janitor = require(SharedPackages.Janitor)
local CharacterController = require("./PlayerController/CharacterController") 
local LevelHandler = require("./PlayerController/LevelHandler")

local MovementConfigs = require(ClientModules.Controllers.Movement.configs)
local StateManagerClient = require(ClientModules.Systems.StateManagerClient)
local HUDManager = require(ReplicatedStorage.Modules.Client.Managers.HUD)

PlayerController.LocalController = nil

function PlayerController.new(Player: Player)
    local self = setmetatable({}, PlayerController)
    self.Player = Player

    self.PlayerJanitor = Janitor.new()
	self.StateManagerClient = StateManagerClient.NewEntity(Player.UserId, "Idling")
	
    self.LevelHandler = LevelHandler.new(Player)
	self.LevelHandler:Start()
	
	self.HUD = HUDManager.new()

	local function updateHUD()
		if not self.HUD or not getmetatable(self.HUD) then
			return
		end

		local Stats: HUDManager.Stats = {
			Level = self.LevelHandler.level;
			XP = {
				Current = self.LevelHandler.currentXP;
				Needed = self.LevelHandler.requiredXPForNextLevel;
			}
		}
		self.HUD:UpdateStats(Stats)
	end

	updateHUD()
	self.PlayerJanitor:Add(self.LevelHandler.Changed:Connect(updateHUD), "Disconnect", "LevelHUDSync")
	self.PlayerJanitor:Add(self.LevelHandler.LeveledUp:Connect(function(_, Payload)
		local newLevel = Payload and Payload.NewLevel or self.LevelHandler.level
		local oldLevel = Payload and Payload.OldLevel or self.LevelHandler.oldLevel
		local levelsGained = math.max(1, math.floor((newLevel or 1) - (oldLevel or 0)))
		local boostStrength = 1
		local boostDuration = MovementConfigs.LevelUpBoostDuration or 0

		if MovementConfigs.ApplyLevelUpBoost then
			boostStrength, boostDuration = MovementConfigs.ApplyLevelUpBoost(levelsGained)
		end

		if self.CharacterController and getmetatable(self.CharacterController) and self.CharacterController.ApplyLevelUpBoost then
			self.CharacterController:ApplyLevelUpBoost(levelsGained, boostStrength, boostDuration)
		end
	end), "Disconnect", "LevelMovementBoost")

    self.PlayerJanitor:Add(Player.CharacterAdded:Connect(function(Character)
        self:OnCharacter(Character)
	end), "Disconnect", "OnCharacter"); if Player.Character then self:OnCharacter(Player.Character) end 
	
	self.PlayerJanitor:Add(Players.PlayerRemoving:Connect(function(Player)
		if self.Player == Player then
			if getmetatable(self) then
				self:Destroy()
			end
			
			StateManagerClient.RemoveEntity(Player.UserId)
		end
	end), "Disconnect", "OnPlayerRemoving")

	if Player == Players.LocalPlayer then
		PlayerController.LocalController = self
	end

    return self
end

function PlayerController.GetLocalController()
	return PlayerController.LocalController
end

function PlayerController:OnCharacter(Character: Model)
    self.Character = Character
    self.CharacterController = CharacterController.new(Character, MovementConfigs)

	self.CharacterController:Setup()
	local Humanoid: Humanoid = Character:WaitForChild("Humanoid")
	
	self.PlayerJanitor:Add(Humanoid.Died:Connect(function()
		StateManagerClient.BruteChangeState(self.Player.UserId, "Idling")
		self.CharacterController:Destroy()
	end), "Disconnect", "OnPlayerDied")

	self.PlayerJanitor:Add(self.Player.CharacterRemoving:Connect(function()
		if not getmetatable(self) or not getmetatable(self.CharacterController) then return end
        self.CharacterController:Destroy()
    end), "Disconnect", "OnCharacterRemoving")
end

function PlayerController:Destroy()
    if self.CharacterController then self.CharacterController:Destroy() end    
	if getmetatable(self.HUD) then self.HUD:Destroy() end            
    if self.LevelHandler and getmetatable(self.LevelHandler) then self.LevelHandler:Destroy() end

	if PlayerController.LocalController == self then
		PlayerController.LocalController = nil
	end

    self.PlayerJanitor:Cleanup()
    setmetatable(self, nil)
end

return PlayerController