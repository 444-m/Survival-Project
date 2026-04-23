--!strict
--!native
local num = {}

local suffixes = {
	"k";"M";"B";"T";"Qa";"Qi";"Sx";"Sp";"Oc";"No";
	"Dc";"Ud";"Dd";"Td";"Qad";"Qid";"Sxd";"Spd";"Ocd";"Nod";
	"Vg";"Uvg";"Dvg";"Tvg";"Qavg";"Qivg";"Sxvg";"Spvg";"Ocvg";"Novg";
	"Tg";"Utg";"Dtg";"Ttg";"Qatg";"Qitg";"Sxtg";"Sptg";"Octg";"Notg";
	"Qd";"Uqd";"Dqd";"Tqd";"Qaqa";"Qiqa";"Sxqa";"Spqa";"Ocqa";"Noqa";
	"Ct";
}

function num.format_timer(seconds: number): string
	if seconds == math.huge then return "∞" end
	seconds = seconds // 1
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, s)
	end
	return string.format("%d:%02d", m, s)
end

function num.format_timer_ms(seconds: number): string
	if seconds == math.huge then return "∞" end
	local ms = math.floor((seconds % 1) * 1000)
	seconds = seconds // 1
	local h = seconds // 3600
	local m = (seconds % 3600) // 60
	local s = seconds % 60
	if h > 0 then
		return string.format("%d:%02d:%02d.%03d", h, m, s, ms)
	end
	return string.format("%d:%02d.%03d", m, s, ms)
end

