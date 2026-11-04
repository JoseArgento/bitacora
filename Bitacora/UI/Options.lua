local _, ns = ...
local L = ns.L
local UI = ns.UI

-- A page in the game's Options → AddOns list. Forever loads Blizzard_Settings_Shared, whose
-- Settings.RegisterCanvasLayoutCategory takes any frame we draw ourselves.

local QUALITIES = { { 2, "QUALITY_UNCOMMON" }, { 3, "QUALITY_RARE" }, { 4, "QUALITY_EPIC" }, { 5, "QUALITY_LEGENDARY" } }

local panel = CreateFrame("Frame")
panel:Hide()
UI.options = panel

local title = UI.Label(panel, L.TITLE, "GameFontNormalLarge")
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
check("tooltipNotes", L.OPT_TOOLTIP, -64)
check("zoneNotes", L.OPT_ZONE, -92)
check("screenshotChat", L.OPT_SCREENSHOT, -120)
check("journalQuests", L.OPT_QUESTS, -148)

local lootLabel = UI.Label(panel, L.SETTINGS_LOOT, "GameFontNormal")
lootLabel:SetPoint("TOPLEFT", 16, -188)
local loot = UI.Button(panel, "", 160, nil)
loot:SetPoint("TOPLEFT", lootLabel, "BOTTOMLEFT", 0, -6)

local skinLabel = UI.Label(panel, L.OPT_SKIN, "GameFontNormal")
skinLabel:SetPoint("TOPLEFT", loot, "BOTTOMLEFT", 0, -18)
local skin = UI.Button(panel, "", 160, nil)
skin:SetPoint("TOPLEFT", skinLabel, "BOTTOMLEFT", 0, -6)

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

panel.loot, panel.skin, panel.checks = loot, skin, checks
panel:SetScript("OnShow", panel.Refresh)

function UI.RegisterOptions()
	if UI.optionsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory) then
		return
	end
	local category = Settings.RegisterCanvasLayoutCategory(panel, L.TITLE)
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
