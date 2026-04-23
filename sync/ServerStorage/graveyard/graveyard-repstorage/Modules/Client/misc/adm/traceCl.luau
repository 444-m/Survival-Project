local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")

local Player = Players.LocalPlayer

local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)
local CameraController = require(ReplicatedStorage.Modules.Client.Controllers.Camera.CameraController)
local CameraShake = require(ReplicatedStorage.Modules.Client.Systems.CameraShake)
local BlinkClient = require(ReplicatedStorage.Packages.Shared.Blink.Client)

local module = {}
module.applyEffectsToInitiator = false

local Armed = false
local Nearby = {}
local NearTrack = nil
local NearFx = nil
local SelfFx = nil
local NearBlur = nil
local NearBloom = nil
local DomainSound = nil
local DomainBedSound = nil
local FearGui = nil
local FearLabels = {}
local FractureSlices = {}
local NextFearSpawnAt = 0

local FearSpring = advents.spring.new(0)
local FearColorSpring = advents.spring.new(0)
local FearBlinkSpring = advents.spring.new(0)
local FearDistortSpring = advents.spring.new(0)
local SelfPulseSpring = advents.spring.new(0)
local BoomSpring = advents.spring.new(0)

local TraceWords = {
	"TRACE";
	"SHIFT";
	"CUT";
	"VOID";
	"FLASH";
	"LOCK";
	"RIFT";
	"PHASE";
	"SEVER";
	"ZERO";
	"JUDGE";
	"ABSOLVE";
	"AUTHORITY";
	"OMNI";
	"LIMIT";
}

local function shouldApplyToInitiator(): boolean
	return Armed and module.applyEffectsToInitiator == true
end

FearSpring.d = .8
FearSpring.s = 8.8
FearColorSpring.d = .78
FearColorSpring.s = 6.5
FearBlinkSpring.d = .68
FearBlinkSpring.s = 14.5
FearDistortSpring.d = .74
FearDistortSpring.s = 10.8
SelfPulseSpring.d = .84
SelfPulseSpring.s = 6.4
BoomSpring.d = .72
BoomSpring.s = 12.5

local function getNearFx(create)
	if NearFx and NearFx.Parent then
		return NearFx
	end

	local existing = Lighting:FindFirstChild("_tr")
	if existing and existing:IsA("ColorCorrectionEffect") then
		NearFx = existing
		return NearFx
	end

	if not create then
		return nil
	end

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "_tr"
	effect.Enabled = true
	effect.Brightness = 0
	effect.Contrast = 0
	effect.Saturation = 0
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Parent = Lighting
	NearFx = effect
	return effect
end

local function getSelfFx(create)
	if SelfFx and SelfFx.Parent then
		return SelfFx
	end

	local existing = Lighting:FindFirstChild("_trs")
	if existing and existing:IsA("ColorCorrectionEffect") then
		SelfFx = existing
		return SelfFx
	end

	if not create then
		return nil
	end

	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "_trs"
	effect.Enabled = true
	effect.Brightness = 0
	effect.Contrast = 0
	effect.Saturation = 0
	effect.TintColor = Color3.new(1, 1, 1)
	effect.Parent = Lighting
	SelfFx = effect
	return effect
end

local function getNearBlur(create)
	if NearBlur and NearBlur.Parent then
		return NearBlur
	end

	local existing = Lighting:FindFirstChild("_trb")
	if existing and existing:IsA("BlurEffect") then
		NearBlur = existing
		return NearBlur
	end

	if not create then
		return nil
	end

	local blur = Instance.new("BlurEffect")
	blur.Name = "_trb"
	blur.Size = 0
	blur.Enabled = true
	blur.Parent = Lighting
	NearBlur = blur
	return blur
end

