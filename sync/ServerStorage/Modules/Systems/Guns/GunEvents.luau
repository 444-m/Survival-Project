local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Shared.Signal)

return {
	OnHit = Signal();
}