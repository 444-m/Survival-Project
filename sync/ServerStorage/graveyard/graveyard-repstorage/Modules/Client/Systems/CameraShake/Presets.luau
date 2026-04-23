--!strict
export type ShakePreset = {
	Name: string?;
	Magnitude: number;
	Roughness: number;
	FadeIn: number;
	FadeOut: number;
	Sustain: boolean?;
	EasingStyle: string?;
	PositionInfluence: vector?;
	RotationInfluence: vector?;
	FovInfluence: number?;
	PositionFrequency: vector?;
	RotationFrequency: vector?;
	FovFrequency: number?;
	PositionBias: vector?;
	RotationBias: vector?;
	Scale: (self: ShakePreset, Amount: number) -> ShakePreset;
	With: (self: ShakePreset, Overrides: {[string]: any}) -> ShakePreset;
}

local Presets = {}

local PresetMethods = {}
PresetMethods.__index = PresetMethods

local function clonePreset(Source: {[string]: any}, ScaleAmount: number?, Overrides: {[string]: any}?): ShakePreset
	local Target = {} :: {[string]: any}
	for Key, Value in next, Source do
		if Key ~= "Scale" and Key ~= "With" then
			Target[Key] = Value
		end
	end

	if ScaleAmount and ScaleAmount ~= 1 then
		Target.Magnitude = (Target.Magnitude or 0) * ScaleAmount
		Target.Roughness = (Target.Roughness or 0) * (.92 + ((ScaleAmount - 1) * .22))
		Target.FovInfluence = (Target.FovInfluence or 0) * ScaleAmount
		if Target.PositionInfluence then
			Target.PositionInfluence *= ScaleAmount
		end
		if Target.RotationInfluence then
			Target.RotationInfluence *= ScaleAmount
		end
	end

	if Overrides then
		for Key, Value in next, Overrides do
			Target[Key] = Value
		end
	end

	return setmetatable(Target, PresetMethods) :: any
end

function PresetMethods:Scale(Amount: number): ShakePreset
	return clonePreset(self, Amount)
end

function PresetMethods:With(Overrides: {[string]: any}): ShakePreset
	return clonePreset(self, nil, Overrides)
end

local function makePreset(Data: {[string]: any}): ShakePreset
	return clonePreset(Data)
end

Presets.Windbreak = makePreset({
	Name = "Windbreak";
	Magnitude = .58;
	Roughness = 8.5;
	FadeIn = .04;
	FadeOut = .22;
	EasingStyle = "BezierOut";
	PositionInfluence = vector.create(.22, .02, .05);
	RotationInfluence = vector.create(.45, .68, 1.2);
	FovInfluence = .38;
	PositionFrequency = vector.create(.8, 1.1, .72);
	RotationFrequency = vector.create(.95, .8, 1.24);
	FovFrequency = .86;
})

Presets.LevelUp = makePreset({
	Name = "LevelUp";
	Magnitude = .78;
	Roughness = 10.5;
	FadeIn = .03;
	FadeOut = .34;
	EasingStyle = "BezierInOut";
	PositionInfluence = vector.create(.16, .04, .07);
	RotationInfluence = vector.create(.5, .32, 1.45);
	FovInfluence = .68;
	PositionFrequency = vector.create(.82, 1.05, .9);
	RotationFrequency = vector.create(1.1, .9, 1.45);
	FovFrequency = 1.1;
	RotationBias = vector.create(0, 0, .08);
})

Presets.RecoilLight = makePreset({
	Name = "RecoilLight";
	Magnitude = .42;
	Roughness = 18;
	FadeIn = 0;
	FadeOut = .12;
	EasingStyle = "ExpOut";
	PositionInfluence = vector.create(.02, .01, .08);
	RotationInfluence = vector.create(.45, .18, .22);
	FovInfluence = .08;
	PositionBias = vector.create(0, 0, -.55);
	RotationBias = vector.create(-.95, .1, .02);
})

Presets.RecoilHeavy = makePreset({
	Name = "RecoilHeavy";
	Magnitude = .72;
	Roughness = 22;
	FadeIn = 0;
	FadeOut = .16;
	EasingStyle = "ExpOut";
	PositionInfluence = vector.create(.03, .02, .12);
	RotationInfluence = vector.create(.82, .3, .32);
	FovInfluence = .14;
	PositionBias = vector.create(0, 0, -.8);
	RotationBias = vector.create(-1.35, .16, .04);
})

Presets.CombatHitLight = makePreset({
	Name = "CombatHitLight";
	Magnitude = .36;
	Roughness = 14;
	FadeIn = .01;
	FadeOut = .14;
	EasingStyle = "BezierOut";
	PositionInfluence = vector.create(.08, .05, .06);
	RotationInfluence = vector.create(.55, .45, .85);
	FovInfluence = .12;
})

Presets.CombatHitHeavy = makePreset({
	Name = "CombatHitHeavy";
	Magnitude = .88;
	Roughness = 16;
	FadeIn = .01;
	FadeOut = .24;
	EasingStyle = "BezierOut";
	PositionInfluence = vector.create(.16, .09, .12);
	RotationInfluence = vector.create(1.12, .9, 1.45);
	FovInfluence = .3;
})

Presets.ExplosionSmall = makePreset({
	Name = "ExplosionSmall";
	Magnitude = 1.15;
	Roughness = 12.5;
	FadeIn = 0;
	FadeOut = .36;
	EasingStyle = "BezierInOut";
	PositionInfluence = vector.create(.3, .2, .28);
	RotationInfluence = vector.create(1.45, 1.1, 1.85);
	FovInfluence = .55;
	PositionBias = vector.create(0, .08, -.12);
})

Presets.ExplosionLarge = makePreset({
	Name = "ExplosionLarge";
	Magnitude = 1.85;
	Roughness = 10.5;
	FadeIn = 0;
	FadeOut = .5;
	EasingStyle = "BezierInOut";
	PositionInfluence = vector.create(.45, .3, .36);
	RotationInfluence = vector.create(2.2, 1.5, 2.7);
	FovInfluence = .95;
	PositionBias = vector.create(0, .16, -.2);
})

Presets.Landing = makePreset({
	Name = "Landing";
	Magnitude = .44;
	Roughness = 9;
	FadeIn = 0;
	FadeOut = .18;
	EasingStyle = "Smooth";
	PositionInfluence = vector.create(.02, .14, .04);
	RotationInfluence = vector.create(.45, .16, .3);
	FovInfluence = .08;
	PositionBias = vector.create(0, -.42, 0);
	RotationBias = vector.create(.28, 0, 0);
})

Presets.Dash = makePreset({
	Name = "Dash";
	Magnitude = .52;
	Roughness = 11.5;
	FadeIn = .01;
	FadeOut = .16;
	EasingStyle = "BezierOut";
	PositionInfluence = vector.create(.09, .03, .18);
	RotationInfluence = vector.create(.28, .16, .82);
	FovInfluence = .2;
	PositionBias = vector.create(0, 0, -.2);
})

Presets.SustainRumble = makePreset({
	Name = "SustainRumble";
	Magnitude = .18;
	Roughness = 4.5;
	FadeIn = .08;
	FadeOut = .22;
	Sustain = true;
	EasingStyle = "BezierInOut";
	PositionInfluence = vector.create(.04, .03, .03);
	RotationInfluence = vector.create(.18, .18, .22);
	FovInfluence = .04;
})

return Presets
