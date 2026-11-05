local ADDON, ns = ...
local L = ns.L

-- Guild reminders: an officer writes "Thursday 19:45, raid night: bring flasks" and it pops up for everyone in
-- the guild who has the addon. Only officers (guild rank 0 or 1, checked in the roster) can send them.
--
-- The time travels as an absolute moment (server epoch), so it pops at the same instant for everyone whatever
-- their time zone, and is shown in each player's own local time. Messages, plain text:
--   A|1|<id>|<at>|<every>|<text>   a reminder: first time, then every <every> seconds (0 = once, 86400, 604800)
--   X|1|<id>                       the officer deleted it
--   Q|1                            "send me the guild's reminders"
--   W|1|<text>                     a reminder for one person, whispered: only taken from guildmates and friends
-- What arrives is parsed with patterns; the text loses "|" (the game's escape character) and control
-- characters and is cut to 120 bytes. Nothing received is run.

local G = {}
ns.GuildReminders = G

G.PREFIX = "BitacoraAviso1"
local MAX_TEXT, MAX_KEEP = 120, 50
local WINDOW, PER_WINDOW = 30, 20
local PERIODS = { [0] = true, [86400] = true, [604800] = true }

local function guildKey()
	if not IsInGuild() or (ns.db and ns.db.settings.guildReminders == false) then
		return nil
	end
	local guild, _, _, realm = GetGuildInfo("player")
	if not guild or issecretvalue(guild) or guild == "" then
		return nil
	end
	return guild .. "-" .. (realm or GetNormalizedRealmName() or "")
end

function G.IsTrial()
	return (IsTrialAccount and IsTrialAccount()) or (IsVeteranTrialAccount and IsVeteranTrialAccount()) or false
end

function G.IAmOfficer()
	return guildKey() ~= nil and C_GuildInfo.IsGuildOfficer() == true and not G.IsTrial()
end

function G.IsOfficer(sender)
	for i = 1, GetNumGuildMembers() or 0 do
		local name, _, rankIndex = GetGuildRosterInfo(i)
		if name and not issecretvalue(name) and Ambiguate(name, "none") == sender then
			return type(rankIndex) == "number" and rankIndex <= 1
		end
	end
	C_GuildInfo.GuildRoster()
	return false
end

function G.Clean(text)
	if type(text) ~= "string" then
		return nil
	end
	text = strtrim((text:gsub("|", ""):gsub("%c", " ")))
	local out, n = {}, 0
	for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
		if n + #ch > MAX_TEXT then
			break
		end
		out[#out + 1] = ch
		n = n + #ch
	end
	text = table.concat(out)
	return text ~= "" and text or nil
end

-- This guild's reminders: id -> { by, at, every, text, t }.
function G.List()
	local key = guildKey()
	if not key then
		return {}
	end
	ns.db.guildReminders = ns.db.guildReminders or {}
	ns.db.guildReminders[key] = ns.db.guildReminders[key] or {}
	return ns.db.guildReminders[key]
end

-- Sorted for the list: { { id, by, at, every, text, next } }, the next one first.
function G.Sorted(now)
	now = now or GetServerTime()
	local out = {}
	for id, r in pairs(G.List()) do
		local nextAt = r.at
		if r.every > 0 and nextAt < now then
			nextAt = r.at + math.ceil((now - r.at) / r.every) * r.every
		end
		if r.every > 0 or r.at >= now - 3600 then
			out[#out + 1] = { id = id, by = r.by, at = r.at, every = r.every, text = r.text, next = nextAt }
		end
	end
	table.sort(out, function(a, b)
		return a.next < b.next
	end)
	return out
end

local SUCCESS = Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
local function send(text)
	if not guildKey() or G.IsTrial() then
		return false
	end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		C_Timer.After(20, function()
			send(text)
		end)
		return false
	end
	local r = C_ChatInfo.SendAddonMessage(G.PREFIX, text, "GUILD")
	return r == nil or r == SUCCESS
end

local function message(id, r)
	return table.concat({ "A", 1, id, r.at, r.every, r.text }, "|")
end

-- An officer creates one. at: server epoch of the first time; every: 0, 86400 or 604800.
function G.Create(text, at, every)
	if not G.IAmOfficer() then
		return nil
	end
	text = G.Clean(text)
	at, every = tonumber(at), tonumber(every) or 0
	if not text or not at or not PERIODS[every] then
		return nil
	end
	local id = string.format("%x", (GetServerTime() * 1000 + math.random(0, 999)) % 4294967296)
	local r = { by = UnitName("player"), at = math.floor(at), every = every, text = text, t = time() }
	G.List()[id] = r
	send(message(id, r))
	ns.Fire("reminders")
	return id
end

function G.Delete(id)
	local r = G.List()[id]
	if not r or r.by ~= UnitName("player") then
		return false
	end
	G.List()[id] = nil
	send("X|1|" .. id)
	ns.Fire("reminders")
	return true
end

-- Given a local weekday (0 = every day, 1 = Sunday) and an hour, the next such moment as server epoch.
function G.NextAt(wday, hour, min, now)
	now = now or time()
	local t = date("*t", now)
	for ahead = 0, 7 do
		local cand = time({ year = t.year, month = t.month, day = t.day + ahead, hour = hour, min = min, sec = 0 })
		if cand > now and (wday == 0 or date("*t", cand).wday == wday) then
			-- local clock to server clock: the same instant
			return cand + (GetServerTime() - time())
		end
	end
end

-- Pop up the ones due (within 10 minutes, or 6 hours when logging in), once per character and time.
-- If this addon is Recordame and Bitácora's reminders are loaded too, Bitácora shows them: no double alert.
function G.Check(event)
	if ADDON == "Recordame" and (C_AddOns.IsAddOnLoaded("Bitacora") or C_AddOns.IsAddOnLoaded("Bitacora_Recordatorios")) then
		return {}
	end
	local now = GetServerTime()
	local window = event == "login" and 6 * 3600 or 600
	local char = ns.Char()
	char.guildFired = char.guildFired or {}
	local fired = {}
	for id, r in pairs(G.List()) do
		local due = r.at
		if r.every > 0 and now > r.at then
			due = r.at + math.floor((now - r.at) / r.every) * r.every
		end
		if due <= now and now - due <= window and (char.guildFired[id] or 0) < due then
			char.guildFired[id] = due
			ns.Alert(L.GUILD_REMINDER_FIRED:format(r.by, r.text))
			fired[#fired + 1] = id
		end
	end
	return fired
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

local lastReply = 0
function G.OnAddonMessage(prefix, text, channel, sender)
	if prefix ~= G.PREFIX or (channel ~= "GUILD" and channel ~= "WHISPER") then
		return
	end
	if issecretvalue(text) or issecretvalue(sender) or type(text) ~= "string" or type(sender) ~= "string" then
		return
	end
	if #text > 200 or #sender > 64 then
		return
	end
	sender = Ambiguate(sender, "none")
	if sender == UnitName("player") or not allowed(sender) then
		return
	end
	if channel == "WHISPER" then
		local body = text:match("^W|1|(.+)$")
		if body then
			G.OnWhisper(sender, body)
		end
		return
	end
	if text == "Q|1" then
		-- officers send back the reminders they wrote, once in a while
		if time() - lastReply >= 30 then
			local mine = {}
			for id, r in pairs(G.List()) do
				if r.by == UnitName("player") then
					mine[#mine + 1] = message(id, r)
				end
			end
			if #mine > 0 then
				lastReply = time()
				for i, m in ipairs(mine) do
					C_Timer.After(1 + 0.4 * i, function()
						send(m)
					end)
				end
			end
		end
		return
	end
	local kind, id, rest = text:match("^([AX])|1|(%x+)|?(.*)$")
	if not kind or #id > 12 or not G.IsOfficer(sender) then
		return
	end
	local list = G.List()
	if kind == "X" then
		if rest == "" and list[id] and list[id].by == sender then
			list[id] = nil
			ns.Fire("reminders")
		end
		return
	end
	local at, every, body = rest:match("^(%d+)|(%d+)|(.+)$")
	at, every = tonumber(at), tonumber(every)
	body = G.Clean(body)
	if not at or not PERIODS[every] or not body then
		return
	end
	if not list[id] then
		local n = 0
		for _ in pairs(list) do
			n = n + 1
		end
		if n >= MAX_KEEP then
			return
		end
	end
	list[id] = { by = sender, at = at, every = every, text = body, t = time() }
	ns.Fire("reminders")
end

function G.Ask()
	return send("Q|1")
end

-- Whispered reminders ---------------------------------------------------------------------------
-- "/recordame a Pepito: traé agua": the text goes to Pepito as an addon message on the whisper channel and
-- rings on his side right away (he is online, or the game says he is not). Only guildmates and friends
-- are listened to; anyone else is ignored without a word.

local TARGET_OFFLINE = Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.TargetOffline or 12
local NOT_IN_GROUP = Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.NotInGroup or 7

function G.IsFriend(sender)
	if not sender or sender == "" then
		return false
	end
	if C_FriendList and C_FriendList.GetFriendInfo then
		local info = C_FriendList.GetFriendInfo(sender)
		if type(info) == "table" and ns.Plain(info.name) then
			return true
		end
	end
	for i = 1, (C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetNumFriends()) or 0 do
		local info = C_FriendList.GetFriendInfoByIndex and C_FriendList.GetFriendInfoByIndex(i)
		local name = info and ns.Plain(info.name)
		if type(name) == "string" and Ambiguate(name, "none") == sender then
			return true
		end
	end
	return false
end

function G.IsGuildmate(sender)
	if not IsInGuild() then
		return false
	end
	for i = 1, GetNumGuildMembers() or 0 do
		local name = GetGuildRosterInfo(i)
		if name and not issecretvalue(name) and Ambiguate(name, "none") == sender then
			return true
		end
	end
	return false
end

-- "Name: text" or "Name text" -> name, text
function G.ParseWhisper(rest)
	rest = ns.Trim(rest)
	local name, text = rest:match("^([^%s:]+)%s*:%s*(.+)$")
	if not name then
		name, text = rest:match("^(%S+)%s+(.+)$")
	end
	if not name or not text then
		return nil
	end
	return name, text
end

function G.Whisper(target, text)
	text = G.Clean(text)
	target = ns.Trim(target)
	if not text or target == "" or G.IsTrial() then
		return false, L.WHISPER_CANNOT
	end
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		return false, L.WHISPER_CANNOT
	end
	local r = C_ChatInfo.SendAddonMessage(G.PREFIX, "W|1|" .. text, "WHISPER", target)
	if r == TARGET_OFFLINE or r == NOT_IN_GROUP then
		return false, L.WHISPER_OFFLINE:format(target)
	end
	if r ~= nil and r ~= SUCCESS then
		return false, L.WHISPER_CANNOT
	end
	return true, L.WHISPER_SENT:format(target)
end

-- A whispered reminder arrives: kept as a one-time reminder (so it shows in the list) and rung now.
function G.OnWhisper(sender, body)
	if not ns.Reminders or not (G.IsGuildmate(sender) or G.IsFriend(sender)) then
		return nil
	end
	body = G.Clean(body)
	if not body then
		return nil
	end
	local r = ns.Reminders.Create({ text = L.WHISPER_FROM:format(sender, body), kind = "login" })
	if r then
		r.done, r.fired, r.from = true, time(), sender
		ns.Alert(L.REMINDER_FIRED:format(r.text))
		ns.Fire("reminders")
	end
	return r
end

C_ChatInfo.RegisterAddonMessagePrefix(G.PREFIX)
