local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Globals = require(ReplicatedStorage.Modules.Shared.Globals)
local Networking = require(ReplicatedStorage.Modules.Shared.Networking)
local getRankInGroup = require(ReplicatedStorage.Modules.Shared.utils.getRankInGroup)
local conch = require(ReplicatedStorage.Packages.Shared.conch_standalone)

local admin = {}

function admin.setup(player: Player)
    local groupRank = getRankInGroup.getRank(player.UserId, Globals.GroupId).rank

    if groupRank >= Globals.MinAdminRank then
        if groupRank >= Globals.SuperUserRank then
            conch.give_roles(conch.get_user(player), "super-user")
        end

        Networking.Server.ConchInit.Fire(player, {Active = true})
    end
end

return admin
