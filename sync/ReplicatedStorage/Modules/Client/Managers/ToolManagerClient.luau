local ToolManagerClient = {}
ToolManagerClient.__index = ToolManagerClient

local CentralHeartbeat = require "@game/ReplicatedStorage/Modules/Shared/misc/CentralHeartbeat"

local Signal = require "@game/ReplicatedStorage/Packages/Shared/Signal"
local Janitor = require "@game/ReplicatedStorage/Packages/Shared/Janitor"
local Spring = require "@game/ReplicatedStorage/Modules/Shared/utils/advents"
	 .spring
	
local Tools = require "../../Shared/Storage/Tools" 
local Input = require "../../Client/Input" 

local Networking = require "@game/ReplicatedStorage/Modules/Shared/Networking"
local BlinkClient = Networking.Client

const MAX_TOOLS = 10
const MAX_INVENTORY_CAPACITY = 50
const SLOT_W = 72
const SLOT_GAP = 6
const TB_PADDING = 20
const DRAG_THRESHOLD = 6

local UIS = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

const EQUIP_TWEEN_IN  = TweenInfo.new(.18, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
const EQUIP_TWEEN_OUT = TweenInfo.new(.38, Enum.EasingStyle.Sine, Enum.EasingDirection.In)

type WeaponSetup = {
	Use: (self: WeaponSetup, ...any) -> {[string]: any};
	Cancel: (self: WeaponSetup, ...any) -> ();
}

local Setups = {} :: {[string]: WeaponSetup}
for _,v in next, script:GetDescendants() do 
	if v:IsA("ModuleScript") then
		Setups[v.Name] = require(v)
	end
end; ToolManagerClient.Setups = Setups

local function firstEmpty(tbl: {any}, max: number): number?
	for i = 1, max do
		if not tbl[i] then return i end
	end
	return nil
end

local function countFilled(tbl: {any}): number
	local n = 0
	for _, v in next, tbl do
		if v then n += 1 end
	end
	return n
end

type Item = {
	name: string;
	image: string;
	qty: number;
}

local function copyItem(item: Item?): Item?
	if not item then return nil end
	return {
		name = item.name;
		image = item.image;
		qty = item.qty;
	}
end

local function takeOne(tbl, idx): Item?
	local it = tbl[idx]
	if not it then return nil end
	if (it.qty or 1) > 1 then
		it.qty -= 1
		return { name = it.name; image = it.image; qty = 1; }
	else
		tbl[idx] = nil
		return { name = it.name; image = it.image; qty = 1; }
	end
end

local function mergeInto(tbl, idx, item: Item?)
	if not item then return end
	if not tbl[idx] then
		tbl[idx] = item
		return
	end
	local existing = tbl[idx]
	if existing.name == item.name then
		existing.qty += item.qty
	else
		-- swap
		tbl[idx] = item
		return existing
	end
end

type SlotRef = {
	frame: Frame;
	img: ImageButton?;
	nameLabel: TextLabel?;
	qtyLabel: TextLabel?;
	keyLabel: TextLabel?;
	stroke: UIStroke?;
	glowFrame: Frame?;
	glowStroke: UIStroke?;
}

function ToolManagerClient:_setEquipped(slot: number?, weaponName: string?)
	if self._equipLock and slot ~= nil and slot ~= self.Equipped then
		return
	end
	local toolData = Tools[weaponName]
	if toolData and type(toolData.EquipRequirement) == "function" then
		local success = toolData.EquipRequirement(self)
		if not success then
			return
		end
	end
	local prevSlot = self.Equipped
	local prevWeapon = self.EquippedWeapon
	local currentWeapon = weaponName or (slot and self.Storage.Hotbar[slot] and self.Storage.Hotbar[slot].name) or nil
	if prevSlot == slot and prevWeapon == currentWeapon then return end
	self.EquippedWeapon = currentWeapon
	self.Equipped = slot
	self:_setAds(false)
	self:_refreshAllSlots()
	if slot or currentWeapon then
		local payloadItem = slot and self.Storage.Hotbar[slot] or nil
		self.States.Equipped:Fire(slot, payloadItem, currentWeapon)
		local tool = currentWeapon and Tools[currentWeapon]
		if slot and payloadItem and tool and tool.ActivateOnEquip then
			self.States.Activated:Fire(slot, payloadItem)
		end
	elseif prevWeapon then
		self.EquippedWeapon = nil
		self.States.UnEquipped:Fire(prevSlot, nil, prevWeapon)
		self.States.Equipped:Fire(nil, nil, nil)
	end
end

function ToolManagerClient:SetEquipLocked(locked: boolean, owner: string?)
	if locked then
		self._equipLock = owner or "Locked"
	else
		self._equipLock = nil
	end
end

function ToolManagerClient:GetEquipLockOwner(): string?
	return self._equipLock
end

function ToolManagerClient:_applySnapshot(data)
	if type(data) ~= "table" then return end
	local hb = data.inhotbar or {}
	local inv = data.ininvnetory or {}
	for i = 1, MAX_TOOLS do
		self.Storage.Hotbar[i] = hb[i]
	end
	for i = 1, MAX_INVENTORY_CAPACITY do
		self.Storage.Inventory[i] = inv[i]
	end
	if data.equipped and self.Storage.Hotbar[data.equipped] then
		self:_setEquipped(data.equipped)
	else
		self:_setEquipped(nil)
	end
	self:_refreshAllSlots()
	for i = 1, MAX_INVENTORY_CAPACITY do
		self:_refreshInvCell(i)
	end
	self:_refreshCountLabel()
	self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
	self.States.Changed:Fire()
end

local function _tweenEquipGlow(ref: SlotRef, on: boolean)
	if not ref.glowFrame or not ref.glowStroke then return end
	if on then
		ref.glowFrame.Visible = true
		ref.glowFrame.BackgroundTransparency = 0.88
		ref.glowStroke.Thickness = 2
	else
		ref.glowFrame.BackgroundTransparency = 1
		ref.glowStroke.Thickness = 0
		ref.glowFrame.Visible = false
	end
end

function ToolManagerClient.new(Player: Player)
	local PlayerGui = Player:WaitForChild("PlayerGui")
	local InventoryUI = PlayerGui:WaitForChild("Inventory", 999)

	local self = setmetatable({}, ToolManagerClient)

	self.Janitor = Janitor.new()
	self.InventoryUI = InventoryUI
	self.PlayerGui = PlayerGui
	self.Player = Player
	InventoryUI.Enabled = true
	self.Equipped = nil :: number?
	self.EquippedWeapon = nil :: string?
	self.InventoryOpen = false

	self.States = {
		Equipped = Signal();
		Activated = Signal();
		UnEquipped = Signal();
		Changed = Signal();
		Ads = Signal();
	}

	self.Storage = {
		Inventory = {} :: {Item?};
		Hotbar = {} :: {Item?};
	}

	self.SlotRefs = {} :: {SlotRef}
	self.InvCells = {} :: {Frame}

	self.DragState = {
		active = false;
		pending = false;
		pendingSource = nil :: string?;
		pendingIndex = nil :: number?;
		pendingOrigin = nil :: Vector2?;
		ghost = nil :: Frame?;
		source = nil :: string?;
		index = nil :: number?;
		item = nil :: Item?;
	}

	self._tbWidthSpring = Spring.new(0)
	self._tbWidthSpring.s = 18
	self._tbWidthSpring.d = .7

	self._invHeightSpring = Spring.new(0)
	self._invHeightSpring.s = 18
	self._invHeightSpring.d = .7

	self._invNativeHeight = 0
	self._invNativeW = 0
	self._slotW = SLOT_W

	self._adsActive = false

	self:_buildHotbar()
	self:_buildInventory()
	self:_bindInputs()
	self:_bindDrag()
	self:_startLoop()

	if BlinkClient.ToolInventory then
		self.Janitor:Add(BlinkClient.ToolInventory.On(function(payload)
			if type(payload) ~= "table" or type(payload.Payload) ~= "string" then return end
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, payload.Payload)
			if ok then
				self:_applySnapshot(decoded)
			end
		end), "Disconnect")
	end
	if BlinkClient.ToolEquip then
		self.Janitor:Add(BlinkClient.ToolEquip.On(function(payload)
			if type(payload) ~= "table" or type(payload.Payload) ~= "string" then return end
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, payload.Payload)
			if ok and type(decoded.slot) == "number" then
				self:_setEquipped(decoded.slot)
			end
		end), "Disconnect")
	end
	if BlinkClient.ToolUnequip then
		self.Janitor:Add(BlinkClient.ToolUnequip.On(function(payload)
			self:_setEquipped(nil)
		end), "Disconnect")
	end

	return self
