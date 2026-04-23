--!strict
local LightingServer = {}

local RunService = game:GetService("RunService")

local Shared = require "@game/ReplicatedStorage/Modules/Shared/Controllers/LightingShared"

local REAL_SECONDS_PER_GAME_MINUTE = Shared.Config.DayLength / (24 * 60)

local ClockTime = Shared.Config.StartTime
local SyncRemote = Shared.GetRemote("DayNightSync")
local LastSyncTime = 0
local LastPhase: Shared.TimeOfDay = "Morning"

local SpeedMultiplier = 1

function LightingServer.SetSpeed(Speed: number)
	SpeedMultiplier = math.max(0, Speed)
end

function LightingServer.GetSpeed(): number
	return SpeedMultiplier
end

local function MakePayload(): Shared.SyncPayload
	local Phase, NextPhase, Alpha = Shared.GetCurrentPhase(ClockTime)
	return {
		ClockTime = ClockTime,
		Phase = Phase,
		NextPhase = NextPhase,
		PhaseAlpha = Alpha,
	}
end

local function Tick(DeltaTime: number)
	local GameMinutesElapsed = DeltaTime / REAL_SECONDS_PER_GAME_MINUTE
	ClockTime = (ClockTime + (GameMinutesElapsed / 60) * SpeedMultiplier) % 24

	local Phase = Shared.GetCurrentPhase(ClockTime)
	local Now = os.clock()

	if Now - LastSyncTime >= 1 / Shared.SYNC_RATE or Phase ~= LastPhase then
		LastSyncTime = Now
		LastPhase = Phase
		SyncRemote:FireAllClients(MakePayload())
	end
end

function LightingServer.SetTime(Time: number)
	ClockTime = Time % 24
	SyncRemote:FireAllClients(MakePayload())
end

function LightingServer.GetTime(): number
	return ClockTime
end

function LightingServer.GetPhase(): Shared.TimeOfDay
	local Phase = Shared.GetCurrentPhase(ClockTime)
	return Phase
end

function LightingServer.Start()
	RunService.Heartbeat:Connect(Tick)
end

return LightingServer
