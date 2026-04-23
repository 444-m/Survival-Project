--!strict
local anim = {}

function anim.playAnim(animator: Animator, track: AnimationTrack, fade: number?)
	fade = fade or .1

	if track and track:IsA("Animation") then
		track = anim.loadAnimation(animator, track)
	end

	if not track then return nil :: any end

	local IncomingPriority = track.Priority

	for _, playing in next, animator:GetPlayingAnimationTracks() do
		if playing:HasTag("Main") then
			local PlayingPriority = playing.Priority
			if PlayingPriority.Value >= IncomingPriority.Value then
				continue
			end
			anim.stopAnim(playing, fade :: number)
		end
	end

	track:Play(fade)
	track:AddTag("Main")

	return track
end

function anim.loadAnimation(animator: Animator, animation: Animation)
	local track = animator:LoadAnimation(animation)
	track:AddTag("Main")
	return track
end

function anim.stopAnim(track: AnimationTrack, fade: number?)
	fade = fade or .1
	if track then
		track:Stop(fade)
	end
end

return anim