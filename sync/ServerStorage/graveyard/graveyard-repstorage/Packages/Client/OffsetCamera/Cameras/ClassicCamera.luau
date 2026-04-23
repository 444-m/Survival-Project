--!strict

local UserInputService = game:GetService("UserInputService")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

if not RunService:IsClient() then
	error(`{script:GetFullName()} must only be required from the client!`)
end

local PlayerScripts = Players.LocalPlayer.PlayerScripts
local PlayerModuleScript = PlayerScripts:WaitForChild("PlayerModule")
local PlayerModule = require(PlayerModuleScript)

local CameraModuleScript = PlayerModuleScript:WaitForChild("CameraModule")
local CameraInput = require(CameraModuleScript:WaitForChild("CameraInput"))
local Util = require(CameraModuleScript:WaitForChild("CameraUtils"))

local FlagUtil = require(PlayerModuleScript.CommonUtils.FlagUtil)
local FFlagUserCameraInputDt = FlagUtil.getUserFlag("UserCameraInputDt")
local FFlagUserFixCameraFPError = FlagUtil.getUserFlag("UserFixCameraFPError")

local ZoomController = require(CameraModuleScript.ZoomController)

local ControlModule = PlayerModule:GetControls()
local CameraModule = PlayerModule:GetCameras()

local RotateAndReplicate = require(script.Parent.Parent.RotateAndReplicate)
local ZoomOffsets = require(script.Parent.Parent.ZoomOffsets)
local Spring = require(script.Parent.Parent.Spring)

local Module = {}

local oldGetSubjectPosition
local oldCalculateNewLookCFrameFromArg
local oldOcclusionUpdate
local oldUpdate

function Module.resetOldControllerMethods()
	CameraModule.activeCameraController.Update = oldUpdate
	CameraModule.activeCameraController.GetSubjectPosition = oldGetSubjectPosition
	CameraModule.activeCameraController.CalculateNewLookCFrameFromArg = oldCalculateNewLookCFrameFromArg

	CameraModule.activeOcclusionModule.Update = oldOcclusionUpdate

	oldUpdate = nil
	oldGetSubjectPosition = nil
	oldCalculateNewLookCFrameFromArg = nil

	oldOcclusionUpdate = nil
end

