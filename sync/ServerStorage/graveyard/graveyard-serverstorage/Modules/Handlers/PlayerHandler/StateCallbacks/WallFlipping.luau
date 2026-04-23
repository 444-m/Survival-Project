local ReplicatedStorage = game:GetService("ReplicatedStorage")

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local sounds = advents.sounds

local Globals = require(ReplicatedStorage.Modules.Shared.Globals)

local WallFlipping = {}

function WallFlipping.Start(Character: Model)
	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
	if not HRP or not Humanoid then return end
	
	sounds.play({
		soundId = "Movement/WallFlip";
		mode = "position";
		position = HRP.Position;
	})
end

return WallFlipping