local _, ns = ...
local L = ns.L

local J = {}
ns.Journal = J

-- Entries keep raw facts (kind + fields), never translated text, so the web page and the UI can word them.
-- { t = epoch, d = "YYYY-MM-DD HH:MM", kind = "...", level = n, zone = "...", ... }

J.MILESTONES = { start = true, level = true, zone = true, boss = true, death = true, achievement = true, loot = true, money = true, note = true, camp = true, blueprint = true }

-- Forever's camping blueprints, by the camp object the recipe builds (same data as Taller/Blueprints.lua;
-- keep the two in step). ⏳ From the beta: names and IDs may change.
J.BLUEPRINTS = {
	[279970] = { "Fermenter", "Alchemy" },
	[279990] = { "Alchemy Laboratory", "Alchemy" },
	[279988] = { "Anvil", "Blacksmithing" },
	[279955] = { "Master Forge", "Blacksmithing" },
	[279985] = { "Arcane Salvager", "Enchanting" },
	[279987] = { "Arcane Forge", "Enchanting" },
	[279949] = { "Repair Bot", "Engineering" },
	[279989] = { "Anarchist's Workbench", "Engineering" },
	[279964] = { "Greenhouse", "Herbalism" },
	[279947] = { "Seed Hybridizer", "Herbalism" },
	[279941] = { "Tanning Rack", "Leatherworking" },
	[279945] = { "Sewing Machine", "Leatherworking" },
	[279948] = { "Rock Garden", "Mining" },
	[279952] = { "Molten Foundry", "Mining" },
	[279969] = { "Field Guide", "Skinning" },
	[279938] = { "Trapper's Workbench", "Skinning" },
	[279943] = { "Spinning Wheel", "Tailoring" },
	[279959] = { "Loom", "Tailoring" },
	[279940] = { "Toxin Study", "First Aid" },
	[279951] = { "Plague Doctor's Laboratory", "First Aid" },
	[279965] = { "Fishing Rack", "Fishing" },
}

-- The campfire spell of Forever's camping. ⏳ Its ID is not known yet: a cast is matched by ID when the
-- table has one, else by the spell's name (the client's own, any of these languages).
J.CAMPFIRE_SPELLS = {}
J.CAMPFIRE_NAMES = { ["basic campfire"] = true, ["campfire"] = true, ["fogata básica"] = true, ["fogata"] = true, ["hoguera"] = true, ["hoguera básica"] = true, ["campsite"] = true, ["campamento"] = true }

J.LEGACY_CURRENCY = 4225

-- Legacy points an achievement is worth: Forever's Legacy challenges are achievements that pay points
-- (Blizzard_LegacyAchievementOverrides.lua reads them the same way). 0 for an ordinary achievement.
function J.LegacyPoints(achievementID)
	local f = C_Traits and C_Traits.GetTraitCurrencyForAchievement
	if not f or type(achievementID) ~= "number" then
		return 0
	end
	-- Constants.LegacyConsts.LEGACY_POINTS_TRAIT_CURRENCY_ID in Blizzard's LegacyConstantsDocumentation.lua (1.60.1)
	local points = ns.Plain(f(J.LEGACY_CURRENCY, achievementID))
	return type(points) == "number" and points > 0 and points or 0
end
J.MONEY_STEPS = { 10000, 100000, 1000000, 10000000 } -- 1, 10, 100 and 1000 gold

local lastBoss -- { id, t }: ENCOUNTER_END and BOSS_KILL can both fire for one kill

function J.Add(kind, fields, charKey)
	local c = ns.Char(charKey)
	if not c then
		return nil
	end
	local t, d = ns.Now()
	local where = ns.Where()
	local e = { t = t, d = d, kind = kind, level = UnitLevel("player"), zone = where.zone, sub = where.sub ~= "" and where.sub or nil }
	for k, v in pairs(fields or {}) do
		e[k] = v
	end
	table.insert(c.journal, e)
	ns.Fire("journal", e)
	return e
end

function J.Entries(charKey, filter)
	local c = ns.Char(charKey)
	if not c then
		return {}
	end
	if filter ~= "milestones" then
		return c.journal
	end
	local out = {}
	for _, e in ipairs(c.journal) do
		if J.MILESTONES[e.kind] and not (e.kind == "boss" and not e.first) then
			table.insert(out, e)
		end
	end
	return out
end