end

function ToolManagerClient:_hotbarUI(): Frame
	return self.InventoryUI:FindFirstChild("Hotbar")
end

function ToolManagerClient:_invUI(): Frame
	return self.InventoryUI:FindFirstChild("Inventory")
end

function ToolManagerClient:_countEquipped(): number
	local n = 0
	for i = 1, MAX_TOOLS do
		if self.Storage.Hotbar[i] then n += 1 end
	end
	return n
end

function ToolManagerClient:_tbTargetWidth(showAll: boolean): number
	local n = showAll and MAX_TOOLS or math.max(1, self:_countEquipped())
	return n * self._slotW + (n - 1) * SLOT_GAP + TB_PADDING
end

function ToolManagerClient:_refreshSlot(i: number)
	local ref = self.SlotRefs[i]
	if not ref then return end
	local item = self.Storage.Hotbar[i]

	if ref.img then ref.img.Image = item and item.image or item and Tools[item.name].Image or "" end

	if ref.nameLabel then
		local qty = item and (item.qty or 1) or 0
		if item then
			if ref.qtyLabel then
				ref.nameLabel.Text = item.name
			else
				ref.nameLabel.Text = qty > 1 and (item.name .. " (" .. qty .. "x)") or item.name
			end
			ref.nameLabel.Visible = true
		else
			ref.nameLabel.Text = ""
			ref.nameLabel.Visible = false
		end
	end
	if ref.qtyLabel then
		local qty = item and (item.qty or 1) or 0
		ref.qtyLabel.Text = qty > 1 and (tostring(qty) .. "x") or ""
		ref.qtyLabel.Visible = qty > 1
	end
	if ref.keyLabel then ref.keyLabel.Text = tostring(i) end

	local isEquipped = self.Equipped == i and item ~= nil
	_tweenEquipGlow(ref, isEquipped)

	ref.frame.Visible = self.InventoryOpen or item ~= nil
