local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local P = UI.P

UI.tabs = {}
UI.pages = {}
UI.tabOfTopic = {} -- "notes" -> tab index, for refreshing the visible tab when its data changes
UI.keys = {} -- index -> key

-- Global names carry the addon's folder name, so the full Bitácora and its standalone parts can be loaded together.
local FRAME = ADDON .. "Frame"
local f = P.Book(FRAME, { title = ns.edition.title or L.TITLE, single = ns.edition.single })
UI.frame = f
f.TitleText = f.title -- what the compartment tooltip and the old code expect
f.Tabs = {}
f.OnMoved = function(point, _, relPoint, x, y)
	ns.db.settings.point = { point, relPoint, x, y }
end

UI.builders = {} -- [index] = function(page) ... return { Refresh = fn } end
UI.views = {}

-- Each tab file of this edition registers itself, in TOC order (notebook, journal, album, reminders…).
-- The builder gets the page: { left = frame, right = frame or nil } inside the book.
function UI.RegisterTab(textKey, topic, builder)
	local i = #UI.builders + 1
	UI.builders[i] = builder
	UI.tabOfTopic[topic] = i
	UI.keys[i] = topic
	local tab = f:AddTab(topic, L[textKey])
	tab:SetID(i)
	UI.tabs[i] = tab
	f.Tabs[i] = tab
	UI.pages[i] = f:AddPage(topic)
	-- a standalone part has a single tab: no bookmarks
	f:SetTabsShown(i > 1)
end

function UI.SelectTab(i)
	if type(i) == "string" then
		i = UI.tabOfTopic[i]
	end
	if not UI.builders[i] then
		i = 1
	end
	f.selectedTab = i
	if not UI.views[i] and UI.builders[i] then
		UI.views[i] = UI.builders[i](UI.pages[i])
	end
	f:SelectTab(UI.keys[i])
	if UI.views[i] and UI.views[i].Refresh then
		UI.views[i].Refresh()
	end
	ns.db.settings.tab = i
end

-- a bookmark click lands here (the book already showed the page)
f.OnTab = function(key)
	local i = UI.tabOfTopic[key]
	if i and f.selectedTab ~= i then
		UI.SelectTab(i)
	end
end

function UI.SelectedTab()
	return f.selectedTab
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

-- Refresh the visible tab when its data changes.
for _, topic in ipairs({ "notes", "journal", "album", "reminders" }) do
	ns.On(topic, function()
		local i = UI.tabOfTopic[topic]
		if i and f:IsShown() and f.selectedTab == i and UI.views[i] and UI.views[i].Refresh then
			UI.views[i].Refresh(true)
		end
	end)
end
