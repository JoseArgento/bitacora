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
	if fn then
		fn(...)
	end
end)

local function whereCtx()
	local w = ns.Where()
	return { event = "zone", zone = w.zone, sub = w.sub, mapID = w.mapID }
end

local function zoneNotes()
	if not ns.db.settings.zoneNotes then
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

on("PLAYER_LOGIN", function()
	ns.Char() -- creates this character's record on first use
	ns.Journal.OnLogin()
	ns.Fire("login")
	-- reminders a moment later, so the alert is not lost in the loading screen spam
	C_Timer.After(5, function()
		ns.Reminders.Check({ event = "login", level = UnitLevel("player"), now = time() }, ns.CharKey())
		ns.Reminders.Check(whereCtx(), ns.CharKey())
	end)
	C_Timer.NewTicker(30, function()
		ns.Reminders.Check({ event = "tick", now = time() }, ns.CharKey())
	end)
end)

on("ZONE_CHANGED_NEW_AREA", function()
	ns.Journal.OnZoneChanged(false)
	ns.Reminders.Check(whereCtx(), ns.CharKey())
	zoneNotes()
end)

-- Subzones (an inn, a district of a city) only matter to reminders.
on("ZONE_CHANGED", function()
	ns.Reminders.Check(whereCtx(), ns.CharKey())
end)
on("ZONE_CHANGED_INDOORS", function()
	ns.Reminders.Check(whereCtx(), ns.CharKey())
end)

on("PLAYER_LEVEL_UP", function(level)
	ns.Journal.OnLevelUp(level)
	ns.Reminders.Check({ event = "level", level = level }, ns.CharKey())
end)

on("ENCOUNTER_END", ns.Journal.OnEncounterEnd)
on("BOSS_KILL", ns.Journal.OnBossKill)
on("PLAYER_DEAD", ns.Journal.OnDead)
on("QUEST_TURNED_IN", ns.Journal.OnQuestTurnedIn)
on("CHAT_MSG_LOOT", ns.Journal.OnLoot)
on("ACHIEVEMENT_EARNED", ns.Journal.OnAchievement)
on("PLAYER_MONEY", ns.Journal.OnMoney)
on("TIME_PLAYED_MSG", ns.Journal.OnTimePlayed)
on("SCREENSHOT_SUCCEEDED", ns.Album.OnScreenshot)

for event, place in pairs({ MAIL_SHOW = "MAIL", BANKFRAME_OPENED = "BANK", MERCHANT_SHOW = "MERCHANT", AUCTION_HOUSE_SHOW = "AUCTION" }) do
	on(event, function()
		ns.Reminders.Check({ event = "place", place = place }, ns.CharKey())
	end)
end

-- Slash commands ---------------------------------------------------------------------------------

SLASH_BITACORA1 = "/bitacora"
SLASH_BITACORA2 = "/bita"
SlashCmdList.BITACORA = function(msg)
	msg = ns.Trim(msg)
	local cmd, rest = msg:match("^(%S+)%s*(.*)$")
	cmd = cmd and string.lower(cmd) or ""
	if cmd == "nota" or cmd == "note" then
		if rest ~= "" then
			ns.Notes.Create({ body = rest })
			ns.Print(L.QUICK_NOTE_SAVED)
		end
	elseif cmd == "entrada" or cmd == "entry" then
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
function Bitacora_Toggle()
	ns.Toggle()
end

function Bitacora_OnAddonCompartmentClick()
	ns.Toggle()
end

function Bitacora_OnAddonCompartmentEnter(_, button)
	GameTooltip:SetOwner(button or UIParent, "ANCHOR_LEFT")
	GameTooltip:SetText(L.TITLE)
	GameTooltip:AddLine(L.COMPARTMENT_HINT, 1, 1, 1)
	GameTooltip:Show()
end

function Bitacora_OnAddonCompartmentLeave()
	GameTooltip:Hide()
end
