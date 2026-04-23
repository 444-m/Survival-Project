local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local ServerStorage = game:GetService("ServerStorage")

local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local BlinkServer = Networking.Server
local Tools = require(ReplicatedStorage.Modules.Shared.Storage.Tools)
local Janitor = require(ReplicatedStorage.Packages.Shared.Janitor)
local StunModule = require(script.Parent.StunModule)

local ToolModels = ServerStorage.Assets.Tools

const MAX_TOOLS = 10
const MAX_INVENTORY_CAPACITY = 50

local ToolManagerServer = {}
ToolManagerServer.__index = ToolManagerServer
ToolManagerServer.Managers = {}
ToolManagerServer.ActiveToolSetups = {} :: { [Model]: { [string]: { models: {Instance}, cleanups: {()->()}, data: any, equipped: boolean } } }

local ToolModelSetups = {}
local setupsFolder = script:FindFirstChild("Setups")
if setupsFolder then
	for _, v: ModuleScript in next, setupsFolder:GetDescendants() do
		if v:IsA("ModuleScript") then
			ToolModelSetups[v.Name] = require(v)
		end
	end
end

local function firstEmpty(tbl, max)
	for i = 1, max do
		if not tbl[i] then return i end
	end
	return nil
end

local function buildItem(name, qty)
	local data = Tools[name]
	if not data then return nil end
	local maxq = data.MaxQuantity or 0
	if maxq <= 0 then
		qty = qty or 1
	else
		qty = math.min(qty or 1, maxq)
	end
	return {
		name = name;
		qty = qty or 1;
		image = data.Image;
	}
end

local function cloneList(list, max)
	local t = {}
	for i = 1, max do
		t[i] = list[i]
	end
	return t
end

local function deepCopyItem(item)
	if not item then return nil end
	return {
		name = item.name;
		qty = item.qty;
		image = item.image;
	}
end

local function deepCopyTools(tools)
	local copy = {
		Hotbar = {};
		Inventory = {};
		Equipped = tools and tools.Equipped or nil;
	}
	if tools then
		for i = 1, MAX_TOOLS do
			copy.Hotbar[i] = deepCopyItem(tools.Hotbar and tools.Hotbar[i])
		end
		for i = 1, MAX_INVENTORY_CAPACITY do
			copy.Inventory[i] = deepCopyItem(tools.Inventory and tools.Inventory[i])
		end
	end
	return copy
end

local pruneSetups

local function consumeOne(mgr, slot: number?, name: string, opts: {skipPrune: boolean}?)
	local tools = mgr.Tools
	tools.Hotbar = tools.Hotbar or {}
	tools.Inventory = tools.Inventory or {}

	local function dec(tbl, idx)
		local it = tbl[idx]
		if not it or it.name ~= name then return false end
		if (it.qty or 1) > 1 then
			it.qty -= 1
		else
			tbl[idx] = nil
		end
		return true
	end

	if slot and dec(tools.Hotbar, slot) then
		if tools.Equipped == slot and not tools.Hotbar[slot] then
			if opts and opts.skipPrune then
				tools.Equipped = nil
				mgr:_replicate()
			else
				mgr:_equip(nil)
			end
		else
			mgr:_replicate()
		end
		if not (opts and opts.skipPrune) then
			pruneSetups(mgr.Player.Character, mgr.Tools)
		end
		return true
	end

	for i = 1, MAX_TOOLS do
		if dec(tools.Hotbar, i) then
			if tools.Equipped == i and not tools.Hotbar[i] then
				if opts and opts.skipPrune then
					tools.Equipped = nil
					mgr:_replicate()
				else
					mgr:_equip(nil)
				end
			else
				mgr:_replicate()
			end
			if not (opts and opts.skipPrune) then
				pruneSetups(mgr.Player.Character, mgr.Tools)
			end
			return true
		end
	end

	for i = 1, MAX_INVENTORY_CAPACITY do
		if dec(tools.Inventory, i) then
			mgr:_replicate()
			if not (opts and opts.skipPrune) then
				pruneSetups(mgr.Player.Character, mgr.Tools)
			end
			return true
		end
	end

	return false
end

local function getSetupEntry(character: Model, name: string, create: boolean)
	local charMap = ToolManagerServer.ActiveToolSetups[character]
	if not charMap and create then
		charMap = {}
		ToolManagerServer.ActiveToolSetups[character] = charMap
	end
	if not charMap then return nil end
	local entry = charMap[name]
	if not entry and create then
		entry = { models = {}, cleanups = {}, data = {}, equipped = false }
		charMap[name] = entry
	end
	return entry
end

