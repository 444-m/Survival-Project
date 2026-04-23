local ViewportAnimator = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local animUtils = require(ReplicatedStorage.Modules.Shared.utils.advents).animator

function ViewportAnimator.Animate(Animator: Animator, Track: AnimationTrack)
	animUtils.playAnim(Animator, Track)
end

return ViewportAnimator
