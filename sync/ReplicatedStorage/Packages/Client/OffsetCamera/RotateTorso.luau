--!strict

local Module = {}

function Module.getTorso(character: Instance): BasePart?
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso") :: any 
end

function Module.splitAngles(angle: number, headMin: number, headMax: number, waistMinPercent: number, waistMaxPercent: number, waistWeight: number)
	local waistAngle = 0
	if angle < 0 then
		waistAngle = if math.abs(headMin) <= 1e-4 then 0 else headMin * waistMinPercent * (angle / headMin) ^ waistWeight
	elseif angle > 0 then
		waistAngle = if math.abs(headMax) <= 1e-4 then 0 else headMax * waistMaxPercent * (angle / headMax) ^ waistWeight
	end
	
	local neckAngle = angle - waistAngle
	return neckAngle, waistAngle
end

local ETA = math.pi / 2
local PI = math.pi

function Module.rotateR6(waistPitch: number, waistYaw: number, neckPitch: number, neckYaw: number, rootPart: Part, humanoid: Humanoid, torso: BasePart, root: Motor6D, left: Motor6D, right: Motor6D, neck: Motor6D)
	local hipHeightOffset = (math.cos(waistPitch) - 1) * torso.Size.Y / 2
	humanoid.HipHeight = hipHeightOffset

	root.C1 = CFrame.fromOrientation(waistPitch - ETA, PI, waistYaw) + root.C1.Position
	
	if waistYaw ~= 0 then
		left.C0 = left.C0.Rotation + Vector3.new(0, -1, 0)
		left.C1 = left.C1.Rotation + Vector3.new(0.5, 1, 0)
		
		right.C0 = right.C0.Rotation + Vector3.new(0, -1, 0)
		right.C1 = right.C1.Rotation + Vector3.new(-0.5, 1, 0)
	else
		left.C0 = left.C0.Rotation + Vector3.new(-1, -1, 0)
		left.C1 = left.C1.Rotation + Vector3.new(-0.5, 1, 0)
		
		right.C0 = right.C0.Rotation + Vector3.new(1, -1, 0)
		right.C1 = right.C1.Rotation + Vector3.new(0.5, 1, 0)
	end
	
	left.C1 = CFrame.fromOrientation(0, -waistYaw - ETA, -waistPitch) + left.C1.Position
	right.C1 = CFrame.fromOrientation(0, -waistYaw + ETA, waistPitch) + right.C1.Position
	
	neck.C1 = CFrame.fromOrientation(neckPitch - ETA, neckYaw - PI, 0) + neck.C1.Position
end

function Module.rotateR15(waistPitch: number, waistYaw: number, neckPitch: number, neckYaw: number, waist: Motor6D, neck: Motor6D)
	waist.C1 = CFrame.fromEulerAnglesXYZ(-waistPitch, waistYaw, 0) + waist.C1.Position
	neck.C1 = CFrame.fromOrientation(-neckPitch, neckYaw, 0) + neck.C1.Position
end

local oldHipHeights = {}

local function cleanupHipHeight(humanoid: Humanoid)
	local oldHipHeightData = oldHipHeights[humanoid]
	if oldHipHeightData then
		humanoid.HipHeight = oldHipHeightData.offset
		oldHipHeightData.reparented:Disconnect()
		oldHipHeights[humanoid] = nil
	end
end

local function cacheHipHeight(humanoid: Humanoid)
	if not oldHipHeights[humanoid] then
		oldHipHeights[humanoid] = {
			offset = humanoid.HipHeight,
			reparented = humanoid.AncestryChanged:Connect(function()
				if not humanoid.Parent then
					cleanupHipHeight(humanoid)
				end
			end),
		}
	end
end

function Module.isR6(character: Model)
	return not not character:FindFirstChild("Torso")
end

function Module.isR15(character: Model)
	return not not character:FindFirstChild("UpperTorso")
end

