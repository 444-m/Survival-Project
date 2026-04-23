local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Networking = require(ReplicatedStorage.Modules.Shared.Networking)

local Tools = require(ReplicatedStorage.Modules.Shared.Storage.Tools)
local Ammo = require(ReplicatedStorage.Modules.Shared.Systems.Guns.Components.Ammo)

local Signal = require(ReplicatedStorage.Packages.Shared.Signal)
local Janitor = require(ReplicatedStorage.Packages.Shared.Janitor)
local Promise = require(ReplicatedStorage.Modules.Client.Systems.CameraShake.Promise)

local BlinkClient = Networking.Client

local GunManager = {}
GunManager.__index = GunManager

type GunState = {
	Name: string;
	AmmoPool: typeof(Ammo.new(1, 1));
	Reloading: boolean?;
	Cycle: number?;
	CycleCount: number;
}

local defaultManager: GunManager?

local function clamp(n: number, max: number)
	return math.clamp(n, 0, max)
end

function GunManager.new()
	local self = setmetatable({}, GunManager)
	self.Guns = {} :: {[string]: GunState}
	self.Current = nil :: GunState?
	self.ReloadingSignal = Signal()
	self.ReloadTick = Signal()
	self.ReloadCommit = Signal()
	self.ReloadJanitors = {}
	self.AmmoSignal = Signal()
	if BlinkClient and BlinkClient.GunAmmo and BlinkClient.GunAmmo.On then
		BlinkClient.GunAmmo.On(function(payload)
			self:_applySync(payload)
		end)
	end
	return self
end

function GunManager.Get(): GunManager
	defaultManager = defaultManager or GunManager.new()
	return defaultManager
end

function GunManager:_baseConfig(name: string)
	local data = Tools[name]
	if not data or not data.Ammo then
		return nil, nil, nil
	end
	local ammo = (data.MaxAmmo or data.Ammo) or 1
	local reserve = data.Reserve or ammo * 4
	local cycles = data.CycleReloads or 1
	return ammo, reserve, cycles
end

function GunManager:_ensure(name: string): GunState
	local gun = self.Guns[name]
	if not gun then
		local ammo, reserve, cycles = self:_baseConfig(name)
		if not ammo then
			return nil
		end
		gun = {
			Name = name;
			AmmoPool = Ammo.new(ammo, reserve);
			Reloading = false;
			Cycle = 0;
			CycleCount = cycles or 1;
		}
		self.Guns[name] = gun
	end
	return gun
end

function GunManager:SetCurrent(name: string?)
	if not name then
		self.Current = nil
		return
	end
	self.Current = self:_ensure(name)
end

function GunManager:GetState(name: string)
	local gun = self:_ensure(name)
	return gun and gun.AmmoPool or nil
end

function GunManager:Shoot(name: string, amount: number?)
	local gun = self:_ensure(name)
	if not gun then
		return false, "NotAGun", nil
	end
	if gun.Reloading then
		return false, "Reloading", gun.AmmoPool
	end
	if gun.AmmoPool:IsOutOfAmmo() or gun.AmmoPool:IsEmpty() then
		return false, "NoAmmo", gun.AmmoPool
	end
	gun.AmmoPool:Fire(amount or 1)
	self.AmmoSignal:Fire(name, gun.AmmoPool)
	return true, "Fired", gun.AmmoPool
end

