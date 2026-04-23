local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Promise = require(ReplicatedStorage.Packages.Shared.Promise)
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local Animations = require(ReplicatedStorage.Modules.Shared.Animations)
local Bandage = {
	track = nil;
	promise = nil;
}

const HEAL_AMOUNT = 25

local function playTrack(animator: Animator?, track: AnimationTrack?): any
	track.Looped = false
	
	return Promise.new(function(resolve, _, onCancel)
		if not animator or not track then
			resolve()
			return
		end

		local playing = advents.animator.playAnim(animator, track, .1)
		if not playing then
			resolve()
			return
		end

		playing.Priority = Enum.AnimationPriority.Action4
		Bandage.track = playing

		local conn
		conn = playing.Stopped:Connect(function()
			if conn then conn:Disconnect() end
			resolve()
		end)

		onCancel(function()
			if conn then conn:Disconnect() end
			advents.animator.stopAnim(playing, .1)
		end)
	end)
end

local function playHealEffect()
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "BandageHeal"
	cc.TintColor = Color3.fromRGB(200, 255, 220)
	cc.Brightness = 0
	cc.Contrast = 0
	cc.Saturation = 0
	cc.Parent = Lighting

	local brightness = advents.spring.new(0)
	brightness.speed = 30
	brightness.damper = .34
	brightness.target = .12

	local saturation = advents.spring.new(0)
	saturation.speed = 26
	saturation.damper = .36
	saturation.target = 1

	local tint = advents.spring.new(0)
	tint.speed = 22
	tint.damper = .38
	tint.target = 1

	task.delay(.05, function()
		brightness.target = 0
		saturation.target = 0
		tint.target = 0
	end)

	local baseTint = Color3.fromRGB(255, 255, 255)
	local peakTint = Color3.fromRGB(180, 255, 210)

	while true do
		RunService.PreRender:Wait()
		local b = brightness.value
		local s = saturation.value
		local t = math.clamp(tint.value, 0, 1)

		cc.Brightness = b
		cc.Contrast = b * .8
		cc.Saturation = .08 + s * .32
		cc.TintColor = baseTint:Lerp(peakTint, t)

		if brightness.target == 0 and brightness.settling < .06 and saturation.settling < .06 and tint.settling < .06 then
			break
		end
	end
	cc:Destroy()
end

function Bandage:Use()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return { Cancel = true } end
	
	if humanoid.Health >= humanoid.MaxHealth then
		return { Cancel = true; Reason = "FullHealth"; }
	end
	
	if Bandage.promise and Bandage.promise.getStatus and Bandage.promise:getStatus() == Promise.Status.Started then
		return { Cancel = true }
	end

	local animator = humanoid:FindFirstChildOfClass("Animator")
	local start = Animations.LoadedAnimations.Tools.Bandage.Start.loaded
	local mid = Animations.LoadedAnimations.Tools.Bandage.Mid.loaded
	local ending = Animations.LoadedAnimations.Tools.Bandage.End.loaded
	local midLength = mid and mid.Length or .6
	local endLength = ending and ending.Length or .6
	local healDuration = (midLength + endLength) * 1.2

	local serverResolve
	local serverPromise = Promise.new(function(resolve)
		serverResolve = resolve
	end)

	local sequence = playTrack(animator, start)
		:andThen(function()
			return Promise.new(function(resolve, _, onCancel)
				if not animator or not mid then
					if serverResolve then serverResolve() end
					resolve()
					return
				end
				local playing = advents.animator.playAnim(animator, mid, .1)
				if not playing then
					if serverResolve then serverResolve() end
					resolve()
					return
				end
				playing.Looped = false
				playing.Priority = Enum.AnimationPriority.Action4
				Bandage.track = playing

				if serverResolve then
					serverResolve()
					serverResolve = nil
				end

				local conn
				conn = playing.Stopped:Connect(function()
					if conn then conn:Disconnect() end
					resolve()
				end)

				onCancel(function()
					if conn then conn:Disconnect() end
					advents.animator.stopAnim(playing, .1)
				end)
			end)
		end)
		:andThen(function()
			return playTrack(animator, ending)
		end)
		:andThen(function()
			playHealEffect()
		end)

	if serverResolve then
		task.defer(serverResolve)
	end

	Bandage.promise = sequence

	return {
		DeferServer = true;
		LockEquip = true;
		Promise = sequence;
		ServerPromise = serverPromise;
		consume = true;
		heal = HEAL_AMOUNT;
		endLength = endLength;
		healDuration = healDuration;
		keepModel = true;
	}
end

function Bandage:Cancel()
	if Bandage.promise and Bandage.promise.cancel then
		Bandage.promise:cancel()
	end
	if Bandage.track then
		advents.animator.stopAnim(Bandage.track, .15)
	end
end

return Bandage
