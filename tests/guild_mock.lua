-- Guild, weekly reset and addon messages (shared with the Bingo's tests): for the guild chronicle.
-- Each test client gets its own copy, and tests carry messages from one to the other.

MOCK.guild = { name = "Los Del Fondo", realm = "Forever" } -- nil: not in a guild
MOCK.trial = false
MOCK.sent = {} -- { prefix, text, chatType }
MOCK.chatSent = {} -- { text, chatType } from C_ChatInfo.SendChatMessage
MOCK.prefixes = {}
MOCK.sendResult = 0
MOCK.lockdown = false
MOCK.resetAt = 1762300800 -- 2025-11-05 00:00 UTC; tests move it
MOCK.inGroup = false
MOCK.guildmates = {} -- unit -> true
MOCK.onTaxi = false

function GetNormalizedRealmName()
	return MOCK.player.realm
end
function IsInGuild()
	return MOCK.guild ~= nil
end
function GetGuildInfo(unit)
	if unit == "player" and MOCK.guild then
		return MOCK.guild.name, "Miembro", 3, MOCK.guild.realm
	end
end
function GetServerTime()
	return MOCK.now
end
MOCK.realmOffset = 0 -- seconds the realm's clock is ahead of the computer's
C_DateAndTime = {
	GetCurrentCalendarTime = function()
		local t = date("*t", MOCK.now + MOCK.realmOffset)
		return { year = t.year, month = t.month, monthDay = t.day, weekday = t.wday, hour = t.hour, minute = t.min }
	end,
	GetSecondsUntilWeeklyReset = function()
		if not MOCK.resetAt then
			return nil
		end
		while MOCK.resetAt <= MOCK.now do -- the reset comes back every week, as in the game
			MOCK.resetAt = MOCK.resetAt + 7 * 86400
		end
		return MOCK.resetAt - MOCK.now
	end,
}
function IsTrialAccount()
	return MOCK.trial
end
function IsVeteranTrialAccount()
	return false
end
function Ambiguate(name, context)
	assert(context == "none" or context == "short" or context == "guild" or context == "all", "Ambiguate context")
	local short, realm = name:match("^(.-)%-(.+)$")
	if short and realm == MOCK.player.realm then
		return short
	end
	return name
end
function UnitIsInMyGuild(unit)
	return MOCK.guildmates[unit] == true
end
function UnitClassification(unit)
	return unit == "target" and MOCK.target and MOCK.target.classification or "normal"
end
function UnitOnTaxi(unit)
	return unit == "player" and MOCK.onTaxi
end
function IsInGroup()
	return MOCK.inGroup
end
function GameTooltip_Hide()
	GameTooltip:Hide()
end
SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON = 856
Enum.SendAddonMessageResult = {
	Success = 0,
	InvalidPrefix = 1,
	InvalidMessage = 2,
	AddonMessageThrottle = 3,
	InvalidChatType = 4,
	NotInGroup = 5,
	TargetRequired = 6,
	InvalidChannel = 7,
	ChannelThrottle = 8,
	GeneralError = 9,
	NotInGuild = 10,
	AddOnMessageLockdown = 11,
	TargetOffline = 12,
}
C_ChatInfo = {
	RegisterAddonMessagePrefix = function(prefix)
		assert(type(prefix) == "string" and #prefix > 0 and #prefix <= 16, "prefix is 1 to 16 characters")
		MOCK.prefixes[prefix] = true
		return 0
	end,
	SendAddonMessage = function(prefix, text, chatType, target)
		assert(MOCK.prefixes[prefix], "send with a registered prefix")
		assert(type(text) == "string" and #text <= 255, "addon messages are at most 255 bytes")
		if MOCK.sendResult == 0 then
			table.insert(MOCK.sent, { prefix = prefix, text = text, chatType = chatType or "PARTY", target = target })
		end
		return MOCK.sendResult
	end,
	InChatMessagingLockdown = function()
		return MOCK.lockdown
	end,
	SendChatMessage = function(text, chatType)
		table.insert(MOCK.chatSent, { text = text, chatType = chatType })
	end,
}

-- Encounter Journal: two dungeons and a raid. dungeonEncounterID is what ENCOUNTER_END gives.
MOCK.ej = {
	dungeons = {
		{ id = 63, name = "Deadmines", bosses = { { "Rhahk'Zor", 1001, 2741 }, { "Sneed", 1002, 2742 }, { "Edwin VanCleef", 1003, 2746 } } },
		{ id = 64, name = "Shadowfang Keep", bosses = { { "Arugal", 1101, 2750 } } },
	},
	raids = { { id = 760, name = "Onyxia's Lair", bosses = { { "Onyxia", 1201, 1084 } } } },
	selected = nil,
	tier = 1,
}
function EJ_GetCurrentTier()
	return MOCK.ej.tier
end
function EJ_SelectTier(t)
	MOCK.ej.tier = t
end
function EJ_GetInstanceByIndex(i, raid)
	local list = raid and MOCK.ej.raids or MOCK.ej.dungeons
	local inst = list[i]
	if inst then
		return inst.id, inst.name
	end
end
function EJ_SelectInstance(id)
	MOCK.ej.selected = id
	MOCK.ej.tier = 99 -- selecting moves the tier, as in the game: the addon has to put it back
end
local function findInstance(id)
	for _, list in ipairs({ MOCK.ej.dungeons, MOCK.ej.raids }) do
		for _, inst in ipairs(list) do
			if inst.id == id then
				return inst
			end
		end
	end
end
function EJ_GetEncounterInfoByIndex(j, instanceID)
	local inst = findInstance(instanceID or MOCK.ej.selected)
	local b = inst and inst.bosses[j]
	if b then
		return b[1], "", b[2]
	end
end
function EJ_GetEncounterInfo(bossID)
	for _, list in ipairs({ MOCK.ej.dungeons, MOCK.ej.raids }) do
		for _, inst in ipairs(list) do
			for _, b in ipairs(inst.bosses) do
				if b[2] == bossID then
					return b[1], "", b[2], 0, "", inst.id, b[3], 0
				end
			end
		end
	end
end

-- Achievements: categories { id, name, parent, total, done }
MOCK.categories = {
	{ 92, "General", -1, 10, 3 },
	{ 96, "Quests", -1, 20, 5 },
	{ 14861, "Eastern Kingdoms", 96, 8, 2 },
}
function GetCategoryList()
	local out = {}
	for i, c in ipairs(MOCK.categories) do
		out[i] = c[1]
	end
	return out
end
function GetCategoryInfo(id)
	for _, c in ipairs(MOCK.categories) do
		if c[1] == id then
			return c[2], c[3], 0
		end
	end
end
function GetCategoryNumAchievements(id, includeAll)
	assert(includeAll == true, "count every achievement of the category")
	for _, c in ipairs(MOCK.categories) do
		if c[1] == id then
			return c[4], c[5], c[4] - c[5]
		end
	end
	return 0, 0, 0
end
C_Item.GetItemNameByID = C_Item.GetItemNameByID or function(id)
	return MOCK.itemNamesByID and MOCK.itemNamesByID[id]
end

-- Guild ranks: MOCK.officer says whether you are one; MOCK.roster lists { "Name-Realm", rankIndex }.
MOCK.officer = false
MOCK.roster = { { "Josecito-Forever", 2 }, { "Ana-Forever", 2 }, { "Lider-Forever", 0 }, { "Ofi-Forever", 1 } }
MOCK.rosterRequests = 0
C_GuildInfo = {
	IsGuildOfficer = function()
		return MOCK.officer
	end,
	GuildRoster = function()
		MOCK.rosterRequests = MOCK.rosterRequests + 1
	end,
}
function GetNumGuildMembers()
	return #MOCK.roster
end
function GetGuildRosterInfo(i)
	local r = MOCK.roster[i]
	if r then
		return r[1], "Rank" .. r[2], r[2]
	end
end
