--!strict
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require("@self/Janitor")
local advents = require(ReplicatedStorage.Modules.Shared.utils.advents)

export type ShakePreset = {
	Name: string?,
	Magnitude: number,
	Roughness: number,
	FadeIn: number,
	FadeOut: number,
	Sustain: boolean?,
	EasingStyle: string?,
	PositionInfluence: vector?,
	RotationInfluence: vector?,
	FovInfluence: number?,
	PositionFrequency: vector?,
	RotationFrequency: vector?,
	FovFrequency: number?,
	PositionBias: vector?,
	RotationBias: vector?,
}

export type ShakeCallback = (Delta: CFrame, FovOffset: number, PositionOffset: vector, RotationOffset: vector, Dt: number) -> ()

export type ShakeTrack = {
	Id: number,
	StartFadeOut: (self: ShakeTrack, FadeOut: number?) -> (),
	Stop: (self: ShakeTrack, FadeOut: number?) -> (),
	Scale: (self: ShakeTrack, MagnitudeScale: number, RoughnessScale: number?) -> ShakeTrack,
	IsAlive: (self: ShakeTrack) -> boolean,
}

type InternalShake = ShakePreset & {
	Id: number,
	Age: number,
	Time: number,
	FadeOutStart: number?,
	Dead: boolean,
	Seed: number,
}

type InternalShakeTrack = ShakeTrack & {
	_Shake: InternalShake?,
}

type CameraShake = {
	Callback: ShakeCallback,
	Janitor: any,
	PositionSpring: any,
	RotationSpring: any,
	FovSpring: any,
	PositionOffset: vector,
	RotationOffset: vector,
	FovOffset: number,
	Shakes: {[number]: InternalShake},
	Running: boolean,
	NextId: number,
	Connection: RBXScriptConnection?,
	Update: (self: CameraShake, Dt: number) -> (),
	Start: (self: CameraShake) -> CameraShake,
	Stop: (self: CameraShake, Reset: boolean?) -> CameraShake,
	Destroy: (self: CameraShake) -> (),
	Shake: (self: CameraShake, MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, Sustain: boolean?, EasingStyle: string?) -> ShakeTrack,
	ShakeSustain: (self: CameraShake, MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, EasingStyle: string?) -> ShakeTrack,
	Impulse: (self: CameraShake, MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, EasingStyle: string?) -> ShakeTrack,
	StopAll: (self: CameraShake, FadeOut: number?) -> (),
	GetOffset: (self: CameraShake) -> (CFrame, number, vector, vector),
}

local CameraShake = {}
CameraShake.__index = CameraShake

local Presets = require("@self/Presets")
CameraShake.Presets = Presets

local DEFAULT_POSITION = vector.create(.15, .09, .12)
local DEFAULT_ROTATION = vector.create(1.25, 1.5, 1.85)
local DEFAULT_POSITION_FREQUENCY = vector.create(1, 1.2, .88)
local DEFAULT_ROTATION_FREQUENCY = vector.create(1.1, .94, 1.26)

local function clamp01(Value: number): number
	return math.clamp(Value, 0, 1)
end

local function bezierOut(Alpha: number): number
	return advents.easing.bezier_out(clamp01(Alpha), 0, .2, .8, 1)
end

local function bezierInOut(Alpha: number): number
	return advents.easing.bezier_inout(clamp01(Alpha), 0, .18, .82, 1)
end

local function expoOut(Alpha: number): number
	if Alpha <= 0 then
		return 0
	end
	if Alpha >= 1 then
		return 1
	end
	return 1 - (2 ^ (-10 * Alpha))
end

local function smoothStep(Alpha: number): number
	local T = clamp01(Alpha)
	return T * T * (3 - (2 * T))
end

local function getEase(Style: string?, Alpha: number): number
	local Key = string.lower(Style or "bezierout")
	if Key == "linear" then
		return clamp01(Alpha)
	end
	if Key == "smooth" then
		return smoothStep(Alpha)
	end
	if Key == "expout" then
		return expoOut(Alpha)
	end
	if Key == "bezierinout" then
		return bezierInOut(Alpha)
	end
	return bezierOut(Alpha)
end

local function hashPhase(Seed: number, Offset: number): number
	local Value = math.sin((Seed * 12.9898) + (Offset * 78.233)) * 43758.5453
	return (Value - math.floor(Value)) * math.pi * 2
end

