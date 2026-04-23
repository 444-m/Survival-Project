local LEVEL_UP_COLOR_EFFECT_NAME = "LevelUpPulseColor"
local LEVEL_UP_VIGNETTE_GUI_NAME = "LevelUpPulseVignetteGui"
local LEVEL_UP_VIGNETTE_NAME = "LevelUpPulseVignette"
local LEVEL_UP_VIGNETTE_IMAGE = "rbxasset://textures/ui/VR/edgeBlur.png"

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local CameraShake = require(ReplicatedStorage.Modules.Client.Systems.CameraShake)

local LevelBoostEffects = {}
LevelBoostEffects.__index = LevelBoostEffects

local function getLevelUpColorEffect(camera: Camera, createIfMissing: boolean?): ColorCorrectionEffect?
	local existing = camera:FindFirstChild(LEVEL_UP_COLOR_EFFECT_NAME)
	if existing and existing:IsA("ColorCorrectionEffect") then
		return existing
	end

	if not createIfMissing then
		return nil
	end

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = LEVEL_UP_COLOR_EFFECT_NAME
	effect.Enabled = true
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Saturation = 0
	effect.Contrast = 0
	effect.Brightness = 0
	effect.Parent = camera
	return effect
end

local function clearLevelUpVignette(player: Player)
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	local screen = playerGui:FindFirstChild(LEVEL_UP_VIGNETTE_GUI_NAME)
	if screen then
		screen:Destroy()
	end
end

local function getLevelUpVignette(player: Player, config, createIfMissing: boolean?): ImageLabel?
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		if not createIfMissing then
			return nil
		end

		playerGui = player:WaitForChild("PlayerGui", 2)
		if not playerGui or not playerGui:IsA("PlayerGui") then
			return nil
		end
	end

	local screen = playerGui:FindFirstChild(LEVEL_UP_VIGNETTE_GUI_NAME)
	if screen and not screen:IsA("ScreenGui") then
		screen:Destroy()
		screen = nil
	end

	if not screen then
		if not createIfMissing then
			return nil
		end

		screen = Instance.new("ScreenGui")
		screen.Name = LEVEL_UP_VIGNETTE_GUI_NAME
		screen.IgnoreGuiInset = true
		screen.ResetOnSpawn = false
		screen.DisplayOrder = 10_000
		screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
		screen.Parent = playerGui
	end

	local vignette = screen:FindFirstChild(LEVEL_UP_VIGNETTE_NAME)
	if vignette and not vignette:IsA("ImageLabel") then
		vignette:Destroy()
		vignette = nil
	end

	if not vignette then
		if not createIfMissing then
			return nil
		end

		vignette = Instance.new("ImageLabel")
		vignette.Name = LEVEL_UP_VIGNETTE_NAME
		vignette.BackgroundTransparency = 1
		vignette.BorderSizePixel = 0
		vignette.AnchorPoint = Vector2.new(.5, .5)
		vignette.Position = UDim2.fromScale(.5, .5)
		vignette.Size = UDim2.fromScale(config.LevelUpFxVignetteScale or 2.28, config.LevelUpFxVignetteScale or 2.28)
		vignette.Image = LEVEL_UP_VIGNETTE_IMAGE
		vignette.ImageTransparency = 1
		vignette.ScaleType = Enum.ScaleType.Stretch
		vignette.ZIndex = 1
		vignette.Parent = screen
	end

	return vignette
end

function LevelBoostEffects.new(player: Player, camera: Camera, cameraShake, config)
	local self = setmetatable({}, LevelBoostEffects)
	self.Player = player
	self.Camera = camera
	self.CameraShake = cameraShake
	self.Config = config
	self.Pulse = {
		StartedAt = 0;
		ActiveUntil = 0;
		Duration = config.LevelUpFxDuration or .78;
		RiseDuration = config.LevelUpFxRise or .12;
		Strength = 1;
	}
	self.Power = {
		StartedAt = 0;
		ActiveUntil = 0;
		Duration = 0;
		Strength = 1;
	}
	self.ShakeTrack = nil
	return self
end

function LevelBoostEffects:GetPulseAlpha(): number
	local pulse = self.Pulse
	local activeUntil = pulse and pulse.ActiveUntil or 0
	if activeUntil <= 0 then
		return 0
	end

	local duration = math.max(pulse.Duration or 0, .001)
	local remaining = activeUntil - os.clock()
	if remaining <= 0 then
		return 0
	end

	local elapsed = duration - remaining
	local riseDuration = math.min(pulse.RiseDuration or (duration * .15), duration * .45)
	if elapsed <= riseDuration then
		local riseAlpha = math.clamp(elapsed / math.max(riseDuration, .001), 0, 1)
		return advents.easing.bezier_out(riseAlpha, 0, .24, .82, 1)
	end

	local fadeAlpha = math.clamp((elapsed - riseDuration) / math.max(duration - riseDuration, .001), 0, 1)
	return 1 - advents.easing.bezier_out(fadeAlpha, 0, .08, .72, 1)
end

