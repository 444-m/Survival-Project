local Players = game:GetService("Players")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local Tools = require(ReplicatedStorage.Modules.Shared.Storage.Tools)
local DamageManagerServer = require(ServerStorage.Modules.Managers.DamageManagerServer)
local ease = advents.easing

local BandageSetup = {}
BandageSetup.Handle = ServerStorage.Assets.Tools.Handles.Bandage.Equipped["bandage.001"]

local BandageEquipModel = ServerStorage.Assets.Tools.Equipped["bandage.001"]
local BandageEquipHandle = ServerStorage.Assets.Tools.Handles.Bandage.Equipped["bandage.001"]

function BandageSetup:Equip(char: Model, data, models)
	local humanoid: Humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	if humanoid.Health >= humanoid.MaxHealth then
		return
	end
	
	local rightArm = char:FindFirstChild("Right Arm")
	local leftArm = char:FindFirstChild("Left Arm")
	if not rightArm then return end
	
	local equipModel = BandageEquipModel:Clone()
	equipModel.Parent = rightArm
	
	local handleMotor = BandageEquipHandle:Clone()
	handleMotor.Part0 = rightArm
	handleMotor.Part1 = equipModel
	handleMotor.Parent = rightArm
	
	data.EquipModel = equipModel
	data.BandageHandleClone = handleMotor
end

function BandageSetup:Unequip(char: Model, data, models)
	if data and data.EquipModel then
		data.EquipModel:Destroy()
		data.EquipModel = nil
	end
	if data and data.BandageHandleClone then
		data.BandageHandleClone:Destroy()
		data.BandageHandleClone = nil
	end
end

function BandageSetup:Activate(char: Model, data, models, payload)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return false end
	if humanoid.Health >= humanoid.MaxHealth then
		return false
	end

	local heal = type(data) == "table" and tonumber(data.heal) or nil
	heal = heal or 25
	if heal <= 0 then return false end

	local maxHealth = humanoid.MaxHealth
	local startHealth = humanoid.Health
	local target = math.min(maxHealth, startHealth + heal)
	local delta = target - startHealth
	if delta <= 0 then
		return false
	end

	local duration = nil
	if type(data) == "table" and tonumber(data.healDuration) then
		duration = tonumber(data.healDuration)
	elseif type(payload) == "table" and tonumber(payload.healDuration) then
		duration = tonumber(payload.healDuration)
	else
		duration = Tools.Bandage and Tools.Bandage.Stun and Tools.Bandage.Stun.duration or 1
	end
	duration = math.clamp(duration, .4, 6)
	local start = os.clock()

	while true do
		local alpha = math.clamp((os.clock() - start) / math.max(duration, .1), 0, 1)
		local stepTarget = startHealth + delta * ease.hermite(alpha, "out")
		local current = DamageManagerServer.GetHP(char)
		local add = stepTarget - current
		if add > 0 then
			DamageManagerServer.Heal(char, add)
		end
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end

	if data and data.EquipModel then
		local endLen = (type(data) == "table" and tonumber(data.endLength)) or (type(payload) == "table" and tonumber(payload.endLength)) or .6
		local function destroyModel()
			if data and data.EquipModel then
				data.EquipModel:Destroy()
				data.EquipModel = nil
			end
			if data and data.BandageHandleClone then
				data.BandageHandleClone:Destroy()
				data.BandageHandleClone = nil
			end
			if models then
				for i, m in next, models do
					if m and m.Destroy then
						pcall(function()
							m:Destroy()
						end)
					end
					models[i] = nil
				end
			end
		end
		task.delay(math.max(endLen, .05), destroyModel)
	end

	return true
end

return BandageSetup