end

function ToolManagerClient:_refreshAllSlots()
	for i = 1, MAX_TOOLS do
		self:_refreshSlot(i)
	end
	self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
end

function ToolManagerClient:_refreshInvCell(i: number)
	local cell = self.InvCells[i]
	if not cell then return end
	local item = self.Storage.Inventory[i]

	local img = cell:FindFirstChildOfClass("ImageLabel")
	local nameLabel = cell:FindFirstChildOfClass("TextLabel")
	local qtyFrame = cell:FindFirstChildOfClass("Frame")
	local qtyLabel = qtyFrame and qtyFrame:FindFirstChildOfClass("TextLabel")

	if img then img.Image = item and item.image or item and Tools[item.name].Image or "" end

	if nameLabel then
		nameLabel.Text = item and item.name or ""
		nameLabel.Visible = item ~= nil
	end
	if qtyLabel then qtyLabel.Text = item and tostring(item.qty) or "" end
	if qtyLabel then qtyLabel.Text = item and (tostring(item.qty) .. "x") or "" end
	if qtyFrame then qtyFrame.Visible = item ~= nil end

	cell.Visible = self.InventoryOpen or item ~= nil
end

function ToolManagerClient:_refreshCountLabel()
	local invUI = self:_invUI()
	local headerFrame = invUI:FindFirstChild("Frame")
	if not headerFrame then return end
	local innerFrame = headerFrame:FindFirstChild("Frame")
	if not innerFrame then return end
	for _, v in next, innerFrame:GetChildren() do
		if v:IsA("TextLabel") then
			v.Text = countFilled(self.Storage.Inventory) .. "/" .. MAX_INVENTORY_CAPACITY
			break
		end
	end
