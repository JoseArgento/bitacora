local _, ns = ...
local L = ns.L
local UI = ns.UI
local J = ns.Journal

local KIND_ICON = {
	start = "Interface\\Icons\\INV_Misc_Book_09",
	level = "Interface\\Icons\\Spell_Holy_SurgeOfLight",
	zone = "Interface\\Icons\\INV_Misc_Map_01",
	boss = "Interface\\Icons\\Achievement_Boss_Onyxia",
	death = "Interface\\Icons\\Ability_Rogue_FeignDeath",
	quest = "Interface\\GossipFrame\\ActiveQuestIcon",
	loot = "Interface\\Icons\\INV_Misc_Bag_10",
	achievement = "Interface\\Icons\\Achievement_General",
	money = "Interface\\Icons\\INV_Misc_Coin_01",
	played = "Interface\\Icons\\INV_Misc_PocketWatch_01",
	note = "Interface\\Icons\\INV_Feather_05",
}

UI.builders[2] = function(panel)
	local view = { filter = "milestones", char = nil }

	-- the summary goes under the list: the top row holds search, filters, write and the character menu
	local summary = UI.Label(panel, "", "GameFontHighlightSmall")
	summary:SetPoint("BOTTOMLEFT", 4, 2)

	local charButton = UI.Button(panel, "", 160, nil)
	charButton:SetPoint("TOPRIGHT", -4, 0)

	local write = UI.Button(panel, L.ADD_ENTRY, 90, function()
		UI.Prompt(L.ENTRY_PROMPT, "", function(text)
			J.AddManual(text)
		end)
	end)
	write:SetPoint("RIGHT", charButton, "LEFT", -8, 0)

	local filterAll, filterMilestones
	filterMilestones = UI.Button(panel, L.FILTER_MILESTONES, 90, function()
		view.filter = "milestones"
		view.Refresh()
	end)
	filterMilestones:SetPoint("RIGHT", write, "LEFT", -16, 0)
	filterAll = UI.Button(panel, L.FILTER_ALL, 70, function()
		view.filter = "all"
		view.Refresh()
	end)
	filterAll:SetPoint("RIGHT", filterMilestones, "LEFT", -4, 0)

	local search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
	search:SetSize(170, 20)
	search:SetPoint("TOPLEFT", 8, -2)
	search:HookScript("OnTextChanged", function()
		view.Refresh()
	end)
	view.search = search

	local inset = CreateFrame("Frame", nil, panel, "InsetFrameTemplate")
	inset:SetPoint("TOPLEFT", 0, -30)
	inset:SetPoint("BOTTOMRIGHT", 0, 18)

	local list = UI.List(inset, 26, function(row, e)
		if not row.icon then
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(20, 20)
			row.icon:SetPoint("LEFT", 6, 0)
			row.date = UI.Label(row, "", "GameFontDisableSmall")
			row.date:SetPoint("LEFT", row.icon, "RIGHT", 8, 0)
			row.date:SetWidth(108)
			row.text = UI.Label(row, "", "GameFontHighlight")
			row.text:SetPoint("LEFT", row.date, "RIGHT", 6, 0)
			row.text:SetPoint("RIGHT", -8, 0)
			row.text:SetWordWrap(false)
			UI.EnableLinks(row)
		end
		row.icon:SetTexture(KIND_ICON[e.kind] or KIND_ICON.note)
		row.date:SetText(UI.FormatDate(e))
		local where = (e.kind ~= "zone" and e.kind ~= "death" and e.kind ~= "start" and e.zone and e.zone ~= "") and ("  |cff808080" .. e.zone .. "|r") or ""
		row.text:SetText(J.Text(e) .. where)
	end)
	list.box:SetPoint("TOPLEFT", 4, -4)
	list.box:SetPoint("BOTTOMRIGHT", -20, 4)

	local empty = UI.Label(inset, L.JOURNAL_EMPTY, "GameFontDisable", "CENTER")
	empty:SetPoint("CENTER")

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
					view.Refresh()
				end)
			end
		end)
	end)

	function view.Refresh()
		local key = view.char or ns.CharKey()
		local entries = J.Entries(key, view.filter)
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
		if view.filter == "all" then
			filterAll:LockHighlight()
			filterMilestones:UnlockHighlight()
		else
			filterMilestones:LockHighlight()
			filterAll:UnlockHighlight()
		end
	end

	return view
end
