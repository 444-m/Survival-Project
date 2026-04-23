local RunService = game:GetService("RunService")

local StunModule = {}

local active = {} :: {
	[Humanoid]: {
		untilTime: number,
		lastSpeed: number,
		lastJump: number
	}
}

local function restore(h: Humanoid)
	local state = active[h]
	if not state then return end
	if h and h.Parent then
		if state.lastSpeed then h.WalkSpeed = state.lastSpeed end
		if h.UseJumpPower ~= false then
			if state.lastJump then h.JumpPower = state.lastJump end
		else
			if state.lastJump then h.JumpHeight = state.lastJump end
		end
	end
	active[h] = nil
end

function StunModule.Apply(h: Humanoid?, opts: { duration: number, walkSpeed: number?, jumpPower: number?, jumpHeight: number?, override: boolean? }?)
	if not h or not opts then return end
	local now = os.clock()
	local dur = math.max(0, opts.duration or 0)
	local untilTime = now + dur
	local override = opts.override ~= false

	local state = active[h]
	if state and not override and state.untilTime > now then
		return
	end

	if not state then
		state = {
			untilTime = untilTime,
			lastSpeed = h.WalkSpeed,
			lastJump = h.UseJumpPower ~= false and h.JumpPower or h.JumpHeight,
		}
		active[h] = state
	end
	state.untilTime = untilTime

	if opts.walkSpeed then
		h.WalkSpeed = opts.walkSpeed
	end
	local jumpValue = if h.UseJumpPower ~= false then opts.jumpPower else opts.jumpHeight
	if jumpValue then
		if h.UseJumpPower ~= false then h.JumpPower = jumpValue else h.JumpHeight = jumpValue end
	end

	task.delay(dur, function()
		if active[h] and active[h].untilTime <= os.clock() then
			restore(h)
		end
	end)
end

function StunModule.Clear(h: Humanoid?)
	if h then
		restore(h)
	end
end

return StunModule
