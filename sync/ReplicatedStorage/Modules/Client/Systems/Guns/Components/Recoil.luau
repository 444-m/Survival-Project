local RunService = game:GetService("RunService")

local Spring = require "@self/spring"
local Janitor = require "@self/Janitor"

local Camera = workspace.CurrentCamera

local Recoil = {}
Recoil.__index = Recoil

const rng = Random.new()

type AxisData = {
	x: number?;
	y: number?;
	z: number?;
}

type Preset = {
	pattern: {AxisData}?;
	patternReset: number?;
	multiplier: number?;
	adsMultiplier: number?;
	recovery: number?;
	smoothing: number?;
	kickSpeed: number?;
	kickDamper: number?;
	visualScale: number?;
	visualSpeed: number?;
	visualDamper: number?;
	shakeScale: number?;
	shakeSpeed: number?;
	shakeDamper: number?;
	maxX: number?;
	maxY: number?;
}

type PresetKey = keyof<Preset> 
	
type RecoilImpl = {
	__index: RecoilImpl;
	new: (preset: Preset?) -> Recoil;
	Load: (self: Recoil, preset: Preset) -> ();
	Aim: (self: Recoil, state: boolean) -> ();
	Fire: (self: Recoil, data: AxisData?) -> ();
	Shake: (self: Recoil, intensity: number?, duration: number?, frequency: number?) -> ();
	Reset: (self: Recoil) -> ();
	Destroy: (self: Recoil) -> ();
	_start: (self: Recoil) -> ();
	_stop: (self: Recoil) -> ();
	_update: (self: Recoil) -> ();
}

type Recoil = typeof(setmetatable({} :: {
	kick: any;
	visual: any;
	shake: any;
	shotCount: number;
	patternIndex: number;
	lastShot: number;
	preset: Preset;
	isAiming: boolean;
	smoothed: vector;
	_janitor: any;
	_shakeJanitor: any;
	_connection: RBXScriptConnection?;
}, {} :: RecoilImpl))

local function makeSpring(speed: number, damper: number)
	local s = Spring.new(vector.zero)
	s.speed = speed
	s.damper = damper
	return s
end

function Recoil.new(preset: Preset?)
	local self = setmetatable({}, Recoil)

	self.kick = makeSpring(18, .55)
	self.visual = makeSpring(22, .45)
	self.shake = makeSpring(28, .38)

	self.shotCount = 0
	self.patternIndex = 1
	self.lastShot = 0

	self.preset = {
		pattern = {};
		patternReset = .6;
		multiplier = 1;
		adsMultiplier = .5;
		recovery = .08;
		smoothing = .12;
		kickSpeed = 18;
		kickDamper = .55;
		visualScale = 1.4;
		visualSpeed = 22;
		visualDamper = .45;
		shakeScale = .6;
		shakeSpeed = 28;
		shakeDamper = .38;
		maxX = 12;
		maxY = 22;
	}

	self.isAiming = false
	self.smoothed = vector.zero
	self.currentDelta = vector.zero
	self._janitor = Janitor.new()
	self._shakeJanitor = self._janitor:Add(Janitor.new(), "Destroy")
	self._connection = nil

	if preset then
		self:Load(preset)
	end

	return self
end

function Recoil:Load(preset: Preset)
	for k: PresetKey, v in next, preset do
		self.preset[k] = v
	end
	local p = self.preset
	self.kick.speed = p.kickSpeed
	self.kick.damper = p.kickDamper
	self.visual.speed = p.visualSpeed
	self.visual.damper = p.visualDamper
	self.shake.speed = p.shakeSpeed
	self.shake.damper = p.shakeDamper
end

function Recoil:Aim(state: boolean)
	self.isAiming = state
end

function Recoil:Fire(data: AxisData?)
	local p = self.preset
	local now = os.clock()

	if now - self.lastShot > p.patternReset then
		self.patternIndex = 1
		self.shotCount = 0
	end

	self.lastShot = now
	self.shotCount += 1

	local raw: AxisData = data or {x = 0; y = 1; z = 0}

	if #p.pattern > 0 then
		local step = p.pattern[math.min(self.patternIndex, #p.pattern)]
		raw = {
			x = step.x or raw.x;
			y = step.y or raw.y;
			z = step.z or raw.z;
		}
		self.patternIndex = math.min(self.patternIndex + 1, #p.pattern)
	end

	local mul = p.multiplier * (self.isAiming and p.adsMultiplier or 1)
	local kickVec = vector.create(raw.x * mul, raw.y * mul, raw.z * mul)

	self.kick:impulse(kickVec)
	self.visual:impulse(kickVec * p.visualScale)
	self.shake:impulse(vector.create(
		rng:NextNumber(-1, 1) * p.shakeScale * mul,
		rng:NextNumber(-1, 1) * p.shakeScale * mul * .7,
		rng:NextNumber(-1, 1) * p.shakeScale * mul * .4
		))
end

function Recoil:Shake(intensity: number?, duration: number?, frequency: number?)
	intensity = intensity or .5
	duration = duration or .3
	frequency = frequency or 22

	local t0 = os.clock()
	self._shakeJanitor:Cleanup()
	self._shakeJanitor:Add(RunService.PreRender:Connect(function()
		local elapsed = os.clock() - t0
		if elapsed >= duration then
			self._shakeJanitor:Cleanup()
			return
		end
		local fade = 1 - elapsed / duration
		self.visual:impulse(vector.create(
			math.sin(elapsed * frequency) * intensity * fade * .08,
			math.cos(elapsed * frequency * 1.3) * intensity * fade * .08,
			math.sin(elapsed * frequency * .7) * intensity * fade * .04
			))
	end), "Disconnect")
end

function Recoil:_update()
	local p = self.preset
	local now = os.clock()

	if now - self.lastShot > p.recovery then
		self.kick.target = vector.zero
		self.visual.target = vector.zero
		self.shake.target = vector.zero
	end

	local kv: vector = self.kick.value
	local vv: vector = self.visual.value
	local sv: vector = self.shake.value

	self.smoothed = self.smoothed + (kv - self.smoothed) * p.smoothing

	local total = vector.create(
		math.clamp(self.smoothed.x + vv.x + sv.x, -p.maxX, p.maxX),
		math.clamp(self.smoothed.y + vv.y + sv.y, -p.maxY, p.maxY),
		self.smoothed.z + vv.z + sv.z
	)

	self.currentDelta = total

	local settling = vector.magnitude(kv) < .001
		and vector.magnitude(self.visual.value) < .001
		and vector.magnitude(self.shake.value) < .001

	if settling and now - self.lastShot > p.recovery + 1 then
		self:_stop()
	end
end

function Recoil:Step()
	self:_update()
end

function Recoil:_start()
	self._connection = self._janitor:Add(RunService.PreRender:Connect(function()
		self:_update()
	end), "Disconnect", "_connection")
end

function Recoil:_stop()
	self._janitor:Remove("_connection")
	self._connection = nil
end

function Recoil:Reset()
	self.kick.p = vector.zero
	self.kick.v = vector.zero
	self.visual.p = vector.zero
	self.visual.v = vector.zero
	self.shake.p = vector.zero
	self.shake.v = vector.zero
	self.smoothed = vector.zero
	self.currentDelta = vector.zero
	self.shotCount = 0
	self.patternIndex = 1
	self.lastShot = 0
	self._shakeJanitor:Cleanup()
	self:_stop()
end

function Recoil:GetDelta()
	return self.currentDelta or vector.zero
end

function Recoil:Destroy()
	self:Reset()
	self._janitor:Destroy()
	setmetatable(self, nil)
end

return Recoil