end

function ToolManagerClient:_getDropTarget(mp: Vector2): (string?, number?)
	local inset = GuiService:GetGuiInset()
	local screenPos = mp - inset

	local hits = self.PlayerGui:GetGuiObjectsAtPosition(screenPos.X, screenPos.Y)

	for _, obj in next, hits do
		if obj == self.DragState.ghost or (self.DragState.ghost and obj:IsDescendantOf(self.DragState.ghost)) then
			continue
		end

		for i = 1, MAX_TOOLS do
			local ref = self.SlotRefs[i]
			if ref and ref.frame.Visible and (obj == ref.frame or obj:IsDescendantOf(ref.frame)) then
				return "hotbar", i
			end
		end

		if self.InventoryOpen then
			for i = 1, MAX_INVENTORY_CAPACITY do
				local cell = self.InvCells[i]
				if cell and (obj == cell or obj:IsDescendantOf(cell)) then
					return "inventory", i
				end
			end
		end
	end

	return nil, nil
end

function ToolManagerClient:_buildHotbar()
	local hb = self:_hotbarUI()
	local inputFrame = hb:WaitForChild("input")
	local template = inputFrame:WaitForChild("Template")
	template.Visible = false

	for _, child in next, inputFrame:GetChildren() do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end
	self.SlotRefs = {}

	for i = 1, MAX_TOOLS do
		local slot = template:Clone()
		slot.Name = "Slot_" .. i
		slot.Visible = false
		slot.LayoutOrder = i
		slot.Parent = inputFrame

		local imgFrame = nil
		local keyFrame = nil
		for _, v in next, slot:GetChildren() do
			if v:IsA("Frame") then
				if v:FindFirstChildOfClass("ImageButton") then
					imgFrame = v
				else
					keyFrame = v
				end
			end
		end

		local img = imgFrame and imgFrame:FindFirstChildOfClass("ImageButton")
		local nameLabel = slot:FindFirstChildWhichIsA("TextLabel")
		local keyLabel = keyFrame and keyFrame:FindFirstChildOfClass("TextLabel")

		if nameLabel == keyLabel then
			nameLabel = nil
		end
		local qtyLabel = nil
		for _, tl in next, slot:GetDescendants() do
			if tl:IsA("TextLabel") and tl ~= nameLabel and tl ~= keyLabel then
				qtyLabel = tl
				break
			end
		end
		local stroke = slot:FindFirstChildOfClass("UIStroke")

		local glowFrame = Instance.new("Frame")
		glowFrame.Name = "Glow"
		glowFrame.Size = UDim2.new(1, 0, 1, 0)
		glowFrame.BackgroundColor3 = Color3.fromRGB(212, 175, 95)
		glowFrame.BackgroundTransparency = 1
		glowFrame.BorderSizePixel = 0
		glowFrame.ZIndex = slot.ZIndex + 1
		glowFrame.Visible = false
		local gc = Instance.new("UICorner")
		gc.CornerRadius = UDim.new(0, 8)
		gc.Parent = glowFrame

		local glowStroke = Instance.new("UIStroke")
		glowStroke.Color = Color3.fromRGB(212, 175, 95)
		glowStroke.Thickness = 0
		glowStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		glowStroke.Parent = glowFrame

		glowFrame.Parent = slot

		if keyLabel then keyLabel.Text = tostring(i) end

		self.SlotRefs[i] = {
			frame = slot;
			img = img;
			nameLabel = nameLabel;
			qtyLabel = qtyLabel;
			keyLabel = keyLabel;
			stroke = stroke;
			glowFrame = glowFrame;
			glowStroke = glowStroke;
		}

		local btn = slot:FindFirstChildOfClass("TextButton")
		if btn then
			self.Janitor:Add(btn.MouseButton1Click:Connect(function()
				if not self.DragState.active then
					self:_onHotbarClick(i)
				end
			end), "Disconnect")
			self.Janitor:Add(btn.MouseButton1Down:Connect(function()
				self:_queueDrag("hotbar", i)
			end), "Disconnect")
		end
	end

	task.defer(function()
		local ref = self.SlotRefs[1]
		if ref and ref.frame.AbsoluteSize.X > 0 then
			self._slotW = ref.frame.AbsoluteSize.X
		end
		local w = self:_tbTargetWidth(false)
		self._tbWidthSpring.p = w
		self._tbWidthSpring.t = w
		self:_refreshAllSlots()
	end)
