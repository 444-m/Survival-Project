--!strict
-- scrapped!!!!
local thread = require("./thread")
local debris = {}

local objects: {[string]: { obj: Instance; handle: any;}} = {}
local uidCounter = 0

function debris.add(obj: Instance, delay: number): string
	uidCounter += 1
	local uid = tostring(uidCounter)

	local handle = thread.delay(delay, function()
		if objects[uid] and objects[uid].obj and objects[uid].obj.Parent then
			objects[uid].obj:Destroy()
		end
		objects[uid] = nil
	end)

	objects[uid] = { obj=obj; handle=handle; }
	return uid
end

function debris.cancel(uid: string)
	if objects[uid] then
		objects[uid].handle.active = false
		objects[uid] = nil
	end
end

function debris.clearAll()
	for _,data in next, objects do
		data.handle.active = false
	end
	objects = {}
end

return debris