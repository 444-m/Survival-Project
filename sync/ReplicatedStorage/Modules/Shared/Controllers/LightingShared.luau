--!strict

local Config = require "@self/LightingConfig"

export type TimeOfDay = keyof<{
	Dawn: any; Morning: any; Noon: any; Afternoon: any;
	Dusk: any; Evening: any; Night: any; Midnight: any;
}>

export type LightingSnapshot = {
	ClockTime: number;
	Ambient: Color3;
	OutdoorAmbient: Color3;
	Brightness: number;
	ColorShift_Bottom: Color3;
	ColorShift_Top: Color3;
	EnvironmentDiffuseScale: number;
	EnvironmentSpecularScale: number;
	ExposureCompensation: number;
}

export type FogSnapshot = {
	FogColor: Color3;
	FogEnd: number;
	FogStart: number;
}

export type AtmosphereSnapshot = {
	Density: number;
	Offset: number;
	Color: Color3;
	Decay: Color3;
	Glare: number;
	Haze: number;
}

export type CloudSnapshot = {
	Cover: number;
	Density: number;
	Color: Color3;
}

export type ColorCorrectionSnapshot = {
	Brightness: number;
	Contrast: number;
	Saturation: number;
	TintColor: Color3;
}

export type BloomSnapshot = {
	Intensity: number;
	Size: number;
	Threshold: number;
}

export type SunRaysSnapshot = {
	Intensity: number;
	Spread: number;
}

export type DepthOfFieldSnapshot = {
	FarIntensity: number;
	NearIntensity: number;
	FocusDistance: number;
	InFocusRadius: number;
}

export type PhaseConfig = {
	Lighting: LightingSnapshot;
	Fog: FogSnapshot;
	Atmosphere: AtmosphereSnapshot;
	Clouds: CloudSnapshot;
	ColorCorrection: ColorCorrectionSnapshot;
	Bloom: BloomSnapshot;
	SunRays: SunRaysSnapshot;
	DepthOfField: DepthOfFieldSnapshot;
}

export type SyncPayload = {
	ClockTime: number;
	Phase: TimeOfDay;
	NextPhase: TimeOfDay;
	PhaseAlpha: number;
}

local REMOTES_FOLDER = "DayNightRemotes"

local function GetOrCreateFolder(): Folder
	local RS = game:GetService("ReplicatedStorage")
	local Existing = RS:FindFirstChild(REMOTES_FOLDER)
	if Existing then return Existing :: Folder end
	local F = Instance.new("Folder")
	F.Name = REMOTES_FOLDER
	F.Parent = RS
	return F
end

local Shared = {}

Shared.SYNC_RATE = 10
Shared.Config = Config

Shared.PHASE_ORDER = {
	"Dawn", "Morning", "Noon", "Afternoon", "Dusk", "Evening", "Night", "Midnight",
} :: {TimeOfDay}

Shared.PHASE_TIMES = {
	Dawn      = 5.5,
	Morning   = 7.5,
	Noon      = 12,
	Afternoon = 15,
	Dusk      = 18,
	Evening   = 20,
	Night     = 22,
	Midnight  = 0,
} :: {[TimeOfDay]: number}

function Shared.GetRemote(Name: string): RemoteEvent
	local Folder = GetOrCreateFolder()
	local Existing = Folder:FindFirstChild(Name)
	if Existing then return Existing :: RemoteEvent end
	local R = Instance.new("RemoteEvent")
	R.Name = Name
	R.Parent = Folder
	return R
end

