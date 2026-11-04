local ADDON, ns = ...
local L = ns.L

-- Center-screen alert + chat line + sound. RaidWarningUtil is Forever's (mainline) API;
-- the old RaidNotice_AddMessage only exists with the deprecation fallbacks on.
function ns.Alert(text)
	if RaidWarningUtil and RaidWarningUtil.AddMessage then
		RaidWarningUtil.AddMessage(text, ChatTypeInfo and ChatTypeInfo["RAID_WARNING"] or { r = 1, g = 0.82, b = 0 })
	end
	ns.Print(text)
	if SOUNDKIT and SOUNDKIT.RAID_WARNING then
		PlaySound(SOUNDKIT.RAID_WARNING)
	end
end

local frame = CreateFrame("Frame")
ns.eventFrame = frame
local handlers = {}

local function on(event, fn)
	handlers[event] = fn
	frame:RegisterEvent(event)
end

frame:SetScript("OnEvent", function(_, event, ...)
	local fn = handlers[event]
	if fn and not (ns.disabled and event ~= "ADDON_LOADED") then
		fn(...)
	end
end)

local function whereCtx()
	local w = ns.Where()
	return { event = "zone", zone = w.zone, sub = w.sub, mapID = w.mapID }
end

local function zoneNotes()
	if not ns.Notes or not ns.db.settings.zoneNotes then
		return
	end
	local w = ns.Where()
	if not w.mapID then
		return
	end
	local notes = ns.Notes.ForAttachment("zone", w.mapID, ns.CharKey())
	if #notes > 0 then
		local titles = {}
		for i = 1, math.min(#notes, 3) do
			table.insert(titles, ns.Notes.DisplayTitle(notes[i]))
		end
		ns.Print(L.ZONE_NOTES:format(#notes, w.zone, table.concat(titles, ", ")))
	end
end

on("ADDON_LOADED", function(name)
	if name ~= ADDON then
		return
	end
	ns.InitDB()
	frame:UnregisterEvent("ADDON_LOADED")
end)

-- A standalone part steps aside when the full Bitácora is loaded too: the full one already does its job,
-- and both share the same data (Bitacora_Datos).
local FULL = "Bitacora"
local function fullLoaded()
	-- a standalone edition (Recordame) has its own data: it never steps aside
	return ADDON ~= FULL and not ns.edition.standalone and C_AddOns.IsAddOnLoaded(FULL)
end

on("PLAYER_LOGIN", function()
	if fullLoaded() then
		ns.disabled = true
		ns.Print(L.STANDALONE_OFF:format(ns.edition.title or ADDON))
		return
	end
	ns.Char() -- creates this character's record on first use
	if ns.Journal then
		ns.Journal.OnLogin()
	end
	ns.Fire("login")
	-- reminders a moment later, so the alert is not lost in the loading screen spam
	if ns.Reminders then
		C_Timer.After(5, function()
			ns.Reminders.Check({ event = "login", level = UnitLevel("player"), now = time() }, ns.CharKey())
			ns.Reminders.Check(whereCtx(), ns.CharKey())
		end)
		C_Timer.NewTicker(30, function()
			ns.Reminders.Check({ event = "tick", now = time() }, ns.CharKey())
			if ns.GuildReminders then
				ns.GuildReminders.Check("tick")
			end
		end)
		if ns.GuildReminders then
			C_Timer.After(10, function()
				ns.GuildReminders.Check("login")
				ns.GuildReminders.Ask()
			end)
		end
	end
end)

local function remind(ctx)
	if ns.Reminders then
		ns.Reminders.Check(ctx, ns.CharKey())
	end
end

-- Right after a hearthstone, a flight or a portal the zone text can still be the old zone, or empty
-- (reported in Forever's beta). Read it a moment later, once per arrival, and again if it was empty.
local zonePending = false
local function arrived(retry)
	local w = ns.Where()
	if (w.zone == nil or w.zone == "") and not w.mapID and not retry then
		C_Timer.After(2, function()
			arrived(true)
		end)
		return
	end
	if ns.Journal then
		ns.Journal.OnZoneChanged(false)
	end
	remind(whereCtx())
	zoneNotes()
end
on("ZONE_CHANGED_NEW_AREA", function()
	if zonePending then
		return
	end
	zonePending = true
	C_Timer.After(1, function()
		zonePending = false
		arrived(false)
	end)
end)

-- Subzones (an inn, a district of a city) only matter to reminders.
on("ZONE_CHANGED", function()
	remind(whereCtx())
end)
on("ZONE_CHANGED_INDOORS", function()
	remind(whereCtx())
end)

on("PLAYER_LEVEL_UP", function(level)
	if ns.Journal then
		ns.Journal.OnLevelUp(level)
	end
	remind({ event = "level", level = level })
end)

if ns.Journal then
	on("ENCOUNTER_END", ns.Journal.OnEncounterEnd)
	on("BOSS_KILL", ns.Journal.OnBossKill)
	on("PLAYER_DEAD", ns.Journal.OnDead)
	on("QUEST_TURNED_IN", ns.Journal.OnQuestTurnedIn)
	on("CHAT_MSG_LOOT", ns.Journal.OnLoot)
	on("ACHIEVEMENT_EARNED", ns.Journal.OnAchievement)
	on("PLAYER_MONEY", ns.Journal.OnMoney)
	on("TIME_PLAYED_MSG", ns.Journal.OnTimePlayed)
end
if ns.Album then
	on("SCREENSHOT_SUCCEEDED", ns.Album.OnScreenshot)
end
if ns.Chronicle or ns.GuildReminders then
	on("CHAT_MSG_ADDON", function(...)
		if ns.Chronicle then
			ns.Chronicle.OnAddonMessage(...)
		end
		if ns.GuildReminders then
			ns.GuildReminders.OnAddonMessage(...)
		end
	end)
end
if ns.Reminders then
	for event, place in pairs({ MAIL_SHOW = "MAIL", BANKFRAME_OPENED = "BANK", MERCHANT_SHOW = "MERCHANT", AUCTION_HOUSE_SHOW = "AUCTION" }) do
		local last
		on(event, function()
			-- opening the same window twice in a row (some fire twice in Forever) is one visit
			local now = GetTime()
			if last and now - last < 3 then
				return
			end
			last = now
			remind({ event = "place", place = place })
		end)
	end
end

-- Slash commands ---------------------------------------------------------------------------------

local KEY = string.upper(ADDON)
for i, command in ipairs(ns.edition.slash) do
	_G["SLASH_" .. KEY .. i] = command
end
SlashCmdList[KEY] = function(msg)
	if ns.disabled then
		ns.Print(L.STANDALONE_OFF:format(ns.edition.title or ADDON))
		return
	end
	msg = ns.Trim(msg)
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and string.lower(cmd) or ""
	if (cmd == "nota" or cmd == "note") and ns.Notes then
		if rest ~= "" then
			ns.Notes.Create({ body = rest })
			ns.Print(L.QUICK_NOTE_SAVED)
		end
	elseif (cmd == "entrada" or cmd == "entry") and ns.Journal then
		if ns.Journal.AddManual(rest) then
			ns.Print(L.ENTRY_SAVED)
		end
	elseif cmd == "opciones" or cmd == "options" or cmd == "config" then
		ns.OpenOptions()
	elseif cmd == "help" or cmd == "ayuda" or cmd == "?" then
		ns.Print(L.HELP)
	else
		ns.Toggle()
	end
end

-- Key binding (Bindings.xml) and the addon compartment next to the minimap (TOC fields).
local function toggle()
	if ns.disabled then
		ns.Print(L.STANDALONE_OFF:format(ns.edition.title or ADDON))
		return
	end
	ns.Toggle()
end
_G[ADDON .. "_Toggle"] = toggle
_G[ADDON .. "_OnAddonCompartmentClick"] = toggle
_G[ADDON .. "_OnAddonCompartmentEnter"] = function(_, button)
	GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
	GameTooltip:SetText(ns.edition.title or L.TITLE)
	GameTooltip:AddLine(L.COMPARTMENT_HINT, 1, 1, 1)
	GameTooltip:Show()
end
_G[ADDON .. "_OnAddonCompartmentLeave"] = function()
	GameTooltip:Hide()
end