local function cleanupTool(character: Model, name: string)
	local charMap = ToolManagerServer.ActiveToolSetups[character]
	if not charMap then return end
	local entry = charMap[name]
	if not entry then return end
	local setup = ToolModelSetups[name]
	if entry.equipped and setup and setup.Unequip then
		pcall(setup.Unequip, setup, character, entry.data, entry.models)
	end
	if setup and setup.RemoveSetup then
		pcall(setup.RemoveSetup, setup, character, entry.data, entry.models)
	end
	for _, fn in next, entry.cleanups do
		pcall(fn)
	end
	for _, m in next, entry.models do
		if m and m.Destroy then
			pcall(function() m:Destroy() end)
		end
	end
	charMap[name] = nil
	if next(charMap) == nil then
		ToolManagerServer.ActiveToolSetups[character] = nil
	end
end

function pruneSetups(character: Model, tools)
	if not character then return end
	local charMap = ToolManagerServer.ActiveToolSetups[character]
	if not charMap then return end
	local keep = {}
	if tools then
		local hb = tools.Hotbar or {}
		for i = 1, MAX_TOOLS do
			local it = hb[i]
			if it and it.name then
				keep[it.name] = true
			end
		end
		local inv = tools.Inventory or {}
		for i = 1, MAX_INVENTORY_CAPACITY do
			local it = inv[i]
			if it and it.name then
				keep[it.name] = true
			end
		end
	end
	for name in next, charMap do
		if not keep[name] then
			cleanupTool(character, name)
		end
	end
end

local function ensureSetup(name: string, character: Model)
	if not ToolModels or not character then return end
	local entry = getSetupEntry(character, name, true)
	if entry.setupd then
		return entry
	end
	local toolModel = ToolModels:FindFirstChild(name)
	if toolModel then
		toolModel = toolModel:Clone()
		table.insert(entry.models, toolModel)
	end
	local setup = ToolModelSetups[name]
	if setup and setup.Setup then
		local ok, res, cleanup = pcall(setup.Setup, setup, character, toolModel, entry.data)
		if ok then
			if typeof(res) == "Instance" then
				table.insert(entry.models, res)
			elseif type(res) == "table" then
				for _, inst in next, res do
					table.insert(entry.models, inst)
				end
			end
			if type(cleanup) == "function" then
				table.insert(entry.cleanups, cleanup)
			end
		end
	end
	entry.setupd = true
	return entry
end

local function pruneSetups(character: Model, tools)
	if not character then return end
	local charMap = ToolManagerServer.ActiveToolSetups[character]
	if not charMap then return end
	local keep = {}
	if tools then
		local hb = tools.Hotbar or {}
		for i = 1, MAX_TOOLS do
			local it = hb[i]
			if it and it.name then
				keep[it.name] = true
			end
		end
		local inv = tools.Inventory or {}
		for i = 1, MAX_INVENTORY_CAPACITY do
			local it = inv[i]
			if it and it.name then
				keep[it.name] = true
			end
		end
	end
	for name in next, charMap do
		if not keep[name] then
			cleanupTool(character, name)
		end
	end
end

local function deepSearch(t: {}, find: string)
	if type(t) ~= "table" then return end

	for key, value in next, t do
		if key == find then
			return value
		end
		if type(value) == "table" then
			local found = deepSearch(value, find)
			if found then
				return found
			end
		end
	end
	return nil
end

local function runUnequip(character: Model, name: string)
	local entry = getSetupEntry(character, name, false)
	if not entry then return end
	local setup = ToolModelSetups[name]
	if setup and setup.Unequip then
		pcall(setup.Unequip, setup, character, entry.data, entry.models)
	end
	entry.equipped = false
end

function ToolManagerServer.new(player: Player)
	if ToolManagerServer.get(player.UserId) then
		return ToolManagerServer.get(player.UserId)
	end

	local self = setmetatable({}, ToolManagerServer)
	self.Player = player
	self.Janitor = Janitor.new()
	self.Tools = {
		Hotbar = {};
		Inventory = {};
		Equipped = nil;
	}
	self:_replicate()

	local function LoadTools(Character: Model)
		local tools = self.Tools
		if not tools then return end
		for i = 1, MAX_TOOLS do
			local item = tools.Hotbar and tools.Hotbar[i]
			local name = item and item.name
			if name then
				ensureSetup(name, Character)
			end
		end
		for i = 1, MAX_INVENTORY_CAPACITY do
			local item = tools.Inventory and tools.Inventory[i]
			local name = item and item.name
			if name then
				ensureSetup(name, Character)
			end
		end
	end

	if player.Character then
		task.spawn(LoadTools, player.Character)
	end
	if player.CharacterAdded then
		self.Janitor:Add(player.CharacterAdded:Connect(LoadTools), "Disconnect")
	end
	if player.CharacterRemoving then
		self.Janitor:Add(player.CharacterRemoving:Connect(function(char)
			self:_equip(nil)
			local active = ToolManagerServer.ActiveToolSetups[char]
			if active then
				for name in next, active do
					cleanupTool(char, name)
				end
			end
		end), "Disconnect")
	end

	ToolManagerServer.Managers[self.Player.UserId] = self
	return self
