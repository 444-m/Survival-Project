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
local FFlagUserFixCameraFPError = FlagUtil.getUserFlag("UserFixCameraFPError")

local ZoomController = require(CameraModuleScript.ZoomController)

local ControlModule = PlayerModule:GetControls()
local CameraModule = PlayerModule:GetCameras()
assert(next(CameraModule), `OffsetCamera only works if you manually copy the StarterPlayerScripts.PlayerModule that's created at runtime, put it in StarterPlayerScripts, and at the bottom of the CameraModule return the new camera instead of an empty table! Sorry for the inconvenience, this is a Roblox issue.`)

local RotateAndReplicate = require(script.RotateAndReplicate)

local ClassicCamera = require(script.Cameras.ClassicCamera)

--? Thanks ZoomController
local ZOOM_DEFAULT = 12.5

local Module = {}

--[[
	CHANGE THESE SETTINGS OUTSIDE OF THIS MODULE BY REDEFINING THEM IN ANOTHER SCRIPT LIKE SO:
		OffsetCamera.settings.subjectName = "Head"
		OffsetCamera.settings.subjectRotationConvergence = {
			[0.5] = 0.5,
			[12.5] = 0,
		}
		OffsetCamera.settings.offsets = {
			[0.5] = CFrame.identity,
			[3] = CFrame.new(1.75, 0, 0) * CFrame.fromEulerAnglesYXZ(0, 0, -math.pi / 24),
			[12.5] = CFrame.new(0, 3, 0),
		}
		OffsetCamera.bendToFollowCamera = false
]]

-- https://devforum.roblox.com/t/offset-camera-over-the-shoulder-and-more-for-mobile-console-and-pc/3177209
Module.settings = {
	-- Set me to the name of a basepart or attachment under the Character or Camera.CameraSubject, and I'll treat that as my focus
	subjectName = nil :: string?,

	-- Set me to true if you want me to focus on the whole vehicle instead of the subject
	centerOnVehicle = false,

	-- Set me to 0 if you don't want the camera to rotate with the subject
	-- Set me to 1 if you want to rotate entirely with the subject, like following the head as it turns or the shoulder when it wobbles
	-- It's best if you redefine the whole table like this instead of changing individual keys
	subjectRotationConvergence = {
		[Players.LocalPlayer.CameraMinZoomDistance] = 1,
		[ZOOM_DEFAULT] = 0,
	},
	
	-- Set me to define the camera keypoints at different distances
	-- It's best if you redefine the whole table like this instead of changing individual keys
	offsets = {
		[Players.LocalPlayer.CameraMinZoomDistance] = CFrame.identity,
		[3] = CFrame.new(1.75, 0, 0),
	},
	
	-- Set me if you want to go from Right-Handed to Left-Handed
	mirrorOffsets = false,
	
	-- Set us if you want to make the camera faster or slower in a direction
	horizontalSensitivity = 1,
	verticalSensitivity = 1,
	
	-- Set me to true if you want the character to bend their head and torso to follow the camera
	bendToFollowCamera = true,
	-- Change me to change how fast the character bends to face the camera. Slower is more dramatic, faster is snappier.
	bendSpeed = 10,
	
	-- Set me to false to let players look past their max yaw without spinning the character to correct the offset
	rotateCharacterYawToFollowCamera = true,
	
	-- Set us to true if you want to restrict how far the camera can turn horizontally when standing or sitting.
	restrictCameraByTorsoYawWhenStanding = false,
	restrictCameraByTorsoYawWhenSitting = false,
	
	-- Change us to change how far up and down the camera can look, and how far the head & torso will rotate to follow
	-- https://www.desmos.com/calculator/tjyrshl4xt   This is an interactive graphing calculator you can use to preview the angles
	maxHeadPitch = math.rad(80),
	minHeadPitch = math.rad(-80),
	maxTorsoPitchPercent = 0.625,
	minTorsoPitchPercent = 0.5,
	torsoPitchWeight = 3,
	
	-- Change us to change how far left and right the camera can look, and how far the head & torso will rotate to follow
	maxHeadYaw = math.rad(90),
	minHeadYaw = math.rad(-90),
	maxTorsoYawPercent = 0.5,
	minTorsoYawPercent = 0.5,
	torsoYawWeight = 1,
}

local enabled = false

