--!strict
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)
local advents = require("@game/ReplicatedStorage/Modules/Shared/utils/advents")

type hiddenInstance = BasePart | Decal | Texture
type visibilityState = {
	character: Model?;
	originals: {[hiddenInstance]: number};
	springs: {[hiddenInstance]: typeof(Spring.new(0))};
	highlightOriginals: {[Highlight]: {fill: number; outline: number}};
	highlightSprings: {[Highlight]: {fill: typeof(Spring.new(0)); outline: typeof(Spring.new(0))}};
	descendantAdded: RBXScriptConnection?;
	isInvisible: boolean;
}

local SPRING_SPEED = 18
local SPRING_DAMPER = .55

local invisiblePlayers = {} :: {[Player]: boolean}
local visibilityStates = {} :: {[Player]: visibilityState}
local playerConnections = {} :: {[Player]: RBXScriptConnection}

local function disconnectState(state: visibilityState?)
	if not state then return end
	if state.descendantAdded then
		state.descendantAdded:Disconnect()
		state.descendantAdded = nil
	end
end

local function clearState(player: Player, instantRestore: boolean?)
	local state = visibilityStates[player]
	if not state then return end
	disconnectState(state)
	if instantRestore then
		for instance, transparency in next, state.originals do
			if instance.Parent then
				instance.Transparency = transparency
			end
		end
		for hl, orig in next, state.highlightOriginals do
			if hl.Parent then
				hl.FillTransparency = orig.fill
				hl.OutlineTransparency = orig.outline
			end
		end
	end
	visibilityStates[player] = nil
end

local function trackHighlight(state: visibilityState, instance: Instance)
	if not instance:IsA("Highlight") then return end
	local hl = instance :: Highlight

	if not state.highlightOriginals[hl] then
		state.highlightOriginals[hl] = {fill = hl.FillTransparency; outline = hl.OutlineTransparency}
	end

	local orig = state.highlightOriginals[hl]
	local sprs = state.highlightSprings[hl]

	if not sprs then
		local fill = advents.spring.new(hl.FillTransparency)
		fill.s = SPRING_SPEED
		fill.d = SPRING_DAMPER
		local outline = advents.spring.new(hl.OutlineTransparency)
		outline.s = SPRING_SPEED
		outline.d = SPRING_DAMPER
		sprs = {fill = fill; outline = outline}
		state.highlightSprings[hl] = sprs
	end

	if state.isInvisible then
		sprs.fill.t = 1
		sprs.fill.v = sprs.fill.v + 8
		sprs.outline.t = 1
		sprs.outline.v = sprs.outline.v + 8
	else
		sprs.fill.t = orig.fill
		sprs.fill.v = sprs.fill.v - 8
		sprs.outline.t = orig.outline
		sprs.outline.v = sprs.outline.v - 8
	end
end

local function trackInstance(state: visibilityState, instance: Instance)
	if instance:IsA("Highlight") then
		trackHighlight(state, instance)
		return
	end
	if not (instance:IsA("BasePart") or instance:IsA("Decal") or instance:IsA("Texture")) then return end
	if instance:IsA("BasePart") and instance.Name == "HumanoidRootPart" then return end

	local hidden = instance :: hiddenInstance

	if state.originals[hidden] == nil then
		state.originals[hidden] = hidden.Transparency
	end

	local original = state.originals[hidden]
	local spr = state.springs[hidden]

	if not spr then
		spr = advents.spring.new(hidden.Transparency)
		spr.s = SPRING_SPEED
		spr.d = SPRING_DAMPER
		state.springs[hidden] = spr
	end

	if state.isInvisible then
		spr.t = 1
		spr.v = spr.v + 8
	else
		spr.t = original
		spr.v = spr.v - 8
	end
end

