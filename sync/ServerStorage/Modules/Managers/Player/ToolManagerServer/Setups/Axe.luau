local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)

local AxeSetup = {}
AxeSetup.HandleTemplate = ServerStorage.Assets.Tools.Handles.Axe.Handle

local Axe = ServerStorage.Assets.Tools.Axe

function AxeSetup:Setup(char: Model, toolModel: Model, data)
	if not char or not toolModel then return end

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not torso then return end

	toolModel.Parent = torso

	for _, v in next, toolModel:GetDescendants() do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Massless = true
		end
	end

	local axeMesh = toolModel:FindFirstChild("AxeMesh") or toolModel
	local axeWeld: Weld = toolModel:FindFirstChild("AxeWeld")
	axeWeld.Part0 = torso
	axeWeld.Part1 = axeMesh

	if data then
		data.HolsterModel = toolModel
		data.AxeMesh = axeMesh
		data.AxeWeld = axeWeld
	end
end

function AxeSetup:RemoveSetup(char: Model, data, models)
	if data then
		if data.EquipMotor then
			data.EquipMotor:Destroy()
			data.EquipMotor = nil
		end
		if data.HolsterMotor then
			data.HolsterMotor:Destroy()
			data.HolsterMotor = nil
		end
		data.HolsterModel = nil
		data.EquipModel = nil
		data.AxeMesh = nil
		data.AxeHandle = nil
		data.AxeWeld = nil
	end
	if models then
		for _, m in next, models do
			if m.Destroy then m:Destroy() end
		end
		table.clear(models)
	end
end

function AxeSetup:Equip(char: Model, data, models)
	local rightArm = char:FindFirstChild("Right Arm") or char:FindFirstChild("RightUpperArm")
	if not rightArm then return end

	if data and data.HolsterMotor then
		data.HolsterMotor:Destroy()
		data.HolsterMotor = nil
	end
	if data and data.HolsterModel then
		data.HolsterModel.Parent = nil
	end
	if data and data.EquipMotor then
		data.EquipMotor:Destroy()
		data.EquipMotor = nil
	end
	if data and data.EquipModel then
		if models then
			for i, m in next, models do
				if m == data.EquipModel then
					table.remove(models, i)
					break
				end
			end
		end
		data.EquipModel:Destroy()
		data.EquipModel = nil
	end

	local toolTemplate = ServerStorage.Assets.Tools.Equipped:FindFirstChild("Axe")
	local toolModel = toolTemplate and toolTemplate:Clone()
	if not toolModel then return end

	toolModel.Parent = rightArm

	for _, v in next, toolModel:GetDescendants() do
		if v:IsA("BasePart") then
			v.CanCollide = false
			v.Massless = true
		end
	end

	local AxeMesh = toolModel:FindFirstChild("AxeMesh") or toolModel
	local ToolHandle = AxeMesh and AxeMesh:FindFirstChild("Handle") or toolModel:FindFirstChild("Handle")
	if not ToolHandle then
		toolModel:Destroy()
		return
	end

	local AxeWeld: Weld = ToolHandle:FindFirstChild("AxeWeld") or Instance.new("Weld")
	AxeWeld.Name = "AxeWeld"
	AxeWeld.Part0 = ToolHandle
	AxeWeld.Part1 = AxeMesh:IsA("BasePart") and AxeMesh or ToolHandle
	AxeWeld.Parent = ToolHandle

	local AxeHandleMotorClone = AxeSetup.HandleTemplate and AxeSetup.HandleTemplate:Clone()
	if AxeHandleMotorClone then
		AxeHandleMotorClone.Part0 = rightArm
		AxeHandleMotorClone.Part1 = ToolHandle
		AxeHandleMotorClone.Parent = rightArm
		AxeHandleMotorClone.Transform = CFrame.new(0, .6, 0)

		local spring = advents.spring.new(.6)
		spring.d = .55
		spring.s = 7
		spring.t = 0
		spring.p = .6

		local conn
		conn = RunService.Heartbeat:Connect(function(dt)
			AxeHandleMotorClone.Transform = CFrame.new(0, spring.p, 0)
			if math.abs(spring.p) < .01 then
				AxeHandleMotorClone.Transform = CFrame.identity
				if conn then conn:Disconnect() end
			end
		end)
	end

	if models then table.insert(models, toolModel) end
	if data then
		data.EquipMotor = AxeHandleMotorClone
		data.EquipModel = toolModel
		data.AxeMesh = AxeMesh
		data.AxeHandle = ToolHandle
		data.AxeWeld = AxeWeld
	end
end

function AxeSetup:Unequip(char: Model, data, models)
	if data and data.EquipMotor then
		data.EquipMotor:Destroy()
		data.EquipMotor = nil
	end
	if data and data.EquipModel then
		if models then
			for i, m in next, models do
				if m == data.EquipModel then
					table.remove(models, i)
					break
				end
			end
		end
		data.EquipModel:Destroy()
		data.EquipModel = nil
	end

	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	if not torso then return end

	local holster = data and data.HolsterModel
	if not holster then
		local toolTemplate = ServerStorage.Assets.Tools:FindFirstChild("Axe") or Axe
		holster = toolTemplate and toolTemplate:Clone()
		if holster and models then table.insert(models, holster) end
		if data then data.HolsterModel = holster end
	end

	self:Setup(char, holster, data)
end

local function treeFall(tree: Model)
	for _, child in tree:GetChildren() do
		if child:IsA("BasePart") then
			child.Anchored = false
			if child.Name == "ChopPart" then
				local canopy = child:FindFirstChild("Canopy")
				if canopy then canopy:Destroy() end
			end
		end
	end
end

local function treeChop(tree: Model, chopPart: BasePart)
	if not tree:GetAttribute("Health") then
		tree:SetAttribute("Health", 100)
	end
	tree:SetAttribute("Health", tree:GetAttribute("Health") - 10)
	advents.sounds.play({
		soundId = "Tools/Axe/WoodChop";
		mode = "part";
		target = chopPart;
	})
	if tree:GetAttribute("Health") <= 0 then
		treeFall(tree)
	end
end

local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Include
overlapParams.FilterDescendantsInstances = {workspace:WaitForChild("objects").map.Trees}

local function hitLoop(handle: BasePart)
	local dmg_effect_time = 0
	local range = 3
	local damaged = {}

	for step = 0, dmg_effect_time, dmg_effect_time / 35 do
		task.wait(dmg_effect_time / 35)
		local parts = workspace:GetPartBoundsInRadius(handle.Position, range, overlapParams)
		for _, hitPart in next, parts do
			if hitPart.Name ~= "ChopPart" then continue end
			local tree = hitPart.Parent
			if tree and tree:IsA("Model") and not damaged[tree] then
				damaged[tree] = true
				advents.sounds.play({
					soundId = "Tools/Axe/Hit";
					mode = "part";
					target = hitPart;
				})
				treeChop(tree, hitPart)
			end
		end
	end
end

function AxeSetup:Activate(char: Model, data, models, payload)
	task.spawn(function()
		hitLoop(data.AxeHandle)
	end)
end

return AxeSetup