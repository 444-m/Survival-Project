--!strict
local players = game:GetService("Players")
local runService = game:GetService("RunService")
local uis = game:GetService("UserInputService")
local BlinkClient = require(game.ReplicatedStorage.Packages.Shared.Blink.Client)

local player = players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local controls = require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule")):GetControls()

local connection: RBXScriptConnection?
local bodyVelocity: BodyVelocity?
local bodyGyro: BodyGyro?
local mobileGui: ScreenGui?
local descendPressed = false

local FlySpeed = 60

local function createMobileGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "FlyControls"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 80, 0, 80)
	btn.Position = UDim2.new(1, -100, 1, -180)
	btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	btn.BackgroundTransparency = .4
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = "↓"
	btn.TextSize = 32
	btn.Font = Enum.Font.GothamBold
	btn.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = btn

	btn.MouseButton1Down:Connect(function() descendPressed = true end)
	btn.MouseButton1Up:Connect(function() descendPressed = false end)

	gui.Parent = playerGui
	return gui
end

local function startFly()
	local character = player.Character
	if not character then return end

	local hrp = character:FindFirstChild("HumanoidRootPart") :: BasePart
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid then return end

	humanoid.PlatformStand = true

	bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.P = 1e4
	bodyVelocity.Parent = hrp

	bodyGyro = Instance.new("BodyGyro")
	bodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	bodyGyro.P = 1e4
	bodyGyro.D = 100
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.Parent = hrp

	if uis.TouchEnabled and not uis.KeyboardEnabled then
		mobileGui = createMobileGui()
	end

	local camera = workspace.CurrentCamera

	connection = runService.Heartbeat:Connect(function()
		if not hrp.Parent then return end

		local moveVec = controls:GetMoveVector()
		local cf = camera.CFrame

		local forward = cf.LookVector * -moveVec.Z
		local right = cf.RightVector * moveVec.X

		local verticalInput = 0

		if uis:IsKeyDown(Enum.KeyCode.Space)
			or uis:IsKeyDown(Enum.KeyCode.ButtonA)
			or (humanoid.Jump == true) then
			verticalInput += 1
		end

		if uis:IsKeyDown(Enum.KeyCode.LeftShift)
			or uis:IsKeyDown(Enum.KeyCode.ButtonB)
			or descendPressed then
			verticalInput -= 1
		end

		local finalDir = forward + right + Vector3.new(0, verticalInput, 0)

		if finalDir.Magnitude > 0 then
			bodyVelocity.Velocity = finalDir.Unit * FlySpeed
		else
			bodyVelocity.Velocity = Vector3.zero
		end

		bodyGyro.CFrame = cf
	end)
end

local function stopFly()
	descendPressed = false

	if connection then
		connection:Disconnect()
		connection = nil
	end

	if bodyVelocity then
		bodyVelocity:Destroy()
		bodyVelocity = nil
	end

	if bodyGyro then
		bodyGyro:Destroy()
		bodyGyro = nil
	end

	if mobileGui then
		mobileGui:Destroy()
		mobileGui = nil
	end

	local character = player.Character
	if not character then return end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.PlatformStand = false
	end
end

BlinkClient.FlyToggle.On(function(payload)
	if payload.Enabled then
		startFly()
	else
		stopFly()
	end
end)

player.CharacterAdded:Connect(function()
	stopFly()
end)

return nil
