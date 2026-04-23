local Spring = require(script.Parent.Spring)

local UpdateRemote = script.Parent.UpdateRemote
local ResetRemote = script.Parent.ResetRemote

local OffsetCameraModule = script.Parent
local OffsetCamera = require(OffsetCameraModule)
local RotateTorso = require(OffsetCameraModule.RotateTorso)

local lastOrders = {}
local lastReset = {}

local playerSprings = {}

UpdateRemote.OnClientEvent:Connect(function(player: Player, order: number, newTorsoPitch: number, newTorsoYaw: number)
	local lastOrder = lastOrders[player] or -math.huge
	local lastReset = lastReset[player] or -math.huge
	if order < lastOrder or order < lastReset then
		return
	end
	lastOrders[player] = order
	
	local initialCharacter = player.Character
	if not initialCharacter then
		return
	end

	local data = OffsetCamera.settings

	local target = Vector3.new(newTorsoPitch, newTorsoYaw)

	local initialPitch, initialYaw = RotateTorso.getRotation(initialCharacter)
	local spring = playerSprings[player] or Spring.new(target, data.bendSpeed, 1, function(self)
		local character = player.Character
		if not character then
			self.disconnect()
			playerSprings[player] = nil
			return
		end

		local pitch = self.position.X
		local yaw = self.position.Y

		if self.target == Vector3.zero then
			if pitch < 1e-4 and yaw < 1e-4 and self.velocity.Magnitude < 1e-4 then
				self.disconnect()
				playerSprings[player] = nil
				RotateTorso.reset(character)
				return
			end
		end

		local neckPitch, waistPitch = RotateTorso.splitAngles(pitch, data.minHeadPitch, data.maxHeadPitch, data.minTorsoPitchPercent, data.maxTorsoPitchPercent, data.torsoPitchWeight)
		local neckYaw, waistYaw = RotateTorso.splitAngles(yaw, data.minHeadYaw, data.maxHeadYaw, data.minTorsoYawPercent, data.maxTorsoYawPercent, data.torsoYawWeight)
		RotateTorso.rotate(character, waistPitch, waistYaw, neckPitch, neckYaw)
	end)
	playerSprings[player] = spring
	
	spring.target = target
end)

ResetRemote.OnClientEvent:Connect(function(player: Player, order: number?)
	lastReset[player] = order

	local spring = playerSprings[player]
	if spring then
		spring.target = Vector3.zero
	end
end)