local function harmonicNoise(Time: number, BaseFrequency: number, Phase: number): number
	local T = Time * BaseFrequency
	local A = math.sin(T + Phase)
	local B = math.sin((T * 1.87) + (Phase * 1.41)) * .5
	local C = math.sin((T * 2.73) + (Phase * .74)) * .25
	return (A + B + C) / 1.75
end

local function getEnvelope(Shake: InternalShake): number
	local FadeIn = math.max(Shake.FadeIn, 0)
	local FadeOut = math.max(Shake.FadeOut, 0)
	local Age = math.max(Shake.Age, 0)
	local Ease = Shake.EasingStyle

	if Shake.Sustain then
		if Shake.FadeOutStart then
			local ElapsedFade = Age - Shake.FadeOutStart
			if FadeOut <= 0 then
				return 0
			end
			return 1 - getEase(Ease, ElapsedFade / FadeOut)
		end

		if FadeIn <= 0 then
			return 1
		end

		return getEase(Ease, Age / FadeIn)
	end

	local Total = FadeIn + FadeOut
	if Total <= 0 then
		return 1
	end

	if Age < FadeIn then
		if FadeIn <= 0 then
			return 1
		end
		return getEase(Ease, Age / FadeIn)
	end

	local FadeAlpha = (Age - FadeIn) / math.max(FadeOut, 1e-4)
	return 1 - getEase(Ease, FadeAlpha)
end

local function makeTrack(Shake: InternalShake): InternalShakeTrack
	local Track = {} :: InternalShakeTrack
	Track.Id = Shake.Id
	Track._Shake = Shake

	function Track:StartFadeOut(FadeOut: number?)
		local CurrentShake = self._Shake
		if not CurrentShake or CurrentShake.Dead then
			return
		end

		CurrentShake.Sustain = false
		CurrentShake.FadeOutStart = CurrentShake.Age
		if FadeOut ~= nil then
			CurrentShake.FadeOut = math.max(FadeOut, 0)
		end
	end

	function Track:Stop(FadeOut: number?)
		self:StartFadeOut(FadeOut)
	end

	function Track:Scale(MagnitudeScale: number, RoughnessScale: number?): ShakeTrack
		local CurrentShake = self._Shake
		if CurrentShake and not CurrentShake.Dead then
			CurrentShake.Magnitude *= MagnitudeScale
			CurrentShake.Roughness *= RoughnessScale or MagnitudeScale
		end
		return self
	end

	function Track:IsAlive(): boolean
		local CurrentShake = self._Shake
		return CurrentShake ~= nil and not CurrentShake.Dead
	end

	return Track
end

local function copyPreset(Preset: ShakePreset): ShakePreset
	return {
		Name = Preset.Name,
		Magnitude = Preset.Magnitude,
		Roughness = Preset.Roughness,
		FadeIn = Preset.FadeIn,
		FadeOut = Preset.FadeOut,
		Sustain = Preset.Sustain,
		EasingStyle = Preset.EasingStyle,
		PositionInfluence = Preset.PositionInfluence,
		RotationInfluence = Preset.RotationInfluence,
		FovInfluence = Preset.FovInfluence,
		PositionFrequency = Preset.PositionFrequency,
		RotationFrequency = Preset.RotationFrequency,
		FovFrequency = Preset.FovFrequency,
		PositionBias = Preset.PositionBias,
		RotationBias = Preset.RotationBias,
	}
end

local function resolvePreset(MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, Sustain: boolean?, EasingStyle: string?): ShakePreset
	local Preset: ShakePreset

	if type(MagnitudeOrPreset) == "table" then
		Preset = copyPreset(MagnitudeOrPreset :: ShakePreset)
		if type(RoughnessOrOverrides) == "table" then
			for Key, Value in next, RoughnessOrOverrides :: {[string]: any} do
				(Preset :: {[string]: any})[Key] = Value
			end
		end
	else
		Preset = {
			Magnitude = MagnitudeOrPreset :: number,
			Roughness = type(RoughnessOrOverrides) == "number" and (RoughnessOrOverrides :: number) or 14,
			FadeIn = FadeIn or 0,
			FadeOut = FadeOut or .2,
			PositionInfluence = PositionInfluence or DEFAULT_POSITION,
			RotationInfluence = RotationInfluence or DEFAULT_ROTATION,
			FovInfluence = FovInfluence or 0,
			Sustain = Sustain,
			EasingStyle = EasingStyle or "BezierOut",
			PositionFrequency = DEFAULT_POSITION_FREQUENCY,
			RotationFrequency = DEFAULT_ROTATION_FREQUENCY,
			FovFrequency = 1.08,
			PositionBias = vector.zero,
			RotationBias = vector.zero,
		}
	end

	Preset.Magnitude = math.max(Preset.Magnitude or 0, 0)
	Preset.Roughness = math.max(Preset.Roughness or 0, 0)
	Preset.FadeIn = math.max(Preset.FadeIn or 0, 0)
	Preset.FadeOut = math.max(Preset.FadeOut or 0, 0)
	Preset.PositionInfluence = Preset.PositionInfluence or DEFAULT_POSITION
	Preset.RotationInfluence = Preset.RotationInfluence or DEFAULT_ROTATION
	Preset.FovInfluence = Preset.FovInfluence or 0
	Preset.PositionFrequency = Preset.PositionFrequency or DEFAULT_POSITION_FREQUENCY
	Preset.RotationFrequency = Preset.RotationFrequency or DEFAULT_ROTATION_FREQUENCY
	Preset.FovFrequency = Preset.FovFrequency or 1.08
	Preset.PositionBias = Preset.PositionBias or vector.zero
	Preset.RotationBias = Preset.RotationBias or vector.zero
	Preset.EasingStyle = Preset.EasingStyle or "BezierOut"

	return Preset
