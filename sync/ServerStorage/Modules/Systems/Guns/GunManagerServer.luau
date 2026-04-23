local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local Tools = require(ReplicatedStorage.Modules.Shared.Storage.Tools)
local Ammo = require(ReplicatedStorage.Modules.Shared.Systems.Guns.Components.Ammo)
local Signal = require(ReplicatedStorage.Packages.Shared.Signal)
local _ProjectileServer = require(script.Parent.Parent.Parent.Managers.ProjectileServer)
local _ProjectileShared = require(ReplicatedStorage.Modules.Shared.Systems.Guns.ProjectileShared)
local BulletHoles = require(ReplicatedStorage.Modules.Shared.Systems.Guns.Components.BulletHoles)
local DamageManagerServer = require(ServerStorage.Modules.Managers.DamageManagerServer)

local BlinkServer = Networking.Server

local GunManagerServer = {}
GunManagerServer.__index = GunManagerServer
GunManagerServer.Cache = {}
GunManagerServer.OnHit = require "./GunEvents"
	            .OnHit

local function clamp(n: number, max: number)
	return math.clamp(n, 0, max)
end 

type GunCallback = {
	fireCallback: (player: Player, ...any) -> ();
}

local Blood = require(ServerStorage.Modules.Systems.BloodServer)
local Guns: {[string]: GunCallback} = {} 
for _,v in next, script:GetChildren() do
	if v:IsA("ModuleScript") then
		Guns[v.Name] = require(v)
	end
end

function GunManagerServer.new(player: Player)
	if GunManagerServer.Cache[player] then
		return GunManagerServer.Cache[player]
	end
	local self = setmetatable({}, GunManagerServer)
	self.Player = player
	self.Guns = {} :: {[string]: {Name: string, AmmoPool: typeof(Ammo.new(1,1))}}
	
	GunManagerServer.OnHit:Connect(function(hit)
		local result: RaycastResult = hit.result
		if not result then return end

		local instance = result.Instance
		local parentModel = instance:FindFirstAncestorOfClass("Model")
		local def = hit.def

		if parentModel and parentModel:FindFirstChildOfClass("Humanoid") then
			Blood.Splat(result.Position, result.Normal)

			local humanoid = parentModel:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end

			local victimPlayer = Players:GetPlayerFromCharacter(parentModel)
			if victimPlayer and victimPlayer == hit.player then return end
			if not def or not def.Damage then return end

			local isHeadshot = instance.Name == "Head"
			local distance = (result.Position - hit.payload.Origin).Magnitude
			local dmg = def.Damage
			local falloff = 1

			if distance > dmg.FalloffStart then
				local t = math.clamp((distance - dmg.FalloffStart) / (dmg.FalloffEnd - dmg.FalloffStart), 0, 1)
				falloff = 1 - t
			end

			local final = math.max(dmg.Base * falloff * (isHeadshot and dmg.HeadshotMultiplier or 1), dmg.Min)

			local target = victimPlayer or parentModel
			DamageManagerServer.Damage(hit.player, target, {
				Amount = final;
				Type = isHeadshot and "Headshot" or "Bullet";
				Delayed = true;
				DrainRate = 120;
			})

			BulletHoles.SpawnBlood(result, _ProjectileShared.Revolver.HitBulletHoleImage)
		else
			BulletHoles.SpawnWall(result, _ProjectileShared.Revolver.BulletHoleImage, _ProjectileShared.Revolver)
		end
	end)

	GunManagerServer.Cache[player] = self
	return self
end

function GunManagerServer.get(player: Player?)
	if not player then return nil end
	return GunManagerServer.Cache[player] or GunManagerServer.new(player)
end

function GunManagerServer:_base(name: string)
	local data = Tools[name]
	local ammo = data and (data.MaxAmmo or data.Ammo) or 1
	local reserve = data and data.Reserve or ammo * 4
	return ammo, reserve
end

function GunManagerServer:_ensure(name: string)
	local gun = self.Guns[name]
	if not gun then
		local ammo, reserve = self:_base(name)
		gun = {
			Name = name;
			AmmoPool = Ammo.new(ammo, reserve);
		}
		self.Guns[name] = gun
		self:Sync(name)
	end
	return gun
end

function GunManagerServer:Sync(name: string)
	if not BlinkServer or not BlinkServer.GunAmmo or not BlinkServer.GunAmmo.Fire then return end
	local gun = self.Guns[name]
	if not gun then return end
	local pool = gun.AmmoPool
	BlinkServer.GunAmmo.Fire(self.Player, {
		Name = name;
		Ammo = pool.Ammo;
		Reserve = pool.Reserve or 0;
		MaxAmmo = pool.MaxAmmo;
	})
end

function GunManagerServer:Fire(name: string, amount: number?, data)
	if not getmetatable(self) then return end
	
	local gun = self:_ensure(name)
	if gun.AmmoPool:IsOutOfAmmo() or gun.AmmoPool:IsEmpty() then
		self:Sync(name)
		return false, "NoAmmo", gun.AmmoPool
	end
	
	if gun and Guns[name] and Guns[name].fireCallback and self.Player then
		Guns[name].fireCallback(self.Player, data)
	end
	
	gun.AmmoPool:Fire(amount or 1)
	self:Sync(name)
	return true, "Fired", gun.AmmoPool
end

function GunManagerServer:Reload(name: string, amount: number?)
	local gun = self:_ensure(name)
	gun.AmmoPool:Reload(amount or gun.AmmoPool.MaxAmmo)
	self:Sync(name)
end

function GunManagerServer:SetReserve(name: string, amount: number)
	local gun = self:_ensure(name)
	gun.AmmoPool:SetReserve(amount)
	self:Sync(name)
end

function GunManagerServer:AddReserve(name: string, amount: number)
	local gun = self:_ensure(name)
	gun.AmmoPool:AddReserve(amount)
	self:Sync(name)
end

function GunManagerServer:SetAmmo(name: string, amount: number)
	local gun = self:_ensure(name)
	gun.AmmoPool.Ammo = clamp(amount, gun.AmmoPool.MaxAmmo)
	self:Sync(name)
end

function GunManagerServer:ApplyCommand(payload)
	if type(payload) ~= "table" then return end
	local name = payload.Name
	if type(name) ~= "string" then return end
	local action = payload.Action
	local value = payload.Value
	if action == "SetReserve" then
		self:SetReserve(name, value or 0)
	elseif action == "AddReserve" then
		self:AddReserve(name, value or 0)
	elseif action == "Reload" then
		self:Reload(name, value)
	elseif action == "SetAmmo" then
		self:SetAmmo(name, value or 0)
	end
end

if BlinkServer and BlinkServer.GunCommand and BlinkServer.GunCommand.On then
	BlinkServer.GunCommand.On(function(player: Player, payload)
		local mgr = GunManagerServer.get(player)
		if not mgr then return end
		mgr:ApplyCommand(payload)
	end)
end

Players.PlayerRemoving:Connect(function(player)
	GunManagerServer.Cache[player] = nil
end)

return GunManagerServer
