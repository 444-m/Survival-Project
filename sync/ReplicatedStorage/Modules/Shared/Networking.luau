local RunService = game:GetService("RunService")

local Networking = {}

if RunService:IsClient() then
	Networking.Client = require "@game/ReplicatedStorage/Packages/Shared/Blink/Client"
else
	Networking.Server = require "@game/ReplicatedStorage/Packages/Shared/Blink/Server"
end

return Networking