end

function ToolManagerServer.get(id: number)
	return ToolManagerServer.Managers[id]
end

function ToolManagerServer:_data()
	local data = self.Tools or {}
	return deepCopyTools(data)
end

function ToolManagerServer:_serialize(list, max)
	list = list or {}
	local t = {}
	for i = 1, max do
		local v = list[i]
		if v and v.name and Tools[v.name] then
			t[i] = {
				name = v.name;
				qty = v.qty or 1;
				image = Tools[v.name].Image;
			}
		else
			t[i] = nil
		end
	end
	return t
end

function ToolManagerServer:_replicate()
	local tools = self:_data()
	local payload = {
		inhotbar = self:_serialize(tools.Hotbar, MAX_TOOLS);
		ininvnetory = self:_serialize(tools.Inventory, MAX_INVENTORY_CAPACITY);
		equipped = tools.Equipped;
	}
	local encoded = HttpService:JSONEncode(payload)
	if BlinkServer.ToolInventory then
		BlinkServer.ToolInventory.Fire(self.Player, { Payload = encoded })
	end
end

function ToolManagerServer:_getInventory()
	local tools = self:_data()
	return {
		ininvnetory = cloneList(tools.Inventory, MAX_INVENTORY_CAPACITY);
		inhotbar = cloneList(tools.Hotbar, MAX_TOOLS);
	}
end

function ToolManagerServer:_canActivate(slot: number?, name: string?)
	if type(slot) ~= "number" or type(name) ~= "string" then return false end
	if slot < 1 or slot > MAX_TOOLS then return false end
	local tools = self:_data()
	local hotbar = tools.Hotbar or {}
	local item = hotbar[slot]
	if not item or item.name ~= name then return false end
	return true
end

function ToolManagerServer:_addToInventory(weapon: string, slot: number?, qty: number?)
	if not Tools[weapon] then return false end
	local maxq = Tools[weapon].MaxQuantity or 0
	local unlimited = maxq <= 0
	local result = false
	qty = math.max(1, qty or 1)

	local tools = self.Tools
	tools.Hotbar = tools.Hotbar or {}
	tools.Inventory = tools.Inventory or {}

	local function totalCount(name)
		local count = 0
		for i = 1, MAX_TOOLS do
			local it = tools.Hotbar[i]
			if it and it.name == name then
				count += it.qty or 1
			end
		end
		for i = 1, MAX_INVENTORY_CAPACITY do
			local it = tools.Inventory[i]
			if it and it.name == name then
				count += it.qty or 1
			end
		end
		return count
	end

	local current = totalCount(weapon)
	local space = unlimited and qty or math.max(0, maxq - current)
	local toGive = unlimited and qty or math.min(qty, space)
	if toGive <= 0 then return false end

	local remaining = toGive
	local function fill(dest, maxSlots)
		for i = 1, maxSlots do
			if remaining <= 0 then break end
			local it = dest[i]
			if it and it.name == weapon then
				if unlimited then
					it.qty += remaining
					remaining = 0
					return true
				else
					local can = math.min(remaining, maxq - (it.qty or 1))
					if can > 0 then
						it.qty = (it.qty or 1) + can
						remaining -= can
					end
				end
			end
		end
		for i = 1, maxSlots do
			if remaining <= 0 then break end
			if not dest[i] then
				local put = unlimited and remaining or math.min(remaining, maxq)
				dest[i] = buildItem(weapon, put)
				remaining -= put
			end
		end
		return remaining <= 0
	end

	if slot and slot >= 1 and slot <= MAX_TOOLS and not tools.Hotbar[slot] then
		fill(tools.Hotbar, MAX_TOOLS)
	else
		fill(tools.Hotbar, MAX_TOOLS)
	end
	if remaining > 0 then
		fill(tools.Inventory, MAX_INVENTORY_CAPACITY)
	end

	if remaining > 0 then
		return false
	end

	result = true

	if result then
		self:_replicate()
		local character = self.Player.Character
		if character then
			task.spawn(ensureSetup, weapon, character)
			pruneSetups(character, self.Tools)
		end
	end

	return result