local function applyInvisibility(player: Player, character: Model)
	local existing = visibilityStates[player]
	if existing and existing.character ~= character then
		clearState(player, false)
		existing = nil
	end

	local state = existing
	if not state then
		state = {
			character = character;
			originals = {};
			springs = {};
			highlightOriginals = {};
			highlightSprings = {};
			descendantAdded = nil;
			isInvisible = true;
		}
		visibilityStates[player] = state
	else
		state.character = character
		state.isInvisible = true
	end

	for _, descendant in next, character:GetDescendants() do
		trackInstance(state, descendant)
	end

	disconnectState(state)
	state.descendantAdded = character.DescendantAdded:Connect(function(descendant)
		trackInstance(state, descendant)
	end)
end

local function setInvisible(player: Player, shouldBeInvisible: boolean)
	invisiblePlayers[player] = shouldBeInvisible

	if shouldBeInvisible then
		local character = player.Character
		if character then
			applyInvisibility(player, character)
		end
	else
		local state = visibilityStates[player]
		if state then
			state.isInvisible = false
			disconnectState(state)
			for instance in next, state.originals do
				if instance.Parent then
					trackInstance(state, instance)
				end
			end
			for hl in next, state.highlightOriginals do
				if hl.Parent then
					trackHighlight(state, hl)
				end
			end
		end
	end
end

local function setupPlayer(player: Player)
	if playerConnections[player] then
		playerConnections[player]:Disconnect()
	end

	playerConnections[player] = player.CharacterAdded:Connect(function(character)
		if invisiblePlayers[player] then
			task.defer(function()
				if player.Character == character and invisiblePlayers[player] then
					applyInvisibility(player, character)
				end
			end)
		else
			clearState(player, false)
		end
	end)

	if invisiblePlayers[player] and player.Character then
		applyInvisibility(player, player.Character)
	end
end

RunService.Heartbeat:Connect(function()
	local toClear = {}

	for player, state in next, visibilityStates do
		local active = false

		for instance, spr in next, state.springs do
			if not instance.Parent then
				state.springs[instance] = nil
				state.originals[instance] = nil
				continue
			end

			local target = state.isInvisible and 1 or (state.originals[instance] or 0)
			spr.t = target

			local p = math.clamp(spr.p, 0, 1)
			instance.Transparency = p

			if math.abs(target - p) > .001 or math.abs(spr.v) > .001 then
				active = true
			end
		end

		for hl, sprs in next, state.highlightSprings do
			if not hl.Parent then
				state.highlightSprings[hl] = nil
				state.highlightOriginals[hl] = nil
				continue
			end

			local orig = state.highlightOriginals[hl]
			local targetFill = state.isInvisible and 1 or orig.fill
			local targetOutline = state.isInvisible and 1 or orig.outline

			sprs.fill.t = targetFill
			sprs.outline.t = targetOutline

			hl.FillTransparency = math.clamp(sprs.fill.p, 0, 1)
			hl.OutlineTransparency = math.clamp(sprs.outline.p, 0, 1)

			if math.abs(targetFill - sprs.fill.p) > .001 or math.abs(sprs.fill.v) > .001
				or math.abs(targetOutline - sprs.outline.p) > .001 or math.abs(sprs.outline.v) > .001 then
				active = true
			end
		end

		if not state.isInvisible and not active then
			table.insert(toClear, player)
		end
	end

	for _, player in next, toClear do
		clearState(player, false)
	end
end)

conch.register("invisible", {
	description = "Makes a player invisible.";
	permissions = {"visibility"};
	arguments = function()
		return conch.args.player("player", "the player to make invisible")
	end;
	callback = function(player: Player)
		setInvisible(player, true)
		print(`{player.Name} is now invisible`)
	end;
})

conch.register("visible", {
	description = "Makes a player visible again.";
	permissions = {"visibility"};
	arguments = function()
		return conch.args.player("player", "the player to make visible")
	end;
	callback = function(player: Player)
		setInvisible(player, false)
		print(`{player.Name} is now visible`)
	end;
})

for _, player in next, Players:GetPlayers() do
	setupPlayer(player)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(function(player)
	clearState(player, true)
	invisiblePlayers[player] = nil

	local connection = playerConnections[player]
	if connection then
		connection:Disconnect()
		playerConnections[player] = nil
	end
end)

return nil