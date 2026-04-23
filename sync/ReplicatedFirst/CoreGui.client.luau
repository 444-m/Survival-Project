local CoreGuis = {
	Backpack = false;
}

for CoreGui, Toggle in next, CoreGuis do
	game:GetService("StarterGui"):SetCoreGuiEnabled(Enum.CoreGuiType[CoreGui], Toggle)
end