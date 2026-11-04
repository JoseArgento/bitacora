local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = ns.Chronicle

UI.RegisterTab("TAB_CHRONICLE", "chronicle", function(panel)
	local view = {}
	local status = UI.Label(panel, "", "GameFontDisableSmall")
	status:SetPoint("TOPLEFT", 4, -4)
	status:SetPoint("TOPRIGHT", -4, -4)
	status:SetWordWrap(true)

	local inset = UI.Inset(panel)
	inset:SetPoint("TOPLEFT", 0, -40)
	inset:SetPoint("BOTTOMRIGHT", 0, 0)

	local list = UI.List(inset, 22, function(row, item)
		if not row.text then
			row.text = UI.Label(row, "", "GameFontHighlight")
			row.text:SetPoint("LEFT", 8, 0)
			row.text:SetPoint("RIGHT", -110, 0)
			row.text:SetWordWrap(false)
			row.when = UI.Label(row, "", "GameFontDisableSmall", "RIGHT")
			row.when:SetPoint("RIGHT", -8, 0)
		end
		row.text:SetText(C.Describe(item))
		row.when:SetText(date("%d/%m %H:%M", item.t))
	end)
	list.box:SetPoint("TOPLEFT", 4, -4)
	list.box:SetPoint("BOTTOMRIGHT", -20, 4)

	local empty = UI.Label(inset, L.CHRON_EMPTY, "GameFontDisable", "CENTER")
	empty:SetPoint("TOPLEFT", 20, -40)
	empty:SetPoint("TOPRIGHT", -20, -40)

	function view.Refresh()
		local entries = C.Entries()
		local items = {}
		for i = #entries, 1, -1 do
			table.insert(items, entries[i])
		end
		list:SetData(items)
		status:SetText(C.Status() or "")
		empty:SetShown(#items == 0)
	end
	view.status, view.list = status, list
	return view
end)

ns.On("chronicle", function()
	local i = UI.tabOfTopic.chronicle
	if i and UI.frame:IsShown() and PanelTemplates_GetSelectedTab(UI.frame) == i and UI.views[i] then
		UI.views[i].Refresh()
	end
end)
