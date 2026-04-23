--!strict

local UpdateRemote = script.Parent.UpdateRemote
local ResetRemote = script.Parent.ResetRemote
local RotateTorso = require(script.Parent.RotateTorso)
local Spring = require(script.Parent.Spring)

local Module = {}

function Module.getRootYaw(cameraCFrame: CFrame, rootPartCFrame: CFrame)
	local relativeCamera = rootPartCFrame:Inverse() * cameraCFrame
	local rcx, rcy, rcz = relativeCamera:ToOrientation()
	return -rcy
end

local order = -2^52
local function replicatePitch(character: Model, pitch: number?, yaw: number?)
	if pitch and yaw then
		UpdateRemote:FireServer(character, order, pitch, yaw)
	else
		ResetRemote:FireServer(character, order)
	end
	order += 1
end

local function getYaws(camera: Camera, rootPart: Part, torso: BasePart, humanoid: Humanoid, data)
	local torsoYaw = Module.getRootYaw(camera.CFrame, rootPart:GetPivot())
	local clampedTorsoYaw = math.clamp(torsoYaw, data.minHeadYaw, data.maxHeadYaw)
	if
		torso:IsGrounded()
		or (humanoid.SeatPart and data.minHeadYaw ~= data.maxHeadYaw)
		or not data.rotateCharacterYawToFollowCamera
	then
		clampedTorsoYaw = clampedTorsoYaw - (torsoYaw - clampedTorsoYaw) * (data.maxHeadYaw - data.minHeadYaw) / (data.minHeadYaw + 2 * math.pi - data.maxHeadYaw)
	end
	
	return torsoYaw, clampedTorsoYaw
end

local spring

local springedCharacter
function Module.setCharacterAngles(OffsetCamera, camera: Camera, character: Model, newPitch: number?)
	local data = OffsetCamera.settings

	springedCharacter = character

	if RotateTorso.isR6(character) then
		local rootPart, torso, humanoid, root, left, right, neck = RotateTorso.getComponentsR6(character)
		if not rootPart or not torso or not humanoid or not root or not left or not right or not neck then
			return
		end

		local torsoYaw, clampedTorsoYaw = getYaws(camera, rootPart, torso, humanoid, data)

		replicatePitch(character, newPitch, clampedTorsoYaw)

		if not newPitch then
			if spring then
				spring.target = Vector3.zero
			end
		else
			local target = Vector3.new(newPitch, clampedTorsoYaw)

			local intialPitch, initialYaw = RotateTorso.getRotationR6(root)
			spring = spring or Spring.new(Vector3.new(intialPitch, initialYaw), data.bendSpeed, 1, function(self)
				local rootPart, torso, humanoid, root, left, right, neck = RotateTorso.getComponentsR6(springedCharacter)
				if not rootPart or not torso or not humanoid or not root or not left or not right or not neck then
					self.disconnect()
					spring = nil
					return
				end

				local pitch = self.position.X
				local yaw = self.position.Y

				if self.target == Vector3.zero then
					if pitch < 1e-4 and yaw < 1e-4 and self.velocity.Magnitude < 1e-4 then
						self.disconnect()
						spring = nil
						RotateTorso.rotateR6(0, 0, 0, 0, rootPart, humanoid, torso, root, left, right, neck)
					end
				end

				local neckPitch, waistPitch = RotateTorso.splitAngles(pitch, data.minHeadPitch, data.maxHeadPitch, data.minTorsoPitchPercent, data.maxTorsoPitchPercent, data.torsoPitchWeight)
				local neckYaw, waistYaw = RotateTorso.splitAngles(yaw, data.minHeadYaw, data.maxHeadYaw, data.minTorsoYawPercent, data.maxTorsoYawPercent, data.torsoYawWeight)
				RotateTorso.rotateR6(waistPitch, waistYaw, neckPitch, neckYaw, rootPart, humanoid, torso, root, left, right, neck)
			end)

			spring.target = target
		end

	elseif RotateTorso.isR15(character) then
		local rootPart, torso, humanoid, waist, neck = RotateTorso.getComponentsR15(character)
		if not rootPart or not torso or not humanoid or not waist or not neck then
			return
		end

		local torsoYaw, clampedTorsoYaw = getYaws(camera, rootPart, torso, humanoid, data)
		replicatePitch(character, newPitch, clampedTorsoYaw)

		if not newPitch then
			if spring then
				spring.target = Vector3.zero
			end
		else
			local target = Vector3.new(newPitch, clampedTorsoYaw)

			local intialPitch, initialYaw = RotateTorso.getRotationR15(waist, neck)
			spring = spring or Spring.new(Vector3.new(intialPitch, initialYaw), data.bendSpeed, 1, function(self)
				local rootPart, torso, humanoid, waist, neck = RotateTorso.getComponentsR15(springedCharacter)
				if not rootPart or not torso or not humanoid or not waist or not neck then
					self.disconnect()
					spring = nil
					return
				end

				local pitch = self.position.X
				local yaw = self.position.Y

				if self.target == Vector3.zero then
					if pitch < 1e-4 and yaw < 1e-4 and self.velocity.Magnitude < 1e-4 then
						self.disconnect()
						spring = nil
						RotateTorso.rotateR15(0, 0, 0, 0, waist, neck)
					end
				end

				local neckPitch, waistPitch = RotateTorso.splitAngles(pitch, data.minHeadPitch, data.maxHeadPitch, data.minTorsoPitchPercent, data.maxTorsoPitchPercent, data.torsoPitchWeight)
				local neckYaw, waistYaw = RotateTorso.splitAngles(yaw, data.minHeadYaw, data.maxHeadYaw, data.minTorsoYawPercent, data.maxTorsoYawPercent, data.torsoYawWeight)
				RotateTorso.rotateR15(waistPitch, waistYaw, neckPitch, neckYaw, waist, neck)
			end)

			spring.target = target
		end
	end
end

local resetHipHeight = 0
function Module.resetHumanoidStuff(OffsetCamera, lastHumanoid: Humanoid)
	assert(lastHumanoid)

	if lastHumanoid.Parent == nil then
		return
	end

	local camera = workspace.CurrentCamera
	local character = lastHumanoid.Parent
	if character and character:IsA("Model") and camera then
		Module.setCharacterAngles(OffsetCamera, camera, character, nil)

		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("Part") and not rootPart:IsGrounded() and not lastHumanoid.SeatPart then
			local cx, cy, cz = camera.CFrame:ToOrientation()
			rootPart:PivotTo(CFrame.fromOrientation(0, cy, 0) + rootPart.Position)
		end
	end
	lastHumanoid.HipHeight = resetHipHeight
	lastHumanoid.AutoRotate = true
end

function Module.setHumanoidStuff(OffsetCamera, newHumanoid: Humanoid)
	resetHipHeight = newHumanoid.HipHeight
end

return Module