end

function CameraShake.new(Callback: ShakeCallback): CameraShake
	local self = setmetatable({}, CameraShake) :: any

	self.Callback = Callback
	self.Janitor = Janitor.new()
	self.PositionSpring = advents.spring.new(vector.zero)
	self.RotationSpring = advents.spring.new(vector.zero)
	self.FovSpring = advents.spring.new(0)
	self.PositionSpring.d = .8
	self.PositionSpring.s = 26
	self.RotationSpring.d = .84
	self.RotationSpring.s = 28
	self.FovSpring.d = .88
	self.FovSpring.s = 24
	self.PositionOffset = vector.zero
	self.RotationOffset = vector.zero
	self.FovOffset = 0
	self.Shakes = {}
	self.Running = false
	self.NextId = 0
	self.Connection = nil

	self.Janitor:Add(function()
		self:Stop(true)
	end, true, "CameraShakeShutdown")

	self:Start()
	return self
end

function CameraShake:Start(): CameraShake
	if self.Running then
		return self
	end

	self.Running = true
	self.Connection = RunService.RenderStepped:Connect(function(Dt: number)
		self:Update(Dt)
	end)
	self.Janitor:Add(self.Connection, "Disconnect", "CameraShakeConnection")

	return self
end

function CameraShake:Stop(Reset: boolean?): CameraShake
	self.Running = false
	self.Janitor:Remove("CameraShakeConnection")
	self.Connection = nil

	if Reset then
		self:StopAll(0)
		self.PositionSpring.p = vector.zero
		self.PositionSpring.t = vector.zero
		self.RotationSpring.p = vector.zero
		self.RotationSpring.t = vector.zero
		self.FovSpring.p = 0
		self.FovSpring.t = 0
		self.PositionOffset = vector.zero
		self.RotationOffset = vector.zero
		self.FovOffset = 0
		self.Callback(CFrame.identity, 0, vector.zero, vector.zero, 0)
	end

	return self
end

function CameraShake:Destroy()
	self.Janitor:Cleanup()
end

function CameraShake:GetOffset(): (CFrame, number, vector, vector)
	local PositionOffset = self.PositionOffset
	local RotationOffset = self.RotationOffset
	local Delta = CFrame.new(PositionOffset)
		* CFrame.Angles(math.rad(RotationOffset.X), math.rad(RotationOffset.Y), math.rad(RotationOffset.Z))
	return Delta, self.FovOffset, PositionOffset, RotationOffset
end

