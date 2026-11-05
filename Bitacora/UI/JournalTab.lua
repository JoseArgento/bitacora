local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = UI.P
local J = ns.Journal

-- Left page: search, filters, the entries (newest first), "Write".
-- Right page: the character (menu), its numbers, and the entry you clicked, in full.
UI.RegisterTab("TAB_JOURNAL", "journal", function(page)
	local view = { filter = "milestones", char = nil, selected = nil }
	local left, right = page.left, page.right or page.left

	-- left page -------------------------------------------------------------------------------------
	local search = UI.Input(left, 150, nil, L.SEARCH_JOURNAL)
	search:SetPoint("TOPLEFT", 0, 0)
	search:HookScript("OnTextChanged", function()
		view.Refresh()
	end)
	view.search = search

	local filters = UI.ChipRow(left, 200)
	filters:SetPoint("LEFT", search, "RIGHT", 10, 0)

	local rule = UI.Rule(left)
	rule:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -8)
	rule:SetPoint("RIGHT", left, "RIGHT", 0, 0)

	local listFrame = CreateFrame("Frame", nil, left)
	listFrame:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	listFrame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 34)

	local list
	list = UI.List(listFrame, 40, function(row, e)
		if not row.tag then
			row.tag = UI.Tag(row, "", "note")
			row.tag:SetPoint("TOPLEFT", 4, -5)
			row.date = UI.Label(row, "", "small")
			row.date:SetPoint("TOPRIGHT", -4, -4)
			row.text = UI.Label(row, "", "body")
			row.text:SetPoint("BOTTOMLEFT", 4, 4)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetWordWrap(false)
			UI.EnableLinks(row)
		end
		row.tag:Set(L.KINDS and L.KINDS[e.kind] or e.kind, e.kind)
		row.date:SetText(UI.FormatDate(e))
		-- one line: the entry, then the place in muted ink ("Llegó a nivel 11. · Bosque de Elwynn")
		local where = (e.kind ~= "zone" and e.kind ~= "death" and e.kind ~= "start" and e.zone and e.zone ~= "") and (" |cff6c4e31· " .. e.zone .. "|r") or ""
		local text = J.Text(e)
		if where ~= "" then
			text = text:gsub("%.$", "") -- "Reached level 11 · Elwynn Forest", not "level 11. · Elwynn"
		end
		row.text:SetText(text .. where)
		row.selected:SetShown(view.selected == e)
	end, function(e)
		view.selected = e
		list:Refresh()
		view.ShowEntry()
	end)
	list.box:SetPoint("TOPLEFT", 0, 0)
	list.box:SetPoint("BOTTOMRIGHT", -16, 0)

	local empty = UI.Label(listFrame, L.JOURNAL_EMPTY, "muted", "CENTER")
	empty:SetPoint("CENTER")

	local write = UI.Button(left, L.ADD_ENTRY, 110, function()
		UI.Prompt(L.ENTRY_PROMPT, "", function(text)
			J.AddManual(text)
		end)
	end)
	write:SetPoint("BOTTOMLEFT", 0, 0)

	-- right page --------------------------------------------------------------------------------------
	local charButton = UI.Button(right, "", 170, nil)
	charButton:SetPoint("TOPLEFT", 0, 0)
	local charHint = UI.Label(right, L.JOURNAL_OF, "muted")
	charHint:SetPoint("LEFT", charButton, "RIGHT", 10, 0)

	local summaryHead = UI.Label(right, L.SUMMARY_HEAD, "heading")
	summaryHead:SetPoint("TOPLEFT", charButton, "BOTTOMLEFT", 0, -18)
	local summary = UI.Label(right, "", "body")
	summary:SetPoint("TOPLEFT", summaryHead, "BOTTOMLEFT", 0, -6)
	summary:SetPoint("RIGHT", 0, 0)
	summary:SetWordWrap(true)
	summary:SetSpacing(3)

	local entryRule = UI.Rule(right)
	entryRule:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -14)
	entryRule:SetPoint("RIGHT", 0, 0)

	local entryHead = UI.Label(right, L.ENTRY_HEAD, "heading")
	entryHead:SetPoint("TOPLEFT", entryRule, "BOTTOMLEFT", 0, -12)
	local entryTag = UI.Tag(right, "", "note")
	entryTag:SetPoint("LEFT", entryHead, "RIGHT", 8, 0)
	local entryWhen = UI.Label(right, "", "small")
	entryWhen:SetPoint("TOPLEFT", entryHead, "BOTTOMLEFT", 0, -6)
	local entryText = CreateFrame("Frame", nil, right)
	entryText:SetPoint("TOPLEFT", entryWhen, "BOTTOMLEFT", 0, -6)
	entryText:SetPoint("BOTTOMRIGHT", 0, 0)
	UI.EnableLinks(entryText)
	entryText.text = UI.Label(entryText, "", "italic")
	entryText.text:SetPoint("TOPLEFT")
	entryText.text:SetPoint("RIGHT")
	entryText.text:SetWordWrap(true)
	entryText.text:SetSpacing(3)
	local entryHint = UI.Label(right, L.ENTRY_PICK, "muted")
	entryHint:SetPoint("TOPLEFT", entryHead, "BOTTOMLEFT", 0, -6)

	charButton:SetScript("OnClick", function(self)
		UI.Menu(self, function(root)
			local keys = {}
			for key in pairs(ns.db.chars) do
				table.insert(keys, key)
			end
			table.sort(keys)
			for _, key in ipairs(keys) do
				root:CreateRadio(key, function()
					return (view.char or ns.CharKey()) == key
				end, function()
					view.char = key
					view.selected = nil
					view.Refresh()
				end)
			end
		end)
	end)

	function view.ShowEntry()
		local e = view.selected
		entryHint:SetShown(e == nil)
		entryTag:SetShown(e ~= nil)
		entryWhen:SetShown(e ~= nil)
		entryText:SetShown(e ~= nil)
		if not e then
			return
		end
		entryTag:Set(L.KINDS and L.KINDS[e.kind] or e.kind, e.kind)
		local when = UI.FormatDate(e)
		if e.level then
			when = when .. " · " .. L.LEVEL_N:format(e.level)
		end
		if e.zone and e.zone ~= "" then
			when = when .. " · " .. e.zone
		end
		entryWhen:SetText(when)
		entryText.text:SetText(J.Text(e))
	end

	function view.Refresh()
		local key = view.char or ns.CharKey()
		local entries = J.Entries(key, view.filter)
		if view.filter == "milestones" then
			entries = J.Grouped(entries)
		end
		local query = ns.Lower(search:GetText())
		-- newest first
		local items = {}
		for i = #entries, 1, -1 do
			local e = entries[i]
			if query == "" or J.Matches(e, query) then
				table.insert(items, e)
			end
		end
		list:SetData(items)
		empty:SetShown(#items == 0)
		local s = J.Summary(key)
		local c = ns.db.chars[key]
		summary:SetText(L.SUMMARY:format(c and c.level or s.level, s.entries, s.bosses, s.deaths))
		charButton:SetText(key or "?")
		filters:Set({
			{
				text = L.FILTER_MILESTONES,
				selected = view.filter == "milestones",
				onClick = function()
					view.filter = "milestones"
					view.Refresh()
				end,
			},
			{
				text = L.FILTER_ALL,
				selected = view.filter == "all",
				onClick = function()
					view.filter = "all"
					view.Refresh()
				end,
			},
		})
		view.ShowEntry()
	end

	view.list = list
	return view
end)
