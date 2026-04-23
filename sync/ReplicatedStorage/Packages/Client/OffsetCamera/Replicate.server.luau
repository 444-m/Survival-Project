--!strict

local Players = game:GetService("Players")

local OffsetCamera = script.Parent
local UpdateRemote = OffsetCamera.UpdateRemote
local ResetRemote = OffsetCamera.ResetRemote
local RotateTorso = require(OffsetCamera.RotateTorso)

local lastOrders = {}
local lastReset = {}

Players.PlayerRemoving:Connect(function(player)
	lastOrders[player] = nil
	lastReset[player] = nil
end)

local function isInvalidCharacter(character: unknown, order: unknown)
	assert(typeof(character) == "Instance" and character:IsA("Model"))

	if type(order) ~= "number" or order ~= order or 2^52 < order or order < -2^52 or order ~= order // 1 then
		return true
	end

	if RotateTorso.isR6(character) then
		local rootPart, torso, humanoid, root, left, right = RotateTorso.getComponentsR6(character)
		if not rootPart or not torso or not humanoid or not root or not left or not right then
			return true
		end
	elseif RotateTorso.isR15(character) then
		local rootPart, torso, humanoid, waist = RotateTorso.getComponentsR15(character)
		if not rootPart or not torso or not humanoid or not waist then
			return true
		end
	end
	
	return false
end

UpdateRemote.OnServerEvent:Connect(function(player, character: unknown, order: unknown, torsoPitch: unknown, torsoYaw: unknown)
	if type(torsoPitch) ~= "number" or torsoPitch ~= torsoPitch or torsoPitch < -2 * math.pi or torsoPitch > 2 * math.pi then
		return
	end
	
	if type(torsoYaw) ~= "number" or torsoYaw ~= torsoYaw or torsoYaw < -2 * math.pi or torsoYaw > 2 * math.pi then
		return
	end
	
	local order: number = order :: any
	local pitch: number, yaw: number = torsoPitch, torsoYaw

	if isInvalidCharacter(character, order) then
		return
	end
	
	local lastOrder = lastOrders[player] or -math.huge
	local lastReset = lastReset[player] or -math.huge
	if order < lastOrder or order < lastReset then
		return
	end
	lastOrders[player] = order

	for _, other in Players:GetPlayers() do
		if other ~= player then
			UpdateRemote:FireClient(other, player, order, pitch, yaw)
		end
	end
end)

ResetRemote.OnServerEvent:Connect(function(player, character: unknown, order: unknown)
	if isInvalidCharacter(character, order) then
		return
	end

	local order: number = order :: any
	lastReset[player] = order
	
	for _, other in Players:GetPlayers() do
		if other ~= player then
			ResetRemote:FireClient(other, player, order)
		end
	end
end)

Players.PlayerRemoving:Connect(function(player, reason)
	for _, other in Players:GetPlayers() do
		if other ~= player then
			ResetRemote:FireClient(other, player, math.huge)
		end
	end
end)
