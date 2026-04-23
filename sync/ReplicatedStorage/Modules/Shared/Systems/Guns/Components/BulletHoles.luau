local TweenService = game:GetService("TweenService")

local BulletHoles = {}

const WALL_LIFETIME = 15
const FADE_TIME = 1.5
const BLOOD_LIFETIME = 20
const BLOOD_FADE_TIME = 2

local function getPartSize(payload)
	local ref = game:GetService("ReplicatedStorage")
	for _, key in next, payload.Bullet.Path do
		ref = ref:FindFirstChild(key)
		if not ref then break end
	end
	if not ref then return Vector2.new(.3, .3) end
	local part = ref:FindFirstChild("Bullet") or ref:FindFirstChildOfClass("Part") or ref:FindFirstChildOfClass("MeshPart")
	if not part then return Vector2.new(.3, .3) end
	local s = part.Size
	local vals = {s.X, s.Y, s.Z}
	table.sort(vals)
	return Vector2.new(vals[1] * 1.5, vals[2] * 1.5)
end

local function getNormalFace(normal: vector): Enum.NormalId
	local axes = {
		{face = Enum.NormalId.Top, dot = vector.dot(normal, vector.create(0, 1, 0))};
		{face = Enum.NormalId.Bottom, dot = vector.dot(normal, vector.create(0, -1, 0))};
		{face = Enum.NormalId.Front, dot = vector.dot(normal, vector.create(0, 0, -1))};
		{face = Enum.NormalId.Back, dot = vector.dot(normal, vector.create(0, 0, 1))};
		{face = Enum.NormalId.Right, dot = vector.dot(normal, vector.create(1, 0, 0))};
		{face = Enum.NormalId.Left, dot = vector.dot(normal, vector.create(-1, 0, 0))};
	}
	local best = axes[1]
	for _, v in axes do
		if v.dot > best.dot then best = v end
	end
	return best.face
end

local function fadeAndDestroy(decal: Decal, lifetime: number, fadeTime: number)
	task.delay(lifetime, function()
		if not decal or not decal.Parent then return end
		local info = TweenInfo.new(fadeTime, Enum.EasingStyle.Linear)
		TweenService:Create(decal, info, { Transparency = 1 }):Play()
		task.delay(fadeTime, function()
			if decal and decal.Parent then decal:Destroy() end
		end)
	end)
end

function BulletHoles.SpawnWall(result: RaycastResult, imageId: string, payload)
	local hitPart = result.Instance
	if not hitPart or not hitPart:IsA("BasePart") then return end

	local decal = Instance.new("Decal")
	decal.Texture = imageId
	decal.Transparency = 0
	decal.Face = getNormalFace(result.Normal)
	decal.Parent = hitPart

	fadeAndDestroy(decal, WALL_LIFETIME, FADE_TIME)
end

function BulletHoles.SpawnBlood(result: RaycastResult, imageId: string)
	local hitPart = result.Instance
	if not hitPart or not hitPart:IsA("BasePart") then return end

	local decal = Instance.new("Decal")
	decal.Texture = imageId
	decal.Transparency = 0
	decal.Face = getNormalFace(result.Normal)
	decal.Parent = hitPart

	fadeAndDestroy(decal, BLOOD_LIFETIME, BLOOD_FADE_TIME)
end

return BulletHoles