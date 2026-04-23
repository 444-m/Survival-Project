local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Axe = {
	cycle = 1;
	ViewportConfigs = {
		XOffset = .72;
		YOffset = .38;
		ZOffset = .95;
	};
}

local player = game.Players.LocalPlayer

local advents = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
local Animations = require "@game/ReplicatedStorage/Modules/Shared/Animations"
local Sounds = require(ReplicatedStorage.Modules.Shared.Sounds)

function Axe:Use(tooldata: {[string]: any})
	local character = player.Character
	if not character then return end
	
	Axe.cycle = Axe.cycle == 1 and 2 or 1
	
	local animator = character:FindFirstChildOfClass("Humanoid") and character:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
	
	local map = {
		[1] = "L";
		[2] = "R";
	}
	
	local anim = `Swing{map[Axe.cycle]}`
	local Track = advents.animator.playAnim(animator, Animations.LoadedAnimations.Weapons.Axe[anim].loaded)
	Track.Priority = Enum.AnimationPriority.Action4
	
	Track.Destroying:Connect(function()
		return {
			Direction = Axe.cycle == 1 and "Left" or "Right";
		}
	end)
	
	Track.Stopped:Connect(function()
		return {
			Direction = Axe.cycle == 1 and "Left" or "Right";
		}
	end)
	
	Sounds.play(Sounds.LoadedSounds.Tools.Axe.Swing);
	
	Axe.track = Track

	Track:GetMarkerReachedSignal("Hit"):Wait()
	
	return {
		Direction = Axe.cycle == 1 and "Left" or "Right";
	}
end

function Axe:Cancel()
	if Axe.track then
		advents.animator.stopAnim(Axe.track, .15)
	end
end

return Axe
