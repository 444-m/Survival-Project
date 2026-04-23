local CentralHeartbeat = {
    fns = {};
    running = false;
    heartbeat = nil;
}

function CentralHeartbeat:Start()
    if CentralHeartbeat.running then return end
    CentralHeartbeat.running = true

    CentralHeartbeat.heartbeat = game:GetService("RunService").Heartbeat:Connect(function(dt)
        for _, fn in next, CentralHeartbeat.fns do
            fn(dt)
        end
    end)
end

function CentralHeartbeat:Bind(fn: (dt: number) -> (), index: string?)
    if index then
        CentralHeartbeat.fns[index] = fn
        return
    end

    table.insert(CentralHeartbeat.fns, fn)
end

function CentralHeartbeat:Unbind(fn: (dt: number) -> ()?, index: string?)
    if index then
        CentralHeartbeat.fns[index] = nil
        return
    end

    for i, boundFn in next, CentralHeartbeat.fns do
        if boundFn == fn then
            table.remove(CentralHeartbeat.fns, i)
            break
        end
    end
end

function CentralHeartbeat:Clear()
    CentralHeartbeat.fns = {}
end

function CentralHeartbeat:IsRunning()
    return CentralHeartbeat.running
end

function CentralHeartbeat:GetBoundFunctions()
    return CentralHeartbeat.fns
end

function CentralHeartbeat:Stop()
    if not CentralHeartbeat.running then return end
    CentralHeartbeat.running = false

    if CentralHeartbeat.heartbeat then
        CentralHeartbeat.heartbeat:Disconnect()
        CentralHeartbeat.heartbeat = nil
    end
end

CentralHeartbeat:Start()

return CentralHeartbeat