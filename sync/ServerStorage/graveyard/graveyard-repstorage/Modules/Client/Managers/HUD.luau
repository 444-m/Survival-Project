local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HUD = {}
HUD.__index = HUD

local Player = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui") :: PlayerGui

type GuiObjects = {["BottomBar" | "TopBar"]: {[string]: GuiObject}}
export type Stats = {
	Level: number;
	XP: {Current: number; Needed: number;}
}

local Janitor = require(ReplicatedStorage.Packages.Shared.Janitor)
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)

local Sounds = require(ReplicatedStorage.Modules.Client.Sounds)

function HUD.new()
	local self = setmetatable({}, HUD)

	self.HUD = PlayerGui:WaitForChild("HUD", 41e67)
	self.BottomBar = self.HUD:WaitForChild("BottomBar")
	self.TopBar = self.HUD:WaitForChild("TopBar")

	self.Janitor = Janitor.new()

	self.MainButtons = {
		BottomBar = {
			AbilitiesButton = self.BottomBar:WaitForChild("AbilitiesButton");
			CodesButton = self.BottomBar:WaitForChild("CodesButton");
			DailyButton = self.BottomBar:WaitForChild("DailyButton");
			PlayButton = self.BottomBar:WaitForChild("PlayButton");
			ProfileButton = self.BottomBar:WaitForChild("ProfileButton");
			QuestsButton = self.BottomBar:WaitForChild("QuestsButton");
			StoreButton = self.BottomBar:WaitForChild("StoreButton");
		};
		
		TopBar = {
			PlayerLevel = self.TopBar:WaitForChild("PlayerLevel");
		}
	}

	self:__init()

	return self
end

function HUD:__init()
	self.HUD.Enabled = true

	local TopBar = self:__getGuiObjects().TopBar
	
	local PlayerLevel = TopBar.PlayerLevel
	local ProfileImage: ImageLabel = PlayerLevel:WaitForChild("ProfileImage")
	local PlayerName: TextLabel = ProfileImage:WaitForChild("PlayerName")
	self.PlayerLevel = PlayerLevel
	self.ExpLabel = PlayerLevel:WaitForChild("ExpLabel") :: TextLabel
	self.LevelLabel = PlayerLevel:WaitForChild("LevelLabel") :: TextLabel

	PlayerName.Text = Player.DisplayName
	ProfileImage.Image = Players:GetUserThumbnailAsync(Player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)

	for ClassName, Class in self:__getGuiObjects() do
		local idx = 0
		for i, Button in Class do
			idx += 1
			local Scale = Button:FindFirstChild("UIScale") :: UIScale?
			if not Scale then
				Scale = Instance.new("UIScale")
				Scale.Scale = 1
				Scale.Parent = Button
			end

			local SizeSpring = advents.spring.new(1)
			SizeSpring.speed = 26
			SizeSpring.damper = .7

			local RotSpring = advents.spring.new(0)
			RotSpring.speed = 24
			RotSpring.damper = .72

			local TweenFrom = 1
			local TweenTo = 1
			local TweenStart = os.clock()
			local TweenDur = .1
			local TweenMode = "out"

			local RotFrom = 0
			local RotTo = 0
			local RotStart = os.clock()
			local RotDur = .1
			local RotMode = "out"
			local WavePhase = (idx * .65) + (ClassName == "BottomBar" and 0 or 1.1)
			local WaveSpeed = 1.05
			local WaveScaleAmp = 0
			local WaveRotAmp = 0
			local PulseAmp = 0
			local Hovered = false

			local function SetTarget(Target: number, Duration: number, Mode: string?)
				TweenFrom = SizeSpring.target or TweenTo
				TweenTo = Target
				TweenStart = os.clock()
				TweenDur = math.max(Duration or .1, .0001)
				TweenMode = Mode or "out"
			end
			local function SetRotation(Target: number, Duration: number, Mode: string?)
				RotFrom = RotSpring.target or RotTo
				RotTo = Target
				RotStart = os.clock()
				RotDur = math.max(Duration or .1, .0001)
				RotMode = Mode or "out"
			end

			self.Janitor:Add(RunService.Heartbeat:Connect(function()
				local t = math.clamp((os.clock() - TweenStart) / TweenDur, 0, 1)
				local a = (
					(advents.easing.bezier_inout(t, 0, .18, .82, 1) * .5)
					+ (advents.easing.hermite(t, TweenMode :: any) * .3)
					+ (advents.easing.sigmoid(t, TweenMode :: any) * .2)
				)
				SizeSpring.target = TweenFrom + ((TweenTo - TweenFrom) * a)
				local wave = math.sin((os.clock() * WaveSpeed) + WavePhase)
				local pulse = math.sin((os.clock() * (WaveSpeed * 1.6)) + (WavePhase * .8))
				local waveAmp = Hovered and WaveScaleAmp or 0
				local pulseAmp = Hovered and (PulseAmp * .5) or 0
				Scale.Scale = SizeSpring.value * (1 + (wave * waveAmp) + (pulse * pulseAmp))

				local r = math.clamp((os.clock() - RotStart) / RotDur, 0, 1)
				local ar = (
					(advents.easing.bezier_inout(r, 0, .22, .78, 1) * .55)
					+ (advents.easing.hermite(r, RotMode :: any) * .3)
					+ (advents.easing.sigmoid(r, RotMode :: any) * .15)
				)
				RotSpring.target = RotFrom + ((RotTo - RotFrom) * ar)
				local rotAmp = Hovered and WaveRotAmp or 0
				Button.Rotation = RotSpring.value + (wave * rotAmp)
			end), "Disconnect", `Loop_{ClassName}_{i}`)

			self.Janitor:Add(Button.MouseEnter:Connect(function()
				Hovered = true
				SetTarget(1.12, .1, "out")
				SetRotation(1.1, .12, "out")
				Sounds.play(Sounds.LoadedSounds.UI.UiHover, nil, true)
			end), "Disconnect", `MouseEnter_{ClassName}_{i}`)

			self.Janitor:Add(Button.MouseLeave:Connect(function()
				Hovered = false
				SetTarget(1, .12, "out")
				SetRotation(0, .14, "out")
			end), "Disconnect", `MouseLeave_{ClassName}_{i}`)

			if Button:IsA("GuiButton") then
				self.Janitor:Add(Button.MouseButton1Down:Connect(function()
					SetTarget(.86, .05, "in")
					SetRotation(-1.15, .05, "in")
					Sounds.play(Sounds.LoadedSounds.UI.UiClick, nil, true)
				end), "Disconnect", `MouseDown_{ClassName}_{i}`)

				self.Janitor:Add(Button.MouseButton1Up:Connect(function()
					SetTarget(1.09, .07, "out")
					SetRotation(.7, .07, "out")
				end), "Disconnect", `MouseUp_{ClassName}_{i}`)
			end
		end
	end
end

function HUD:__getGuiObjects(): GuiObjects
	return self.MainButtons
end

function HUD:UpdateStats(Stats: Stats)
	local currentXP = math.max(0, math.floor(Stats.XP.Current + .5))
	local neededXP = math.max(0, math.floor(Stats.XP.Needed + .5))
	local level = math.max(1, math.floor(Stats.Level + .5))

	local expText = `{currentXP}/{neededXP}`
	local levelText = `Level {level}`

	if self.LastExpText ~= expText then
		self.ExpLabel.Text = expText
		self.LastExpText = expText
	end

	if self.LastLevelText ~= levelText then
		self.LevelLabel.Text = levelText
		self.LastLevelText = levelText
	end
end

function HUD:Destroy()
	self.Janitor:Destroy()
end

return HUD
