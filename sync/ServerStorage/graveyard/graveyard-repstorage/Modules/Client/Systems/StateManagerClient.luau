local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SharedPackages = ReplicatedStorage.Packages.Shared

local Signal = require(SharedPackages.Signal)
local BlinkClient = require(SharedPackages.Blink.Client)
local PlayerStates = require(ReplicatedStorage.Modules.Shared.Systems.PlayerStates)
local HasBlinkStateEvents = BlinkClient.StateSync ~= nil and BlinkClient.StateUpdate ~= nil
if not HasBlinkStateEvents then
	warn("[StateManagerClient] Blink StateSync/StateUpdate is missing; state changes are local-only until Blink events are generated.")
end

local StateManagerClient = {}
StateManagerClient.Entities = {}
StateManagerClient.StateChanged = Signal()

export type Entity = {
	Id: number;
	State: string;
	PreviousState: string?;
	StateChanged: any;
}

local Entities = StateManagerClient.Entities
local DefaultState = "Idling"

local function IsValidState(State: string): boolean
	return PlayerStates[State] ~= nil
end

local function EnsureEntity(Id: number, InitialState: string?): Entity
	local Entity = Entities[Id]
	if Entity then
		return Entity
	end

	local StartingState = InitialState or DefaultState
	if not IsValidState(StartingState) then
		StartingState = DefaultState
	end

	Entity = {
		Id = Id,
		State = StartingState;
		PreviousState = nil;
		StateChanged = Signal();
	}
	
	Entities[Id] = Entity
	return Entity
end

local function ApplyState(IdOrPayload, NewState: string?, PreviousState: string?)
	local Id = IdOrPayload
	if type(IdOrPayload) == "table" then
		Id = IdOrPayload.Id
		NewState = IdOrPayload.NewState
		PreviousState = IdOrPayload.PreviousState
	end
	if type(Id) ~= "number" or type(NewState) ~= "string" then
		return
	end
	if not IsValidState(NewState) then
		return
	end

	local Entity = EnsureEntity(Id, NewState)
	local OldState = Entity.State
	if OldState == NewState then
		return
	end

	Entity.PreviousState = PreviousState or OldState
	Entity.State = NewState
	Entity.StateChanged:Fire(NewState, Entity.PreviousState)
	StateManagerClient.StateChanged:Fire(Id, NewState, Entity.PreviousState)
end

local SyncDisconnect = nil
if HasBlinkStateEvents then
	SyncDisconnect = BlinkClient.StateSync.On(ApplyState)
end

function StateManagerClient.NewEntity(Id: number, InitialState: string?): Entity
	return EnsureEntity(Id, InitialState)
end

function StateManagerClient.IsValidState(State: string): boolean
	return IsValidState(State)
end

function StateManagerClient.GetEntity(Id: number): Entity?
	return Entities[Id]
end

function StateManagerClient.GetEntityState(Id: number): string?
	local Entity = Entities[Id]
	if not Entity then
		return nil
	end
	return Entity.State
end

function StateManagerClient.UpdateEntityState(Id: number, NewState: string): boolean
	if not IsValidState(NewState) then
		return false
	end

	local Entity = EnsureEntity(Id, NewState)
	if Entity.State == NewState then
		return false
	end

	local OldState = Entity.State
	Entity.PreviousState = OldState
	Entity.State = NewState
	Entity.StateChanged:Fire(NewState, OldState)
	StateManagerClient.StateChanged:Fire(Id, NewState, OldState)

	if HasBlinkStateEvents then
		BlinkClient.StateUpdate.Fire({
			Id = Id;
			NewState = NewState;
			Brute = false;
		})
	end
	return true
end

function StateManagerClient.BruteChangeState(Id: number, NewState: string): boolean
	if not IsValidState(NewState) then
		return false
	end

	local Entity = EnsureEntity(Id, NewState)
	if Entity.State == NewState then
		return false
	end

	local OldState = Entity.State
	Entity.PreviousState = OldState
	Entity.State = NewState
	Entity.StateChanged:Fire(NewState, OldState)
	StateManagerClient.StateChanged:Fire(Id, NewState, OldState)

	if HasBlinkStateEvents then
		BlinkClient.StateUpdate.Fire({
			Id = Id;
			NewState = NewState;
			Brute = true;
		})
	end
	return true
end

function StateManagerClient.RemoveEntity(Id: number): boolean
	local Entity = Entities[Id]
	if not Entity then
		return false
	end

	Entities[Id] = nil
	if Entity.StateChanged then
		Entity.StateChanged:Destroy()
		Entity.StateChanged = nil
	end

	return true
end

function StateManagerClient.CanTransition(Id: number, NewState: string): boolean
	local CurrentEntityState = StateManagerClient.GetEntityState(Id)
	
	if not CurrentEntityState then
		return false
	end
	
	if not IsValidState(NewState) then
		return false
	end
	
	local CurrentPriority = PlayerStates[CurrentEntityState]
	local NewPriority = PlayerStates[NewState]
	
	if NewPriority < CurrentPriority then
		return false
	end
	
	return true
end

function StateManagerClient.Destroy()
	if SyncDisconnect then
		SyncDisconnect()
	end

	for Id in next, Entities do
		StateManagerClient.RemoveEntity(Id)
	end

	if StateManagerClient.StateChanged then
		StateManagerClient.StateChanged:Destroy()
		StateManagerClient.StateChanged = nil
	end
end

return StateManagerClient