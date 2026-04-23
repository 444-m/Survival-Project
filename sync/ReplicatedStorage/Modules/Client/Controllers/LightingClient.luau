--!strict

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local advents = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
local easing = advents.easing
local Shared = require "@game/ReplicatedStorage/Modules/Shared/Controllers/LightingShared"

local Terrain = workspace.Terrain

local Atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local Clouds = Terrain:FindFirstChildOfClass("Clouds")
local ColorCorrection = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
local Bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local SunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")

-- ❌ Depth of Field completely removed
local DepthOfField = nil

if not Atmosphere then
	Atmosphere = Instance.new("Atmosphere")
	Atmosphere.Parent = Lighting
end

if not Clouds then
	Clouds = Instance.new("Clouds")
	Clouds.Parent = Terrain
end

if not ColorCorrection then
	ColorCorrection = Instance.new("ColorCorrectionEffect")
	ColorCorrection.Parent = Lighting
end

if not Bloom then
	Bloom = Instance.new("BloomEffect")
	Bloom.Parent = Lighting
end

if not SunRays then
	SunRays = Instance.new("SunRaysEffect")
	SunRays.Parent = Lighting
end

-- make sure DOF is deleted if it exists in studio
local existingDOF = Lighting:FindFirstChildOfClass("DepthOfFieldEffect")
if existingDOF then
	existingDOF:Destroy()
end

if ColorCorrection then ColorCorrection.Enabled = true end
if Bloom then Bloom.Enabled = true end
if SunRays then SunRays.Enabled = true end

type State = {
	ClockTime: number,
	Phase: Shared.TimeOfDay,
	NextPhase: Shared.TimeOfDay,
	PhaseAlpha: number,
}

local CurrentState: State = {
	ClockTime = Shared.Config.StartTime,
	Phase = "Morning",
	NextPhase = "Noon",
	PhaseAlpha = 0,
}

local TargetState: State = table.clone(CurrentState)

local ClockVelocity = 0
local AlphaVelocity = 0

local function SpringDamp(Current: number, Target: number, Velocity: number, Stiffness: number, Damping: number, DT: number): (number, number)
	local Force = (Target - Current) * Stiffness - Velocity * Damping
	local NewVelocity = Velocity + Force * DT
	return Current + NewVelocity * DT, NewVelocity
end

local function ApplySnapshot(Snap: Shared.PhaseConfig)
	local L = Snap.Lighting
	local F = Snap.Fog
	local A = Snap.Atmosphere
	local C = Snap.Clouds
	local CC = Snap.ColorCorrection
	local B = Snap.Bloom
	local SR = Snap.SunRays

	Lighting.ClockTime = L.ClockTime
	Lighting.Ambient = L.Ambient
	Lighting.OutdoorAmbient = L.OutdoorAmbient
	Lighting.Brightness = L.Brightness
	Lighting.ColorShift_Bottom = L.ColorShift_Bottom
	Lighting.ColorShift_Top = L.ColorShift_Top
	Lighting.EnvironmentDiffuseScale = L.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = L.EnvironmentSpecularScale
	Lighting.ExposureCompensation = L.ExposureCompensation
	Lighting.FogColor = F.FogColor
	Lighting.FogEnd = F.FogEnd
	Lighting.FogStart = F.FogStart

	if Atmosphere then
		Atmosphere.Density = A.Density
		Atmosphere.Offset = A.Offset
		Atmosphere.Color = A.Color
		Atmosphere.Decay = A.Decay
		Atmosphere.Glare = A.Glare
		Atmosphere.Haze = A.Haze
	end

	if Clouds then
		Clouds.Cover = C.Cover
		Clouds.Density = C.Density
		Clouds.Color = C.Color
	end

	if ColorCorrection then
		ColorCorrection.Brightness = CC.Brightness
		ColorCorrection.Contrast = CC.Contrast
		ColorCorrection.Saturation = CC.Saturation
		ColorCorrection.TintColor = CC.TintColor
	end

	if Bloom then
		Bloom.Intensity = B.Intensity
		Bloom.Size = B.Size
		Bloom.Threshold = B.Threshold
	end

	if SunRays then
		SunRays.Intensity = SR.Intensity
		SunRays.Spread = SR.Spread
	end
end

local SyncRemote = Shared.GetRemote("DayNightSync")

local LightingClient = {
	HasSynced = false;
}

function LightingClient.Init()
	SyncRemote.OnClientEvent:Connect(function(Payload: Shared.SyncPayload)
		if not LightingClient.HasSynced then
			LightingClient.HasSynced = true
			CurrentState.ClockTime = Payload.ClockTime
			CurrentState.Phase = Payload.Phase
			CurrentState.NextPhase = Payload.NextPhase
			CurrentState.PhaseAlpha = Payload.PhaseAlpha
		end

		TargetState.ClockTime = Payload.ClockTime
		TargetState.Phase = Payload.Phase
		TargetState.NextPhase = Payload.NextPhase
		TargetState.PhaseAlpha = Payload.PhaseAlpha
	end)

	RunService.PreRender:Connect(function(DT)
		if not LightingClient.HasSynced then return end

		local PhaseA = Shared.Config.Phases[TargetState.Phase]
		local PhaseB = Shared.Config.Phases[TargetState.NextPhase]
		if not PhaseA or not PhaseB then return end

		CurrentState.PhaseAlpha, AlphaVelocity = SpringDamp(
			CurrentState.PhaseAlpha, TargetState.PhaseAlpha, AlphaVelocity, 8, 4, DT
		)

		CurrentState.Phase = TargetState.Phase
		CurrentState.NextPhase = TargetState.NextPhase

		local Alpha = math.clamp(CurrentState.PhaseAlpha, 0, 1)
		local IsDawnDusk = CurrentState.Phase == "Dawn" or CurrentState.Phase == "Dusk"
		local TimeEase = easing.cubic(Alpha, "inout")
		local BlendEase = if IsDawnDusk then easing.hermite(Alpha, "inout") else easing.quart(Alpha, "inout")

		ApplySnapshot(Shared.InterpolatePhase(PhaseA, PhaseB, TimeEase, BlendEase))
	end)
end

return LightingClient