function num.bnum(value: number): string
	if value ~= value or value == math.huge then return "∞" end
	if value == -math.huge then return "-∞" end
	if value < 0 then return "-" .. num.bnum(-value) end
	if value < 1000 then return tostring(value) end
	if value >= 1e156 then
		local exp = (math.log(value) / math.log(10)) // 1
		return string.format("1e+%d", exp)
	end
	local exp = 0
	while value >= 1000 and exp < #suffixes do
		value /= 1000
		exp += 1
	end
	local decimals = if value < 10 then 2 elseif value < 100 then 1 else 0
	local factor = 10 ^ decimals
	value = ((value * factor) // 1) / factor
	return string.format("%g%s", value, suffixes[exp])
end

function num.ordinal(n: number): string
	n = n // 1
	local abs = math.abs(n)
	local last2 = abs % 100
	if last2 >= 11 and last2 <= 13 then
		return tostring(n) .. "th"
	end
	local last = abs % 10
	if last == 1 then return tostring(n) .. "st" end
	if last == 2 then return tostring(n) .. "nd" end
	if last == 3 then return tostring(n) .. "rd" end
	return tostring(n) .. "th"
end

function num.comma(n: number): string
	local s = tostring((math.abs(n) // 1))
	local result = ""
	local len = #s
	for i = 1, len do
		if i > 1 and (len - i + 1) % 3 == 0 then
			result ..= ","
		end
		result ..= string.sub(s, i, i)
	end
	return if n < 0 then "-" .. result else result
end

function num.to_roman(n: number): string
	n = n // 1
	assert(n >= 1 and n <= 3999, "to_roman: out of range")
	local vals = {1000;900;500;400;100;90;50;40;10;9;5;4;1;}
	local syms = {"M";"CM";"D";"CD";"C";"XC";"L";"XL";"X";"IX";"V";"IV";"I";}
	local result = ""
	for i, v in next, vals do
		while n >= v do
			result ..= syms[i]
			n -= v
		end
	end
	return result
end

function num.wrap(val: number, min: number, max: number): number
	local range = max - min
	return ((val - min) % range) + min
end

function num.cycle(n: number, max: number): number
	return math.fmod(n - 1, max) + 1
end

function num.ping_pong(t: number, length: number): number
	t = t % (length * 2)
	return length - math.abs(t - length)
end

function num.snap(v: number, step: number): number
	return (v / step + .5 // 1) * step
end

function num.remap(v: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return outMin + (v - inMin) / (inMax - inMin) * (outMax - outMin)
end

function num.remap_clamped(v: number, inMin: number, inMax: number, outMin: number, outMax: number): number
	return math.clamp(num.remap(v, inMin, inMax, outMin, outMax), outMin, outMax)
end

function num.round_to(v: number, places: number): number
	local f = 10 ^ places
	return (v * f + .5 // 1) / f
end

function num.digits(n: number): number
	if n == 0 then return 1 end
	return (math.log(math.abs(n)) / math.log(10)) // 1 + 1
end

function num.digits_sum(n: number): number
	n = math.abs(n) // 1
	local s = 0
	while n > 0 do
		s += n % 10
		n = n // 10
	end
	return s
end

function num.reverse_digits(n: number): number
	local neg = n < 0
	local s = tostring(math.abs(n) // 1)
	local result = tonumber(string.reverse(s)) :: number
	return if neg then -result else result
end

function num.is_palindrome(n: number): boolean
	return num.reverse_digits(n) == math.abs(n) // 1
end

function num.is_prime(n: number): boolean
	n = n // 1
	if n < 2 then return false end
	if n == 2 then return true end
	if n % 2 == 0 then return false end
	local limit = math.sqrt(n) // 1
	for i = 3, limit, 2 do
		if n % i == 0 then return false end
	end
	return true
end

function num.next_prime(n: number): number
	n = n // 1 + 1
	while not num.is_prime(n) do
		n += 1
	end
	return n
end

function num.factors(n: number): {number}
	n = math.abs(n) // 1
	local result = {}
	for i = 1, math.sqrt(n) // 1 do
		if n % i == 0 then
			table.insert(result, i)
			if i ~= n // i then
				table.insert(result, n // i)
			end
		end
	end
	table.sort(result)
	return result
end

function num.prime_factors(n: number): {number}
	n = math.abs(n) // 1
	local result = {}
	local d = 2
	while d * d <= n do
		while n % d == 0 do
			table.insert(result, d)
			n = n // d
		end
		d += 1
	end
	if n > 1 then table.insert(result, n) end
	return result
end

function num.gcd(a: number, b: number): number
	a, b = math.abs(a) // 1, math.abs(b) // 1
	while b ~= 0 do
		a, b = b, a % b
	end
	return a
end

function num.lcm(a: number, b: number): number
	return math.abs(a * b) // num.gcd(a, b)
end

function num.fibonacci(n: number): number
	n = n // 1
	if n <= 0 then return 0 end
	if n == 1 then return 1 end
	local a, b = 0, 1
	for _ = 2, n do
		a, b = b, a + b
	end
	return b
end

function num.factorial(n: number): number
	n = n // 1
	assert(n >= 0, "factorial: negative input")
	if n == 0 then return 1 end
	local result = 1
	for i = 2, n do
		result *= i
	end
	return result
end

function num.choose(n: number, k: number): number
	n, k = n // 1, k // 1
	if k < 0 or k > n then return 0 end
	if k == 0 or k == n then return 1 end
	k = math.min(k, n - k)
	local result = 1
	for i = 0, k - 1 do
		result = result * (n - i) // (i + 1)
	end
	return result
end

function num.collatz(n: number): {number}
	n = math.abs(n) // 1
	assert(n > 0, "collatz: must be positive")
	local seq = {n;}
	while n ~= 1 do
		n = if n % 2 == 0 then n // 2 else 3 * n + 1
		table.insert(seq, n)
	end
	return seq
end

function num.is_perfect(n: number): boolean
	n = n // 1
	if n < 2 then return false end
	local s = 1
	for i = 2, math.sqrt(n) // 1 do
		if n % i == 0 then
			s += i
			if i ~= n // i then s += n // i end
		end
	end
	return s == n
end

function num.is_power_of(n: number, base: number): boolean
	n = n // 1
	if n < 1 then return false end
	while n > 1 do
		if n % base ~= 0 then return false end
		n = n // base
	end
	return true
end

function num.sum(t: {number}): number
	local s = 0
	for _, v in next, t do s += v end
	return s
end

function num.avg(t: {number}): number
	return num.sum(t) / #t
end

function num.median(t: {number}): number
	local s = table.clone(t)
	table.sort(s)
	local n = #s
	if n % 2 == 0 then
		return (s[n // 2] + s[n // 2 + 1]) / 2
	end
	return s[(n + 1) // 2]
end

function num.std(t: {number}): number
	local mean = num.avg(t)
	local s = 0
	for _, v in next, t do s += (v - mean) ^ 2 end
	return math.sqrt(s / #t)
end

function num.variance(t: {number}): number
	local mean = num.avg(t)
	local s = 0
	for _, v in next, t do s += (v - mean) ^ 2 end
	return s / #t
end

function num.min_max(t: {number}): (number, number)
	local lo, hi = t[1], t[1]
	for i = 2, #t do
		if t[i] < lo then lo = t[i] end
		if t[i] > hi then hi = t[i] end
	end
	return lo, hi
end

function num.normalize(t: {number}): {number}
	local lo, hi = num.min_max(t)
	local range = hi - lo
	if range == 0 then return table.clone(t) end
	local result = {}
	for i, v in next, t do
		result[i] = (v - lo) / range
	end
	return result
end

function num.percentile(t: {number}, p: number): number
	local s = table.clone(t)
	table.sort(s)
	local idx = p / 100 * (#s - 1)
	local lo = idx // 1
	local hi = math.ceil(idx)
	return s[lo + 1] + (s[hi + 1] - s[lo + 1]) * (idx - lo)
end

function num.chance(p: number): boolean
	return math.random() < p
end

function num.rand_range(min: number, max: number): number
	return min + math.random() * (max - min)
end

function num.rand_sign(): number
	return if math.random() < .5 then -1 else 1
end

function num.weighted_random(weights: {number}): number
	local total = num.sum(weights)
	local r = math.random() * total
	local acc = 0
	for i, w in next, weights do
		acc += w
		if r <= acc then return i end
	end
	return #weights
end

function num.gaussian(mean: number, std_dev: number): number
	local u1 = 1 - math.random()
	local u2 = 1 - math.random()
	local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
	return mean + z * std_dev
end

function num.deg_to_rad(d: number): number
	return d * (math.pi / 180)
end

function num.rad_to_deg(r: number): number
	return r * (180 / math.pi)
end

function num.triangle_area(a: number, b: number, c: number): number
	local s = (a + b + c) / 2
	return math.sqrt(s * (s - a) * (s - b) * (s - c))
end

function num.point_in_circle(px: number, py: number, cx: number, cy: number, r: number): boolean
	local dx, dy = px - cx, py - cy
	return dx * dx + dy * dy <= r * r
end

function num.point_in_rect(px: number, py: number, rx: number, ry: number, rw: number, rh: number): boolean
	return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

function num.line_intersect(
	ax: number, ay: number, bx: number, by: number,
	cx: number, cy: number, dx: number, dy: number
): (number?, number?)
	local denom = (ax - bx) * (cy - dy) - (ay - by) * (cx - dx)
	if math.abs(denom) < 1e-10 then return nil, nil end
	local t = ((ax - cx) * (cy - dy) - (ay - cy) * (cx - dx)) / denom
	local u = -((ax - bx) * (ay - cy) - (ay - by) * (ax - cx)) / denom
	if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
		return ax + t * (bx - ax), ay + t * (by - ay)
	end
	return nil, nil
end

function num.closest_point_on_segment(px: number, py: number, ax: number, ay: number, bx: number, by: number): (number, number)
	local dx, dy = bx - ax, by - ay
	local lenSq = dx * dx + dy * dy
	if lenSq == 0 then return ax, ay end
	local t = math.clamp(((px - ax) * dx + (py - ay) * dy) / lenSq, 0, 1)
	return ax + t * dx, ay + t * dy
end

function num.impulse(mass: number, delta_vel: number): number
	return mass * delta_vel
end

function num.projectile_range(v: number, angle_deg: number, g: number?): number
	g = g or 196.2
	local a = num.deg_to_rad(angle_deg)
	return v * v * math.sin(2 * a) / (g :: number)
end

function num.projectile_peak(v: number, angle_deg: number, g: number?): number
	g = g or 196.2
	local vy = v * math.sin(num.deg_to_rad(angle_deg))
	return vy * vy / (2 * (g :: number))
end

function num.projectile_time(v: number, angle_deg: number, g: number?): number
	g = g or 196.2
	local vy = v * math.sin(num.deg_to_rad(angle_deg))
	return 2 * vy / (g :: number)
end

function num.angle_to_hit(tx: number, ty: number, v: number, g: number?): number?
	g = g or 196.2
	local disc = v ^ 4 - (g :: number) * ((g :: number) * tx ^ 2 + 2 * ty * v ^ 2)
	if disc < 0 then return nil end
	return num.rad_to_deg(math.atan((v ^ 2 - math.sqrt(disc)) / ((g :: number) * tx)))
end

return num