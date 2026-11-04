local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = ns.Progress

-- Rows of the Progress tab, as plain data (the tests read them; the list draws them).
-- { header = "..." } or { left = "...", right = "..." }
function P.Rows(charKey)
	local rows = {}
	local function header(text)
		table.insert(rows, { header = text })
	end
	local function line(left, right)
		table.insert(rows, { left = left, right = right and tostring(right) or "" })
	end

	local s = P.Stats(charKey)
	header(L.PROG_STATS)
	if s.level then
		line(L.STAT_LEVEL, s.level)
	end
	line(L.STAT_DAYS, s.days)
	if s.played then
		line(L.STAT_PLAYED, SecondsToTime(s.played))
	end
	line(L.STAT_ZONES, s.zones)
	line(L.STAT_QUESTS, s.quests)
	line(L.STAT_BOSSES, s.bosses)
	line(L.STAT_FIRSTS, s.firsts)
	line(L.STAT_LOOT, s.loot)
	line(L.STAT_DEATHS, s.deaths)
	if s.worstZone then
		line(L.STAT_WORST:format(s.worstZone, s.worstDeaths))
	end

	local dungeons = P.Dungeons(charKey)
	if #dungeons == 0 then
		header(L.PROG_DUNGEONS)
		line((EncounterJournal and EncounterJournal:IsShown()) and L.PROG_EJ_BUSY or L.PROG_EJ_EMPTY)
	end
	for _, raid in ipairs({ false, true }) do
		local any = false
		for _, d in ipairs(dungeons) do
			if d.raid == raid then
				if not any then
					header(raid and L.PROG_RAIDS or L.PROG_DUNGEONS)
					any = true
				end
				local color = d.killed == d.total and "|cff40c040" or (d.killed > 0 and "|cffffd100" or "|cff9d9d9d")
				line(d.name, color .. L.PROG_OF:format(d.killed, d.total) .. "|r")
			end
		end
	end

	local ach = P.Achievements()
	if #ach > 0 then
		header(L.PROG_ACHIEVEMENTS)
		for _, a in ipairs(ach) do
			line(a.name, L.PROG_OF:format(a.done, a.total))
		end
	end
	return rows
end

UI.RegisterTab("TAB_PROGRESS", "progress", function(panel)
	local view = {}
	local inset = UI.Inset(panel)
	inset:SetAllPoints()

	local list = UI.List(inset, 20, function(row, item)
		if not row.left then
			row.left = UI.Label(row, "", "GameFontHighlight")
			row.left:SetPoint("LEFT", 8, 0)
			row.left:SetPoint("RIGHT", -110, 0)
			row.left:SetWordWrap(false)
			row.right = UI.Label(row, "", "GameFontHighlight", "RIGHT")
			row.right:SetPoint("RIGHT", -8, 0)
		end
		if item.header then
			row.left:SetFontObject("GameFontNormal")
			row.left:SetText(item.header)
			row.right:SetText("")
		else
			row.left:SetFontObject("GameFontHighlight")
			row.left:SetText("  " .. item.left)
			row.right:SetText(item.right)
		end
	end)
	list.box:SetPoint("TOPLEFT", 4, -4)
	list.box:SetPoint("BOTTOMRIGHT", -20, 4)

	function view.Refresh()
		list:SetData(P.Rows())
	end
	return view
end)

-- A kill or a new zone changes the numbers.
ns.On("journal", function()
	local i = UI.tabOfTopic.progress
	if i and UI.frame:IsShown() and PanelTemplates_GetSelectedTab(UI.frame) == i and UI.views[i] then
		UI.views[i].Refresh()
	end
end)