end

function ToolManagerServer:_clearInventory()
	self.Tools = {
		Hotbar = {};
		Inventory = {};
		Equipped = nil;
	}
	self:_replicate()
	local character = self.Player.Character
	if character then
		local active = ToolManagerServer.ActiveToolSetups[character]
		if active then
			for name in next, active do
				cleanupTool(character, name)
			end
		end
		pruneSetups(character, self.Tools)
	end
end

function ToolManagerServer:_equip(slot: number?)
	local tools = self.Tools
	tools.Hotbar = tools.Hotbar or {}
	tools.Inventory = tools.Inventory or {}

	local prevSlot = tools.Equipped
	local prevItem = prevSlot and tools.Hotbar[prevSlot] or nil

	if slot ~= nil then
		if slot < 1 or slot > MAX_TOOLS then
			return false
		end
		if not tools.Hotbar[slot] then
			return false
		end
		tools.Equipped = slot
	else
		tools.Equipped = nil
	end

	local newSlot = tools.Equipped
	local newItem = newSlot and tools.Hotbar[newSlot] or nil

	local character = self.Player.Character
	if character then
		if prevItem then ensureSetup(prevItem.name, character) end
		if newItem then ensureSetup(newItem.name, character) end

		if prevItem and (not newItem or prevItem.name ~= newItem.name or prevSlot ~= newSlot) then
			runUnequip(character, prevItem.name)
		end
		if newItem then
			local entry = ensureSetup(newItem.name, character)
			local setup = ToolModelSetups[newItem.name]
			if setup and setup.Equip then
				pcall(setup.Equip, setup, character, entry.data, entry.models)
			end
			entry.equipped = true
		else
			local charMap = ToolManagerServer.ActiveToolSetups[character]
			if charMap then
				for _, entry in next, charMap do
					entry.equipped = false
				end
			end
		end
	end
	if newSlot and BlinkServer.ToolEquip then
		local encoded = HttpService:JSONEncode({slot = newSlot, item = newItem})
		BlinkServer.ToolEquip.Fire(self.Player, { Payload = encoded })
	elseif not newSlot and BlinkServer.ToolUnequip then
		local encoded = HttpService:JSONEncode({slot = nil})
		BlinkServer.ToolUnequip.Fire(self.Player, { Payload = encoded })
	end
	self:_replicate()
	return true
end

function ToolManagerServer:Destroy()
	self.Janitor:Destroy()
	ToolManagerServer.Managers[self.Player.UserId] = nil
end

function ToolManagerServer.GetInventory(player: Player)
	local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
	return mgr:_getInventory()
end

function ToolManagerServer.AddToInventory(player: Player, weapon: string, slot: number?, qty: number?)
	local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
	return mgr:_addToInventory(weapon, slot, qty)
end

function ToolManagerServer.ClearInventory(player: Player)
	local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
	return mgr:_clearInventory()
end

function ToolManagerServer.Equip(player: Player, slot: number?)
	local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
	return mgr:_equip(slot)
end

function ToolManagerServer.Unequip(player: Player)
	local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
	return mgr:_equip(nil)
end

Players.PlayerRemoving:Connect(function(player)
	local mgr = ToolManagerServer.get(player.UserId)
	if mgr then
		mgr:Destroy()
	end
end)