function Shared.GetCurrentPhase(ClockTime: number): (TimeOfDay, TimeOfDay, number)
	local Order = Shared.PHASE_ORDER
	local Times = Shared.PHASE_TIMES

	local CurrentIndex = 1
	for I = 1, #Order do
		local T = Times[Order[I]]
		local Prev = Times[Order[CurrentIndex]]
		local CT = ClockTime

		local NormT = T
		local NormPrev = Prev
		local NormCT = CT

		if T == 0 then NormT = 24 end
		if Prev == 0 then NormPrev = 24 end
		if CT == 0 then NormCT = 24 end

		if NormT <= NormCT and NormT > NormPrev then
			CurrentIndex = I
		end
	end

	local NextIndex = (CurrentIndex % #Order) + 1
	local CurrentPhase = Order[CurrentIndex]
	local NextPhase = Order[NextIndex]

	local CurrentTime = Times[CurrentPhase]
	local NextTime = Times[NextPhase]

	if CurrentTime == 0 then CurrentTime = 24 end
	if NextTime == 0 or NextTime <= CurrentTime then NextTime += 24 end

	local CT = ClockTime == 0 and 24 or ClockTime
	local Alpha = math.clamp((CT - CurrentTime) / (NextTime - CurrentTime), 0, 1)

	return CurrentPhase, NextPhase, Alpha
end

local function L(A: number, B: number, T: number): number
	return A + (B - A) * T
end

local function LC(A: Color3, B: Color3, T: number): Color3
	return Color3.new(A.R + (B.R - A.R) * T, A.G + (B.G - A.G) * T, A.B + (B.B - A.B) * T)
end

local function Lf(a: number?, b: number?, t: number): number
	const av = a or b or 0
	const bv = b or a or 0
	return L(av, bv, t)
end

local function LCf(a: Color3?, b: Color3?, t: number): Color3
	const av = a or b or Color3.new(0, 0, 0)
	const bv = b or a or Color3.new(0, 0, 0)
	return LC(av, bv, t)
end

function Shared.InterpolatePhase(A: PhaseConfig, B: PhaseConfig, T: number, E: number): PhaseConfig
	const AL = A.Lighting or {}
	const BL = B.Lighting or {}
	const AF = A.Fog or {}
	const BF = B.Fog or {}
	const AA = A.Atmosphere or {}
	const BA = B.Atmosphere or {}
	const AC = A.Clouds or {}
	const BC = B.Clouds or {}
	const ACC = A.ColorCorrection or {}
	const BCC = B.ColorCorrection or {}
	const AB = A.Bloom or {}
	const BB = B.Bloom or {}
	const AS = A.SunRays or {}
	const BS = B.SunRays or {}
	const AD = A.DepthOfField or {}
	const BD = B.DepthOfField or {}

	return {
		Lighting = {
			ClockTime                = Lf(AL.ClockTime, BL.ClockTime, T);
			Ambient                  = LCf(AL.Ambient, BL.Ambient, E);
			OutdoorAmbient           = LCf(AL.OutdoorAmbient, BL.OutdoorAmbient, E);
			Brightness               = Lf(AL.Brightness, BL.Brightness, E);
			ColorShift_Bottom        = LCf(AL.ColorShift_Bottom, BL.ColorShift_Bottom, E);
			ColorShift_Top           = LCf(AL.ColorShift_Top, BL.ColorShift_Top, E);
			EnvironmentDiffuseScale  = Lf(AL.EnvironmentDiffuseScale, BL.EnvironmentDiffuseScale, E);
			EnvironmentSpecularScale = Lf(AL.EnvironmentSpecularScale, BL.EnvironmentSpecularScale, E);
			ExposureCompensation     = Lf(AL.ExposureCompensation, BL.ExposureCompensation, E);
		};
		Fog = {
			FogColor = LCf(AF.FogColor, BF.FogColor, E);
			FogEnd   = Lf(AF.FogEnd, BF.FogEnd, E);
			FogStart = Lf(AF.FogStart, BF.FogStart, E);
		};
		Atmosphere = {
			Density = Lf(AA.Density, BA.Density, E);
			Offset  = Lf(AA.Offset, BA.Offset, E);
			Color   = LCf(AA.Color, BA.Color, E);
			Decay   = LCf(AA.Decay, BA.Decay, E);
			Glare   = Lf(AA.Glare, BA.Glare, E);
			Haze    = Lf(AA.Haze, BA.Haze, E);
		};
		Clouds = {
			Cover   = Lf(AC.Cover, BC.Cover, E);
			Density = Lf(AC.Density, BC.Density, E);
			Color   = LCf(AC.Color, BC.Color, E);
		};
		ColorCorrection = {
			Brightness = Lf(ACC.Brightness, BCC.Brightness, E);
			Contrast   = Lf(ACC.Contrast, BCC.Contrast, E);
			Saturation = Lf(ACC.Saturation, BCC.Saturation, E);
			TintColor  = LCf(ACC.TintColor, BCC.TintColor, E);
		};
		Bloom = {
			Intensity = Lf(AB.Intensity, BB.Intensity, E);
			Size      = Lf(AB.Size, BB.Size, E);
			Threshold = Lf(AB.Threshold, BB.Threshold, E);
		};
		SunRays = {
			Intensity = Lf(AS.Intensity, BS.Intensity, E);
			Spread    = Lf(AS.Spread, BS.Spread, E);
		};
		DepthOfField = {
			FarIntensity  = Lf(AD.FarIntensity, BD.FarIntensity, E);
			NearIntensity = Lf(AD.NearIntensity, BD.NearIntensity, E);
			FocusDistance = Lf(AD.FocusDistance, BD.FocusDistance, E);
			InFocusRadius = Lf(AD.InFocusRadius, BD.InFocusRadius, E);
		};
	}
end

return Shared
