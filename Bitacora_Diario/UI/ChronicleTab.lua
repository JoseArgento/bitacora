local _, ns = ...
local L = ns.L
local UI = ns.UI
local C = ns.Chronicle

-- Left page: the guild's milestones, newest first. Right page: how the chronicle stands and the week.
UI.RegisterTab("TAB_CHRONICLE", "chronicle", function(page)
	local view = {}
	local left, right = page.left, page.right or page.left

	local head = UI.Label(left, L.TAB_CHRONICLE, "heading")
	head:SetPoint("TOPLEFT", 0, 0)
	local rule = UI.Rule(left)
	rule:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -6)
	rule:SetPoint("RIGHT", left, "RIGHT", 0, 0)

	local listFrame = CreateFrame("Frame", nil, left)
	listFrame:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	listFrame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)

	local list = UI.List(listFrame, 40, function(row, item)
		if not row.text then
			row.text = UI.Label(row, "", "body")
			row.text:SetPoint("TOPLEFT", 4, -4)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetWordWrap(false)
			row.when = UI.Label(row, "", "small")
			row.when:SetPoint("BOTTOMLEFT", 4, 4)
		end
		row.text:SetText(C.Describe(item))
		row.when:SetText(date("%d/%m %H:%M", item.t))
	end)
	list.box:SetPoint("TOPLEFT", 0, 0)
	list.box:SetPoint("BOTTOMRIGHT", -16, 0)

	local empty = UI.Label(listFrame, L.CHRON_EMPTY, "muted", "CENTER")
	empty:SetPoint("TOPLEFT", 10, -30)
	empty:SetPoint("TOPRIGHT", -10, -30)
	empty:SetWordWrap(true)

	local statusHead = UI.Label(right, L.CHRON_STATUS_HEAD, "heading")
	if page.right then
		statusHead:SetPoint("TOPLEFT", 0, 0)
	else
		statusHead:Hide()
	end
	local status = UI.Label(right, "", "muted")
	if page.right then
		status:SetPoint("TOPLEFT", statusHead, "BOTTOMLEFT", 0, -6)
		status:SetPoint("RIGHT", 0, 0)
	else
		status:SetPoint("BOTTOMLEFT", left, "BOTTOMLEFT", 0, 0)
		status:SetPoint("RIGHT", 0, 0)
		listFrame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 40)
	end
	status:SetWordWrap(true)
	status:SetSpacing(3)

	local weekHead = UI.Label(right, L.CHRON_WEEK_HEAD, "heading")
	weekHead:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -18)
	local week = UI.Label(right, "", "body")
	week:SetPoint("TOPLEFT", weekHead, "BOTTOMLEFT", 0, -6)
	week:SetPoint("RIGHT", 0, 0)
	week:SetWordWrap(true)
	week:SetSpacing(3)
	if not page.right then
		weekHead:Hide()
		week:Hide()
	end

	function view.Refresh()
		local entries = C.Entries()
		local items = {}
		for i = #entries, 1, -1 do
			table.insert(items, entries[i])
		end
		list:SetData(items)
		status:SetText(C.Status() or "")
		empty:SetShown(#items == 0)
		-- the last seven days, counted by person
		local since, counts, names = time() - 7 * 86400, {}, {}
		for _, e in ipairs(entries) do
			if (e.t or 0) >= since and e.who then
				if not counts[e.who] then
					table.insert(names, e.who)
				end
				counts[e.who] = (counts[e.who] or 0) + 1
			end
		end
		table.sort(names, function(a, b)
			return counts[a] > counts[b]
		end)
		local bits = {}
		for i = 1, math.min(#names, 8) do
			table.insert(bits, names[i] .. " ×" .. counts[names[i]])
		end
		week:SetText(#bits > 0 and table.concat(bits, "\n") or L.CHRON_WEEK_EMPTY)
	end
	view.status, view.list = status, list
	return view
end)

ns.On("chronicle", function()
	local i = UI.tabOfTopic.chronicle
	if i and UI.frame:IsShown() and UI.SelectedTab() == i and UI.views[i] then
		UI.views[i].Refresh()
	end
end)
