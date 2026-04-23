local defaults = {
	DefaultSpeed = 16;
	SprintSpeed = 46;
	RunThresholdMultiplier = 1.5;
	RunStateAlphaThreshold = .38;
	RunAirborneVerticalThreshold = 5.5;
	RunSlopeAirborneVerticalThreshold = 12;

	JumpPower = 56;
	JumpCooldown = .22;
	Jumps = 2;

	SpeedAcceleration = 57;
	SpeedDecceleration = 52;
	BackwardSpeedMultiplier = .65;
	BackwardSpeedCurve = 1.45;
	InputAcceleration = 18;
	InputDecceleration = 14;
	AirInputAcceleration = 34;
	AirInputDecceleration = 3;
	InputTurnBoost = 2.4;
	AirTurnBoost = 3.2;
	AirSpeedPreserve = .97;
	AirControl = .24;
	AirControlTurnBoost = .34;
	AirControlEase = 12;
	SpeedBlend = 20;

	GroundProbeDistance = .9;
	GroundNormalY = .5;
	GroundPredictionTime = .08;

	StrafingEnabled = true;

	MomentumEnabled = true;
	MomentumMinStartSpeed = 5;
	MomentumMaxStartSpeed = 28;
	MomentumCarryScale = .18;
	MomentumStartScale = .52;
	MomentumDecel = 13;
	MomentumInputDecelBoost = 2.6;
	MomentumStopThreshold = .03;
	MomentumLandMinSpeed = 14;
	MomentumBoostHold = .4;
	MomentumBoostDecel = 10;
	MomentumLandBoostScale = .65;
	MomentumLandBoostCap = 12;
	MomentumRunBoostScale = .45;
	MomentumRunBoostCap = 8;
	MomentumCancelInputThreshold = .12;
	MomentumVecSmall = .05;
	MomentumStartDelay = 0;
	MomentumLandingDelay = 0;
	MomentumGroundOnly = false;
	MomentumInputInfluence = 0;
	MomentumMaxLifetime = .38;
	MomentumDirectionVelocityMin = .9;
	MomentumSpeedDrag = .28;
	MomentumSpeedDragCurve = .01;
	MomentumSlopeStartBoost = .3;
	MomentumSlopeMinScale = .6;
	MomentumSlopeMaxScale = 1.3;
	MomentumSlopeDecelInfluence = .28;
	MomentumAirDeccelMultiplier = 1.1;
	MomentumEndSpeedThreshold = .04;
	MomentumEndDeccel = 1.2;

	MoveVectorDeadzone = .012;

	MantleFloorHeight = 4.5;
	MantleDownRange = 12;
	MantleUpRange = 14;
	MantleMinHeadRoom = .4;
	MantleForwardRange = 7.5;
	MantleMinHeight = .3;
	MantleMaxHeight = 10;
	MantleExtraHeight = 1.5;
	MantleWaistMinHeight = .8;
	MantleCooldown = .28;
	MantleMomentumScale = .85;
	MantleLaunchBlend = .58;
	MantleMinCheck = 3;
	MantleWallDot = .26;
	MantleMaxSlope = .35;

	WallFlipBackVelocity = 62;
	WallFlipUpVelocity = 48;
	WallFlipDuration = .14;
	WallFlipMomentumScale = 1.08;
	WallFlipCastOrigin = 1.2;
	WallFlipCastDirection = 2.8;
	WallFlipCooldown = 1.4;

	WallRunSpeed = 50;
	WallRunVerticalSpeed = 16;
	WallRunLookDeadzone = .08;
	WallRunMaxPitch = 32;
	WallRunDuration = 7;
	WallRunCastOrigin = 1.2;
	WallRunCastDistance = 3.1;
	WallRunCastDistanceActive = 9.5;
	WallRunNormalYMax = .25;
	WallRunNormalDot = .18;
	WallRunSideDotMin = .46;
	WallRunForwardDot = .02;
	WallRunVelocityDeadzone = 1;
	WallRunActiveBehindLimit = .14;
	WallRunTurnBlend = .7;
	WallRunMinSpeed = 8;
	WallRunInputDeadzone = .04;
	WallRunDirInputThreshold = .08;
	WallRunHoldGrace = .04;
	WallRunInputGrace = .42;
	WallRunCooldown = .08;
	WallRunCameraTilt = 16;
	WallRunCornerForward = 8.5;
	WallRunCornerSide = 8.0;
	WallRunGroundStopDistance = .2;
	WallRunDetectDistance = 4.2;
	WallRunDetectOffsets = {0, 2, -2};
	WallRunActiveDetectOffsets = {0, 1.35, 2.7, 4.05};
	WallRunEntryAngleOffsets = {0, 12, -12, 24, -24, 36, -36};
	WallRunProbeAngleOffsets = {0, 10, -10, 20, -20, 34, -34, 48, -48};
	WallRunCornerForwardOffsets = {1.2, 2.5, 4, 5.5, 7, 8.5};
	WallRunCornerAngleOffsets = {0, 10, -10, 22, -22, 34, -34, 48, -48};
	WallRunEntryGrace = .8;
	WallRunEntryBlend = .28;
	WallRunPostJumpEntryBlend = .82;
	WallRunAttachDuration = .12;
	WallRunAttachExtraDistance = .32;
	WallRunEntryNudgeMax = 1.15;
	WallRunLateralCorrectionSpeed = 17;
	WallRunLateralCorrectionMax = 24;
	WallRunAttachCorrectionBoost = 9;
	WallRunMaxMissedChecks = 18;
	WallRunHardMissMax = 6;
	WallRunSpatialRadius = 3.4;
	WallRunHoldDuration = .08;
	WallRunEntryPrimeWindow = .32;
	WallRunPostJumpBlock = .08;
	WallRunDetachGrace = .085;
	WallRunNormalPush = 1.4;
	WallRunDownwardSpeed = -.08;
	WallRunRearHitTolerance = .72;
	WallRunPassStopBehind = .38;
	WallRunAwayDotThreshold = .16;
	WallRunForwardBlockDistance = 2.6;
	WallRunForwardBlockLow = .5;
	WallRunForwardBlockHigh = 2.9;
	WallRunForwardBlockMinTopHeight = 3.25;
	WallRunObstacleUpBoost = 22;
	WallRunSnapDistance = .7;
	WallRunMinTopHeight = .9;
	WallRunMinSurfaceAboveHit = 1.15;
	WallRunMinSurfaceBelowHit = .8;
	WallRunMinHeight = 2.75;
	WallRunGroundPredictionTime = .08;
	WallRunGroundLeaveVertical = 2;

	WallJumpUpVelocity = 22;
	WallKickSideVelocity = 62;
	WallKickUpVelocity = 28;
	WallKickDuration = .38;
	WallKickPostJumpBlock = .25;
	WallJumpSideVelocity = 12;
	WallJumpForwardVelocity = 14;
	WallJumpDuration = .26;
	WallJumpPrimeWindow = .32;
	WallJumpMinElapsed = .1;
	WallJumpSideInputThreshold = .2;
	WallJumpSnapBlend = .7;
	WallJumpReattachWindow = .36;

	SlideCooldown = 1.65;
	SlidePendingDuration = .9;
	SlideSteerSpeed = 8.8;
	SlideDeceleration = 27;
	SlideInitialDecel = 8;
	SlideInitialDecelDuration = .12;
	SlideStartBoost = 1.25;
	SlideDownhillAccel = 18;
	SlideUphillDecel = 26;
	SlideSlopeDeadzone = .06;
	SlideMinSpeed = 1.5;
	SlideMinDuration = .28;
	SlideAlignResponsiveness = 28;
	SlideAlignMaxTorque = 1.6e6;
	SlideAlignLerp = 18;
	SlideGroundLerp = 5;
	SlideAlignUpBlend = .6;
	SlideAlignUpLerp = 10;
	SlideDesiredLerp = 14;
	SlideVelocityBlend = 13;
	SlideTurnResponse = .4;
	SlideTurnBoost = 1.05;
	SlideGroundProbeLift = .35;
	SlideGroundProbeAhead = 1.35;
	SlideGroundProbeFarAhead = 2.8;
	SlideGroundProbeSide = .95;
	SlideGroundProbeBack = .35;
	SlideGroundProbeDistance = 8.5;
	SlideFlatNormalY = .985;
	SlideNoGroundTimeout = .18;
	SlideSlopeNoGroundTimeout = .4;
	SlideSlopeKeepGroundSpeed = 8;
	SlideWallStopDistance = 2.2;
	SlideWallCastOrigin = 1.2;
	SlideWallNormalYMax = .32;
	SlideWallDotMin = .3;
	SlideWallHeightTolerance = 2.4;
	SlideVerticalForce = 4e4;
	SlideGroundSnapVelocity = -12;
	SlideSlopeGroundSnapVelocity = -20;
	SlideUpwardVelocity = 6;
	SlideDownwardVelocity = -35;
	SlideStopSlopeEpsilon = .03;
	SlideStopDownhillThreshold = .18;
	SlideLowSpeedStopTime = .14;
	SlideStopInputThreshold = .08;
	SlideSlopeDirLerp = 18;
	SlideSlopeTurnBlend = .4;
	SlideSlopeInputMultiplier = 1.18;
	SlideSlopeTurnInputScale = .28;
	SlideSlopeForwardDotMin = -.62;
	SlideForwardDotMin = -.08;
	SlideInputInfluence = .62;
	SlideInputTurnBoost = .36;
	SlideHipHeightBaseOffset = -.12;
	SlideHipHeightDown = -.08;
	SlideHipHeightUp = .02;
	SlideHipHeightLerp = 14;
	SlideHipHeightDownThreshold = .08;
	SlideHipHeightUpThreshold = .08;
	SlideCancelLookBlend = .78;
	SlideCancelFacingBlend = .82;
	SlideCancelPropelScale = 1.38;
	SlideCancelPropelDuration = .52;
	SlideCancelMomentumDelay = .16;
	SlideCancelMomentumScale = 1.04;
	SlideCancelSpeedBoostScale = .48;
	SlideCancelSpeedBoostCap = 1.65;
	SlideCancelSpeedBoostDecel = 8.5;
	SlideCancelSpeedBoostHold = .62;

	VaultForwardRange = 5.2;
	VaultMinHeight = 1.8;
	VaultMaxHeight = 3.8;
	VaultLandDepth = 4.6;
	VaultMaxSlope = .12;
	VaultApproachDot = .2;
	VaultCooldown = .38;
	VaultDuration = .18;
	VaultForwardVelocity = 34;
	VaultUpVelocity = 26;
	VaultMomentumScale = .76;
	VaultMinExitSpeed = 20;
	VaultLaunchBlend = .52;
	VaultExitBlend = .82;
	MantleExitBlend = .78;

	LevelUpBoostDuration = 6.5;
	LevelUpBoostPerExtraLevel = .09;
	LevelUpBoostMaxStrength = 1.4;
	LevelUpBoostSpeedScale = 1.14;
	LevelUpBoostSprintScale = 1.18;
	LevelUpBoostAccelerationScale = 1.18;
	LevelUpBoostVaultScale = 1.14;
	LevelUpBoostWallRunScale = 1.14;
	LevelUpBoostMantleScale = 1.12;
	LevelUpBoostSlideScale = 1.16;
	LevelUpBoostMomentumScale = 1.14;
	LevelUpBoostJumpBonus = 0;
	LevelUpBoostMaxExtraStacks = 6;
	LevelUpBoostImmediateSpeed = 14;
	LevelUpBoostImmediateHoldRatio = .38;
	LevelUpBoostImmediateDecel = 18;
}

