local Ammo = {}
Ammo.__index = Ammo

function Ammo.new(ammo: number, reserve: number?)
    local self = setmetatable({}, Ammo)

    self.Reserve = reserve
    self.Ammo = ammo
    rawset(self, "MaxAmmo", ammo)

    local mt = getmetatable(self)
    if mt.__newindex == nil then
        mt.__newindex = function(t, k, v)
            if k == "MaxAmmo" then
                error(`attempt to assign to read-only field '{k}'`, 2)
            end
            rawset(t, k, v)
        end
    end

    return self
end

function Ammo:Fire(amount: number)
    if self.Ammo <= 0 then return end
    amount = amount or 1
    self.Ammo = math.max(self.Ammo - amount, 0)
end

function Ammo:Reload(amount: number)
    if not getmetatable(self) then return end
    if self.Ammo == self.MaxAmmo then return end
    if not self.Reserve or self.Reserve <= 0 then return end
    amount = amount or 1

    local drawn = math.min(amount, self.Reserve, self.MaxAmmo - self.Ammo)

    self.Ammo += drawn
    self.Reserve -= drawn
end

function Ammo:IsEmpty()
    return self.Ammo <= 0
end

function Ammo:IsFull()
    return self.Ammo == self.MaxAmmo
end

function Ammo:IsOutOfAmmo()
    return self.Ammo <= 0 and (not self.Reserve or self.Reserve <= 0)
end

function Ammo:AddReserve(amount: number)
    if not self.Reserve then return end
    self.Reserve = math.max(self.Reserve + amount, 0)
end

function Ammo:SetReserve(amount: number)
    if not self.Reserve then return end
    self.Reserve = math.max(amount, 0)
end

return Ammo