function GunManager:Reload(name: string, amount: number?)
	local gun = self:_ensure(name)
	if not gun then return end
	if gun.Reloading then return end
	if gun.AmmoPool:IsFull() then return end
	if not gun.AmmoPool.Reserve or gun.AmmoPool.Reserve <= 0 then return end
	gun.Reloading = true
	gun.Cycle = 0
	self.ReloadingSignal:Fire(name, true)
	local jan = self.ReloadJanitors[name] or Janitor.new()
	jan:Cleanup()
	self.ReloadJanitors[name] = jan
	task.spawn(function()
		while gun.Reloading and not gun.AmmoPool:IsFull() and gun.AmmoPool.Reserve and gun.AmmoPool.Reserve > 0 do
			gun.Cycle = ((gun.Cycle or 0) % (gun.CycleCount or 1)) + 1
			self.ReloadTick:Fire(name, gun.Cycle)
			local commitPromise = Promise.new(function(resolve)
				local timeout = task.delay(1.2, function()
					resolve(false)
				end)
				local conn
				conn = self.ReloadCommit:Connect(function(commitName: string)
					if commitName ~= name then return end
					if conn then conn:Disconnect() end
					if timeout then task.cancel(timeout) end
					resolve(true)
				end)
				jan:Add(conn, "Disconnect")
			end)

			local committed = commitPromise:await()
			if not gun.Reloading then break end
			if not committed then
				break
			end

			if BlinkClient and BlinkClient.GunCommand and BlinkClient.GunCommand.Fire then
				BlinkClient.GunCommand.Fire({
					Name = name;
					Action = "Reload";
					Value = amount or 1;
				})
			end
			gun.AmmoPool:Reload(amount or 1)
			if gun.AmmoPool:IsFull() or (gun.AmmoPool.Reserve or 0) <= 0 then
				break
			end
			self.AmmoSignal:Fire(name, gun.AmmoPool)
			task.wait(0.45)
		end
	gun.Reloading = false
	gun.Cycle = 0
	jan:Cleanup()
	self.AmmoSignal:Fire(name, gun.AmmoPool)
	self.ReloadingSignal:Fire(name, false)
	end)
end

function GunManager:SetReserve(name: string, amount: number)
	if BlinkClient and BlinkClient.GunCommand and BlinkClient.GunCommand.Fire then
		BlinkClient.GunCommand.Fire({
			Name = name;
			Action = "SetReserve";
			Value = amount;
		})
	end
end

function GunManager:AddReserve(name: string, amount: number)
	if BlinkClient and BlinkClient.GunCommand and BlinkClient.GunCommand.Fire then
		BlinkClient.GunCommand.Fire({
			Name = name;
			Action = "AddReserve";
			Value = amount;
		})
	end
end

function GunManager:SetAmmo(name: string, amount: number)
	if BlinkClient and BlinkClient.GunCommand and BlinkClient.GunCommand.Fire then
		BlinkClient.GunCommand.Fire({
			Name = name;
			Action = "SetAmmo";
			Value = amount;
		})
	end
end

function GunManager:_applySync(payload)
	if type(payload) ~= "table" then return end
	local name = payload.Name
	local ammo = payload.Ammo
	local reserve = payload.Reserve
	local maxAmmo = payload.MaxAmmo
	if type(name) ~= "string" then return end
	local gun = self:_ensure(name)
	local pool = gun.AmmoPool

	if type(maxAmmo) == "number" and maxAmmo > 0 and maxAmmo ~= pool.MaxAmmo then
		local newPool = Ammo.new(maxAmmo, reserve or pool.Reserve)
		newPool.Ammo = math.min(ammo or pool.Ammo, maxAmmo)
		gun.AmmoPool = newPool
		pool = newPool
	end

	if type(ammo) == "number" then
		pool.Ammo = clamp(ammo, pool.MaxAmmo)
	end
	if type(reserve) == "number" then
		pool.Reserve = math.max(reserve, 0)
	end
	self.AmmoSignal:Fire(name, pool)
end

function GunManager:CancelReload(name: string?)
	if name then
		local gun = self.Guns[name]
		if gun then
			gun.Reloading = false
		end
	else
		for _, gun in next, self.Guns do
			gun.Reloading = false
			gun.Cycle = 0
		end
	end
	for _, jan in next, self.ReloadJanitors do
		jan:Cleanup()
	end
	self.ReloadingSignal:Fire(name, false)
end

function GunManager:IsReloading(name: string)
	local gun = self.Guns[name]
	return gun and gun.Reloading or false
end

return GunManager