local config = table.clone(defaults)
local baseValues = table.clone(defaults)
local LevelBoosts = require("./LevelBoosts")
local levelUpBoost = LevelBoosts.new()

local function getScaledValue(baseValue: number, scale: number, strength: number): number
	return baseValue * (1 + ((scale - 1) * math.max(strength, 1)))
end

local function isLevelUpBoostActive(): boolean
	return levelUpBoost:IsActive()
end

local function recompute()
	for key in next, config do
		if defaults[key] == nil and type(config[key]) ~= "function" then
			config[key] = nil
		end
	end

	for key, value in next, defaults do
		config[key] = baseValues[key]
	end

	if not isLevelUpBoostActive() then
		return
	end

	local strength = levelUpBoost:GetStrength()
	local accelerationScale = 1 + (((baseValues.LevelUpBoostAccelerationScale or 1) - 1) * .8)
	local wallVerticalScale = 1 + (((baseValues.LevelUpBoostWallRunScale or 1) - 1) * .75)
	local mantleBlendBonus = (((baseValues.LevelUpBoostMantleScale or 1) - 1) * .22) * strength
	local slideTurnScale = 1 + (((baseValues.LevelUpBoostSlideScale or 1) - 1) * .55)
	local slideCancelScale = 1 + (((baseValues.LevelUpBoostSlideScale or 1) - 1) * .75)

	config.DefaultSpeed = getScaledValue(baseValues.DefaultSpeed, baseValues.LevelUpBoostSpeedScale or 1, strength)
	config.SprintSpeed = getScaledValue(baseValues.SprintSpeed, baseValues.LevelUpBoostSprintScale or 1, strength)
	config.Jumps = math.max(1, math.floor((baseValues.Jumps or 1) + .5))
	config.SpeedAcceleration = getScaledValue(baseValues.SpeedAcceleration, baseValues.LevelUpBoostAccelerationScale or 1, strength)
	config.InputAcceleration = getScaledValue(baseValues.InputAcceleration, accelerationScale, strength)
	config.AirInputAcceleration = getScaledValue(baseValues.AirInputAcceleration, accelerationScale, strength)

	config.MomentumCarryScale = getScaledValue(baseValues.MomentumCarryScale, baseValues.LevelUpBoostMomentumScale or 1, strength)
	config.MomentumStartScale = getScaledValue(baseValues.MomentumStartScale, baseValues.LevelUpBoostMomentumScale or 1, strength)
	config.MomentumLandBoostScale = getScaledValue(baseValues.MomentumLandBoostScale, baseValues.LevelUpBoostMomentumScale or 1, strength)
	config.MomentumRunBoostScale = getScaledValue(baseValues.MomentumRunBoostScale, baseValues.LevelUpBoostMomentumScale or 1, strength)

	config.VaultForwardVelocity = getScaledValue(baseValues.VaultForwardVelocity, baseValues.LevelUpBoostVaultScale or 1, strength)
	config.VaultUpVelocity = getScaledValue(baseValues.VaultUpVelocity, 1 + (((baseValues.LevelUpBoostVaultScale or 1) - 1) * .75), strength)
	config.VaultMinExitSpeed = getScaledValue(baseValues.VaultMinExitSpeed, baseValues.LevelUpBoostVaultScale or 1, strength)

	config.WallRunSpeed = getScaledValue(baseValues.WallRunSpeed, baseValues.LevelUpBoostWallRunScale or 1, strength)
	config.WallRunVerticalSpeed = getScaledValue(baseValues.WallRunVerticalSpeed, wallVerticalScale, strength)
	config.WallKickSideVelocity = getScaledValue(baseValues.WallKickSideVelocity, baseValues.LevelUpBoostWallRunScale or 1, strength)
	config.WallKickUpVelocity = getScaledValue(baseValues.WallKickUpVelocity, wallVerticalScale, strength)
	config.WallJumpForwardVelocity = getScaledValue(baseValues.WallJumpForwardVelocity, wallVerticalScale, strength)
	config.WallJumpUpVelocity = getScaledValue(baseValues.WallJumpUpVelocity, wallVerticalScale, strength)

	config.MantleMomentumScale = getScaledValue(baseValues.MantleMomentumScale, baseValues.LevelUpBoostMantleScale or 1, strength)
	config.MantleLaunchBlend = math.clamp(baseValues.MantleLaunchBlend + mantleBlendBonus, 0, 1)

	config.SlideStartBoost = getScaledValue(baseValues.SlideStartBoost, baseValues.LevelUpBoostSlideScale or 1, strength)
	config.SlideTurnBoost = getScaledValue(baseValues.SlideTurnBoost, slideTurnScale, strength)
	config.SlideCancelPropelScale = getScaledValue(baseValues.SlideCancelPropelScale, slideCancelScale, strength)
	config.SlideCancelMomentumScale = getScaledValue(baseValues.SlideCancelMomentumScale, slideTurnScale, strength)
	config.SlideCancelSpeedBoostScale = getScaledValue(baseValues.SlideCancelSpeedBoostScale, slideCancelScale, strength)
