--!strict
local easing = {}

type Mode = "in" | "out" | "inout"

local function apply(t: number, mode: Mode, f: (number) -> number): number
	if mode == "in" then
		return f(t)
	elseif mode == "out" then
		return 1 - f(1 - t)
	elseif mode == "inout" then
		if t < .5 then
			return f(t * 2) / 2
		else
			return 1 - f(2 - t * 2) / 2
		end
	end
	return f(t)
end

function easing.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function cubicBezier(t: number, p0: number, p1: number, p2: number, p3: number): number
	local u = 1 - t
	return u*u*u*p0 + 3*u*u*t*p1 + 3*u*t*t*p2 + t*t*t*p3
end

function easing.linear(t: number): number
	return t
end

function easing.quad_bezier(t: number, p0: number, p1: number, p2: number): number
	local u = 1 - t
	return u*u*p0 + 2*u*t*p1 + t*t*p2
end

function easing.quad_bezier_in(t: number, p0: number, p1: number, p2: number): number
	local u = 1 - t
	return u*u*p0 + 2*u*t*p1 + t*t*p2
end

function easing.quad_bezier_out(t: number, p0: number, p1: number, p2: number): number
	local u = 1 - t
	return 1 - (u*u*p0 + 2*u*t*p1 + t*t*p2)
end

function easing.bezier_in(t: number, p0: number, p1: number, p2: number, p3: number): number
	return cubicBezier(t, p0, p1, p2, p3)
end

function easing.bezier_out(t: number, p0: number, p1: number, p2: number, p3: number): number
	return 1 - cubicBezier(1 - t, p0, p1, p2, p3)
end

function easing.bezier_inout(t: number, p0: number, p1: number, p2: number, p3: number): number
	if t < .5 then
		return cubicBezier(t * 2, p0, p1, p2, p3) / 2
	else
		return 1 - cubicBezier(2 - t * 2, p0, p1, p2, p3) / 2
	end
end

function easing.hermite(t: number, mode: Mode): number
	return apply(t, mode, function(x) return 3*x^2 - 2*x^3 end)
end

function easing.arc(t: number, mode: Mode): number
	return apply(t, mode, function(x) return math.sqrt(1 - (x - 1)^2) end)
end

function easing.kodak_barrel(t: number, mode: Mode): number
	return apply(t, mode, function(x) return math.sin(x * math.pi * .5) * ((.5 * x) + .5) end)
end

function easing.punch(t: number, mode: Mode): number
	return apply(t, mode, function(x) return math.sin(x * math.pi * 2) * (1 - x) end)
end

function easing.elastic_spring(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		if x == 0 then return 0 end
		if x == 1 then return 1 end
		return -2^(10*x - .1) * math.sin((x * 10 - .75) * (2 * math.pi / 3))
	end)
end

function easing.swing(t: number, mode: Mode): number
	return apply(t, mode, function(x) return math.sin(x * math.pi * .5) end)
end

function easing.swing_heavy(t: number, mode: Mode): number
	return apply(t, mode, function(x) return math.sin(x * math.pi * .75) end)
end

function easing.sigmoid(t: number, mode: Mode): number
	return apply(t, mode, function(x) return 1 / (1 + math.exp(-12 * (x - .5))) end)
end

function easing.quad(t: number, mode: Mode): number
	return apply(t, mode, function(x) return x^2 end)
end

function easing.cubic(t: number, mode: Mode): number
	return apply(t, mode, function(x) return x^3 end)
end

function easing.quart(t: number, mode: Mode): number
	return apply(t, mode, function(x) return x^4 end)
end

function easing.quint(t: number, mode: Mode): number
	return apply(t, mode, function(x) return x^5 end)
end

function easing.expo(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		if x == 0 then return 0 end
		return 2^(10 * x - 10)
	end)
end

function easing.circ(t: number, mode: Mode): number
	return apply(t, mode, function(x) return 1 - math.sqrt(1 - x^2) end)
end

function easing.back(t: number, mode: Mode, overshoot: number?): number
	local s = overshoot or 1.70158
	return apply(t, mode, function(x) return x^2 * ((s + 1) * x - s) end)
end