end

function ToolManagerClient:_buildInventory()
	local invUI = self:_invUI()
	local scroll = invUI:WaitForChild("ScrollingFrame")
	local template = scroll:FindFirstChild("Frame")
	if not template then return end
	template.Visible = false

	for _, child in next, scroll:GetChildren() do
		if child:IsA("Frame") and child ~= template then
			child:Destroy()
		end
	end
	self.InvCells = {}

	for i = 1, MAX_INVENTORY_CAPACITY do
		local cell = template:Clone()
		cell.Name = "Cell_" .. i
		cell.Visible = false
		cell.LayoutOrder = i
		cell.Parent = scroll

		local nameLabel = cell:FindFirstChildOfClass("TextLabel")
		if nameLabel then nameLabel.Visible = false end

		local btn = cell:FindFirstChildOfClass("TextButton")
		if btn then
			self.Janitor:Add(btn.MouseButton1Click:Connect(function()
				if not self.DragState.active then
					self:_onInvClick(i)
				end
			end), "Disconnect")
			self.Janitor:Add(btn.MouseButton1Down:Connect(function()
				self:_queueDrag("inventory", i)
			end), "Disconnect")
		end

		self.InvCells[i] = cell
		self:_refreshInvCell(i)
	end

	self:_refreshCountLabel()

	task.defer(function()
		local invUI = self:_invUI()
		local sc = invUI:FindFirstChildOfClass("UISizeConstraint")
		local constraintH = sc and sc.MaxSize.Y > 0 and sc.MaxSize.Y or 0
		local measured = invUI.AbsoluteSize.Y > 10 and invUI.AbsoluteSize.Y or 0
		local scrollH = scroll.AbsoluteSize.Y > 0 and scroll.AbsoluteSize.Y or 0
		local maxH = math.max(measured, constraintH, scrollH, 450)
		self._invNativeHeight = maxH
		self._invNativeW = invUI.AbsoluteSize.X > 0 and invUI.AbsoluteSize.X or self._invNativeW
	end)
end

function ToolManagerClient:_onHotbarClick(i: number)
	if not self.Storage.Hotbar[i] then
		if self.Equipped == i then self:_setEquipped(nil) end
		return
	end
	if self.Equipped == i then
		self:_setEquipped(nil)
	else
		self:_setEquipped(i)
	end
end

function ToolManagerClient:_onInvClick(i: number)
	local item = self.Storage.Inventory[i]
	if not item then return end
	local existingSlot = nil
	for s = 1, MAX_TOOLS do
		if self.Storage.Hotbar[s] and self.Storage.Hotbar[s].name == item.name then
			existingSlot = s
			break
		end
	end
	local targetSlot = existingSlot or firstEmpty(self.Storage.Hotbar, MAX_TOOLS)
	if not targetSlot then return end

	if not existingSlot then
		self.Storage.Hotbar[targetSlot] = item
		self.Storage.Inventory[i] = nil
		self:_refreshInvCell(i)
		self:_refreshCountLabel()
	end

	self:_setEquipped(targetSlot, item.name)
	self:_refreshSlot(targetSlot)
	self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
	self.States.Changed:Fire()
end

function ToolManagerClient:_queueDrag(source: string, index: number)
	local item = source == "hotbar" and self.Storage.Hotbar[index] or self.Storage.Inventory[index]
	if not item then return end
	self.DragState.pending = true
	self.DragState.pendingSource = source
	self.DragState.pendingIndex = index
	self.DragState.pendingOrigin = UIS:GetMouseLocation()