end

function config.SetBaseValue(key: string, value: any)
	if defaults[key] == nil then
		rawset(config, key, value)
		return
	end

	baseValues[key] = value
	recompute()
end

function config.GetBaseValue(key: string): any
	return baseValues[key]
end

function config.GetBaseSnapshot(): {[string]: any}
	return table.clone(baseValues)
end

function config.GetDefaults(): {[string]: any}
	return table.clone(defaults)
end

function config.ResetBase()
	for key, value in next, defaults do
		baseValues[key] = value
	end

	recompute()
end

function config.GetLevelUpBoostStrength(levelsGained: number?): number
	local levels = math.max(1, math.floor((levelsGained or 1) + .5))
	local growth = baseValues.LevelUpBoostPerExtraLevel or .08
	local maxStrength = baseValues.LevelUpBoostMaxStrength or 1.35
	return math.min(1 + (math.max(0, levels - 1) * growth), maxStrength)
end

function config.IsLevelUpBoostActive(): boolean
	return isLevelUpBoostActive()
end

function config.ApplyLevelUpBoost(levelsGained: number?): (number, number)
	return levelUpBoost:Apply(levelsGained, baseValues, function(levelCount)
		return config.GetLevelUpBoostStrength(levelCount)
	end, recompute)
end

recompute()

return config
