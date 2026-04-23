type AnimationEntry = {
	loaded: AnimationTrack?,
	unloaded: Animation?
}

type LoadedAnimations = {
	[string]: AnimationEntry | LoadedAnimations
}

local Animations = {
	LoadedAnimations = {} :: LoadedAnimations
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AnimationsFolder = ReplicatedStorage.Assets.Animations

local function scanFolder(folder: Folder, animator: Animator): LoadedAnimations
	local folderTable: LoadedAnimations = {}

	for _, obj in next, folder:GetChildren() do
		if obj:IsA("Animation") then
			if obj.AnimationId == "" then continue end
			folderTable[obj.Name] = {
				loaded = animator:LoadAnimation(obj),
				unloaded = obj
			} :: AnimationEntry
		elseif obj:IsA("Folder") then
			folderTable[obj.Name] = scanFolder(obj, animator)
		end
	end

	return folderTable
end

function Animations.init(animator: Animator)
	for _, obj in next, AnimationsFolder:GetChildren() do
		if obj:IsA("Animation") then
			Animations.LoadedAnimations[obj.Name] = {
				loaded = animator:LoadAnimation(obj),
				unloaded = obj
			} :: AnimationEntry
		elseif obj:IsA("Folder") then
			Animations.LoadedAnimations[obj.Name] = scanFolder(obj, animator)
		end
	end
end

return Animations