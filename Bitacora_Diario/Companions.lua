local _, ns = ...

-- "Compañeros": the people you grouped with, for the whole account. One record per Name-Realm:
-- { name, realm, class, first = epoch, last = epoch, zone = where you last met, times = groups shared,
--   with = { [charKey] = true } }. Nothing is sent anywhere; it only reads the party and raid units.

local Co = {}
ns.Companions = Co

Co.CAP = 500

local current = {} -- key -> true: who is in the group right now, so a roster change counts a person once

local function keyOf(unit)
	local name, realm = UnitName(unit)
	name = ns.Plain(name)
	-- a member whose name has not arrived yet is "Unknown" (UNKNOWNOBJECT); the next roster update retries
	if Co.IsUnknown(name) then
		return nil
	end
	realm = ns.Plain(realm)
	if not realm or realm == "" then
		realm = GetNormalizedRealmName and GetNormalizedRealmName() or ""
	end
	return name .. "-" .. realm, name, realm
end

-- A name that never arrived: the game's "Unknown" (UNKNOWNOBJECT, translated in other clients) or empty.
local NOT_A_NAME = { Unknown = true, Desconocido = true, [""] = true }
function Co.IsUnknown(name)
	return not name or NOT_A_NAME[name] or name == UNKNOWNOBJECT
end

function Co.List()
	ns.db.companions = ns.db.companions or {}
	if not Co.cleaned then
		-- records saved before the filter (or from a client in another language) are dropped once per session
		Co.cleaned = true
		for key, c in pairs(ns.db.companions) do
			if type(c) ~= "table" or Co.IsUnknown(c.name) then
				ns.db.companions[key] = nil
			end
		end
	end
	return ns.db.companions
end

-- Drop the people seen longest ago until the list fits.
local function trim(list)
	local n = 0
	for _ in pairs(list) do
		n = n + 1
	end
	while n > Co.CAP do
		local oldestKey, oldest
		for key, c in pairs(list) do
			if not oldest or (c.last or 0) < oldest then
				oldestKey, oldest = key, c.last or 0
			end
		end
		list[oldestKey] = nil
		n = n - 1
	end
end

-- The group changed: anyone new to it is a shared group (once per person per group).
function Co.OnRoster()
	local list = Co.List()
	local now = time()
	local where = ns.Where()
	local seen = {}
	local changed = false
	for _, unit in ipairs(ns.GroupUnits()) do
		local key, name, realm = keyOf(unit)
		if key then
			seen[key] = true
			if not current[key] then
				local c = list[key]
				if not c then
					c = { name = name, realm = realm, first = now, times = 0, with = {} }
					list[key] = c
				end
				local _, class = UnitClass(unit)
				class = ns.Plain(class)
				if class then
					c.class = class
				end
				c.last = now
				c.zone = where.zone ~= "" and where.zone or c.zone
				c.times = (c.times or 0) + 1
				local me = ns.CharKey()
				if me then
					c.with[me] = true
				end
				changed = true
			end
		end
	end
	current = seen
	if changed then
		trim(list)
		ns.Fire("companions")
	end
end

-- Sorted by last seen, newest first; display name without your own realm.
function Co.Sorted()
	local out = {}
	for key, c in pairs(Co.List()) do
		table.insert(out, { key = key, label = Ambiguate(key, "none"), name = c.name, realm = c.realm, class = c.class, first = c.first, last = c.last, zone = c.zone, times = c.times or 0 })
	end
	table.sort(out, function(a, b)
		if (a.last or 0) ~= (b.last or 0) then
			return (a.last or 0) > (b.last or 0)
		end
		return a.key < b.key
	end)
	return out
end
