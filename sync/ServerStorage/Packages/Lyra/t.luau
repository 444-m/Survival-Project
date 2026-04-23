--!strict

local function typeName(value: any): string
	local valueType = typeof(value)
	if valueType == "nil" then
		return "nil"
	end
	return valueType
end

local function makePrimitiveChecker(expectedType: string)
	return function(value: any)
		local actualType = typeName(value)
		if actualType == expectedType then
			return true
		end

		return false, `expected {expectedType}, got {actualType}`
	end
end

local function formatPath(path: string, message: string?): string
	if message == nil or message == "" then
		return path
	end

	if path == "" then
		return message
	end

	return `{path}: {message}`
end

local t = {}

function t.any(_value: any)
	return true
end

t.string = makePrimitiveChecker("string")
t.number = makePrimitiveChecker("number")
t.boolean = makePrimitiveChecker("boolean")
t.callback = makePrimitiveChecker("function")

function t.optional(checker)
	return function(value: any)
		if value == nil then
			return true
		end

		return checker(value)
	end
end

function t.array(checker)
	return function(value: any)
		if type(value) ~= "table" then
			return false, `expected array, got {typeName(value)}`
		end

		for key, entry in pairs(value) do
			if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
				return false, `expected array index, got {typeName(key)}`
			end

			local ok, err = checker(entry)
			if not ok then
				return false, formatPath(`[{key}]`, err)
			end
		end

		return true
	end
end

function t.strictInterface(shape)
	return function(value: any)
		if type(value) ~= "table" then
			return false, `expected table, got {typeName(value)}`
		end

		for key in pairs(value) do
			if shape[key] == nil then
				return false, `unexpected field '{tostring(key)}'`
			end
		end

		for key, checker in pairs(shape) do
			local ok, err = checker(value[key])
			if not ok then
				return false, formatPath(`field '{tostring(key)}'`, err)
			end
		end

		return true
	end
end

function t.some(...)
	local checkers = table.pack(...)

	return function(value: any)
		local errors = table.create(checkers.n)

		for index = 1, checkers.n do
			local checker = checkers[index]
			local ok, err = checker(value)
			if ok then
				return true
			end

			errors[index] = err or "validator failed"
		end

		return false, table.concat(errors, " or ")
	end
end

return t