end

function ToolManagerClient:_activateDrag()
	local ds = self.DragState
	local source = ds.pendingSource
	local index = ds.pendingIndex
	local sourceTbl = source == "hotbar" and self.Storage.Hotbar or self.Storage.Inventory
	local item = takeOne(sourceTbl, index)
	if not item then
		ds.pending = false
		return
	end

	local originFrame = source == "hotbar" and self.SlotRefs[index].frame or self.InvCells[index]
	local mp = UIS:GetMouseLocation()
	local sz = originFrame.AbsoluteSize

	local ghost = originFrame:Clone()
	ghost.Position = UDim2.fromOffset(mp.X - sz.X * .5, mp.Y - sz.Y * .5)
	ghost.Size = UDim2.fromOffset(sz.X, sz.Y)
	ghost.ZIndex = 100
	ghost.Visible = true
	ghost.Active = false
	for _, v in next, ghost:GetDescendants() do
		if v:IsA("TextButton") then v.Active = false end
		if v:IsA("GuiObject") then v.ZIndex = 100 end
	end

	local ghostGlow = ghost:FindFirstChild("Glow")
	if ghostGlow then ghostGlow:Destroy() end

	local ghostKeyFrame = nil
	for _, v in next, ghost:GetChildren() do
		if v:IsA("Frame") and not v:FindFirstChildOfClass("ImageButton") then
			ghostKeyFrame = v
			break
		end
	end
	if ghostKeyFrame then ghostKeyFrame.Visible = false end

	local ghostImg = ghost:FindFirstChildOfClass("ImageButton")
	if ghostImg then ghostImg.Image = item.image or (Tools[item.name] and Tools[item.name].Image) or "" end
	local ghostName = ghost:FindFirstChildWhichIsA("TextLabel")
	if ghostName then ghostName.Text = item.name or "" end
	for _, tl in next, ghost:GetDescendants() do
		if tl:IsA("TextLabel") and tl ~= ghostName then
			tl.Text = item.qty and item.qty > 1 and (tostring(item.qty) .. "x") or tl.Text
		end
	end

	ghost.Parent = self.InventoryUI

	ds.active = true
	ds.pending = false
	ds.ghost = ghost
	ds.source = source
	ds.index = index
	ds.item = item
	ds.pendingSource = nil
	ds.pendingIndex = nil
	ds.pendingOrigin = nil

	if source == "hotbar" then
		self:_refreshSlot(index)
	else
		self:_refreshInvCell(index)
		self:_refreshCountLabel()
	end
end

function ToolManagerClient:_endDrag()
	local ds = self.DragState
	ds.pending = false
	ds.pendingSource = nil
	ds.pendingIndex = nil
	ds.pendingOrigin = nil
	if not ds.active then return end

	local mp = UIS:GetMouseLocation()
	local targetSource, targetIndex = self:_getDropTarget(mp)
	local sourceTbl = ds.source == "hotbar" and self.Storage.Hotbar or self.Storage.Inventory

	if targetSource == "hotbar" and targetIndex then
		local dest = self.Storage.Hotbar
		local prev = mergeInto(dest, targetIndex, ds.item)
		if ds.source == "hotbar" then
			mergeInto(sourceTbl, ds.index, prev)
			if self.Equipped == ds.index and not sourceTbl[ds.index] then
				self:_setEquipped(nil)
			elseif self.Equipped == ds.index and targetIndex ~= ds.index then
				self:_setEquipped(targetIndex)
			end
			self:_refreshSlot(ds.index)
		else
			mergeInto(sourceTbl, ds.index, prev)
			self:_refreshInvCell(ds.index)
			self:_refreshCountLabel()
		end
		self:_refreshSlot(targetIndex)
		self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
		self.States.Changed:Fire()

	elseif targetSource == "inventory" and targetIndex then
		local dest = self.Storage.Inventory
		local prev = mergeInto(dest, targetIndex, ds.item)
		if ds.source == "inventory" then
			mergeInto(sourceTbl, ds.index, prev)
			self:_refreshInvCell(ds.index)
		else
			mergeInto(sourceTbl, ds.index, prev)
			if self.Equipped == ds.index then
				self:_setEquipped(nil)
			end
			self:_refreshSlot(ds.index)
			self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
		end
		self:_refreshInvCell(targetIndex)
		self:_refreshCountLabel()
		self.States.Changed:Fire()
	else
		-- return to source
		mergeInto(sourceTbl, ds.index, ds.item)
		if ds.source == "hotbar" then
			self:_refreshSlot(ds.index)
		else
			self:_refreshInvCell(ds.index)
			self:_refreshCountLabel()
		end
	end

	if ds.ghost then ds.ghost:Destroy() end
	self.DragState = {
		active = false; pending = false;
		pendingSource = nil; pendingIndex = nil; pendingOrigin = nil;
		ghost = nil; source = nil; index = nil; item = nil;
	}
	self:_refreshAllSlots()
