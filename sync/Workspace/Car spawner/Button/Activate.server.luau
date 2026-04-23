button = script.Parent
regen = button.Parent.Regen

local debounce = false

function onTouch(hit)
	local h = hit.Parent:FindFirstChild("Humanoid")
	if h ~= nil and debounce == false then
		debounce = true
		button.BrickColor = BrickColor.Black()
		regen.Value = 1
		wait(1)
		regen.Value = 0
		wait(5)
		button.BrickColor = BrickColor.new(104)
		debounce = false
	end
end

button.Touched:connect(onTouch)