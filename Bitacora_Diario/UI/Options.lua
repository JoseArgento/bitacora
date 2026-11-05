local _, ns = ...
local L = ns.L
local UI = ns.UI

-- A page in the game's Options → AddOns list. Forever loads Blizzard_Settings_Shared, whose
-- Settings.RegisterCanvasLayoutCategory takes any frame we draw ourselves.

local QUALITIES = { { 2, "QUALITY_UNCOMMON" }, { 3, "QUALITY_RARE" }, { 4, "QUALITY_EPIC" }, { 5, "QUALITY_LEGENDARY" } }

local panel = CreateFrame("Frame")
panel:Hide()
UI.options = panel

local title = UI.Label(panel, ns.edition.title or L.TITLE, "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
local sub = UI.Label(panel, L.OPTIONS_INTRO, "GameFontHighlightSmall")
sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

local checks = {}
local function check(key, text, y)
	local c = UI.Check(panel, text, function(self)
		ns.db.settings[key] = self:GetChecked() and true or false
		ns.Fire("settings", key)
	end)
	c:SetPoint("TOPLEFT", 12, y)
	checks[key] = c
	return c
end
-- only the options of the parts this edition has
local y = -64
local function add(key, text, part)
	if part then
		check(key, text, y)
		y = y - 28
	end
end
add("tooltipNotes", L.OPT_TOOLTIP, ns.Notes)
add("zoneNotes", L.OPT_ZONE, ns.Notes)
add("screenshotChat", L.OPT_SCREENSHOT, ns.Album)
add("journalQuests", L.OPT_QUESTS, ns.Journal)
add("chronicle", L.OPT_CHRONICLE, ns.Chronicle)
add("guildReminders", L.OPT_GUILD_REMINDERS, ns.GuildReminders)
add("reminderPopup", L.OPT_REMINDER_POPUP, ns.Reminders)
add("calendar", L.OPT_CALENDAR, ns.Reminders)
add("calendarAuto", L.OPT_CALENDAR_AUTO, ns.Reminders)
add("campBuff", L.OPT_CAMP_BUFF, ns.Reminders)
add("bookIntro", L.OPT_BOOK_INTRO, true)

local lootLabel = UI.Label(panel, L.SETTINGS_LOOT, "GameFontNormal")
lootLabel:SetPoint("TOPLEFT", 16, y - 12)
local loot = UI.Button(panel, "", 160, nil)
loot:SetPoint("TOPLEFT", lootLabel, "BOTTOMLEFT", 0, -6)
lootLabel:SetShown(ns.Journal ~= nil)
loot:SetShown(ns.Journal ~= nil)

local skinLabel = UI.Label(panel, L.OPT_SKIN, "GameFontNormal")
skinLabel:SetPoint("TOPLEFT", ns.Journal and loot or lootLabel, ns.Journal and "BOTTOMLEFT" or "TOPLEFT", 0, ns.Journal and -18 or 0)
local skin = UI.Button(panel, "", 160, nil)
skin:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 0, -6)

-- which clock the day-and-time reminders follow
local CLOCKS = { { "local", "CLOCK_LOCAL" }, { "realm", "CLOCK_REALM" } }
local clockLabel = UI.Label(panel, L.OPT_CLOCK, "GameFontNormal")
clockLabel:SetPoint("TOPLEFT", skin, "BOTTOMLEFT", 0, -18)
local clock = UI.Button(panel, "", 200, nil)
clock:SetPoint("TOPLEFT", clockLabel, "BOTTOMLEFT", 0, -6)
clockLabel:SetShown(ns.Reminders ~= nil)
clock:SetShown(ns.Reminders ~= nil)
clock:SetScript("OnClick", function(self)
	UI.Menu(self, function(root)
		for _, pair in ipairs(CLOCKS) do
			root:CreateRadio(L[pair[2]], function()
				return (ns.db.settings.clock or "local") == pair[1]
			end, function()
				ns.db.settings.clock = pair[1]
				panel.Refresh()
				ns.Fire("settings", "clock")
			end)
		end
	end)
end)

local function qualityText(q)
	for _, pair in ipairs(QUALITIES) do
		if pair[1] == q then
			return L[pair[2]]
		end
	end
	return tostring(q)
end

function panel.Refresh()
	for key, c in pairs(checks) do
		c:SetChecked(ns.db.settings[key] and true or false)
	end
	loot:SetText(qualityText(ns.db.settings.lootQuality or 4))
	skin:SetText(L["SKIN_" .. string.upper(ns.db.settings.skin or "classic")] or ns.db.settings.skin)
	clock:SetText(L["CLOCK_" .. string.upper(ns.db.settings.clock or "local")] or L.CLOCK_LOCAL)
end

loot:SetScript("OnClick", function(self)
	UI.Menu(self, function(root)
		for _, pair in ipairs(QUALITIES) do
			root:CreateRadio(L[pair[2]], function()
				return (ns.db.settings.lootQuality or 4) == pair[1]
			end, function()
				ns.db.settings.lootQuality = pair[1]
				panel.Refresh()
			end)
		end
	end)
end)

skin:SetScript("OnClick", function(self)
	UI.Menu(self, function(root)
		for _, name in ipairs({ "classic", "tavern" }) do
			root:CreateRadio(L["SKIN_" .. string.upper(name)], function()
				return (ns.db.settings.skin or "classic") == name
			end, function()
				ns.db.settings.skin = name
				panel.Refresh()
				ns.Fire("settings", "skin")
			end)
		end
	end)
end)

panel.loot, panel.skin, panel.clock, panel.checks = loot, skin, clock, checks
panel:SetScript("OnShow", panel.Refresh)

function UI.RegisterOptions()
	if UI.optionsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory) then
		return
	end
	if ns.disabled then
		return
	end
	local category = Settings.RegisterCanvasLayoutCategory(panel, ns.edition.title or L.TITLE)
	Settings.RegisterAddOnCategory(category)
	UI.optionsCategory = category
end

function ns.OpenOptions()
	UI.RegisterOptions()
	if UI.optionsCategory then
		Settings.OpenToCategory(UI.optionsCategory:GetID())
	end
end

ns.On("login", UI.RegisterOptions)