function LevelBoostEffects:GetPowerAlpha(): number
	local power = self.Power
	local activeUntil = power and power.ActiveUntil or 0
	if activeUntil <= 0 then
		return 0
	end

	local duration = math.max(power.Duration or 0, .001)
	local remaining = activeUntil - os.clock()
	if remaining <= 0 then
		return 0
	end

	local elapsed = duration - remaining
	local riseDuration = math.min(duration * .18, .35)
	if elapsed <= riseDuration then
		local riseAlpha = math.clamp(elapsed / math.max(riseDuration, .001), 0, 1)
		return advents.easing.bezier_out(riseAlpha, 0, .22, .78, 1)
	end

	local fadeAlpha = math.clamp((elapsed - riseDuration) / math.max(duration - riseDuration, .001), 0, 1)
	return 1 - advents.easing.bezier_out(fadeAlpha, 0, .12, .78, 1)
end

function LevelBoostEffects:GetShakeAlpha(): number
	local pulse = self.Pulse
	local activeUntil = pulse and pulse.ActiveUntil or 0
	if activeUntil <= 0 then
		return 0
	end

	local duration = math.max(pulse.Duration or 0, .001)
	local remaining = activeUntil - os.clock()
	if remaining <= 0 then
		return 0
	end

	local elapsed = duration - remaining
	local riseDuration = math.min(duration * .16, .08)
	if elapsed <= riseDuration then
		local riseAlpha = math.clamp(elapsed / math.max(riseDuration, .001), 0, 1)
		return advents.easing.bezier_out(riseAlpha, 0, .28, .84, 1)
	end

	local tailDuration = math.min(math.max(duration * .18, .09), .16)
	if remaining <= tailDuration then
		local tailAlpha = math.clamp(remaining / math.max(tailDuration, .001), 0, 1)
		return advents.easing.bezier_out(tailAlpha, 0, .16, .8, 1)
	end

	return 1
end

function LevelBoostEffects:GetFrameState(bobTime: number)
	local pulseAlpha = self:GetPulseAlpha()
	local powerAlpha = self:GetPowerAlpha()
	local pulseStrength = math.max(self.Pulse and self.Pulse.Strength or 1, 1)
	local powerStrength = math.max(self.Power and self.Power.Strength or 1, 1)
	local powerSway = (self.Config.LevelUpPowerSway or .09) * powerAlpha * (.88 + ((powerStrength - 1) * .4))
	local powerWave = math.sin((os.clock() * 7.2) + (bobTime * .55))
	local powerWaveFine = math.sin((os.clock() * 12.5) + (bobTime * .22))

	return {
		PulseAlpha = pulseAlpha;
		PowerAlpha = powerAlpha;
		PulseStrength = pulseStrength;
		PowerStrength = powerStrength;
		SpringScale = 1 + ((self.Config.LevelUpPowerSpringScale or .48) * powerAlpha * (.92 + ((powerStrength - 1) * .35)));
		BlurAdd = (self.Config.LevelUpPowerBlurAdd or 1.75) * powerAlpha * (.85 + ((powerStrength - 1) * .4));
		OffsetY = (self.Config.LevelUpPowerOffsetY or .16) * powerAlpha;
		OffsetZ = (self.Config.LevelUpPowerOffsetZ or .2) * powerAlpha;
		FovAdd = ((self.Config.LevelUpFxFovAdd or 6.75) * pulseAlpha * (.92 + ((pulseStrength - 1) * .42)))
			+ ((self.Config.LevelUpPowerFovAdd or 4.1) * powerAlpha * (.9 + ((powerStrength - 1) * .45)));
		WaveX = powerWave * powerSway;
		WaveZ = powerWaveFine * powerSway * .8;
	}
end

