local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local ServerModules = ServerStorage.Modules

local Conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)
local DataManager = require(ServerModules.Managers.Player.DataManager)
local Sounds = require(ReplicatedStorage.Modules.Shared.Sounds)

local DayNightServer = require(ServerStorage.Modules.Managers.LightingServer)
DayNightServer.Start()

local Build = workspace["objects"]
local Map = Build:WaitForChild("map")
local Pickables = Build:WaitForChild("pickables") -- pickable weapons

local PlayerManagerServer = require(ServerModules.Managers.Player.PlayerManager)

local DestroyOnPickup = {
	Bandage = true;
}

for _,pickable in next, Pickables:GetChildren() do
	local pickUpProximityPrompt = Instance.new("ProximityPrompt")
	pickUpProximityPrompt.Name = "PickUpProximityPrompt"
	pickUpProximityPrompt.ActionText = "Pick Up"
	pickUpProximityPrompt.ObjectText = `Would you like to pick up the {pickable.Name}?`
	pickUpProximityPrompt.RequiresLineOfSight = false
	pickUpProximityPrompt.HoldDuration = .5
	
	pickUpProximityPrompt.Parent = pickable.PrimaryPart
	
	pickUpProximityPrompt.Triggered:Connect(function(player)
		local PlayerManager = PlayerManagerServer.get(player.UserId)
		if PlayerManager and PlayerManager.ToolManager then
			PlayerManager.ToolManager.AddToInventory(player, pickable.Name)
		end
		
		if DestroyOnPickup[pickable.Name] then
			pickable:Destroy()
		end
	end)
end

DataManager:Start()

local ColliisonGroups = {
	"Player";
}

local CollideSettings = {
	["Player"] = {
		["Player"] = false;
	};
}

for _,CollisionGroup in next, ColliisonGroups do
	PhysicsService:RegisterCollisionGroup(CollisionGroup)
end

for Object,Settings in next, CollideSettings do
	for Object2, ShouldCollide in next, Settings do
		PhysicsService:CollisionGroupSetCollidable(Object, Object2, ShouldCollide)
	end
end

for _,Part in next, CollectionService:GetTagged("NoQuery") do
	if Part:IsA("BasePart") then
		Part.CanQuery = false
	end
end

local ConchCommands = ServerModules.misc.conch_commands

for _,module in next, ConchCommands:GetChildren() do
	if module:IsA("ModuleScript") then
		require(module)
	end
end

Conch.initiate_default_lifecycle();
Sounds.init();

require(ConchCommands.Parent.conch_permissions)