local function getNearBloom(create)
	if NearBloom and NearBloom.Parent then
		return NearBloom
	end

	local existing = Lighting:FindFirstChild("_trbl")
	if existing and existing:IsA("BloomEffect") then
		NearBloom = existing
		return NearBloom
	end

	if not create then
		return nil
	end

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "_trbl"
	bloom.Enabled = true
	bloom.Intensity = 0
	bloom.Size = 24
	bloom.Threshold = 1.35
	bloom.Parent = Lighting
	NearBloom = bloom
	return bloom
end

local function getShake()
	return CameraController.CameraShake
end

local function getFearGui()
	if FearGui and FearGui.Parent then
		return FearGui
	end

	local playerGui = Player:FindFirstChildOfClass("PlayerGui") or Player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "_trf"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10_000
	gui.Parent = playerGui
	FearGui = gui
	return gui
end

local function randomGlyph()
	local pools = {
		"ABCDEFGHIJKLMNOPQRSTUVWXYZ";
		"abcdefghijklmnopqrstuvwxyz";
		"0123456789";
		"!@#$%^&*()_+-=[]{}|;:,./<>?";
		"ΔΨΩΦΛΞΣΘΠΓ";
		"░▒▓█▄▀■□▪▫";
	}
	local pool = pools[math.random(1, #pools)]
	return string.sub(pool, math.random(1, #pool), math.random(1, #pool))
end

local function randomString()
	local len = math.random(4, 18)
	local parts = {}
	for i = 1, len do
		if math.random() < .12 then
			table.insert(parts, " ")
		else
			table.insert(parts, randomGlyph())
		end
	end
	return table.concat(parts)
end


local function spawnFearLabel(intensity)
	local gui = getFearGui()
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.AnchorPoint = Vector2.new(.5, .5)
	label.Position = UDim2.fromScale(.18 + (math.random() * .64), .14 + (math.random() * .72))
	label.Size = UDim2.fromScale(.3 + (math.random() * .28), .06 + (math.random() * .05))
	label.Font = Enum.Font.Arcade
	label.TextScaled = true
	label.Text = randomString()
	label.TextColor3 = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(196, 235, 255), math.clamp(.38 + (intensity * .58), 0, 1))
	label.TextStrokeTransparency = 1
	label.TextTransparency = .01 + (math.random() * .06)
	label.Rotation = -14 + (math.random() * 28)
	label.ZIndex = 40 + math.random(0, 12)
	label.Parent = gui

	table.insert(FearLabels, {
		Label = label;
		StartedAt = os.clock();
		Duration = .42 + (math.random() * .7);
		Jitter = 4 + math.random(0, 10);
		BasePosition = label.Position;
		BaseRotation = label.Rotation;
	})
end

local function updateFearLabels(intensity)
	local now = os.clock()
	for index = #FearLabels, 1, -1 do
		local entry = FearLabels[index]
		local label = entry.Label
		if not label or not label.Parent then
			table.remove(FearLabels, index)
		else
			local lifeAlpha = math.clamp((now - entry.StartedAt) / math.max(entry.Duration, .001), 0, 1)
			local fade = 1 - advents.easing.bezier_out(lifeAlpha, 0, .18, .82, 1)
			local jitterX = (-entry.Jitter + (math.random() * entry.Jitter * 2)) * intensity
			local jitterY = (-entry.Jitter + (math.random() * entry.Jitter * 2)) * intensity
			label.Position = entry.BasePosition + UDim2.fromOffset(jitterX, jitterY)
			label.Rotation = entry.BaseRotation + ((-14 + (math.random() * 28)) * intensity)
			label.TextTransparency = math.clamp(.01 + ((1 - fade) * .99), 0, 1)
			label.TextStrokeTransparency = 1
			if lifeAlpha >= 1 then
				label:Destroy()
				table.remove(FearLabels, index)
			end
		end
	end

	if intensity > .08 and now >= NextFearSpawnAt then
		local targetCount = math.floor(3 + (intensity * 9))
		if #FearLabels < targetCount then
			spawnFearLabel(intensity)
		end
		NextFearSpawnAt = now + math.max(.05, .18 - (intensity * .11))
	end
end

local function ensureFractureSlices()
	local gui = getFearGui()
	if #FractureSlices > 0 then
		for _, slice in next, FractureSlices do
			if slice.Frame and slice.Frame.Parent then
				return
			end
		end
	end

	table.clear(FractureSlices)

	for i = 1, 8 do
		local frame = Instance.new("Frame")
		frame.Name = "_trfs"
		frame.BorderSizePixel = 0
		frame.BackgroundColor3 = i % 2 == 0 and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(118, 226, 255)
		frame.BackgroundTransparency = 1
		frame.AnchorPoint = Vector2.new(.5, .5)
		frame.Position = UDim2.fromScale(.5, .5)
		frame.Size = UDim2.fromScale(.9, .015 + (i * .006))
		frame.Rotation = -8 + (i * 2.4)
		frame.ZIndex = 60 + i
		frame.Parent = gui

		table.insert(FractureSlices, {
			Frame = frame;
			BaseY = .14 + ((i - 1) * .1);
			BaseX = .5 + (((i % 2 == 0) and 1 or -1) * (.015 + (i * .008)));
			Life = math.random();
		})
	end
end

local function updateFractureSlices(intensity, boomAlpha)
	ensureFractureSlices()
	local active = math.clamp((intensity * .9) + (boomAlpha * .85), 0, 1)

	for i = #FractureSlices, 1, -1 do
		local slice = FractureSlices[i]
		local frame = slice.Frame
		if not frame or not frame.Parent then
			table.remove(FractureSlices, i)
		else
			slice.Life += .018 + (active * .06)
			local snap = math.sin((slice.Life * 17) + i) * active
			local drift = math.cos((slice.Life * 11) + (i * .7)) * active
			local tear = math.sin((slice.Life * 23) + (i * 1.6)) * active
			frame.Visible = active > .03
			frame.BackgroundTransparency = math.clamp(1 - ((active * .34) + (boomAlpha * .3)), .46, 1)
			frame.Position = UDim2.fromScale(
				slice.BaseX + (snap * .028) + (tear * .012),
				slice.BaseY + (drift * .014)
			)
			frame.Size = UDim2.fromScale(
				.84 + (active * .18) + (math.abs(tear) * .06),
				(.008 + (i * .005)) + (active * .008)
			)
			frame.Rotation = (-10 + (i * 2.8)) + (snap * 14) + (tear * 8)
		end
	end
end

local function getDomainSound()
	if DomainSound and DomainSound.Parent then
		return DomainSound
	end

	local sound = Instance.new("Sound")
	sound.Name = "_trd"
	sound.SoundId = "rbxassetid://82123083577420"
	sound.Looped = true
	sound.Volume = 0
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = SoundService
	DomainSound = sound
	return sound
end

local function getDomainBedSound()
	if DomainBedSound and DomainBedSound.Parent then
		return DomainBedSound
	end

	local sound = Instance.new("Sound")
	sound.Name = "_trdb"
	sound.SoundId = "rbxassetid://82123083577420"
	sound.Looped = true
	sound.Volume = 0
	sound.PlaybackSpeed = .72
	sound.RollOffMode = Enum.RollOffMode.Linear
	sound.Parent = SoundService
	DomainBedSound = sound
	return sound
end

local function playBoomSound()
	local sound = Instance.new("Sound")
	sound.SoundId = "rbxassetid://111802948508055"
	sound.Volume = .75
	sound.Parent = SoundService
	sound.Ended:Connect(function()
		sound:Destroy()
	end)
	sound:Play()
end

local function refreshTrack()
	local count = 0
	for _ in next, Nearby do
		count += 1
	end
	if shouldApplyToInitiator() then
		count += 1
	end

	if count > 0 then
		if not NearTrack or not NearTrack:IsAlive() then
			local shake = getShake()
			if shake then
				NearTrack = shake:ShakeSustain(CameraShake.Presets.Windbreak:Scale(.68):With({
					FadeIn = .06;
					FadeOut = .16;
					Magnitude = .54;
					Roughness = 9.6;
					FovInfluence = .11;
					PositionInfluence = vector.create(.09, .2, .05);
					RotationInfluence = vector.create(.82, .52, .94);
					RotationFrequency = vector.create(2.4, 3.1, 3.7);
					PositionBias = vector.create(0, -.42, 0);
					RotationBias = vector.create(.56, 0, 0);
				}))
			end
		end
	elseif NearTrack then
		NearTrack:Stop(.12)
		NearTrack = nil
	end
end

BlinkClient.TraceBind.On(function(payload)
	Armed = payload.Enabled == true
end)

BlinkClient.TraceNear.On(function(payload)
	if payload.Enabled then
		Nearby[payload.UserId] = payload.Scale or true
	else
		Nearby[payload.UserId] = nil
	end
	refreshTrack()
end)

BlinkClient.TraceBoom.On(function(payload)
	local shake = getShake()
	if shake then
		shake:Shake(CameraShake.Presets.Windbreak:Scale((payload.Magnitude or 1) * 1.18):With({
			FadeIn = .01;
			FadeOut = .32;
			FovInfluence = .18;
			PositionInfluence = vector.create(.4, .14, .12);
			RotationInfluence = vector.create(.8, 1.2, 1.7);
		}))
	end
	BoomSpring.p += 1.2
	BoomSpring.v += 2.15
	playBoomSound()
end)

BlinkClient.TraceBoomFx.On(function(_payload)
	BoomSpring.p += .62
	BoomSpring.v += 1.15
	playBoomSound()
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not Armed then
		return
	end

	if input.KeyCode ~= Enum.KeyCode.T then
		return
	end

	if UserInputService:GetFocusedTextBox() then
		return
	end

	local mouse = Player:GetMouse()
	if not mouse or not mouse.Hit then
		return
	end

	BlinkClient.TraceDash.Fire({
		X = mouse.Hit.Position.X;
		Y = mouse.Hit.Position.Y;
		Z = mouse.Hit.Position.Z;
	})
end)

RunService.PreRender:Connect(function()
	local nearCount = 0
	for _ in next, Nearby do
		nearCount += 1
	end
	local initiatorEffects = shouldApplyToInitiator()
	local effectCount = nearCount + (initiatorEffects and 1 or 0)

	if effectCount > 0 and (not NearTrack or not NearTrack:IsAlive()) then
		refreshTrack()
	end

	local now = os.clock()
	local fearTarget = math.clamp((effectCount / 1.6) + (initiatorEffects and .12 or 0), 0, 1)
	updateFearLabels(fearTarget)
	local blinkWave = math.max(0, math.sin((now * 11.5) + (math.sin(now * 2.3) * 1.7)))
	local wiggleWave = (math.sin((now * 5.2) + .8) + 1) * .5
	local holyWave = (math.sin((now * 2.8) + (math.sin(now * .9) * .4)) + 1) * .5

	FearSpring.t = fearTarget
	FearColorSpring.t = math.clamp((fearTarget * .88) + (wiggleWave * .12), 0, 1)
	FearBlinkSpring.t = fearTarget * blinkWave
	FearDistortSpring.t = fearTarget * (.55 + (wiggleWave * .45))
	SelfPulseSpring.t = initiatorEffects and (.26 + (holyWave * .34)) or 0
	BoomSpring.t = 0

	local boomAlpha = math.clamp(BoomSpring.p, 0, 1)
	local fearAlpha = math.clamp(FearSpring.p + (boomAlpha * .18), 0, 1)
	local blinkAlpha = math.clamp(FearBlinkSpring.p + (boomAlpha * .28), 0, 1)
	local distortAlpha = math.clamp(FearDistortSpring.p + (boomAlpha * .16), 0, 1)
	local selfAlpha = math.clamp(SelfPulseSpring.p + (boomAlpha * .08), 0, 1)
	--updateFractureSlices(math.max(fearAlpha, selfAlpha * .8), boomAlpha)

	local nearFx = getNearFx(fearAlpha > .001)
	if nearFx then
		nearFx.Enabled = fearAlpha > .001
		nearFx.Brightness = (.03 * fearAlpha) + (blinkAlpha * .08) + (boomAlpha * .035)
		nearFx.Contrast = (.34 + (1.28 * fearAlpha)) + (blinkAlpha * .34) + (boomAlpha * .22)
		nearFx.Saturation = -(.26 + (fearAlpha * 1.18))
		nearFx.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(120, 228, 255), math.clamp(FearColorSpring.p + (blinkAlpha * .24), 0, 1))
	end

	local selfFx = getSelfFx(initiatorEffects or selfAlpha > .001)
	if selfFx then
		selfFx.Enabled = initiatorEffects or selfAlpha > .001
		selfFx.Brightness = .026 + (selfAlpha * .05) + (boomAlpha * .018)
		selfFx.Contrast = .12 + (selfAlpha * .46) + (boomAlpha * .08)
		selfFx.Saturation = -.04 + (selfAlpha * .12)
		selfFx.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(240, 249, 255), math.clamp(.62 + (selfAlpha * .38), 0, 1))
	end

	local blur = getNearBlur(fearAlpha > .001 or boomAlpha > .001)
	if blur then
		blur.Enabled = fearAlpha > .001 or boomAlpha > .001
		blur.Size = (fearAlpha * 9.8) + (blinkAlpha * 8.6) + (distortAlpha * 7.4) + (boomAlpha * 13.5)
	end

	local bloom = getNearBloom(initiatorEffects or fearAlpha > .001 or boomAlpha > .001)
	if bloom then
		bloom.Enabled = initiatorEffects or fearAlpha > .001 or boomAlpha > .001
		bloom.Intensity = .34 + (selfAlpha * .42) + (fearAlpha * .62) + (boomAlpha * .8)
		bloom.Size = 24 + (fearAlpha * 21) + (boomAlpha * 18)
		bloom.Threshold = math.clamp(1.08 - (selfAlpha * .18) - (fearAlpha * .12) - (boomAlpha * .08), .58, 1.3)
	end

	local domainSound = getDomainSound()
	local domainBedSound = getDomainBedSound()
	if initiatorEffects or nearCount > 0 then
		if not domainSound.Playing then
			domainSound:Play()
		end
		if not domainBedSound.Playing then
			domainBedSound:Play()
		end
		local ownerBias = initiatorEffects and .14 or 0
		domainSound.Volume += ((.2 + ownerBias + (fearAlpha * .28) + (boomAlpha * .08)) - domainSound.Volume) * .14
		domainSound.PlaybackSpeed += ((.94 + (fearAlpha * .07) + (blinkAlpha * .05) + (initiatorEffects and .07 or 0)) - domainSound.PlaybackSpeed) * .14
		domainBedSound.Volume += ((.12 + (fearAlpha * .22) + (selfAlpha * .12) + (boomAlpha * .06)) - domainBedSound.Volume) * .1
		domainBedSound.PlaybackSpeed += ((.68 + (fearAlpha * .05) + (distortAlpha * .04)) - domainBedSound.PlaybackSpeed) * .1
	elseif domainSound.Playing then
		domainSound.Volume += (0 - domainSound.Volume) * .18
		domainBedSound.Volume += (0 - domainBedSound.Volume) * .14
		if domainSound.Volume <= .02 then
			domainSound:Stop()
			domainSound.Volume = 0
			domainSound.PlaybackSpeed = 1
		end
		if domainBedSound.Volume <= .015 then
			domainBedSound:Stop()
			domainBedSound.Volume = 0
			domainBedSound.PlaybackSpeed = .72
		end
	end
end)

return module
