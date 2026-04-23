type roleEntry = {string}
type roles = {roleEntry}

local conch = require(game.ReplicatedStorage.Packages.Shared.conch_standalone)

local function registerRoles(roleList: roles)
	for _, entry in next, roleList do
		local role = entry[1]
		local permissions = {}
		for i = 2, #entry do
			permissions[i - 1] = entry[i]
		end
		conch.set_role_permissions(role, table.unpack(permissions))
	end
end

registerRoles(table.freeze({
	{"moderator"; "kick"; "ban"; "unban";};
}))

return nil
