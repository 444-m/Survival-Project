local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Networking = require(ReplicatedStorage.Modules.Shared.Networking)

local BlinkServer = Networking.Server

local BloodServer = {}

function BloodServer.Splat(hitPos: Vector3, hitNormal: Vector3)
	BlinkServer.BloodSpawn.FireAll({
		X = hitPos.X; Y = hitPos.Y; Z = hitPos.Z;
		NX = hitNormal.X; NY = hitNormal.Y; NZ = hitNormal.Z;
	})
end

return BloodServer