function CameraShake:Update(Dt: number)
	local PositionTarget = vector.zero
	local RotationTarget = vector.zero
	local FovTarget = 0

	for Id, Shake in next, self.Shakes do
		Shake.Age += Dt
		Shake.Time += Dt * math.max(Shake.Roughness, 0)

		local Envelope = getEnvelope(Shake)
		if Envelope <= 1e-4 then
			Shake.Dead = true
			self.Shakes[Id] = nil
		else
			local Magnitude = Shake.Magnitude * Envelope
			local PositionFrequency = Shake.PositionFrequency or DEFAULT_POSITION_FREQUENCY
			local RotationFrequency = Shake.RotationFrequency or DEFAULT_ROTATION_FREQUENCY
			local PositionNoise = vector.create(
				harmonicNoise(Shake.Time, PositionFrequency.X, hashPhase(Shake.Seed, 1)),
				harmonicNoise(Shake.Time, PositionFrequency.Y, hashPhase(Shake.Seed, 2)),
				harmonicNoise(Shake.Time, PositionFrequency.Z, hashPhase(Shake.Seed, 3))
			)
			local RotationNoise = vector.create(
				harmonicNoise(Shake.Time, RotationFrequency.X, hashPhase(Shake.Seed, 4)),
				harmonicNoise(Shake.Time, RotationFrequency.Y, hashPhase(Shake.Seed, 5)),
				harmonicNoise(Shake.Time, RotationFrequency.Z, hashPhase(Shake.Seed, 6))
			)
			local FovNoise = harmonicNoise(Shake.Time, Shake.FovFrequency or 1.08, hashPhase(Shake.Seed, 7))
			local PositionInfluence = Shake.PositionInfluence or DEFAULT_POSITION
			local RotationInfluence = Shake.RotationInfluence or DEFAULT_ROTATION
			local PositionBias = Shake.PositionBias or vector.zero
			local RotationBias = Shake.RotationBias or vector.zero

			PositionTarget += ((PositionNoise + PositionBias) * Magnitude) * PositionInfluence
			RotationTarget += ((RotationNoise + RotationBias) * Magnitude) * RotationInfluence
			FovTarget += FovNoise * Magnitude * (Shake.FovInfluence or 0)

			if not Shake.Sustain and Shake.Age >= (Shake.FadeIn + Shake.FadeOut) then
				Shake.Dead = true
				self.Shakes[Id] = nil
			end
		end
	end

	self.PositionSpring.t = PositionTarget
	self.RotationSpring.t = RotationTarget
	self.FovSpring.t = FovTarget

	self.PositionOffset = self.PositionSpring.p
	self.RotationOffset = self.RotationSpring.p
	self.FovOffset = self.FovSpring.p

	local Delta, FovOffset, PositionOffset, RotationOffset = self:GetOffset()
	self.Callback(Delta, FovOffset, PositionOffset, RotationOffset, Dt)
end

function CameraShake:Shake(MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, Sustain: boolean?, EasingStyle: string?): ShakeTrack
	local Preset = resolvePreset(MagnitudeOrPreset, RoughnessOrOverrides, FadeIn, FadeOut, PositionInfluence, RotationInfluence, FovInfluence, Sustain, EasingStyle)

	self.NextId += 1
	local Shake = {
		Id = self.NextId,
		Name = Preset.Name,
		Magnitude = Preset.Magnitude,
		Roughness = Preset.Roughness,
		FadeIn = Preset.FadeIn,
		FadeOut = Preset.FadeOut,
		Sustain = Preset.Sustain,
		EasingStyle = Preset.EasingStyle,
		PositionInfluence = Preset.PositionInfluence,
		RotationInfluence = Preset.RotationInfluence,
		FovInfluence = Preset.FovInfluence,
		PositionFrequency = Preset.PositionFrequency,
		RotationFrequency = Preset.RotationFrequency,
		FovFrequency = Preset.FovFrequency,
		PositionBias = Preset.PositionBias,
		RotationBias = Preset.RotationBias,
		Age = 0,
		Time = 0,
		FadeOutStart = nil,
		Dead = false,
		Seed = self.NextId * 7919,
	} :: InternalShake

	self.Shakes[Shake.Id] = Shake
	return makeTrack(Shake)
end

function CameraShake:ShakeSustain(MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, EasingStyle: string?): ShakeTrack
	return self:Shake(MagnitudeOrPreset, RoughnessOrOverrides, FadeIn, FadeOut, PositionInfluence, RotationInfluence, FovInfluence, true, EasingStyle)
end

function CameraShake:Impulse(MagnitudeOrPreset: number | ShakePreset, RoughnessOrOverrides: number | {[string]: any}?, FadeIn: number?, FadeOut: number?, PositionInfluence: vector?, RotationInfluence: vector?, FovInfluence: number?, EasingStyle: string?): ShakeTrack
	return self:Shake(MagnitudeOrPreset, RoughnessOrOverrides, FadeIn, FadeOut, PositionInfluence, RotationInfluence, FovInfluence, false, EasingStyle)
end

function CameraShake:StopAll(FadeOut: number?)
	for _, Shake in next, self.Shakes do
		Shake.Sustain = false
		Shake.FadeOutStart = Shake.Age
		Shake.FadeOut = FadeOut ~= nil and math.max(FadeOut, 0) or Shake.FadeOut
	end
end

return CameraShake
