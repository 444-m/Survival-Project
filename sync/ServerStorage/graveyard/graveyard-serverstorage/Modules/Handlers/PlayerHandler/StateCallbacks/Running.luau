local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local effects = require(ReplicatedStorage.Modules.Shared.utils.advents.effects)
local EffectTemplate = ReplicatedStorage.Assets.Effects.Player.Movement.RunVFX
local StateManager = require(ServerStorage.Modules.Systems.StateManager)

local ActiveStates = {} :: {[Model]: {uid: number?; HRP: BasePart; conn: RBXScriptConnection?}}

local Running = {}

local function IsMovingForward(Character: Model): boolean
	local HRP = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
	if not HRP or not Humanoid then return false end

	local MoveDir = Humanoid.MoveDirection
	if vector.magnitude(MoveDir) < .1 then return false end

	local LocalMove = HRP.CFrame:VectorToObjectSpace(MoveDir)
	return LocalMove.Z < 0
end

local function IsStateActuallyRunning(Character: Model): boolean
	local player = Players:GetPlayerFromCharacter(Character)
	if not player then
		return false
	end

	return StateManager.GetState(player.UserId) == "Running"
end

function Running.Start(Character: Model)
	local State = ActiveStates[Character]
	if not State then
		State = {uid = nil; HRP = Character:WaitForChild("HumanoidRootPart") :: BasePart; conn = nil}
		ActiveStates[Character] = State
	end

	if State.conn then return end

	State.conn = RunService.Heartbeat:Connect(function()
		if not Character.Parent then
			Running.Cleanup(Character)
			return
		end

		local Humanoid = Character:FindFirstChild("Humanoid") :: Humanoid?
		if not Humanoid or Humanoid.Health <= 0 then
			Running.Cleanup(Character)
			return
		end

		if not IsStateActuallyRunning(Character) then
			Running.Stop(Character)
			return
		end

		if IsMovingForward(Character) then
			if not State.uid then
				State.uid = effects.replicate({container = EffectTemplate; type = "enable"; extra = {duration = nil; target = State.HRP}})
			end
		else
			if State.uid then
				effects.disableEffect(State.uid, 0)
				State.uid = nil
			end
		end
	end)
end

function Running.Stop(Character: Model)
	local State = ActiveStates[Character]
	if not State then return end

	if State.conn then
		State.conn:Disconnect()
		State.conn = nil
	end

	if State.uid then
		effects.disableEffect(State.uid, 0)
		State.uid = nil
	end

	ActiveStates[Character] = nil
end

function Running.Cleanup(Character: Model)
	local State = ActiveStates[Character]
	if not State then return end

	if State.conn then
		State.conn:Disconnect()
		State.conn = nil
	end

	if State.uid then
		effects.disableEffect(State.uid, 0)
		State.uid = nil
	end

	ActiveStates[Character] = nil
end

return Running