function Module.isEnabled()
	return enabled
end

-- This cursed code is to make sure when roblox switches cameras automatically that the offset camera is preserved
local function getCameraControllerOverride(
	cameraMovementMode: Enum.ComputerCameraMovementMode? | Enum.DevComputerCameraMovementMode?,
	legacyCameraType: Enum.CameraType?
): typeof(ClassicCamera)?
	if legacyCameraType == Enum.CameraType.Custom or cameraMovementMode == Enum.ComputerCameraMovementMode.Classic then
		return ClassicCamera
	end

	return nil
end

local oldShouldUseVehicleCamera

local function setNewModuleMethods()
	oldShouldUseVehicleCamera = CameraModule.ShouldUseVehicleCamera
	function CameraModule:ShouldUseVehicleCamera()
		return false
	end
end

local function resetOldModuleMethods()
	CameraModule.ShouldUseVehicleCamera = oldShouldUseVehicleCamera
	oldShouldUseVehicleCamera = nil
end

local function setHumanoidStuff()
	local camera = workspace.CurrentCamera
	local subject = camera.CameraSubject
	if subject and subject:IsA("Humanoid") then
		RotateAndReplicate.setHumanoidStuff(Module, subject)
	end
end

local function resetHumanoidStuff()
	local camera = workspace.CurrentCamera
	local subject = workspace.CurrentCamera.CameraSubject
	if subject then
		if subject:IsA("Humanoid") then
			RotateAndReplicate.resetHumanoidStuff(Module, subject)
		elseif subject:IsA("VehicleSeat") and subject.Occupant then
			RotateAndReplicate.resetHumanoidStuff(Module, subject.Occupant)
		elseif subject:IsA("SkateboardPlatform") and subject.ControllingHumanoid then
			RotateAndReplicate.resetHumanoidStuff(Module, subject.ControllingHumanoid)
		end
	end
end

local currentCameraControllerOverride: typeof(ClassicCamera)? = nil

local function cleanup(newCameraControllerOverride: typeof(ClassicCamera)?)
	if currentCameraControllerOverride then
		currentCameraControllerOverride.resetOldControllerMethods()

		if not newCameraControllerOverride then
			resetOldModuleMethods()
			resetHumanoidStuff()
		end
	end
end

local oldActivateCameraController = CameraModule.ActivateCameraController

local function startup(newCameraControllerOverride: typeof(ClassicCamera)?)
	if newCameraControllerOverride then
		if not currentCameraControllerOverride then
			local isUsingVehicleCamera = CameraModule:ShouldUseVehicleCamera()

			setNewModuleMethods()

			if isUsingVehicleCamera then
				local camera = workspace.CurrentCamera
				oldActivateCameraController(CameraModule, nil, camera.CameraType)
			end

			setHumanoidStuff()
		end

		newCameraControllerOverride.setNewControllerMethods(Module)
	end
end

function CameraModule:ActivateCameraController(cameraMovementMode: Enum.ComputerCameraMovementMode? | Enum.DevComputerCameraMovementMode?, legacyCameraType: Enum.CameraType?) -- remove args with FFlagUserRespectLegacyCameraOptions
	if not enabled then
		oldActivateCameraController(self, cameraMovementMode, legacyCameraType)
		return
	end

	local newCameraControllerOverride = getCameraControllerOverride(cameraMovementMode, legacyCameraType)
	cleanup(newCameraControllerOverride)
	oldActivateCameraController(self, cameraMovementMode, legacyCameraType)
	startup(newCameraControllerOverride)
	currentCameraControllerOverride = newCameraControllerOverride :: any
end

--local worldPivot = CFrame.identity
function Module.enable()
	if enabled then
		return
	end
	
	local camera = workspace.CurrentCamera
	local newCameraControllerOverride = getCameraControllerOverride(nil, camera.CameraType)
	startup(newCameraControllerOverride)
	currentCameraControllerOverride = newCameraControllerOverride

	enabled = true
end

function Module.disable()
	if not enabled then
		return
	end
	enabled = false

	cleanup(nil)
	currentCameraControllerOverride = nil

	-- Update the camera mode in case we are driving or whatever else is going on
	oldActivateCameraController(CameraModule)
end

function Module.toggle()
	if not Module.isEnabled() then
		Module.enable()
	else
		Module.disable()
	end
end

return Module