end

function ToolManagerClient:_bindDrag()
	self.Janitor:Add(UIS.InputChanged:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local ds = self.DragState

		if ds.pending and ds.pendingOrigin then
			local mp = UIS:GetMouseLocation()
			local dx = mp.X - ds.pendingOrigin.X
			local dy = mp.Y - ds.pendingOrigin.Y
			if math.sqrt(dx*dx + dy*dy) >= DRAG_THRESHOLD then
				self:_activateDrag()
			end
		end

		if ds.active and ds.ghost then
			local mp = UIS:GetMouseLocation()
			local sz = ds.ghost.AbsoluteSize
			ds.ghost.Position = UDim2.fromOffset(mp.X - sz.X * .5, mp.Y - sz.Y * .5)
		end
	end), "Disconnect")

	self.Janitor:Add(UIS.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		self:_endDrag()
	end), "Disconnect")
end

function ToolManagerClient:_setInventoryOpen(open: boolean)
	self.InventoryOpen = open
	if open then
		self._tbWidthSpring.d = .7
		self._invHeightSpring.d = .7
	else
		self._tbWidthSpring.v = 0
		self._invHeightSpring.v = 0
		self._tbWidthSpring.d = 1
		self._invHeightSpring.d = 1
	end
	self._invHeightSpring.t = open and self._invNativeHeight or 0
	self._tbWidthSpring.t = self:_tbTargetWidth(open)
	local invUI = self:_invUI()
	if open then invUI.Visible = true end
	self:_refreshAllSlots()
	for i = 1, MAX_INVENTORY_CAPACITY do
		self:_refreshInvCell(i)
	end
end

function ToolManagerClient:_startLoop()
	local hb = self:_hotbarUI()
	local invUI = self:_invUI()

	local origInvSizeX = invUI.Size.X
	local origHbPosY = hb.Position.Y

	invUI.Visible = false
	invUI.ClipsDescendants = true
	invUI.Size = UDim2.new(origInvSizeX.Scale, origInvSizeX.Offset, 0, 0)
	hb.ClipsDescendants = true

	CentralHeartbeat:Bind(function()
		local tw = self._tbWidthSpring.p
		local ih = math.max(0, self._invHeightSpring.p)
		local hbSzY = hb.Size.Y

		hb.Size = UDim2.new(0, math.max(0, tw), hbSzY.Scale, hbSzY.Offset)
		hb.Position = UDim2.new(.5, -tw / 2, origHbPosY.Scale, origHbPosY.Offset)

		if self._invNativeW == 0 then
			self._invNativeW = invUI.AbsoluteSize.X
		end

		invUI.Size = UDim2.new(origInvSizeX.Scale, origInvSizeX.Offset, 0, ih)
		invUI.Position = UDim2.new(.5, -self._invNativeW / 2, 1, -(hb.AbsoluteSize.Y + ih + 60))

		if ih < 2 and not self.InventoryOpen then
			invUI.Visible = false
		else
			invUI.Visible = true
		end
	end, "ToolManagerLoop")

	self.Janitor:Add(function()
		CentralHeartbeat:Unbind(nil, "ToolManagerLoop")
	end)
end