function easing.bounce(t: number, mode: Mode): number
	local function bounceOut(x: number): number
		local n = 7.5625
		local d = 2.75
		if x < 1/d then
			return n * x^2
		elseif x < 2/d then
			x -= 1.5/d
			return n * x^2 + .75
		elseif x < 2.5/d then
			x -= 2.25/d
			return n * x^2 + .9375
		else
			x -= 2.625/d
			return n * x^2 + .984375
		end
	end
	return apply(t, mode, function(x) return 1 - bounceOut(1 - x) end)
end

function easing.sine(t: number, mode: Mode): number
	return apply(t, mode, function(x) return 1 - math.cos(x * math.pi / 2) end)
end

function easing.steps(t: number, n: number): number
	return math.floor(t * n) / n
end

function easing.smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function easing.smootherstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * t * (t * (t * 6 - 15) + 10)
end

function easing.smootheststep(t: number): number
	t = math.clamp(t, 0, 1)
	return t^4 * (t * (t * (t * (-20) + 70) - 84) + 35)
end

function easing.double_exp(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		return (math.exp(x) - 1) / (math.exp(1) - 1)
	end)
end

function easing.log_decay(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		return math.log(1 + x * (math.exp(1) - 1))
	end)
end

function easing.gaussian(t: number, mode: Mode, sharpness: number?): number
	local k = sharpness or 5
	return apply(t, mode, function(x)
		return math.exp(-k * (x - 1)^2) - math.exp(-k)
	end)
end

function easing.critical_damping(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		return 1 - (1 + x) * math.exp(-6 * x)
	end)
end

function easing.overdamped(t: number, mode: Mode, zeta: number?): number
	local z = zeta or 1.5
	return apply(t, mode, function(x)
		local r1 = -z + math.sqrt(z^2 - 1)
		local r2 = -z - math.sqrt(z^2 - 1)
		local c1 = r2 / (r2 - r1)
		local c2 = 1 - c1
		return 1 - (c1 * math.exp(r1 * x * 8) + c2 * math.exp(r2 * x * 8))
	end)
end

function easing.underdamped(t: number, mode: Mode, zeta: number?): number
	local z = zeta or .3
	return apply(t, mode, function(x)
		local wd = math.sqrt(1 - z^2)
		return 1 - math.exp(-z * x * 8) * (math.cos(wd * x * 8) + (z / wd) * math.sin(wd * x * 8))
	end)
end

function easing.sinc(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		if x == 0 then return 1 end
		local px = math.pi * (x * 4 - 2)
		return math.sin(px) / px
	end)
end

function easing.tanh_norm(t: number, mode: Mode): number
	return apply(t, mode, function(x)
		return (math.tanh((x - .5) * 6) + math.tanh(3)) / (2 * math.tanh(3))
	end)
end

function easing.power_sigmoid(t: number, mode: Mode, p: number?): number
	local n = p or 3
	return apply(t, mode, function(x)
		return x^n / (x^n + (1 - x)^n)
	end)
end

function easing.gamma(t: number, mode: Mode, g: number?): number
	local gv = g or 2.2
	return apply(t, mode, function(x) return x^gv end)
end

function easing.inv_gamma(t: number, mode: Mode, g: number?): number
	local gv = g or 2.2
	return apply(t, mode, function(x) return x^(1 / gv) end)
end

function easing.elastic_custom(t: number, mode: Mode, amplitude: number?, period: number?): number
	local a = amplitude or 1
	local p = period or .3
	return apply(t, mode, function(x)
		if x == 0 then return 0 end
		if x == 1 then return 1 end
		local s = p / (2 * math.pi) * math.asin(1 / a)
		return -(a * 2^(10 * (x - 1)) * math.sin((x - 1 - s) * 2 * math.pi / p))
	end)
end

function easing.spring_settle(t: number, mode: Mode, freq: number?, decay: number?): number
	local f = freq or 8
	local d = decay or 4
	return apply(t, mode, function(x)
		return 1 - math.exp(-d * x) * math.cos(f * x * math.pi)
	end)
end

function easing.staircase_smooth(t: number, n: number, k: number?): number
	local sharpness = k or 10
	local s = 0
	for i = 1, n do
		s += easing.sigmoid((t - (i - 1) / n) * sharpness * n, "in") / n
	end
	return math.clamp(s, 0, 1)
end

function easing.noise_warp(t: number, mode: Mode, strength: number?): number
	local str = strength or .08
	return apply(t, mode, function(x)
		local warp = math.sin(x * math.pi * 7) * str * (1 - x) * x * 4
		return math.clamp(x + warp, 0, 1)
	end)
end

return easing