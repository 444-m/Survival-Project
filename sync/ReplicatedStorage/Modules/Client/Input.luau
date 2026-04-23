local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage:WaitForChild("Packages")
local ClientPackages = Packages:WaitForChild("Client")

local IAS = require(ClientPackages:WaitForChild("IllusionIAS"))

type KeyCode = Enum.KeyCode | {Enum.KeyCode}
type callbacks = {
	OnStart: () -> ();
	OnRelease: () -> ()?;
}

local Inputs = {}

function Inputs.AddClass(BindClass: string)
	if Inputs[BindClass] then 
		return Inputs[BindClass]
	end

	Inputs[BindClass] = {}; return Inputs[BindClass]
end

function Inputs.GetClass(BindClass: string)
	return Inputs[BindClass]
end

function Inputs.AddBind(BindClass: string, BindName: string, KeyCode: KeyCode, InputType: Enum.InputActionType, callbacks: callbacks)
	local Class = Inputs.GetClass(BindClass); if not Class then return nil end
	if Class[BindName] then return Class[BindName] end

	local Bind = IAS.new(BindName, InputType)
	if type(KeyCode) == "table" then
		Bind:SetCompositeDirections(table.unpack(KeyCode))
	else
		Bind:SetBind(KeyCode)
	end

	Class[BindName] = {
		callbacks = callbacks;
		Bind = Bind
	}

	Bind.Activated:Connect(function(_,pressed)
		local ToDo = pressed and "OnStart" or "OnRelease"
		if callbacks[ToDo] then 
			callbacks[ToDo](Bind)
		end
	end)

	return Class[BindName]
end

function Inputs.GetBind(BindClass: string, Bind: string)
	local Class = Inputs.GetClass(BindClass); if not Class then return nil end
	local FoundBind = Class[Bind]; if not FoundBind then return nil end

	return FoundBind
end

function Inputs.RemoveBind(BindClass: string, Bind: string)
	local Class = Inputs.GetClass(BindClass); if not Class then return end
	local FoundBind = Inputs.GetBind(BindClass, Bind); if not FoundBind then return end

	Class[Bind] = nil
end

function Inputs.RemoveClass(BindClass: string)
	local Class = Inputs.GetClass(BindClass); if not Class then return end
	Inputs[BindClass] = nil
end

return Inputs