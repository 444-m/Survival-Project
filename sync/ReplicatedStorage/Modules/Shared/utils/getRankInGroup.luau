--!strict
local groupService = game:GetService("GroupService")

type rankInfo = {
	rank: number;
	role: string;
	inGroup: boolean;
}

local rankUtil = {}

function rankUtil.getRank(userId: number, groupId: number): rankInfo
	local ok, result = pcall(groupService.GetGroupsAsync, groupService, userId)

	if not ok then
		return {rank = 0; role = ""; inGroup = false}
	end

	for _, entry in next, result do
		if entry and entry.Id and entry.Id == groupId then
			return {rank = entry.Rank; role = entry.Role; inGroup = true}
		end
	end

	return {rank = 0; role = ""; inGroup = false}
end

function rankUtil.getRankFromPlayer(player: Player, groupId: number): rankInfo
	local ok, rank, role = pcall(function()
		return player:GetRankInGroup(groupId), player:GetRoleInGroup(groupId)
	end)

	if not ok then
		return {rank = 0; role = ""; inGroup = false}
	end

	return {rank = rank; role = role; inGroup = rank > 0}
end

function rankUtil.isRankOrAbove(userId: number, groupId: number, minRank: number): boolean
	return rankUtil.getRank(userId, groupId).rank >= minRank
end

function rankUtil.isRankOrBelow(userId: number, groupId: number, maxRank: number): boolean
	local rank = rankUtil.getRank(userId, groupId).rank
	return rank > 0 and rank <= maxRank
end

function rankUtil.isExactRank(userId: number, groupId: number, targetRank: number): boolean
	return rankUtil.getRank(userId, groupId).rank == targetRank
end

function rankUtil.isInGroup(userId: number, groupId: number): boolean
	return rankUtil.getRank(userId, groupId).inGroup
end

return table.freeze(rankUtil)