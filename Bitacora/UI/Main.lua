local _, ns = ...
local L = ns.L
local UI = ns.UI

local TABS = { "TAB_NOTES", "TAB_JOURNAL", "TAB_ALBUM", "TAB_REMINDERS" }
UI.panels = {}

local f = CreateFrame("Frame", "BitacoraFrame", UIParent, "BasicFrameTemplateWithInset")
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
f.TitleText:SetText(L.TITLE)
tinsert(UISpecialFrames, "BitacoraFrame") -- Escape closes it

f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	ns.db.settings.point = { point, relPoint, x, y }
end)

for i, key in ipairs(TABS) do
	local tab = CreateFrame("Button", "BitacoraFrameTab" .. i, f, "PanelTabButtonTemplate")
	tab:SetID(i)
	tab:SetText(L[key])
	if i == 1 then
		tab:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 8, 2)
	else
		tab:SetPoint("LEFT", _G["BitacoraFrameTab" .. (i - 1)], "RIGHT", 3, 0)
	end
	tab:SetScript("OnClick", function(self)
		UI.SelectTab(self:GetID())
		PlaySound(SOUNDKIT.IG_CHARACTER_INFO_TAB)
	end)
	local panel = CreateFrame("Frame", nil, f)
	panel:SetPoint("TOPLEFT", f, "TOPLEFT", 12, -30)
	panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -12, 10)
	panel:Hide()
	UI.panels[i] = panel
end
PanelTemplates_SetNumTabs(f, #TABS)

UI.builders = {} -- [index] = function(panel) ... return { Refresh = fn } end
UI.views = {}

function UI.SelectTab(i)
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
	f:Show()
	UI.SelectTab(tab or ns.db.settings.tab or 1)
end

f:SetScript("OnShow", function()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
end)
f:SetScript("OnHide", function()
	PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)
end)

-- Refresh the visible tab when its data changes.
local topicTab = { notes = 1, journal = 2, album = 3, reminders = 4 }
for topic, i in pairs(topicTab) do
	ns.On(topic, function()
		if f:IsShown() and PanelTemplates_GetSelectedTab(f) == i and UI.views[i] and UI.views[i].Refresh then
			UI.views[i].Refresh(true)
		end
	end)
end
