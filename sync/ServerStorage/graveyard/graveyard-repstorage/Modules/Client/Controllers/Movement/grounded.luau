local Grounded = {}

local function getLegPart(Character: Model, PrimaryName: string, SecondaryName: string): BasePart?
    local primaryPart = Character:FindFirstChild(PrimaryName)
    if primaryPart and primaryPart:IsA("BasePart") then
        return primaryPart
    end

    local secondaryPart = Character:FindFirstChild(SecondaryName)
    if secondaryPart and secondaryPart:IsA("BasePart") then
        return secondaryPart
    end

    return nil
end

local function castProbe(origin: vector, direction: vector, params: RaycastParams)
    return workspace:Raycast(origin, direction, params)
end

local function getFootOrigin(part: BasePart)
    local yOffset = (part.Size.Y * .5) - .01
    return vector.create(part.Position.X, part.Position.Y - yOffset, part.Position.Z)
end

local function getGroundInfoFromOrigins(Character: Model, Options, origins)
    if #origins <= 0 then
        return {
            IsGrounded = false;
            Distance = math.huge;
            Normal = vector.zero;
        }
    end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {Character}
    params.IgnoreWater = false

    local probeDistance = Options.GroundProbeDistance or .75
    local normalThreshold = Options.GroundNormalY or .52
    local down = vector.create(0, -probeDistance, 0)

    local minDistance = math.huge
    local bestNormal = vector.zero
    local isGrounded = false

    for _, origin in next, origins do
        local result = castProbe(origin, down, params)
        if not result then
            result = castProbe(origin + vector.create(.2, 0, 0), down, params) or castProbe(origin + vector.create(-.2, 0, 0), down, params)
        end

        if result then
            local hitPos = vector.create(result.Position.X, result.Position.Y, result.Position.Z)
            local dist = vector.magnitude(hitPos - origin)

            if dist < minDistance then
                minDistance = dist
                bestNormal = vector.create(result.Normal.X, result.Normal.Y, result.Normal.Z)
            end

            if result.Normal.Y >= normalThreshold then
                isGrounded = true
            end
        end
    end

    local humanoid = Character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.FloorMaterial ~= Enum.Material.Air then
        isGrounded = true
        if minDistance == math.huge then
            minDistance = 0
            bestNormal = vector.create(0, 1, 0)
        end
    end

    return {
        IsGrounded = isGrounded;
        Distance = minDistance;
        Normal = bestNormal;
    }
end

function Grounded.getLegOrigins(Character: Model)
    local leftLegPart = getLegPart(Character, "LeftFoot", "Left Leg")
    local rightLegPart = getLegPart(Character, "RightFoot", "Right Leg")
    if not leftLegPart or not rightLegPart then
        return {}
    end

    local origins = {
        getFootOrigin(leftLegPart),
        getFootOrigin(rightLegPart),
    }

    local rootPart = Character:FindFirstChild("HumanoidRootPart")
    if rootPart and rootPart:IsA("BasePart") then
        local rootYOffset = (rootPart.Size.Y * .5) - .05
        table.insert(origins, vector.create(rootPart.Position.X, rootPart.Position.Y - rootYOffset, rootPart.Position.Z))
    end

    return origins
end

function Grounded.getGroundInfo(Character: Model, Options)
    local origins = Grounded.getLegOrigins(Character)
    return getGroundInfoFromOrigins(Character, Options, origins)
end

function Grounded.getGroundInfoPredicted(Character: Model, Options, Dt: number?)
    local origins = Grounded.getLegOrigins(Character)
    local rootPart = Character:FindFirstChild("HumanoidRootPart")
    local dt = math.max(Dt or (Options.GroundPredictionTime or .08), 0)
    if rootPart and dt > 0 then
        local vel = rootPart.AssemblyLinearVelocity
        local offset = vector.create(vel.X, vel.Y, vel.Z) * dt
        for i, origin in next, origins do
            origins[i] = origin + offset
        end
    end
    return getGroundInfoFromOrigins(Character, Options, origins)
end

function Grounded.isGrounded(Character: Model, Options)
    return Grounded.getGroundInfo(Character, Options).IsGrounded
end

return Grounded