function LevelBoostEffects:UpdateVisuals(pulseAlpha: number, powerAlpha: number?)
	local power = math.max(powerAlpha or 0, 0)
	local alpha = math.max(pulseAlpha or 0, power)
	local effect = getLevelUpColorEffect(self.Camera, alpha > .001)
	local vignette = getLevelUpVignette(self.Player, self.Config, alpha > .001)
	if alpha <= .001 then
		if effect then
			effect:Destroy()
		end
		clearLevelUpVignette(self.Player)
		return
	end

	local strength = math.max(self.Pulse and self.Pulse.Strength or 1, 1)
	local powerStrength = math.max(self.Power and self.Power.Strength or 1, 1)
	local tintAlpha = math.clamp(
		((self.Config.LevelUpFxTintAlpha or .34) * math.max(pulseAlpha or 0, 0) * (0.95 + ((strength - 1) * .45)))
			+ ((self.Config.LevelUpPowerTintAlpha or .12) * power * (0.9 + ((powerStrength - 1) * .3))),
		0,
		.88
	)

	effect.TintColor = Color3.new(1, 1, 1):Lerp(self.Config.LevelUpFxColor or Color3.fromRGB(255, 215, 104), tintAlpha)
	effect.Contrast =
		((self.Config.LevelUpFxContrast or .2) * math.max(pulseAlpha or 0, 0) * (0.92 + ((strength - 1) * .35)))
		+ ((self.Config.LevelUpPowerContrast or .08) * power * (0.9 + ((powerStrength - 1) * .2)))
	effect.Saturation =
		((self.Config.LevelUpFxSaturation or .26) * math.max(pulseAlpha or 0, 0) * strength)
		+ ((self.Config.LevelUpPowerSaturation or .12) * power * powerStrength)
	effect.Brightness =
		((self.Config.LevelUpFxBrightness or .08) * math.max(pulseAlpha or 0, 0) * (0.96 + ((strength - 1) * .3)))
		+ ((self.Config.LevelUpPowerBrightness or .04) * power * (0.9 + ((powerStrength - 1) * .2)))

	if vignette then
		local vignetteAlpha = math.clamp(
			((self.Config.LevelUpFxVignetteAlpha or .52) * math.max(pulseAlpha or 0, 0) * (0.95 + ((strength - 1) * .42)))
				+ ((self.Config.LevelUpPowerVignetteAlpha or .28) * power * (0.9 + ((powerStrength - 1) * .24))),
			0,
			.84
		)
		local baseScale = self.Config.LevelUpFxVignetteScale or 2.28
		local scaleBreathe = 1 + ((math.max(pulseAlpha or 0, 0) * .018) + (power * .012))
		vignette.Size = UDim2.fromScale(baseScale * scaleBreathe, baseScale * scaleBreathe)
		vignette.ImageColor3 = (self.Config.LevelUpVignetteColor or Color3.fromRGB(184, 141, 52)):Lerp(
			self.Config.LevelUpFxColor or Color3.fromRGB(244, 219, 146),
			.22 + (math.max(pulseAlpha or 0, 0) * .18)
		)
		vignette.ImageTransparency = 1 - vignetteAlpha
	end
end

function LevelBoostEffects:Play(levelsGained: number?, boostStrength: number?, boostDuration: number?)
	local pulse = self.Pulse
	if not pulse then
		return
	end

	local levels = math.max(1, math.floor((levelsGained or 1) + .5))
	local perExtraLevel = self.Config.LevelUpFxPerExtraLevel or .12
	local maxStrength = self.Config.LevelUpFxMaxStrength or 1.55
	local targetStrength = math.min(
		math.max(boostStrength or 1, 1 + (math.max(0, levels - 1) * perExtraLevel)),
		maxStrength
	)

	local now = os.clock()
	local wasActive = now < (pulse.ActiveUntil or 0)
	pulse.Duration = self.Config.LevelUpFxDuration or .78
	pulse.RiseDuration = math.min(self.Config.LevelUpFxRise or .12, pulse.Duration * .45)
	pulse.StartedAt = now
	pulse.ActiveUntil = now + pulse.Duration
	pulse.Strength = wasActive and math.max(pulse.Strength or 1, targetStrength) or targetStrength

	local power = self.Power
	if power then
		local scaledDuration = math.max((boostDuration or pulse.Duration) * (self.Config.LevelUpPowerDurationScale or .55), pulse.Duration)
		local powerWasActive = now < (power.ActiveUntil or 0)
		power.Duration = math.min(scaledDuration, self.Config.LevelUpPowerMaxDuration or 4.25)
		power.StartedAt = now
		power.ActiveUntil = now + power.Duration
		power.Strength = powerWasActive and math.max(power.Strength or 1, targetStrength) or targetStrength
	end

	getLevelUpColorEffect(self.Camera, true)
	if self.ShakeTrack and self.ShakeTrack.Stop then
		self.ShakeTrack:Stop(0)
	end
	self.ShakeTrack = self.CameraShake:ShakeSustain(
		CameraShake.Presets.LevelUp:Scale(1.05 + ((pulse.Strength - 1) * .82)):With({
			FadeIn = .015;
			FadeOut = 0;
			FovInfluence = 0;
			PositionInfluence = vector.zero;
			RotationInfluence = vector.create(0, 0, 2.35 + ((pulse.Strength - 1) * .72));
			RotationFrequency = vector.create(.01, .01, 2.8);
			RotationBias = vector.create(0, 0, .22);
		})
	)
	self:UpdateVisuals(1, self:GetPowerAlpha())
end

function LevelBoostEffects:Clear()
	if self.Pulse then
		self.Pulse.StartedAt = 0
		self.Pulse.ActiveUntil = 0
		self.Pulse.Duration = self.Config.LevelUpFxDuration or .78
		self.Pulse.RiseDuration = self.Config.LevelUpFxRise or .12
		self.Pulse.Strength = 1
	end

	if self.Power then
		self.Power.StartedAt = 0
		self.Power.ActiveUntil = 0
		self.Power.Duration = 0
		self.Power.Strength = 1
	end

	if self.ShakeTrack and self.ShakeTrack.Stop then
		self.ShakeTrack:Stop(0)
		self.ShakeTrack = nil
	end

	local effect = getLevelUpColorEffect(self.Camera, false)
	if effect then
		effect:Destroy()
	end
	clearLevelUpVignette(self.Player)
end

function LevelBoostEffects:Reset()
	self:Clear()
end

return LevelBoostEffects
