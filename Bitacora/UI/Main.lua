local ADDON, ns = ...
local L = ns.L
local UI = ns.UI

UI.panels = {}
UI.tabs = {}
UI.tabOfTopic = {} -- "notes" -> tab index, for refreshing the visible tab when its data changes

-- Global names carry the addon's folder name, so the full Bitácora and its standalone parts can be loaded together.
local FRAME = ADDON .. "Frame"
local f = CreateFrame("Frame", FRAME, UIParent, "BasicFrameTemplateWithInset")
UI.frame = f
f:SetSize(760, 520)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:SetClampedToScreen(true)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:Hide()
f.TitleText:SetText(ns.edition.title or L.TITLE)
tinsert(UISpecialFrames, FRAME) -- Escape closes it

f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	ns.db.settings.point = { point, relPoint, x, y }
end)

UI.builders = {} -- [index] = function(panel) ... return { Refresh = fn } end
UI.views = {}

-- Each tab file of this edition registers itself, in TOC order (notebook, journal, album, reminders).
function UI.RegisterTab(textKey, topic, builder)
	local i = #UI.builders + 1
	UI.builders[i] = builder
	UI.tabOfTopic[topic] = i
	local tab = CreateFrame("Button", FRAME .. "Tab" .. i, f, "PanelTabButtonTemplate")
	tab:SetID(i)
	tab:SetText(L[textKey])
	if i == 1 then
		tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 8, 2)
	else
		tab:SetPoint("LEFT", UI.tabs[i - 1], "RIGHT", 3, 0)
	end
	tab:SetScript("OnClick", function(self)
		UI.SelectTab(self:GetID())
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)
	UI.tabs[i] = tab
	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
	panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
	panel:Hide()
	UI.panels[i] = panel
	PanelTemplates_SetNumTabs(f, i)
	-- a standalone part has a single tab: no tab strip
	for _, t in ipairs(UI.tabs) do
		t:SetShown(i > 1)
	end
end

function UI.SelectTab(i)
	if not UI.builders[i] then
		i = 1
	end
	PanelTemplates_SetTab(f, i)
	for k, panel in ipairs(UI.panels) do
		panel:SetShown(k == i)
	end
	if not UI.views[i] and UI.builders[i] then
		UI.views[i] = UI.builders[i](UI.panels[i])
	end
	if UI.views[i] and UI.views[i].Refresh then
		UI.views[i].Refresh()
	end
	ns.db.settings.tab = i
end

function ns.Toggle(tab)
	if f:IsShown() and not tab then
		f:Hide()
		return
	end
	local p = ns.db.settings.point
	if p and not f.placed then
		f:ClearAllPoints()
		f:SetPoint(p[1], UIParent, p[2], p[3], p[4])
		f.placed = true
	end
	local wasShown = f:IsShown()
	f:Show()
	UI.SelectTab(tab or ns.db.settings.tab or 1)
	if not wasShown and UI.OpenBook then
		UI.OpenBook()
	end
end

f:SetScript("OnShow", function()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
end)
f:SetScript("OnHide", function()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
end)

-- Refresh the visible tab when its data changes.
for _, topic in ipairs({ "notes", "journal", "album", "reminders" }) do
	ns.On(topic, function()
		local i = UI.tabOfTopic[topic]
		if i and f:IsShown() and PanelTemplates_GetSelectedTab(f) == i and UI.views[i] and UI.views[i].Refresh then
			UI.views[i].Refresh(true)
		end
	end)
end
