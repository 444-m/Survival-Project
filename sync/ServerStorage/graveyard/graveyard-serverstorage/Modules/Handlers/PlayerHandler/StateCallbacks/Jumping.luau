local ReplicatedStorage = game:GetService("ReplicatedStorage")

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local sounds = advents.sounds

local Globals = require(ReplicatedStorage.Modules.Shared.Globals)

local Jump = {}

function Jump.Start(Character: Model)
	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
	if not HRP or not Humanoid then return end
	
	local RayParams = RaycastParams.new()
	RayParams.FilterDescendantsInstances = {Globals.MapContainer}
	RayParams.FilterType = Enum.RaycastFilterType.Include
	
	local IsGrounded = workspace:Raycast(HRP.Position, HRP.CFrame.UpVector * -9.7, RayParams)

	if IsGrounded then
		sounds.play({
			soundId = "Movement/Jump";
			mode = "position";
			position = HRP.Position;
		})
	end
end

return Jump