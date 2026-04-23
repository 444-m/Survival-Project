--!strict
local RunService = game:GetService("RunService")
local thread = {}

type threadtype = thread

type ThreadHandle = {coroutine: threadtype; active: boolean;}
local activeThreads: {ThreadHandle} = {}

local function stepThreads(dt: number)
	for i=#activeThreads,1,-1 do
		local t = activeThreads[i]
		if t.active then
			local success, delay = coroutine.resume(t.coroutine, dt)
			if not success or delay == nil then
				t.active = false
				table.remove(activeThreads, i)
			end
		else
			table.remove(activeThreads, i)
		end
	end
end

RunService.Heartbeat:Connect(stepThreads)

function thread.spawn(fn: () -> ())
	local co = coroutine.create(function()
		fn()
		return nil
	end)
	local handle: ThreadHandle = { coroutine=co; active=true; }
	table.insert(activeThreads, handle)
	coroutine.resume(co)
	return handle
end

function thread.delay(time: number, fn: () -> ())
	return thread.spawn(function()
		local t = 0
		while t < time do
			local dt = RunService.Heartbeat:Wait()
			t += dt
			coroutine.yield(time - t)
		end
		fn()
	end)
end

function thread.wait(seconds: number)
	local t = 0
	while t < seconds do
		local dt = coroutine.yield(seconds - t)
		t += dt or 0
	end
end

function thread.clearAll()
	for _,t in next, activeThreads do
		t.active = false
	end
	activeThreads = {}
end

return thread