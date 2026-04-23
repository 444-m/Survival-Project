local StateManager = {}
StateManager.Entities = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packages = ReplicatedStorage.Packages
local SharedPackages = Packages.Shared

local Signal = require(SharedPackages.Signal)

local PlayerStates = require(ReplicatedStorage.Modules.Shared.Systems.PlayerStates)
local DefaultState = "Idling"

local function IsValidState(State: string): boolean
	return PlayerStates[State] ~= nil
end

function StateManager.GetStatePriority(State: string): number?
	return PlayerStates[State]
end

function StateManager.IsValidState(State: string): boolean
	return IsValidState(State)
end

function StateManager.NewEntity(Id: number, InitialState: string?)
    local ExistingEntity = StateManager.Entities[Id]; if ExistingEntity then return ExistingEntity end
	local StartingState = InitialState or DefaultState
	if not IsValidState(StartingState) then
		StartingState = DefaultState
	end

    local Entity = {
        Id = Id;
        PreviousState = nil;
        State = StartingState;
        StateChanged = Signal();
    }

	StateManager.Entities[Id] = Entity

	return Entity
end

function StateManager.GetEntity(Id: number)
    return StateManager.Entities[Id]
end

function StateManager.GetState(Id: number)
    local Entity = StateManager.Entities[Id]
    return Entity and Entity.State or nil
end

function StateManager.RemoveEntity(Id: number)
    local ExistingEntity = StateManager.Entities[Id]; if not ExistingEntity then return false end
	if ExistingEntity.StateChanged then
		ExistingEntity.StateChanged:Destroy()
	end
    StateManager.Entities[Id] = nil
	return true
end

function StateManager.UpdateEntityState(Id: number, NewState: string)
	local Entity = StateManager.Entities[Id]
	if not Entity then
		return false
	end

	if not IsValidState(NewState) then
		return false
	end
	if Entity.State == NewState then
		return false
	end

	local PreviousState = Entity.State
	local CurrentPriority = PlayerStates[PreviousState]
	local NewPriority = PlayerStates[NewState]

	if CurrentPriority == nil or NewPriority == nil then
		return false
	end

	if NewPriority < CurrentPriority then
		return false
	end

	Entity.PreviousState = PreviousState
	Entity.State = NewState
	Entity.StateChanged:Fire(NewState, PreviousState)
	return true
end

function StateManager.BruteChangeState(Id: number, NewState: string)
	local Entity = StateManager.Entities[Id]
	if not Entity then
		return false
	end

	if not IsValidState(NewState) then
		return false
	end

	if Entity.State == NewState then
		return false
	end

	local PreviousState = Entity.State
	Entity.PreviousState = PreviousState
	Entity.State = NewState
	Entity.StateChanged:Fire(NewState, PreviousState)
	return true
end

return StateManager
