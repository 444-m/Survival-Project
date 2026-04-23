local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserGameSettings = UserSettings():GetService("UserGameSettings")

local advents = require("@game/ReplicatedStorage/Modules/Shared/utils/advents")

local XZ_VECTOR3 = advents.vector.flat

local FpsCamera = {
	HeadMirrors = {};

	HeadAttachments = {
		FaceCenterAttachment = true;
		FaceFrontAttachment = true;
		HairAttachment = true;
		HatAttachment = true;
	};

	InvalidRotationStates = {
		Swimming = true;
		Climbing = true;
		Dead = true;
	};
}

function FpsCamera:Warn(...)
	warn("[FpsCamera]", ...)
end

function FpsCamera:Connect(funcName, event)
	return event:Connect(function(...)
		self[funcName](self, ...)
	end)
end

function FpsCamera:IsInFirstPerson()
	local camera = workspace.CurrentCamera

	if camera then
		if camera.CameraType.Name == "Scriptable" then
			return false
		end

		local focus = camera.Focus.Position
		local origin = camera.CFrame.Position

		return (focus - origin).Magnitude <= 1
	end

	return false
end

function FpsCamera:GetSubjectPosition(...)
	if self:IsInFirstPerson() then
		local camera = workspace.CurrentCamera
		local subject = camera and camera.CameraSubject

		if subject and subject:IsA("Humanoid") and subject.Health > 0 then
			local character = subject.Parent
			local head = character and character:FindFirstChild("Head")

			if head and head:IsA("BasePart") then
				local cf = head.CFrame
				local offset = cf * CFrame.new(0, head.Size.Y / 3, 0)

				return offset.Position, cf.LookVector
			end
		end
	end

	return self:GetBaseSubjectPosition(...)
end

function FpsCamera:IsValidPartToModify(part)
	if part:FindFirstAncestorOfClass("Tool") then
		return false
	end

	if part:IsA("Decal") then
		part = part.Parent
	end

	if part and part:IsA("BasePart") then
		local accessory = part:FindFirstAncestorWhichIsA("Accessory") or part:FindFirstAncestorWhichIsA("Accoutrement")

		if accessory then
			if part.Name ~= "Handle" then
				local handle = accessory:FindFirstChild("Handle", true)

				if handle and handle:IsA("BasePart") then
					part = handle
				end
			end

			for _, child in pairs(part:GetChildren()) do
				if child:IsA("Attachment") and self.HeadAttachments[child.Name] then
					return true
				end
			end
		elseif part.Name == "Head" then
			local model = part.Parent
			local camera = workspace.CurrentCamera
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")

			if humanoid and camera and camera.CameraSubject == humanoid then
				return true
			end
		end
	end

	return false
end

function FpsCamera:MountBaseCamera(BaseCamera)
	local base = BaseCamera.GetSubjectPosition
	self.GetBaseSubjectPosition = base

	if base then
		BaseCamera.GetBaseSubjectPosition = base
		BaseCamera.GetSubjectPosition = self.GetSubjectPosition
	else
		self:Warn("MountBaseCamera - Could not find BaseCamera:GetSubjectPosition()!")
	end
end

function FpsCamera:UpdateTransparency(...)
	assert(self ~= FpsCamera)
	self:BaseUpdate(...)

	if self.ForceRefresh then
		self.ForceRefresh = false

		if self.SetSubject then
			local camera = workspace.CurrentCamera
			if camera then
				self:SetSubject(camera.CameraSubject)
			end
		end
	end
end

function FpsCamera:SetupTransparency(character, ...)
	assert(self ~= FpsCamera)
	self:BaseSetupTransparency(character, ...)

	if self.AttachmentListener then
		self.AttachmentListener:Disconnect()
	end

	self.AttachmentListener = character.DescendantAdded:Connect(function(obj)
		if obj:IsA("Attachment") and self.HeadAttachments[obj.Name] then
			self.cachedParts[obj.Parent] = true
			self.transparencyDirty = true
		end
	end)
end

function FpsCamera:MountTransparency(Transparency)
	local baseUpdate = Transparency.Update

	if baseUpdate then
		Transparency.BaseUpdate = baseUpdate
		--Transparency.Update = self.UpdateTransparency
	else
		self:Warn("MountTransparency - Could not find Transparency:Update()!")
	end

	if Transparency.IsValidPartToModify then
		Transparency.IsValidPartToModify = self.IsValidPartToModify
		Transparency.HeadAttachments = self.HeadAttachments
		Transparency.ForceRefresh = true
	else
		self:Warn("MountTransparency - Could not find Transparency:IsValidPartToModify(part)!")
	end

	if Transparency.SetupTransparency then
		Transparency.BaseSetupTransparency = Transparency.SetupTransparency
		Transparency.SetupTransparency = self.SetupTransparency
	else
		self:Warn("MountTransparency - Could not find Transparency:SetupTransparency(character)!")
	end
end

function FpsCamera:GetShadowAngle()
	local angle = Lighting:GetSunDirection()

	if angle.Y < -.3 then
		angle = Lighting:GetMoonDirection()
	end

	return angle
end

function FpsCamera:MirrorProperty(base, copy, prop)
	base:GetPropertyChangedSignal(prop):Connect(function()
		copy[prop] = base[prop]
	end)
end

