--!strict
local num = {}

local suffixes = {
	"k","M","B","T","Qa","Qi","Sx","Sp","Oc","No","Dc"
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

function num.wrap(val: number, min: number, max: number): number
	local range = max - min
	return ((val - min) % range) + min
end

function num.bnum(value: number): string
	if value ~= value or value == math.huge then return "∞" end
	if value < 0 then return "-" .. num.bnum(-value) end
	if value < 1000 then return tostring(value) end

	if value >= 1e33 then
		local exp = (math.log(value) / math.log(10)) // 1
		return string.format("1e+%d", exp)
	end

	local exp = 0
	while value >= 1000 and exp < #suffixes do
		value /= 1000
		exp += 1
	end

	local decimals
	if value < 10 then
		decimals = 2
	elseif value < 100 then
		decimals = 1
	else
		decimals = 0
	end

	local factor = 10^decimals
	value = ((value * factor) // 1) / factor
	return string.format("%g%s", value, suffixes[exp])
end

function num.cycle(n: number, max: number)
	return math.fmod(n-1, max) + 1
end

return num