if BlinkServer and BlinkServer.StateUpdate and BlinkServer.StateUpdate.On then
	BlinkServer.StateUpdate.On(function(player: Player, payload)
		if type(payload) ~= "table" then return end
		local state = payload.NewState
		if state == "ToolEquip" then
			local slot = type(payload.Id) == "number" and payload.Id or nil
			local name = type(payload.Name) == "string" and payload.Name or nil
			if slot == 0 then slot = nil end
			task.defer(function()
				local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
				if name and slot and slot >=1 and slot <= MAX_TOOLS then
					local data = mgr:_data()
					data.Hotbar = data.Hotbar or {}
					if not data.Hotbar[slot] then
						data.Hotbar[slot] = buildItem(name, 1)
					elseif data.Hotbar[slot].name ~= name then
						local swapped = false
						for i = 1, MAX_TOOLS do
							if data.Hotbar[i] and data.Hotbar[i].name == name then
								data.Hotbar[slot], data.Hotbar[i] = data.Hotbar[i], data.Hotbar[slot]
								swapped = true
								break
							end
						end
						if not swapped then
							data.Hotbar[slot] = buildItem(name, 1)
						end
					end
					mgr.Tools.Hotbar = data.Hotbar
				end
				mgr:_equip(slot)
			end)
		elseif state == "ToolActivate" then
			local slot = type(payload.Id) == "number" and payload.Id or nil
			local name = type(payload.Name) == "string" and payload.Name or nil
			local data = payload.Data
			if slot == 0 then slot = nil end
			task.defer(function()
				local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
				local tools = mgr:_data()
				tools.Hotbar = tools.Hotbar or {}
				if not slot and name then
					for i = 1, MAX_TOOLS do
						if tools.Hotbar[i] and tools.Hotbar[i].name == name then
							slot = i
							break
						end
					end
				end
				if not name and slot and tools.Hotbar[slot] then
					name = tools.Hotbar[slot].name
				end
				if not slot and tools.Equipped and tools.Hotbar[tools.Equipped] then
					slot = tools.Equipped
					name = name or tools.Hotbar[slot].name
				end
				if not name then return end
				local character = player.Character
				if not character then return end
				local entry = ensureSetup(name, character)
				if not entry then return end
				local setup = ToolModelSetups[name]
				if setup and setup.Activate then
					local combined = {}
					if type(entry.data) == "table" then
						for k, v in next, entry.data do
							combined[k] = v
						end
					end
					if type(data) == "table" then
						for k, v in next, data do
							combined[k] = v
						end
					end
					local ok, used = pcall(setup.Activate, setup, character, combined, entry.models, data)
					if ok and used == false then
						return
					end
					local keepModel = type(data) == "table" and data.keepModel == true
					local consumed = false
					if type(data) == "table" and data.consume then
						consumed = consumeOne(mgr, slot, name, {skipPrune = keepModel})
						local function finishCleanup()
							if not consumed then
								consumed = consumeOne(mgr, slot, name)
							end
							pruneSetups(mgr.Player.Character, mgr.Tools)
							cleanupTool(mgr.Player.Character, name)
						end
						if keepModel then
							local endLen = tonumber(data.endLength) or .6
							task.delay(math.max(endLen, .05), finishCleanup)
						else
							finishCleanup()
						end
					end
				end
			end)
		end
	end)
end

local function handleActivate(player: Player, slot: number?, name: string?, data: any)
	if slot == 0 then slot = nil end
	local mgr = ToolManagerServer.get(player.UserId) or ToolManagerServer.new(player)
	local tools = mgr:_data()
	tools.Hotbar = tools.Hotbar or {}
	if not slot and name then
		for i = 1, MAX_TOOLS do
			if tools.Hotbar[i] and tools.Hotbar[i].name == name then
				slot = i
				break
			end
		end
	end
	if not name and slot and tools.Hotbar[slot] then
		name = tools.Hotbar[slot].name
	end
	if not slot and tools.Equipped and tools.Hotbar[tools.Equipped] then
		slot = tools.Equipped
		name = name or tools.Hotbar[slot].name
	end
	if not name then return end
	local character = player.Character
	if not character then return end
	local entry = ensureSetup(name, character)
	if not entry then return end
	local stunConf = Tools[name] and Tools[name].Stun
	if stunConf then
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			StunModule.Apply(humanoid, {
				duration = stunConf.duration or 0;
				walkSpeed = stunConf.walkSpeed;
				jumpPower = stunConf.jumpPower;
				override = data and data.overrideStun ~= false;
			})
		end
	end
	local setup = ToolModelSetups[name]
	if setup and setup.Activate then
		local combined = {}
		if type(entry.data) == "table" then
			for k, v in next, entry.data do combined[k] = v end
		end
		if type(data) == "table" then
			for k, v in next, data do combined[k] = v end
		end
		local ok, used = pcall(setup.Activate, setup, character, combined, entry.models, data)
	if ok and used == false then
		return
	end
	local keepModel = type(data) == "table" and data.keepModel == true
	if type(data) == "table" and data.consume then
		local consumed = consumeOne(mgr, slot, name, {skipPrune = keepModel})
		local function finishCleanup()
			if not consumed then
				consumed = consumeOne(mgr, slot, name)
			end
			pruneSetups(mgr.Player.Character, mgr.Tools)
			cleanupTool(mgr.Player.Character, name)
		end
		if keepModel then
			local endLen = tonumber(data.endLength) or .6
			task.delay(math.max(endLen, .05), finishCleanup)
		else
			finishCleanup()
		end
	end
end
end

if BlinkServer and BlinkServer.ActiveTool and BlinkServer.ActiveTool.On then
	BlinkServer.ActiveTool.On(function(player: Player, payload)
		if type(payload) ~= "table" then return end
		handleActivate(player, payload.Id, payload.Name, payload.Data)
	end)
end

return ToolManagerServer