function FpsCamera:AddHeadMirror(desc)
	if desc:IsA("BasePart") and self:IsValidPartToModify(desc) then
		local mirror = desc:Clone()
		mirror:ClearAllChildren()

		mirror.Locked = true
		mirror.Anchored = true
		mirror.CanCollide = false
		mirror.Parent = self.MirrorBin

		local function onChildAdded(child)
			local prop

			if child:IsA("DataModelMesh") then
				prop = "Scale"
			elseif child:IsA("Decal") then
				prop = "Transparency"
			end

			if prop then
				local copy = child:Clone()
				copy.Parent = mirror

				self:MirrorProperty(child, copy, prop)
			end
		end

		for _, child in pairs(desc:GetChildren()) do
			onChildAdded(child)
		end

		self.HeadMirrors[desc] = mirror
		self:MirrorProperty(desc, mirror, "Transparency")

		desc.ChildAdded:Connect(onChildAdded)
	end
end

function FpsCamera:RemoveHeadMirror(desc)
	local mirror = self.HeadMirrors[desc]

	if mirror then
		mirror:Destroy()
		self.HeadMirrors[desc] = nil
	end
end

function FpsCamera:OnRotationTypeChanged()
	local camera = workspace.CurrentCamera
	local subject = camera and camera.CameraSubject

	if subject and subject:IsA("Humanoid") then
		local rotationType = UserGameSettings.RotationType

		if rotationType == Enum.RotationType.CameraRelative then
			subject.AutoRotate = false

			RunService:BindToRenderStep("FpsCamera", 1000, function(delta)
				camera = workspace.CurrentCamera
				if subject.AutoRotate or not subject:IsDescendantOf(game) or (subject.SeatPart and subject.SeatPart:IsA("VehicleSeat")) then
					RunService:UnbindFromRenderStep("FpsCamera")
					return
				end

				if not camera or camera.CameraType.Name == "Scriptable" then
					return
				end

				local rootPart = subject.RootPart
				local isGrounded = subject.FloorMaterial ~= Enum.Material.Air
				local inFirstPerson = self:IsInFirstPerson()

				if rootPart and (inFirstPerson or not isGrounded) then
					local state = subject:GetState()
					local canRotate = true

					if self.InvalidRotationStates[state.Name] then
						canRotate = false
					end

					if subject.Sit and subject.SeatPart then
						local root = rootPart.AssemblyRootPart

						if root ~= rootPart then
							canRotate = false
						end
					end

					if canRotate then
						local pos = rootPart.Position
						local step = math.min(.2, (delta * 40) / 3)

						local look = camera.CFrame.LookVector * XZ_VECTOR3
						if look.Magnitude > .001 then
							look = look.Unit

							local cf = CFrame.new(pos, pos + look)
							rootPart.CFrame = rootPart.CFrame:Lerp(cf, step)
						end
					end
				end

				if inFirstPerson then
					local cf = camera.CFrame
					local headPos = self:GetSubjectPosition(subject)

					if headPos then
						local offset = headPos - cf.Position
						cf = cf + offset

						camera.CFrame = cf
						camera.Focus = camera.Focus + offset
					end

					local shadowAngle = self:GetShadowAngle()
					local inView = cf.LookVector:Dot(shadowAngle)

					if inView < 0 then
						for real, mirror in pairs(self.HeadMirrors) do
							mirror.CFrame = real.CFrame + (shadowAngle * 9)
						end
					end

					self.MirrorBin.Parent = (inView < 0 and camera or nil)
				else
					self.MirrorBin.Parent = nil
				end
			end)
		else
			subject.AutoRotate = true
			if self.MirrorBin then
				self.MirrorBin.Parent = nil
			end
			RunService:UnbindFromRenderStep("FpsCamera")
		end
	end
end

function FpsCamera:OnCharacterAdded(character)
	local mirrorBin = self.MirrorBin

	if mirrorBin then
		mirrorBin:ClearAllChildren()
		mirrorBin.Parent = nil
	end

	self.HeadMirrors = {}

	for _, desc in pairs(character:GetDescendants()) do
		self:AddHeadMirror(desc)
	end

	if self.DescendantAddedConnection then
		self.DescendantAddedConnection:Disconnect()
	end
	if self.DescendantRemovingConnection then
		self.DescendantRemovingConnection:Disconnect()
	end

	self.DescendantAddedConnection = self:Connect("AddHeadMirror", character.DescendantAdded)
	self.DescendantRemovingConnection = self:Connect("RemoveHeadMirror", character.DescendantRemoving)
end

local started = false

function FpsCamera:Start()
	if started then
		return
	else
		started = true
	end

	local player = Players.LocalPlayer
	local character = player.Character

	local PlayerScripts = player:WaitForChild("PlayerScripts")
	local PlayerModule = PlayerScripts:WaitForChild("PlayerModule")

	local baseCamera = PlayerModule:FindFirstChild("BaseCamera", true)
	local transparency = PlayerModule:FindFirstChild("TransparencyController", true)

	if baseCamera and baseCamera:IsA("ModuleScript") then
		local module = require(baseCamera)
		self:MountBaseCamera(module)
	else
		self:Warn("Start - Could not find BaseCamera module!")
	end

	if transparency and transparency:IsA("ModuleScript") then
		local module = require(transparency)
		self:MountTransparency(module)
	else
		self:Warn("Start - Could not find TransparencyController module!")
	end

	local rotListener = UserGameSettings:GetPropertyChangedSignal("RotationType")
	self:Connect("OnRotationTypeChanged", rotListener)

	self.MirrorBin = Instance.new("Folder")
	self.MirrorBin.Name = "HeadMirrors"

	if character then
		self:OnCharacterAdded(character)
	end

	self:Connect("OnCharacterAdded", player.CharacterAdded)
	self:OnRotationTypeChanged()
end

return FpsCamera
