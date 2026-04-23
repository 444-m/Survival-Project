local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local GunManagerServer = require(ServerStorage.Modules.Systems.Guns.GunManagerServer)

local RevolverSetup = {}
RevolverSetup.Handle = ServerStorage.Assets.Tools.Handles.Revolver.RevolverHandle

local RevolverEquipModel = ServerStorage.Assets.Tools.Equipped.Revolver
local RevolverEquipHandle = ServerStorage.Assets.Tools.Handles.Revolver.Equipped.RevolverHandle

function RevolverSetup:Setup(char: Model, toolModel: Model, data)
	local torso = char:FindFirstChild("Torso")
	if not torso or not toolModel then return end
	toolModel.Parent = torso

	for _,v in next, toolModel:GetDescendants() do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Massless = true
		end
	end

	local revolverHandle = toolModel:WaitForChild("RevolverHandle", 5)
	if not revolverHandle then return end

	local revolverMag: Motor6D = revolverHandle:WaitForChild("Revolver_Mag", 5)
	local revolverBody: Motor6D = revolverHandle:WaitForChild("Revolver_Body", 5)

	if revolverMag then
		revolverMag.Part0 = revolverHandle
		revolverMag.Part1 = toolModel:WaitForChild("Revolver_Mag")
	end

	if revolverBody then
		revolverBody.Part0 = revolverHandle
		revolverBody.Part1 = toolModel:WaitForChild("Revolver_Body")
	end

	local revHandleClone = self.Handle and self.Handle:Clone()
	if revHandleClone then
		revHandleClone.Part0 = torso
		revHandleClone.Part1 = revolverHandle
		revHandleClone.Parent = torso
	end

	if data then
		data.RevHandleClone = revHandleClone
		data.HipModel = toolModel
	end

	return nil, function()
		if revHandleClone then
			revHandleClone:Destroy()
		end
	end
end

function RevolverSetup:RemoveSetup(char: Model, data, models)
	if data and data.RevHandleClone then
		data.RevHandleClone:Destroy()
		data.RevHandleClone = nil
	end
	if models then
		for _, m in next, models do
			if m.Destroy then
				m:Destroy()
			end
		end
		table.clear(models)
	end
end

function RevolverSetup:Equip(char: Model, data, models)
	local rightArm = char:FindFirstChild("Right Arm")
	if not rightArm then return end

	local hipModel = data and data.HipModel
	if hipModel and hipModel.Parent then
		hipModel.Parent = nil
	end

	if not data then return end

	if not data.EquipModel then
		data.EquipModel = RevolverEquipModel:Clone()
	end
	local toolModel = data.EquipModel
	if not toolModel then return end
	toolModel.Parent = rightArm

	for _,v in next, toolModel:GetDescendants() do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Massless = true
		end
	end

	local hipRevolver = char:WaitForChild("Torso"):FindFirstChild("Revolver")
	if hipRevolver then
		hipRevolver:Destroy()
	end

	local revolverHandle = toolModel:WaitForChild("RevolverHandle", 5)
	if not revolverHandle then return end

	local revolverMag: Motor6D = revolverHandle:WaitForChild("Revolver_Mag", 5)
	local revolverBody: Motor6D = revolverHandle:WaitForChild("Revolver_Body", 5)
	local revolverBarrel: Motor6D = toolModel:WaitForChild("Revolver_Body", 5):WaitForChild("Revolver_Barrel", 5)

	if revolverMag then
		revolverMag.Part0 = revolverHandle
		revolverMag.Part1 = toolModel:WaitForChild("Revolver_Mag")
	end

	if revolverBody then
		revolverBody.Part0 = revolverHandle
		revolverBody.Part1 = toolModel:WaitForChild("Revolver_Body")
	end
	
	if revolverBarrel then
		revolverBarrel.Part0 = toolModel:WaitForChild("Revolver_Body")
		revolverBarrel.Part1 = toolModel:WaitForChild("Barrel")
	end

	local revHandleClone = RevolverEquipHandle:Clone()
	if revHandleClone then
		revHandleClone.Part0 = rightArm
		revHandleClone.Part1 = revolverHandle
		revHandleClone.Parent = rightArm
		revHandleClone.Transform = CFrame.new(0,0,.35)
		local spring = advents.spring.new(.35)
		spring.d = .7
		spring.s = 10
		spring.t = 0
		spring.p = .35
		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			revHandleClone.Transform = CFrame.new(0,0,spring.p)
			if math.abs(spring.p) < .01 then
				revHandleClone.Transform = CFrame.identity
				if conn then conn:Disconnect() end
			end
		end)
	end

	if data then
		data.RevHandleClone = revHandleClone
		data.EquipModel = toolModel
	end

	return nil, function()
		if revHandleClone then
			revHandleClone:Destroy()
		end
	end
end

function RevolverSetup:Unequip(char: Model, data, models)
	if data and data.EquipModel then
		data.EquipModel:Destroy()
		data.EquipModel = nil
	end
	if data and data.RevHandleClone then
		data.RevHandleClone:Destroy()
		data.RevHandleClone = nil
	end
	self:Setup(char, ServerStorage.Assets.Tools.Revolver:Clone(), data)
end

function RevolverSetup:Activate(char: Model, data, models, payload)
	local player = Players:GetPlayerFromCharacter(char)
	if not player then return end
	local mgr = GunManagerServer.get(player)
	if not mgr then return end
	if payload and payload.Action == "Reload" then
		mgr:Reload("Revolver", (payload.Value or payload.Amount) or 1)
	else
		mgr:Fire("Revolver", payload and (payload.Value or payload.Amount) or 1, data)
	end
end

return RevolverSetup
