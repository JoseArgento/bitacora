local _, ns = ...
local L = ns.L

-- The guild chronicle: off unless you turn it on. When on, your milestones (every 10 levels and the last
-- one, first boss kills, achievements, loot of your chosen quality) go to the guild as addon messages, and
-- the milestones of guildmates who have Bitácora are kept here.
--
-- One message, plain text: M|1|<kind>|<number>[|<name>]
--   kind: level (number = level), boss (number = encounter ID, name = boss name), achievement (achievement ID),
--         loot (item ID), start
-- What arrives is only parsed with patterns and turned into text with our own strings: achievement and item
-- names are looked up in our own client from the ID, and the only free text, a boss name, has every "|"
-- (the game's escape character for colors and links) removed and is cut to 40 characters. Nothing received is run.

local C = {}
ns.Chronicle = C

C.PREFIX = "BitacoraCron1"
local MAX_LEN, KEEP, WINDOW, PER_WINDOW = 120, 300, 10, 5
local MAX_LEVEL = 60

local function guildKey()
	if not IsInGuild() then
		return nil
	end
	local guild, _, _, realm = GetGuildInfo("player")
	if not guild or issecretvalue(guild) or guild == "" then
		return nil
	end
	return guild .. "-" .. (realm or GetNormalizedRealmName() or "")
end

function C.IsTrial()
	return (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount()) or false
end

function C.Enabled()
	return ns.db and ns.db.settings.chronicle == true
end

function C.Entries()
	local key = guildKey()
	if not key then
		return {}
	end
	ns.db.guild = ns.db.guild or {}
	ns.db.guild[key] = ns.db.guild[key] or {}
	return ns.db.guild[key]
end

function C.Clean(name)
	if type(name) ~= "string" then
		return nil
	end
	name = name:gsub("|", ""):gsub("[%c]", "")
	if #name > 40 then
		name = name:sub(1, 40)
	end
	return name ~= "" and name or nil
end

local SUCCESS = Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
local function send(text)
	if not C.Enabled() or not guildKey() or C.IsTrial() then
		return false
	end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		C_Timer.After(20, function()
			send(text)
		end)
		return false
	end
	local result = C_ChatInfo.SendAddonMessage(C.PREFIX, text, "GUILD")
	return result == nil or result == SUCCESS
end

-- A journal entry: is it a milestone to share?
function C.OnJournal(e)
	if not C.Enabled() or type(e) ~= "table" then
		return
	end
	local msg
	if e.kind == "level" and e.level and (e.level % 10 == 0 or e.level == MAX_LEVEL) then
		msg = "M|1|level|" .. e.level
	elseif e.kind == "boss" and e.first and e.boss then
		msg = "M|1|boss|" .. e.boss .. "|" .. (C.Clean(e.name) or "")
	elseif e.kind == "achievement" and e.achievement then
		msg = "M|1|achievement|" .. e.achievement
	elseif e.kind == "loot" and e.item then
		msg = "M|1|loot|" .. e.item
	elseif e.kind == "start" then
		msg = "M|1|start|0"
	end
	if msg then
		send(msg)
	end
end

local rate = {}
local function allowed(sender)
	local now = time()
	local r = rate[sender]
	if not r or now - r.t >= WINDOW then
		r = { t = now, n = 0 }
		rate[sender] = r
	end
	r.n = r.n + 1
	return r.n <= PER_WINDOW
end

local KINDS = { level = true, boss = true, achievement = true, loot = true, start = true }

function C.OnAddonMessage(prefix, text, channel, sender)
	if prefix ~= C.PREFIX or channel ~= "GUILD" then
		return
	end
	if issecretvalue(text) or issecretvalue(sender) or type(text) ~= "string" or type(sender) ~= "string" then
		return
	end
	if #text > MAX_LEN or #sender > 64 then
		return
	end
	sender = Ambiguate(sender, "none")
	if sender == UnitName("player") or not allowed(sender) then
		return
	end
	local kind, number, name = text:match("^M|1|(%a+)|(%d+)|?(.*)$")
	number = tonumber(number)
	if not kind or not KINDS[kind] or not number or number > 2 ^ 31 then
		return
	end
	if kind == "level" and (number < 1 or number > MAX_LEVEL) then
		return
	end
	local list = C.Entries()
	table.insert(list, { who = sender, kind = kind, n = number, name = kind == "boss" and C.Clean(name) or nil, t = time() })
	while #list > KEEP do
		table.remove(list, 1)
	end
	ns.Fire("chronicle")
end

-- What an entry says, built from our own strings.
function C.Describe(e)
	if e.kind == "level" then
		return L.CHRON_LEVEL:format(e.who, e.n)
	elseif e.kind == "boss" then
		return L.CHRON_BOSS:format(e.who, e.name or ("#" .. e.n))
	elseif e.kind == "achievement" then
		local _, name = GetAchievementInfo(e.n)
		return L.CHRON_ACHIEVEMENT:format(e.who, name or ("#" .. e.n))
	elseif e.kind == "loot" then
		local name = C_Item.GetItemNameByID(e.n)
		return L.CHRON_LOOT:format(e.who, name or ("#" .. e.n))
	elseif e.kind == "start" then
		return L.CHRON_START:format(e.who)
	end
	return ""
end

-- Why the list may be empty or one-sided, for the tab.
function C.Status()
	if not C.Enabled() then
		return L.CHRON_OFF
	elseif not guildKey() then
		return L.CHRON_NO_GUILD
	elseif C.IsTrial() then
		return L.CHRON_TRIAL
	end
end

ns.On("journal", C.OnJournal)
C_ChatInfo.RegisterAddonMessagePrefix(C.PREFIX)
