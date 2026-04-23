local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InputHandler = {}; InputHandler.__index = InputHandler

local MovementController = require("./MovementController")
local Helper = require("./Helper")
local Player = Players.LocalPlayer
local PlayerModule = require(Player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
local Controls = PlayerModule:GetControls()

local Input = require(ReplicatedStorage.Modules.Client.Input)

function InputHandler.new(Character: Model, Options: typeof(require("./configs")), Animator)
	local self = setmetatable({}, InputHandler)

	self.MovementController = MovementController.new(Character, Options, Animator)
	self.Controls = Controls
	self.Options = Options

	self.MoveInputRunner = function(dt)
		local MoveVector = self.Controls:GetMoveVector()
		local Camera = workspace.CurrentCamera
		local MoveDirection = vector.zero

		if not Camera then
			MoveDirection = vector.create(MoveVector.X, 0, -MoveVector.Z)
		else
			local Look = Camera.CFrame.LookVector
			local Right = Camera.CFrame.RightVector
			local ForwardFlat = vector.create(Look.X, 0, Look.Z)
			local RightFlat = vector.create(Right.X, 0, Right.Z)

			if vector.magnitude(ForwardFlat) > 0 then
				ForwardFlat = vector.normalize(ForwardFlat)
			end
			if vector.magnitude(RightFlat) > 0 then
				RightFlat = vector.normalize(RightFlat)
			end

			local WorldMove = (RightFlat * MoveVector.X) + (ForwardFlat * -MoveVector.Z)
			if vector.magnitude(WorldMove) > 1 then
				WorldMove = vector.normalize(WorldMove)
			end

			MoveDirection = WorldMove
		end

		self.MovementController:Step(dt, MoveDirection)
	end

	Input.AddClass("Movement")

	self.Inputs = {
		Slide = Input.AddBind("Movement", "Slide",
			{Enum.KeyCode.LeftControl, Enum.KeyCode.C}, Enum.InputActionType.Direction1D, {
				OnStart = function()
					if getmetatable(self.MovementController) then
						self.MovementController:QueueSlide()
					end
				end;
			});
	}

	Helper.AddToHeartBeat(self.MoveInputRunner)

	self.SpaceBeganConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= Enum.KeyCode.Space then return end
		if not getmetatable(self.MovementController) then return end

		self.MovementController:SetWallRunHold(true)
		self.MovementController:QueueJump()
	end)

	self.SpaceEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= Enum.KeyCode.Space then return end
		if not getmetatable(self.MovementController) then return end

		self.MovementController:SetWallRunHold(false)

		if self.MovementController.Physics and self.MovementController.Physics:IsWallRunning() then
			self.MovementController:QueueWallKick(true)
		end
	end)

	self.StrafeEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= Enum.KeyCode.A and input.KeyCode ~= Enum.KeyCode.D then return end
		if not getmetatable(self.MovementController) then return end
	end)

	self.WallFlipConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= Enum.KeyCode.E then return end
		if not getmetatable(self.MovementController) then return end

		self.MovementController:SetWallFlipHold(true)
		self.MovementController:QueueWallFlip()
	end)

	self.WallFlipEndedConnection = UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if gameProcessed then return end
		if input.KeyCode ~= Enum.KeyCode.E then return end
		if not getmetatable(self.MovementController) then return end

		self.MovementController:SetWallFlipHold(false)
	end)

	return self
end

function InputHandler:Destroy()
	for i, input in self.Inputs do
		Input.RemoveBind("Movement", i)
	end

	if self.MoveInputRunner then
		Helper.RemoveFromHeartBeat(self.MoveInputRunner)
		self.MoveInputRunner = nil
	end

	if self.MovementController then
		self.MovementController:Destroy()
		self.MovementController = nil
	end

	if self.SpaceBeganConnection then
		self.SpaceBeganConnection:Disconnect()
		self.SpaceBeganConnection = nil
	end
	if self.SpaceEndedConnection then
		self.SpaceEndedConnection:Disconnect()
		self.SpaceEndedConnection = nil
	end
	if self.StrafeEndedConnection then
		self.StrafeEndedConnection:Disconnect()
		self.StrafeEndedConnection = nil
	end
	if self.WallFlipConnection then
		self.WallFlipConnection:Disconnect()
		self.WallFlipConnection = nil
	end
	if self.WallFlipEndedConnection then
		self.WallFlipEndedConnection:Disconnect()
		self.WallFlipEndedConnection = nil
	end

	setmetatable(self, nil)
end

return InputHandler