function ToolManagerClient:_bindInputs()
	Input.AddClass("ToolManager")

	Input.AddBind("ToolManager", "ToggleInventory", Enum.KeyCode.Backquote, Enum.InputActionType.Direction1D, {
		OnStart = function()
			self:_setInventoryOpen(not self.InventoryOpen)
		end;
	})

	local keyCodes = {
		Enum.KeyCode.One;
		Enum.KeyCode.Two;
		Enum.KeyCode.Three;
		Enum.KeyCode.Four;
		Enum.KeyCode.Five;
		Enum.KeyCode.Six;
		Enum.KeyCode.Seven;
		Enum.KeyCode.Eight;
		Enum.KeyCode.Nine;
		Enum.KeyCode.Zero;
	}

	for i, kc in next, keyCodes do
		Input.AddBind("ToolManager", "HotbarSlot_" .. i, kc, Enum.InputActionType.Direction1D, {
			OnStart = function()
				self:_onHotbarClick(i)
			end;
		})
	end

	self.Janitor:Add(UIS.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if not self.Equipped then return end
		local item = self.Storage.Hotbar[self.Equipped]
		if not item then return end
		self._holding = true
		self.States.Activated:Fire(self.Equipped, item)
	end), "Disconnect")

	self.Janitor:Add(UIS.InputEnded:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		self._holding = false
	end), "Disconnect")

	CentralHeartbeat:Bind(function()
		if self._holding then
			local item = self.Equipped and self.Storage.Hotbar[self.Equipped]
			if item and Tools[item.name] and Tools[item.name].Holdable then
				self.States.Activated:Fire(self.Equipped, item)
			end
		end
	end, "ToolManagerHoldFire")

end

function ToolManagerClient:_setAds(on: boolean)
	if self._adsActive == on then return end
	self._adsActive = on
	local item = self.Equipped and self.Storage.Hotbar[self.Equipped]
	local name = item and item.name
	local tool = name and Tools[name]
	self.States.Ads:Fire(on, item, tool)
end

function ToolManagerClient:Give(name: string, qty: number?)
	local toolData = Tools[name]
	if not toolData then
		warn("ToolManagerClient: unknown tool", name)
		return
	end

	local item: Item = {
		name = name;
		image = toolData.Image;
		qty = qty or 1;
	}

	print(toolData.image)

	local slot = firstEmpty(self.Storage.Hotbar, MAX_TOOLS)
	if slot then
		self.Storage.Hotbar[slot] = item
		self:_refreshSlot(slot)
		self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
		self.States.Changed:Fire()
		return
	end

	local invSlot = firstEmpty(self.Storage.Inventory, MAX_INVENTORY_CAPACITY)
	if invSlot then
		self.Storage.Inventory[invSlot] = item
		self:_refreshInvCell(invSlot)
		self:_refreshCountLabel()
		self.States.Changed:Fire()
		return
	end

	warn("ToolManagerClient: no space for", name)
end

function ToolManagerClient:Remove(name: string)
	for i = 1, MAX_TOOLS do
		if self.Storage.Hotbar[i] and self.Storage.Hotbar[i].name == name then
			self.Storage.Hotbar[i] = nil
			if self.Equipped == i then
				self:_setEquipped(nil)
			end
			self:_refreshSlot(i)
			self._tbWidthSpring.t = self:_tbTargetWidth(self.InventoryOpen)
			self.States.Changed:Fire()
			return
		end
	end
	for i = 1, MAX_INVENTORY_CAPACITY do
		if self.Storage.Inventory[i] and self.Storage.Inventory[i].name == name then
			self.Storage.Inventory[i] = nil
			self:_refreshInvCell(i)
			self:_refreshCountLabel()
			self.States.Changed:Fire()
			return
		end
	end
end

function ToolManagerClient:Destroy()
	self.Janitor:Cleanup()
	Input.RemoveClass("ToolManager")
	self.States.Ads:Destroy()
	self.States.UnEquipped:Destroy()
	self.States.Activated:Destroy()
	self.States.Equipped:Destroy()
	self.States.Changed:Destroy()
end

return ToolManagerClient