function Module.setNewControllerMethods(OffsetCamera)
	local function getSubjectPivot(self): (CFrame?, Instance?)
		local SEAT_OFFSET = Vector3.new(0,5,0)
		local HEAD_OFFSET = Vector3.new(0,1.5,0)
		local R15_HEAD_OFFSET = Vector3.new(0, 1.5, 0)
		local R15_HEAD_OFFSET_NO_SCALING = Vector3.new(0, 2, 0)
		local HUMANOID_ROOT_PART_SIZE = Vector3.new(2, 2, 1)

		local result = CFrame.new(self.lastSubjectPosition)
		local camera = game.Workspace.CurrentCamera
		local cameraSubject = camera and camera.CameraSubject
		local data = OffsetCamera.settings

		if cameraSubject then
			local subject

			local name = data.subjectName
			if name then
				local character = cameraSubject.Parent
				if cameraSubject:IsA("Humanoid") and character then
					subject = character:FindFirstChild(name, true)
				elseif cameraSubject:IsA("VehicleSeat") and not data.centerOnVehicle then
					subject = cameraSubject.Occupant
				else
					subject = cameraSubject:FindFirstChild(name, true)
				end
			else
				subject = cameraSubject
			end

			if not subject then
				subject = cameraSubject
			end

			if subject:IsA("Humanoid") then
				local humanoid = subject
				local humanoidIsDead = humanoid:GetState() == Enum.HumanoidStateType.Dead

				local cameraOffset = humanoid.CameraOffset
				-- when in mouse lock mode, the character's rotation follows the camera instead of vice versa.
				-- Allow the mouse lock calculation to be camera based instead of subject based to prevent jitter
				if self:GetIsMouseLocked() then
					cameraOffset = Vector3.new()
				end

				local bodyPartToFollow = humanoid.RootPart

				-- If the humanoid is dead, prefer their head part as a follow target, if it exists
				if humanoidIsDead then
					if humanoid.Parent and humanoid.Parent:IsA("Model") then
						bodyPartToFollow = humanoid.Parent:FindFirstChild("Head") or bodyPartToFollow
					end
				end

				if bodyPartToFollow and bodyPartToFollow:IsA("BasePart") then
					local heightOffset
					if humanoid.RigType == Enum.HumanoidRigType.R15 then
						if humanoid.AutomaticScalingEnabled then
							heightOffset = R15_HEAD_OFFSET
							if bodyPartToFollow == humanoid.RootPart then
								local rootPartSizeOffset = (humanoid.RootPart.Size.Y/2) - (HUMANOID_ROOT_PART_SIZE.Y/2)
								heightOffset = heightOffset + Vector3.new(0, rootPartSizeOffset, 0)
							end
						else
							heightOffset = R15_HEAD_OFFSET_NO_SCALING
						end
					else
						heightOffset = HEAD_OFFSET
					end

					if humanoidIsDead then
						heightOffset = Vector3.zero
					end

					result = bodyPartToFollow.CFrame * CFrame.new(heightOffset + cameraOffset)
				end

			elseif subject:IsA("VehicleSeat") then
				local offset = SEAT_OFFSET
				result = subject.CFrame * CFrame.new(offset)
			elseif subject:IsA("SkateboardPlatform") then
				result = subject.CFrame + SEAT_OFFSET
			elseif subject:IsA("BasePart") then
				result = subject.CFrame
			elseif subject:IsA("Attachment") then
				result = subject.WorldCFrame
			elseif subject:IsA("Model") then
				if subject.PrimaryPart then
					result = subject:GetPrimaryPartCFrame()
				else
					result = subject:GetModelCFrame()
				end
			end
		else
			-- cameraSubject is nil
			-- Note: Previous RootCamera did not have this else case and let self.lastSubject and self.lastSubjectPosition
			-- both get set to nil in the case of cameraSubject being nil. This function now exits here to preserve the
			-- last set valid values for these, as nil values are not handled cases
			return nil, nil
		end

		return result, cameraSubject
	end
	
	oldGetSubjectPosition = CameraModule.activeCameraController.GetSubjectPosition
	function CameraModule.activeCameraController:GetSubjectPosition(): Vector3?
		local result, cameraSubject = getSubjectPivot(self)
		if not result or not cameraSubject then
			return nil
		end

		self.lastSubjectPosition = result.Position

		return result.Position
	end

	local rootYaw: number = 0
	local isSitting = false
	
	oldCalculateNewLookCFrameFromArg = CameraModule.activeCameraController.CalculateNewLookCFrameFromArg
	function CameraModule.activeCameraController:CalculateNewLookCFrameFromArg(suppliedLookVector: Vector3?, rotateInput: Vector2): CFrame
		local data = OffsetCamera.settings

		local currLookVector: Vector3 = suppliedLookVector or self:GetCameraLookVector()
		local currPitchAngle = math.asin(currLookVector.Y)
		local pitch = math.clamp(rotateInput.Y, -data.maxHeadPitch + currPitchAngle, -data.minHeadPitch + currPitchAngle)

		local yaw = rotateInput.X

		if
			(data.restrictCameraByTorsoYawWhenSitting and isSitting)
			or (data.restrictCameraByTorsoYawWhenStanding and not isSitting) 
		then
			local nextYaw = rootYaw + yaw
			if nextYaw < data.minHeadYaw then
				yaw += data.minHeadYaw - nextYaw
			elseif data.maxHeadYaw < nextYaw then
				yaw += data.maxHeadYaw - nextYaw
			end
			
			local nextYaw = rootYaw + yaw
			if nextYaw < data.minHeadYaw then
				yaw += data.minHeadYaw - nextYaw
			elseif data.maxHeadYaw < nextYaw then
				yaw += data.maxHeadYaw - nextYaw
			end
		end

		local constrainedRotateInput = Vector2.new(yaw, pitch)
		local startCFrame = CFrame.new(Vector3.zero, currLookVector)
		local newLookCFrame = CFrame.Angles(0, -constrainedRotateInput.X, 0) * startCFrame * CFrame.Angles(-constrainedRotateInput.Y,0,0)
		return newLookCFrame
	end
	
	local yawSpring = Spring.new(Vector3.zero, 30, 1)
	yawSpring.disconnect()

	oldUpdate = CameraModule.activeCameraController.Update
	function CameraModule.activeCameraController:Update(dt: number)
		local data = OffsetCamera.settings

		local tweenAcceleration = math.rad(220) -- Radians/Second^2
		local tweenSpeed = math.rad(0)          -- Radians/Second
		local tweenMaxSpeed = math.rad(250)     -- Radians/Second
		local TIME_BEFORE_AUTO_ROTATE = 2       -- Seconds, used when auto-aligning camera with vehicles

		local INITIAL_CAMERA_ANGLE = CFrame.fromOrientation(math.rad(-15), 0, 0)

		local now = tick()
		local lastUpdate = self.lastUpdate or now - dt -- This can be nil if transitioning from another camera
		local timeDelta = now - lastUpdate -- replace with dt if FFlagUserCameraInputDt
		if FFlagUserCameraInputDt then
			timeDelta = dt
		end

		local camera = workspace.CurrentCamera
		local newCameraCFrame = camera.CFrame
		local newCameraFocus = camera.Focus

		local player = Players.LocalPlayer
		local humanoid = self:GetHumanoid()
		local cameraSubject = camera.CameraSubject
		local subjectPivot: CFrame?, derivedSubject: Instance? = getSubjectPivot(self)

		local isAHumanoid = cameraSubject and cameraSubject:IsA("Humanoid")
		local isInVehicle = cameraSubject and cameraSubject:IsA("VehicleSeat")
		local isOnASkateboard = cameraSubject and cameraSubject:IsA("SkateboardPlatform")

		if cameraSubject ~= self.lastSubject then
			if self.lastSubject and self.lastSubject:IsA("Humanoid") and not (isInVehicle or isOnASkateboard) then
				RotateAndReplicate.resetHumanoidStuff(OffsetCamera, self.lastSubject)
				self.lastSubject.AutoRotate = true
				yawSpring.target = Vector3.zero
				yawSpring.position = Vector3.zero
			end
		end

		if cameraSubject ~= self.lastSubject then
			if isAHumanoid then
				RotateAndReplicate.setHumanoidStuff(OffsetCamera, cameraSubject)
				
				local rootPart = cameraSubject.RootPart :: Part?
				if not data.rotateCharacterYawToFollowCamera and rootPart then
					yawSpring.target = rootPart.AssemblyLinearVelocity
				else
					yawSpring.target = camera.CFrame.LookVector
				end
				yawSpring.position = yawSpring.target
			end
		end
		self.lastSubject = cameraSubject
		self.lastSubjectPosition = if subjectPivot then subjectPivot.Position else self.lastSubjectPosition

		local isClimbing = humanoid and humanoid:GetState() == Enum.HumanoidStateType.Climbing

		if self.lastUpdate == nil or timeDelta > 1 then
			self.lastCameraTransform = nil
		end

		local rotateInput = CameraInput.getRotation(timeDelta)

		self:StepZoom()

		local cameraHeight = self:GetCameraHeight()

		-- Reset tween speed if user is panning
		if rotateInput ~= Vector2.new() then
			tweenSpeed = 0
			self.lastUserPanCamera = tick()
		end

		local userRecentlyPannedCamera = now - self.lastUserPanCamera < TIME_BEFORE_AUTO_ROTATE

		local rootPart: Part = self:GetHumanoidRootPart()

		if isAHumanoid and rootPart then
			rootYaw = RotateAndReplicate.getRootYaw(camera.CFrame, rootPart:GetPivot())
		elseif isInVehicle then
			rootYaw = RotateAndReplicate.getRootYaw(camera.CFrame, cameraSubject:GetPivot())
		elseif isOnASkateboard then
			rootYaw = RotateAndReplicate.getRootYaw(camera.CFrame, cameraSubject:GetPivot())
		end

		isSitting = not not (
			isInVehicle
			or isOnASkateboard
			or (isAHumanoid and cameraSubject:GetState() == Enum.HumanoidStateType.Seated)
		)

		local overrideCameraLookVector = nil
		if self.resetCameraAngle then
			if rootPart then
				overrideCameraLookVector = (rootPart.CFrame * INITIAL_CAMERA_ANGLE).LookVector
			else
				overrideCameraLookVector = INITIAL_CAMERA_ANGLE.LookVector
			end
			self.resetCameraAngle = false
		end

		if subjectPivot and player and camera then
			local zoom = self:GetCameraToSubjectDistance()
			if zoom < 0.5 then
				zoom = 0.5
			end

			if self:GetIsMouseLocked() and not self:IsInFirstPerson() then
				---- We need to use the right vector of the camera after rotation, not before
				local newLookCFrame: CFrame = self:CalculateNewLookCFrameFromArg(nil, rotateInput)

				local offset: Vector3 = self:GetMouseLockOffset()
				-- in mouse lock mode, the offset is applied to the camera instead of to the subject position
				if humanoid then
					offset += humanoid.CameraOffset
				end
				local cameraRelativeOffset: Vector3 = newLookCFrame * offset

				--offset can be NAN, NAN, NAN if newLookVector has only y component
				if Util.IsFiniteVector3(cameraRelativeOffset) then
					subjectPivot *= CFrame.new(cameraRelativeOffset)
				end
			else
				local userPanningTheCamera = rotateInput ~= Vector2.new()

				if not userPanningTheCamera and self.lastCameraTransform then

					local isInFirstPerson = self:IsInFirstPerson()

					if (isInVehicle or isOnASkateboard or (self.isFollowCamera and isClimbing)) and self.lastUpdate and humanoid and humanoid.Torso then
						if isInFirstPerson then
							if self.lastSubjectCFrame and (isInVehicle or isOnASkateboard) and cameraSubject:IsA("BasePart") then
								local y = -Util.GetAngleBetweenXZVectors(self.lastSubjectCFrame.lookVector, cameraSubject.CFrame.lookVector)
								if Util.IsFinite(y) then
									rotateInput = rotateInput + Vector2.new(y, 0)
								end
								tweenSpeed = 0
							end
						elseif not userRecentlyPannedCamera then
							local forwardVector = humanoid.Torso.CFrame.lookVector
							tweenSpeed = math.clamp(tweenSpeed + tweenAcceleration * timeDelta, 0, tweenMaxSpeed)

							local percent = math.clamp(tweenSpeed * timeDelta, 0, 1)
							if self:IsInFirstPerson() and not (self.isFollowCamera and self.isClimbing) then
								percent = 1
							end

							local y = Util.GetAngleBetweenXZVectors(forwardVector, self:GetCameraLookVector())
							if Util.IsFinite(y) and math.abs(y) > 0.0001 then
								rotateInput = rotateInput + Vector2.new(y * percent, 0)
							end
						end

					elseif self.isFollowCamera and not (isInFirstPerson or userRecentlyPannedCamera) then
						-- Logic that was unique to the old FollowCamera module
						local lastVec = -(self.lastCameraTransform.Position - subjectPivot.Position)

						local y = Util.GetAngleBetweenXZVectors(lastVec, self:GetCameraLookVector())

						-- This cutoff is to decide if the humanoid's angle of movement,
						-- relative to the camera's look vector, is enough that
						-- we want the camera to be following them. The point is to provide
						-- a sizable dead zone to allow more precise forward movements.
						local thetaCutoff = 0.4

						-- Check for NaNs
						if Util.IsFinite(y) and math.abs(y) > 0.0001 and math.abs(y) > thetaCutoff * timeDelta then
							rotateInput = rotateInput + Vector2.new(y, 0)
						end
					end
				end
			end

			rotateInput *= Vector2.new(data.horizontalSensitivity, data.verticalSensitivity)

			if not self.isFollowCamera then
				newCameraFocus = subjectPivot
				local rotateLookCFrame = self:CalculateNewLookCFrameFromArg(overrideCameraLookVector, rotateInput)

				if FFlagUserFixCameraFPError then
					newCameraCFrame = rotateLookCFrame * ZoomOffsets.getOffset(OffsetCamera, zoom)
				else
					newCameraCFrame = rotateLookCFrame * ZoomOffsets.getOffset(OffsetCamera, zoom)
				end
			else -- is FollowCamera
				newCameraFocus = CFrame.new(subjectPivot.Position)
				local rotateLookCFrame = self:CalculateNewLookCFrameFromArg(overrideCameraLookVector, rotateInput)

				if FFlagUserFixCameraFPError then
					newCameraCFrame = rotateLookCFrame * ZoomOffsets.getOffset(OffsetCamera, zoom)
				else
					newCameraCFrame = rotateLookCFrame * ZoomOffsets.getOffset(OffsetCamera, zoom) + Vector3.new(0, cameraHeight, 0)
				end
			end

			local toggleOffset = self:GetCameraToggleOffset(timeDelta)
			newCameraFocus += toggleOffset
			newCameraCFrame += toggleOffset

			self.lastCameraTransform = newCameraCFrame
			self.lastCameraFocus = newCameraFocus
			if (isInVehicle or isOnASkateboard) and cameraSubject:IsA("BasePart") then
				self.lastSubjectCFrame = cameraSubject.CFrame
			else
				self.lastSubjectCFrame = nil
			end

			if rootPart and derivedSubject and derivedSubject.Parent then
				local function bend(humanoid: Humanoid)
					local ax, ay, az = camera.CFrame:ToEulerAnglesYXZ()
					local yaw = ay
					local pitch = ax

					local character = humanoid.Parent
					if not character then
						return
					end

					if character:IsA("Model") and data.bendToFollowCamera then
						RotateAndReplicate.setCharacterAngles(OffsetCamera, camera, character, pitch)
					end
					
					-- Needs to be left out so it can update the external variable
					--rootYaw = RotateAndReplicate.getRootYaw(camera.CFrame, (humanoid.SeatPart or rootPart):GetPivot())

					if not rootPart:IsGrounded() and not humanoid.SeatPart then
						if data.rotateCharacterYawToFollowCamera then
							humanoid.AutoRotate = false
							if humanoid.MoveDirection.Magnitude ~= 0 then
								local DAMPENING = 0.9
								rootPart:PivotTo(CFrame.fromOrientation(0, yaw + rootYaw * DAMPENING, 0) + rootPart:GetPivot().Position)
							else
								if rootYaw <= data.minHeadYaw or data.maxHeadYaw <= rootYaw then
									local EPSILON = 1e-4
									local clampedTorsoYaw = math.clamp(rootYaw, data.minHeadYaw, data.maxHeadYaw)
									rootPart:PivotTo(CFrame.fromOrientation(0, yaw + clampedTorsoYaw * (1 - EPSILON), 0) + rootPart:GetPivot().Position)
								end
							end
						else
							humanoid.AutoRotate = true
						end
					end
				end

				if
					derivedSubject:IsA("Humanoid")
					and derivedSubject.Health > 0
					and derivedSubject:GetState() ~= Enum.HumanoidStateType.Dead
					and derivedSubject:GetState() ~= Enum.HumanoidStateType.Swimming
					and derivedSubject:GetState() ~= Enum.HumanoidStateType.PlatformStanding
					and (
						derivedSubject:GetState() ~= Enum.HumanoidStateType.Seated or derivedSubject.SeatPart
					)
				then
					bend(derivedSubject)
				elseif derivedSubject:IsA("VehicleSeat") and derivedSubject.Occupant then
					bend(derivedSubject.Occupant)
				elseif derivedSubject:IsA("SkateboardPlatform") and derivedSubject.ControllingHumanoid then
					bend(derivedSubject.ControllingHumanoid)
				end
			end
		end

		self.lastUpdate = now
		return newCameraCFrame, newCameraFocus
	end
	
	oldOcclusionUpdate = CameraModule.activeOcclusionModule.Update
	function CameraModule.activeOcclusionModule:Update(renderDt, desiredCameraCFrame, desiredCameraFocus, cameraController)
		local data = OffsetCamera.settings

		local rotatedFocus = nil
		local oldZoom = ZoomController.GetZoomRadius()
		local convergence = ZoomOffsets.getSubjectRotationConvergence(OffsetCamera, oldZoom)
		local trueUpVector: Vector3 = desiredCameraFocus.UpVector
		local upVector = Vector3.yAxis:Lerp(trueUpVector, convergence)

		rotatedFocus = CFrame.lookAlong(desiredCameraFocus.p, -desiredCameraCFrame.LookVector, upVector)
			* CFrame.new(
				0, 0, 0,
				-1, 0, 0,
				0, 1, 0,
				0, 0, -1
			)

		local extrapolation = self.focusExtrapolator:Step(renderDt, rotatedFocus)
		local zoom = ZoomController.Update(renderDt, rotatedFocus, extrapolation)
		local newCameraCFrame = rotatedFocus * ZoomOffsets.getOffset(OffsetCamera, zoom) * CFrame.new(0, 0, zoom)
		return newCameraCFrame, desiredCameraFocus
	end
end

return Module