function Module.getComponentsR6(character: Model): (Part?, Part?, Humanoid?, Motor6D?, Motor6D?, Motor6D?, Motor6D?)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("Torso")
	if not rootPart or not rootPart:IsA("Part") or not torso or not torso:IsA("Part") then
		return nil, nil, nil, nil, nil, nil, nil
	end

	local rootJoint = rootPart:FindFirstChild("RootJoint")
	local leftJoint = torso:FindFirstChild("Left Hip")
	local rightJoint = torso:FindFirstChild("Right Hip")
	local neckJoint = torso:FindFirstChild("Neck")
	if 
		not rootJoint or not rootJoint:IsA("Motor6D") or
		not leftJoint or not leftJoint:IsA("Motor6D") or
		not rightJoint or not rightJoint:IsA("Motor6D") or
		not neckJoint or not neckJoint:IsA("Motor6D")
	then
		return nil, nil, nil, nil, nil, nil, nil
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil, nil, nil, nil, nil, nil
	end
	
	return rootPart, torso, humanoid, rootJoint, leftJoint, rightJoint, neckJoint
end

function Module.getComponentsR15(character: Model): (Part?, BasePart?, Humanoid?, Motor6D?, Motor6D?)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso")
	local head = character:FindFirstChild("Head")
	if not rootPart or not rootPart:IsA("Part") or not torso or not torso:IsA("BasePart") or not head or not head:IsA("BasePart") then
		return nil, nil, nil, nil, nil
	end
	
	local waistJoint = torso:FindFirstChild("Waist")
	local neckJoint = head:FindFirstChild("Neck")
	if
		not waistJoint or not waistJoint:IsA("Motor6D") or
		not neckJoint or not neckJoint:IsA("Motor6D")
	then
		return nil, nil, nil, nil, nil
	end
	
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil, nil, nil, nil, nil
	end
	
	return rootPart, torso, humanoid, waistJoint, neckJoint
end

-- Pitch, Yaw
function Module.getRotationR6(root: Motor6D)
	local rx, ry, rz = root.C1:ToOrientation()
	return rx + ETA, rz
end

-- Pitch, Yaw
function Module.getRotationR15(waist: Motor6D, neck: Motor6D)
	local wx, wy, wz = waist.C1:ToEulerAnglesXYZ()
	local nx, ny, nz = neck.C1:ToOrientation()
	return -wx + -nx, wy + ny
end

-- Pitch, Yaw
function Module.getRotation(character: Model)
	if Module.isR6(character) then
		local rootPart, torso, humanoid, root, left, right, neck = Module.getComponentsR6(character)
		if not rootPart or not torso or not humanoid or not root or not left or not right or not neck then
			return
		end

		return Module.getRotationR6(root)
	elseif Module.isR15(character) then
		local rootPart, torso, humanoid, waist, neck = Module.getComponentsR15(character)
		if not rootPart or not torso or not humanoid or not waist or not neck then
			return
		end

		return Module.getRotationR15(waist, neck)
	end
end


function Module.rotate(character: Model, newWaistPitch: number, newWaistYaw: number, newNeckPitch: number, newNeckYaw: number)
	if Module.isR6(character) then
		local rootPart, torso, humanoid, root, left, right, neck = Module.getComponentsR6(character)
		if not rootPart or not torso or not humanoid or not root or not left or not right or not neck then
			return
		end
		
		cacheHipHeight(humanoid)
		Module.rotateR6(newWaistPitch, newWaistYaw, newNeckPitch, newNeckYaw, rootPart, humanoid, torso, root, left, right, neck)
	elseif Module.isR15(character) then
		local rootPart, torso, humanoid, waist, neck = Module.getComponentsR15(character)
		if not rootPart or not torso or not humanoid or not waist or not neck then
			return
		end

		Module.rotateR15(newWaistPitch, newWaistYaw, newNeckPitch, newNeckYaw, waist, neck)
	end
end

function Module.reset(character: Model)
	if Module.isR6(character) then
		local rootPart, torso, humanoid, root, left, right, neck = Module.getComponentsR6(character)
		if not rootPart or not torso or not humanoid or not root or not left or not right or not neck then
			return
		end

		cleanupHipHeight(humanoid)
		Module.rotateR6(0, 0, 0, 0, rootPart, humanoid, torso, root, left, right, neck)

	elseif Module.isR15(character) then
		local rootPart, torso, humanoid, waist, neck = Module.getComponentsR15(character)
		if not rootPart or not torso or not humanoid or not waist or not neck then
			return
		end

		Module.rotateR15(0, 0, 0, 0, waist, neck)
	end
end

return Module
