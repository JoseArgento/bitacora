local _, ns = ...
local L = ns.L

local J = {}
ns.Journal = J

-- Entries keep raw facts (kind + fields), never translated text, so the web page and the UI can word them.
-- { t = epoch, d = "YYYY-MM-DD HH:MM", kind = "...", level = n, zone = "...", ... }

J.MILESTONES = { start = true, level = true, zone = true, boss = true, death = true, achievement = true, loot = true, money = true, note = true }
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

function J.Text(e)
	local k = e.kind
	if k == "start" then
		return L.J_START:format(e.level or 1, e.zone or "?")
	elseif k == "level" then
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
		return L.J_ACHIEVEMENT:format(e.link or e.name or "?")
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
	if c.isNew then
		c.isNew = nil
		J.MarkMoneySeen()
		J.Add("start")
	end
	J.OnZoneChanged(true)
end

function J.OnLevelUp(level)
	local c = ns.Char()
	if c then
		c.level = level
	end
	J.Add("level", { level = level })
end

-- First visit of a zone (by map ID; by name where the game gives no map). silent: just remember it.
function J.OnZoneChanged(silent)
	local c = ns.Char()
	if not c then
		return
	end
	local where = ns.Where()
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

function J.OnDead()
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
	J.Add("achievement", { achievement = achievementID, name = name, link = GetAchievementLink(achievementID) })
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
