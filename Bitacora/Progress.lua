local _, ns = ...

-- "Progreso": how far a character has come, from what the journal already wrote down plus the game's own
-- Encounter Journal (bosses of every dungeon and raid) and achievement categories.
-- A player asked for exactly this in Forever's Legacy feedback thread (30/9): completion per zone,
-- dungeon and raid, no rewards, just to see it. The game's own statistics panel shows mostly "--".

local P = {}
ns.Progress = P

-- Numbers from the journal: { deaths, quests, bosses (different ones), firsts, loot, zones, days, worstZone, worstDeaths }
function P.Stats(charKey)
	local c = ns.Char(charKey)
	local s = { deaths = 0, quests = 0, bosses = 0, firsts = 0, loot = 0, zones = 0, days = 0 }
	if not c then
		return s
	end
	local days, deathsBy = {}, {}
	s.legacy = 0
	for _, e in ipairs(c.journal) do
		if e.d then
			days[e.d] = true
		end
		if e.kind == "achievement" and type(e.legacy) == "number" then
			s.legacy = s.legacy + e.legacy
		end
		if e.kind == "death" then
			s.deaths = s.deaths + 1
			if e.zone and e.zone ~= "" then
				deathsBy[e.zone] = (deathsBy[e.zone] or 0) + 1
			end
		elseif e.kind == "quest" then
			s.quests = s.quests + 1
		elseif e.kind == "boss" and e.first then
			s.firsts = s.firsts + 1
		elseif e.kind == "loot" then
			s.loot = s.loot + 1
		end
	end
	for _ in pairs(c.bosses or {}) do
		s.bosses = s.bosses + 1
	end
	for _ in pairs(c.visited or {}) do
		s.zones = s.zones + 1
	end
	for _ in pairs(days) do
		s.days = s.days + 1
	end
	for zone, n in pairs(deathsBy) do
		if n > (s.worstDeaths or 0) or (n == s.worstDeaths and zone < s.worstZone) then
			s.worstZone, s.worstDeaths = zone, n
		end
	end
	s.played = c.played and c.played.total
	s.level = c.level
	return s
end

-- Legacy points earned on the whole account, from every character's journal.
function P.LegacyPoints()
	local total = 0
	for key in pairs(ns.db.chars) do
		total = total + P.Stats(key).legacy
	end
	return total
end

-- How long each level took: from the "played" seconds the journal writes at the start and at every level-up.
-- { { level = n, seconds = s, at = epoch } } for the levels the journal saw from beginning to end.
function P.Splits(charKey)
	local c = ns.Char(charKey)
	local out = {}
	if not c then
		return out
	end
	local prev -- the entry that began the current level
	for _, e in ipairs(c.journal) do
		if (e.kind == "start" or e.kind == "level") and type(e.level) == "number" and type(e.played) == "number" then
			if prev and e.kind == "level" and e.level > prev.level and e.played >= prev.played then
				-- levels skipped at once (a quest that gives two) get the whole span on the first one
				table.insert(out, { level = prev.level, seconds = e.played - prev.played, at = e.t })
			end
			prev = e
		end
	end
	return out
end

-- The account's fastest time at each level: { [level] = { seconds, name } }.
function P.BestSplits()
	local best = {}
	for key, c in pairs(ns.db.chars) do
		for _, s in ipairs(P.Splits(key)) do
			if not best[s.level] or s.seconds < best[s.level].seconds then
				best[s.level] = { seconds = s.seconds, name = c.name or key }
			end
		end
	end
	return best
end

-- Every dungeon and raid of the Encounter Journal with its bosses, read once per session:
-- { { id, name, raid = bool, bosses = { { name, encounter = dungeonEncounterID } } } }.
-- Selecting an instance changes the Encounter Journal's own selection, so this is not done while it is
-- open, and the tier is put back afterwards.
local instances
function P.Instances()
	if instances then
		return instances
	end
	if EncounterJournal and EncounterJournal:IsShown() then
		return {}
	end
	local tier = EJ_GetCurrentTier and EJ_GetCurrentTier()
	-- the Adventure Guide keeps the instance it shows here (Blizzard_EncounterJournal); put it back after
	local shown = EncounterJournal and EncounterJournal.instanceID
	local out = {}
	for _, raid in ipairs({ false, true }) do
		local i = 1
		while true do
			local instanceID, name = EJ_GetInstanceByIndex(i, raid)
			if not instanceID then
				break
			end
			EJ_SelectInstance(instanceID)
			local inst = { id = instanceID, name = name, raid = raid, bosses = {} }
			local j = 1
			while true do
				local bossName, _, bossID = EJ_GetEncounterInfoByIndex(j, instanceID)
				if not bossName then
					break
				end
				-- the 7th value is the ID ENCOUNTER_END / BOSS_KILL give, which the journal keeps
				local _, _, _, _, _, _, encounter = EJ_GetEncounterInfo(bossID)
				table.insert(inst.bosses, { name = bossName, encounter = encounter })
				j = j + 1
			end
			if #inst.bosses > 0 then
				table.insert(out, inst)
			end
			i = i + 1
		end
	end
	if tier and EJ_SelectTier then
		EJ_SelectTier(tier)
	end
	if shown then
		EJ_SelectInstance(shown)
	end
	-- right after login the journal can still be empty: only keep a list that has something in it
	if #out > 0 then
		instances = out
	end
	return out
end

-- Each instance with how many of its bosses this character has killed.
function P.Dungeons(charKey)
	local c = ns.Char(charKey)
	local killed = c and c.bosses or {}
	local out = {}
	for _, inst in ipairs(P.Instances()) do
		local n = 0
		for _, b in ipairs(inst.bosses) do
			if b.encounter and killed[b.encounter] then
				n = n + 1
			end
		end
		table.insert(out, { name = inst.name, raid = inst.raid, killed = n, total = #inst.bosses })
	end
	return out
end

-- Achievement categories with how many are done: { { name, done, total } }, top-level ones only, with
-- their subcategories added in. This is the game's own count (account or character, as the game keeps it).
function P.Achievements()
	local list = GetCategoryList and GetCategoryList() or {}
	local top, order = {}, {}
	local names = {}
	for _, id in ipairs(list) do
		local name, parent = GetCategoryInfo(id)
		names[id] = name
		local root = (parent and parent ~= -1) and parent or id
		local total, done = GetCategoryNumAchievements(id, true)
		if not top[root] then
			top[root] = { done = 0, total = 0 }
			table.insert(order, root)
		end
		top[root].done = top[root].done + (done or 0)
		top[root].total = top[root].total + (total or 0)
	end
	local out = {}
	for _, root in ipairs(order) do
		local t = top[root]
		if t.total > 0 and names[root] then
			table.insert(out, { name = names[root], done = t.done, total = t.total })
		end
	end
	return out
end