-- The milestones view: consecutive level-ups of the same day fold into one row
-- ("Niveles 2 a 9"); the row keeps the last entry's time and place and the folded entries.
function J.Grouped(entries)
	local out = {}
	local run
	for _, e in ipairs(entries) do
		local day = (e.d or ""):sub(1, 10)
		if e.kind == "level" and run and run.day == day and (e.level or 0) == (run.level or 0) + 1 then
			run.level = e.level
			run.t, run.d = e.t, e.d
			run.zone, run.sub = e.zone, e.sub
			table.insert(run.entries, e)
		else
			if run then
				table.insert(out, #run.entries > 1 and run or run.entries[1])
				run = nil
			end
			if e.kind == "level" then
				run = { kind = "level", group = true, day = day, from = e.level, level = e.level, t = e.t, d = e.d, zone = e.zone, sub = e.sub, entries = { e } }
			else
				table.insert(out, e)
			end
		end
	end
	if run then
		table.insert(out, #run.entries > 1 and run or run.entries[1])
	end
	return out
end

function J.Text(e)
	local k = e.kind
	if k == "start" then
		if e.zone and e.zone ~= "" then
			return L.J_START:format(e.level or 1, e.zone)
		end
		return L.J_START_NOWHERE:format(e.level or 1)
	elseif k == "level" then
		if e.group then
			return L.J_LEVELS:format(e.from or 0, e.level or 0)
		end
		return L.J_LEVEL:format(e.level or 0)
	elseif k == "zone" then
		return L.J_ZONE:format(e.name or e.zone or "?")
	elseif k == "boss" then
		return (e.first and L.J_BOSS_FIRST or L.J_BOSS):format(e.name or "?")
	elseif k == "death" then
		return L.J_DEATH:format(e.zone or "?")
	elseif k == "quest" then
		return e.title and L.J_QUEST:format(e.title) or L.J_QUEST_UNKNOWN:format(e.quest or 0)
	elseif k == "loot" then
		return L.J_LOOT:format(e.link or e.name or "?")
	elseif k == "achievement" then
		if e.legacy then
			return L.J_LEGACY:format(e.link or e.name or "?", e.legacy)
		end
		return L.J_ACHIEVEMENT:format(e.link or e.name or "?")
	elseif k == "camp" then
		return L.J_CAMP
	elseif k == "blueprint" then
		return L.J_BLUEPRINT:format(e.name or "?", e.profession or "?")
	elseif k == "money" then
		return L.J_MONEY:format(GetMoneyString and GetMoneyString(e.amount or 0) or tostring(math.floor((e.amount or 0) / 10000)) .. "g")
	elseif k == "played" then
		return L.J_PLAYED:format(SecondsToTime and SecondsToTime(e.total or 0) or tostring(e.total))
	elseif k == "note" then
		return L.J_NOTE:format(e.text or "")
	end
	return k
end

-- Every word of the query (already lower case) in the entry's text or place.
function J.Matches(e, query)
	local hay = string.lower(ns.PlainText(J.Text(e) .. " " .. (e.zone or "") .. " " .. (e.sub or "")))
	for w in query:gmatch("%S+") do
		if not hay:find(w, 1, true) then
			return false
		end
	end
	return true
end

function J.Summary(charKey)
	local c = ns.Char(charKey)
	local s = { entries = 0, bosses = 0, deaths = 0, level = UnitLevel("player") or 0 }
	if not c then
		return s
	end
	s.entries = #c.journal
	for _, e in ipairs(c.journal) do
		if e.kind == "boss" then
			s.bosses = s.bosses + 1
		elseif e.kind == "death" then
			s.deaths = s.deaths + 1
		end
	end
	return s
end

-- Event handlers ---------------------------------------------------------------------------------

function J.OnLogin()
	local c = ns.Char()
	if not c then
		return
	end
	local _, class = UnitClass("player")
	local _, race = UnitRace("player")
	c.class = ns.Plain(class) or c.class
	c.race = ns.Plain(race) or c.race
	c.level = UnitLevel("player")
	J.StartSession()
	local back = not c.isNew and J.WhereWas()
	if c.isNew then
		c.isNew = nil
		J.MarkMoneySeen()
		J.Add("start", { played = J.Played() })
	end
	J.OnZoneChanged(true)
	if back then
		local text = L.WHERE_WAS:format(back.days, back.zone, back.level)
		if back.note then
			text = text .. " " .. L.WHERE_WAS_NOTE:format(back.note)
		end
		ns.Say("whereWas", text, true)
	end
end

function J.OnLevelUp(level)
	local c = ns.Char()
	if c then
		c.level = level
	end
	J.Add("level", { level = level, played = J.Played() })
end

-- Time played, kept by the addon: the seconds the game reported last (/played) plus what this session
-- added since, or just the sessions this addon saw if the game never said. Written into each level entry,
-- so the Progress tab can tell how long each level took.
function J.Played()
	local c = ns.Char()
	if not c or not c.playtime then
		return nil
	end
	local p = c.playtime
	return (p.acc or 0) + (p.sessionStart and math.max(0, time() - p.sessionStart) or 0)
end

function J.StartSession()
	local c = ns.Char()
	if not c then
		return
	end
	c.playtime = c.playtime or { acc = 0 }
	c.playtime.sessionStart = time()
end

-- Every tick and at logout: fold this session into the total, so a crash loses at most a tick's worth.
function J.OnTick()
	local c = ns.Char()
	local p = c and c.playtime
	if not p or not p.sessionStart then
		return
	end
	local now = time()
	p.acc = (p.acc or 0) + math.max(0, now - p.sessionStart)
	p.sessionStart = now
end

-- First visit of a zone (by map ID; by name where the game gives no map). silent: just remember it.
function J.OnZoneChanged(silent)
	local c = ns.Char()
	if not c then
		return
	end
	local where = ns.Where()
	-- the start entry is written at login, when the zone text can still be empty: fill it in now
	if where.zone ~= "" then
		for i = #c.journal, math.max(1, #c.journal - 5), -1 do
			local e = c.journal[i]
			if e.kind == "start" and (not e.zone or e.zone == "") then
				e.zone, e.sub = where.zone, where.sub ~= "" and where.sub or nil
				ns.Fire("journal", e)
			end
		end
	end
	local key = where.mapID and ("m" .. where.mapID) or (where.zone ~= "" and ("z" .. where.zone)) or nil
	if not key or c.visited[key] then
		return
	end
	c.visited[key] = true
	if not silent then
		local name = where.zone
		if where.mapID then
			local info = C_Map.GetMapInfo(where.mapID)
			name = info and info.name or name
		end
		J.Add("zone", { name = name, mapID = where.mapID })
	end
end

local function recordBoss(id, name)
	local c = ns.Char()
	if not c then
		return
	end
	id = tonumber(id) or 0
	local now = GetTime()
	if lastBoss and lastBoss.id == id and now - lastBoss.t < 30 then
		return
	end
	lastBoss = { id = id, t = now }
	c.bosses[id] = (c.bosses[id] or 0) + 1
	J.Add("boss", { boss = id, name = name, first = c.bosses[id] == 1 or nil, group = GetNumGroupMembers() })
end

function J.OnEncounterEnd(encounterID, encounterName, _, _, success)
	if success == 1 or success == true then
		recordBoss(encounterID, ns.Plain(encounterName))
	end
end

function J.OnBossKill(encounterID, encounterName)
	recordBoss(encounterID, ns.Plain(encounterName))
end

-- In Forever PLAYER_DEAD fires twice for one death (reported in the beta, 1.60.1): one entry per death.
local lastDeath
function J.OnDead()
	local now = GetTime()
	if lastDeath and now - lastDeath < 5 then
		return
	end
	lastDeath = now
	J.Add("death")
end

function J.OnQuestTurnedIn(questID)
	if not ns.db.settings.journalQuests then
		return
	end
	local title = C_QuestLog.GetTitleForQuestID(questID)
	J.Add("quest", { quest = questID, title = ns.Plain(title) })
end

local lootPatterns
local function buildLootPatterns()
	lootPatterns = {}
	for _, key in ipairs({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" }) do
		local fmt = _G[key]
		if type(fmt) == "string" then
			table.insert(lootPatterns, ns.PatternFromFormat(fmt))
		end
	end
end

-- "You receive loot: [Item]" for the player only; items of the chosen quality or better.
function J.OnLoot(text)
	text = ns.Plain(text)
	if type(text) ~= "string" then
		return
	end
	if not lootPatterns then
		buildLootPatterns()
	end
	local link
	for _, p in ipairs(lootPatterns) do
		link = text:match(p)
		if link then
			break
		end
	end
	if not link or not link:find("|Hitem:", 1, true) then
		return
	end
	local quality = C_Item.GetItemQualityByID(link)
	if quality and quality >= (ns.db.settings.lootQuality or 4) then
		local itemID = C_Item.GetItemInfoInstant(link)
		J.Add("loot", { link = link, item = itemID, quality = quality, name = ns.PlainText(link) })
	end
end

function J.OnAchievement(achievementID)
	local _, name = GetAchievementInfo(achievementID)
	local points = J.LegacyPoints(achievementID)
	J.Add("achievement", { achievement = achievementID, name = name, link = GetAchievementLink(achievementID), legacy = points > 0 and points or nil })
end

-- Your first campfire: one entry per character.
function J.OnSpellcast(unit, _, spellID)
	local c = ns.Char()
	if unit ~= "player" or not c or c.camped then
		return
	end
	spellID = ns.Plain(spellID)
	if type(spellID) ~= "number" then
		return
	end
	local hit = J.CAMPFIRE_SPELLS[spellID]
	if not hit and C_Spell and C_Spell.GetSpellName then
		local name = ns.Plain(C_Spell.GetSpellName(spellID))
		hit = type(name) == "string" and J.CAMPFIRE_NAMES[string.lower(name)]
	end
	if hit then
		c.camped = true
		J.Add("camp", { spell = spellID })
	end
end

-- A camping blueprint learned (NEW_RECIPE_LEARNED): known by the camp object its recipe builds.
function J.OnRecipeLearned(recipeID)
	recipeID = ns.Plain(recipeID)
	local f = C_TradeSkillUI and C_TradeSkillUI.GetRecipeSchematic
	if type(recipeID) ~= "number" or not f then
		return
	end
	local s = f(recipeID, false)
	local out = s and ns.Plain(s.outputItemID)
	local b = out and J.BLUEPRINTS[out]
	local c = ns.Char()
	if not b or not c then
		return
	end
	c.blueprints = c.blueprints or {}
	if c.blueprints[out] then
		return
	end
	c.blueprints[out] = true
	J.Add("blueprint", { item = out, name = b[1], profession = b[2] })
end

-- "Where was I": after some days away, one chat line with where the journal left this character.
-- { days, zone, level, note } or nil when the journal is new or recent.
function J.WhereWas(charKey, now)
	local c = ns.Char(charKey)
	if not c or #c.journal == 0 then
		return nil
	end
	now = now or time()
	local last = c.journal[#c.journal]
	local days = math.floor((now - (last.t or now)) / 86400)
	local minDays = tonumber(ns.db.settings.whereDays) or 2
	if days < minDays then
		return nil
	end
	local note
	for i = #c.journal, math.max(1, #c.journal - 20), -1 do
		local e = c.journal[i]
		if e.kind == "note" and e.text then
			note = e.text
			break
		end
	end
	local zone = last.zone
	for i = #c.journal, 1, -1 do
		if c.journal[i].zone and c.journal[i].zone ~= "" then
			zone = c.journal[i].zone
			break
		end
	end
	return { days = days, zone = zone or "?", level = last.level or c.level or 0, note = note }
end

function J.OnMoney()
	local c = ns.Char()
	if not c then
		return
	end
	local money = GetMoney()
	for _, step in ipairs(J.MONEY_STEPS) do
		if money >= step and not c.money[step] then
			c.money[step] = true
			J.Add("money", { amount = step })
		end
	end
end

-- Money milestones already passed before the journal started are not news.
function J.MarkMoneySeen()
	local c = ns.Char()
	if not c then
		return
	end
	local money = GetMoney()
	for _, step in ipairs(J.MONEY_STEPS) do
		if money >= step then
			c.money[step] = true
		end
	end
end

function J.OnTimePlayed(total, thisLevel)
	local c = ns.Char()
	if not c then
		return
	end
	local t = time()
	local last = c.played
	c.played = { total = total, level = thisLevel, t = t }
	-- the game's count is the truth (it also covers time before the addon): re-anchor the session clock,
	-- and move the marks already written by the same amount so the time between them stays right
	if type(total) == "number" and not issecretvalue(total) then
		local estimate = J.Played()
		c.playtime = c.playtime or {}
		c.playtime.acc = total
		c.playtime.sessionStart = t
		local delta = estimate and (total - estimate) or 0
		if delta ~= 0 then
			for _, e in ipairs(c.journal) do
				if type(e.played) == "number" then
					e.played = e.played + delta
				end
			end
		end
	end
	if not last or t - (last.t or 0) >= 86400 then
		J.Add("played", { total = total })
	end
end

function J.AddManual(text)
	text = ns.Trim(text)
	if text == "" then
		return nil
	end
	return J.Add("note", { text = text })
end
