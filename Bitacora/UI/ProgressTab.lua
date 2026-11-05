local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = ns.Progress

-- Colours on parchment: the game's class colours and its bright green / yellow are made for a dark
-- background and wash out on the page. These keep the hue and bring the brightness down to ink level.
local MAX_LUMINANCE = 0.40
local function luminance(r, g, b)
	return 0.2126 * r + 0.7152 * g + 0.0722 * b
end
local function inked(r, g, b)
	local l = luminance(r, g, b)
	if l > MAX_LUMINANCE then
		local k = MAX_LUMINANCE / l
		r, g, b = r * k, g * k, b * k
	end
	return r, g, b
end
local function hex(r, g, b)
	return ("ff%02x%02x%02x"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end
UI.Luminance = luminance

-- The class colour, darkened for the page: r, g, b and the "ffrrggbb" string for |c…|r. Unknown class: ink.
function UI.InkClassColor(class)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if not c then
		local ink = UI.P.INK_SOFT
		return ink[1], ink[2], ink[3], hex(ink[1], ink[2], ink[3])
	end
	local r, g, b = c.r, c.g, c.b
	if not r and c.colorStr then -- only the string: "ffrrggbb"
		r = tonumber(c.colorStr:sub(3, 4), 16) / 255
		g = tonumber(c.colorStr:sub(5, 6), 16) / 255
		b = tonumber(c.colorStr:sub(7, 8), 16) / 255
	end
	if not r then
		local ink = UI.P.INK_SOFT
		return ink[1], ink[2], ink[3], hex(ink[1], ink[2], ink[3])
	end
	r, g, b = inked(r, g, b)
	return r, g, b, hex(r, g, b)
end

local GOOD = hex(UI.P.GREEN[1], UI.P.GREEN[2], UI.P.GREEN[3]) -- a dark ink green
local BAD = hex(UI.P.CRIMSON[1], UI.P.CRIMSON[2], UI.P.CRIMSON[3])
local SOME = hex(UI.P.GOLD_DEEP[1], UI.P.GOLD_DEEP[2], UI.P.GOLD_DEEP[3])
local NONE = hex(UI.P.INK_SOFT[1], UI.P.INK_SOFT[2], UI.P.INK_SOFT[3])
UI.INK_COLORS = { good = GOOD, bad = BAD, some = SOME, none = NONE }

-- Rows of the Progress tab, as plain data (the tests read them; the list draws them).
-- { header = "..." } or { left = "...", right = "..." }
function P.Rows(charKey)
	local rows = {}
	local function header(text)
		table.insert(rows, { header = text })
	end
	local function line(left, right, extra)
		local row = { left = left, right = right and tostring(right) or "" }
		for k, v in pairs(extra or {}) do
			row[k] = v
		end
		table.insert(rows, row)
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
	if s.legacy > 0 or P.LegacyPoints() > 0 then
		line(L.STAT_LEGACY, s.legacy)
		line(L.STAT_LEGACY_ACCOUNT, P.LegacyPoints())
	end
	if s.worstZone then
		line(L.STAT_WORST:format(s.worstZone, s.worstDeaths))
	end

	local splits = P.Splits(charKey)
	if #splits > 0 then
		header(L.PROG_SPLITS)
		local best = P.BestSplits()
		local me = ns.Char(charKey)
		for i = #splits, 1, -1 do
			local s = splits[i]
			local b = best[s.level]
			local right = SecondsToTime(s.seconds)
			if b and b.name ~= (me and me.name) and b.seconds < s.seconds then
				-- slower than your best character: the time in crimson, and who did it faster
				right = "|c" .. BAD .. right .. "|r · " .. L.SPLIT_BEST:format(b.name, SecondsToTime(b.seconds))
			elseif b and b.seconds >= s.seconds then
				right = "|c" .. GOOD .. right .. "|r"
			end
			line(L.SPLIT_LEVEL:format(s.level), right)
		end
	end

	if ns.Companions then
		local people = ns.Companions.Sorted()
		if #people > 0 then
			header(L.PROG_COMPANIONS)
			for i = 1, math.min(#people, 50) do
				local p = people[i]
				local name = p.label
				if p.class then
					local _, _, _, colorStr = UI.InkClassColor(p.class)
					name = "|c" .. colorStr .. name .. "|r"
				end
				local when, zone = p.last and date("%d/%m", p.last) or "", p.zone or ""
				line(name, p.times == 1 and L.COMPANION_TIMES_1:format(when, zone) or L.COMPANION_TIMES:format(p.times, when, zone))
			end
		end
	end

	local dungeons = P.Dungeons(charKey)
	if #dungeons == 0 then
		header(L.PROG_DUNGEONS)
		if EncounterJournal and EncounterJournal:IsShown() then
			line(L.PROG_EJ_BUSY, nil, { note = true })
		else
			-- two short lines instead of one that the row cuts off
			line(L.PROG_EJ_EMPTY, nil, { note = true })
			line(L.PROG_EJ_EMPTY_2, nil, { note = true })
		end
	end
	for _, raid in ipairs({ false, true }) do
		local any = false
		for _, d in ipairs(dungeons) do
			if d.raid == raid then
				if not any then
					header(raid and L.PROG_RAIDS or L.PROG_DUNGEONS)
					any = true
				end
				local color = "|c" .. (d.killed == d.total and GOOD or (d.killed > 0 and SOME or NONE))
				line(d.name, color .. L.PROG_OF:format(d.killed, d.total) .. "|r")
			end
		end
	end

	local ach = P.Achievements()
	if #ach > 0 then
		header(L.PROG_ACHIEVEMENTS)
		-- where these come from: the game's achievement categories, which in Forever are the Legacy challenges
		line(L.PROG_ACH_SOURCE, nil, { note = true })
		line(L.PROG_ACH_SOURCE_2, nil, { note = true })
		for _, a in ipairs(ach) do
			local color = a.done == 0 and NONE or (a.done == a.total and GOOD or SOME)
			line(a.name, "|c" .. color .. L.PROG_OF:format(a.done, a.total) .. "|r", { legacy = true })
		end
	end
	return rows
end

-- Clicking an achievement row opens the game's own window for them: the Legacy challenges in Forever (the
-- Y key), the achievement frame elsewhere. All guarded: a missing or protected function just does nothing.
function UI.OpenLegacy()
	for _, name in ipairs({ "ToggleLegacyChallenges", "ToggleLegacySystemUI", "ToggleAchievementFrame" }) do
		local fn = _G[name]
		if type(fn) == "function" and pcall(fn) then
			return name
		end
	end
end

-- Which rows open the right page: everything from the dungeons on.
local RIGHT_HEADERS = { "PROG_DUNGEONS", "PROG_RAIDS", "PROG_ACHIEVEMENTS" }

function P.SplitRows(rows)
	local left, right = {}, {}
	local onRight = false
	for _, row in ipairs(rows) do
		if row.header then
			onRight = false
			for _, key in ipairs(RIGHT_HEADERS) do
				if row.header == L[key] then
					onRight = true
				end
			end
		end
		table.insert(onRight and right or left, row)
	end
	return left, right
end

-- Left page: your numbers, time per level, companions. Right page: dungeons, raids, achievements.
UI.RegisterTab("TAB_PROGRESS", "progress", function(page)
	local view = {}
	local function makeList(parent)
		local holder = CreateFrame("Frame", nil, parent)
		holder:SetAllPoints()
		local list = UI.List(holder, 22, function(row, item)
			if not row.left then
				row.right = UI.Label(row, "", "body", "RIGHT")
				row.right:SetPoint("RIGHT", -4, 0)
				row.left = UI.Label(row, "", "body")
				row.left:SetPoint("LEFT", 4, 0)
				-- the name takes whatever the right column leaves: a line with nothing on the right is full width
				row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
				row.left:SetWordWrap(false)
			end
			if item.note then
				row.left:SetFontObject(UI.P.fonts.muted)
				row.left:SetText(item.left)
				row.right:SetText("")
				row.rule:SetAlpha(0)
			elseif item.header then
				row.left:SetFontObject(UI.P.fonts.heading)
				row.left:SetText(item.header)
				row.right:SetText("")
				row.rule:SetAlpha(0.6)
			else
				row.left:SetFontObject(UI.P.fonts.body)
				row.left:SetText(item.left)
				row.right:SetText(item.right)
				row.rule:SetAlpha(0.2)
			end
		end, function(item)
			if item and item.legacy then
				UI.OpenLegacy()
			end
		end)
		list.box:SetPoint("TOPLEFT", 0, 0)
		list.box:SetPoint("BOTTOMRIGHT", -16, 0)
		return list
	end
	local leftList = makeList(page.left)
	local rightList = page.right and makeList(page.right)

	function view.Refresh()
		local rows = P.Rows()
		if rightList then
			local l, r = P.SplitRows(rows)
			leftList:SetData(l)
			rightList:SetData(r)
		else
			leftList:SetData(rows)
		end
	end
	view.list, view.rightList = leftList, rightList
	return view
end)

-- A kill, a new zone or a new companion changes the numbers.
local function refresh()
	local i = UI.tabOfTopic.progress
	if i and UI.frame:IsShown() and UI.SelectedTab() == i and UI.views[i] then
		UI.views[i].Refresh()
	end
end
ns.On("journal", refresh)
ns.On("companions", refresh)
