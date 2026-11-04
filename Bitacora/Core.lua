local ADDON, ns = ...
local L = ns.L

ns.DB_VERSION = 1
ns.IMAGE_FOLDER = "Interface\\AddOns\\BitacoraImagenes\\"

-- Callbacks so the UI refreshes when data changes: ns.Fire("notes"), ns.On("notes", fn)
local listeners = {}
function ns.On(topic, fn)
	listeners[topic] = listeners[topic] or {}
	table.insert(listeners[topic], fn)
end
function ns.Fire(topic, ...)
	for _, fn in ipairs(listeners[topic] or {}) do
		fn(...)
	end
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff8fd1c4" .. L.TITLE .. "|r: " .. msg)
end

-- Midnight-era APIs can hand back "secret" values that addons may not read; treat them as missing.
function ns.Plain(value)
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	return value
end

function ns.Now()
	return time(), date("%Y-%m-%d %H:%M")
end

function ns.Trim(s)
	return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

function ns.Lower(s)
	return string.lower(ns.Trim(s))
end

-- Text without colour codes and hyperlink markup, for search and previews: "|cff..|Hitem:..|h[Sword]|h|r" -> "[Sword]"
function ns.PlainText(s)
	s = tostring(s or "")
	s = s:gsub("|H.-|h(.-)|h", "%1")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	s = s:gsub("|T.-|t", ""):gsub("|A.-|a", "")
	return s
end

function ns.Preview(s, n)
	s = ns.PlainText(s):gsub("%s+", " ")
	s = ns.Trim(s)
	n = n or 60
	if #s > n then
		-- do not cut a UTF-8 character in half
		local cut = n
		while cut > 1 and s:byte(cut + 1) and s:byte(cut + 1) >= 128 and s:byte(cut + 1) < 192 do
			cut = cut - 1
		end
		s = s:sub(1, cut) .. "…"
	end
	return s
end

-- Lua pattern from a GlobalStrings format: "You receive loot: %sx%d" -> "^You receive loot: (.+)x(%d+)$"
function ns.PatternFromFormat(fmt)
	local p = fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
	p = p:gsub("%%%d+%%%$s", "(.+)") -- positional "%1$s" (its "$" is escaped by now)
	p = p:gsub("%%%d+%%%$d", "(%%d+)")
	p = p:gsub("%%s", "(.+)")
	p = p:gsub("%%d", "(%%d+)")
	return "^" .. p .. "$"
end

local function copyDefaults(dst, src)
	for k, v in pairs(src) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			copyDefaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

ns.DEFAULTS = {
	version = ns.DB_VERSION,
	nextId = 1,
	settings = {
		lootQuality = 4, -- epic
		journalQuests = true,
		tooltipNotes = true,
		zoneNotes = true,
		screenshotChat = true,
	},
	sections = {},
	notes = {},
	reminders = {},
	chars = {},
}

function ns.InitDB()
	if type(BitacoraDB) ~= "table" then
		BitacoraDB = {}
	end
	copyDefaults(BitacoraDB, ns.DEFAULTS)
	ns.db = BitacoraDB
	if #ns.db.sections == 0 then
		table.insert(ns.db.sections, { id = ns.NewID("s"), name = L.GENERAL })
	end
	ns.db.version = ns.DB_VERSION
end

function ns.NewID(prefix)
	local n = ns.db.nextId
	ns.db.nextId = n + 1
	return prefix .. n
end

-- One key per character. Forever names are unique per region, but the realm keeps alts on other realms apart.
function ns.CharKey()
	if ns.charKey then
		return ns.charKey
	end
	local name, realm = UnitFullName("player")
	name, realm = ns.Plain(name), ns.Plain(realm)
	if not name then
		return nil
	end
	realm = realm and realm ~= "" and realm or (GetRealmName() or ""):gsub("%s", "")
	ns.charKey = name .. "-" .. realm
	return ns.charKey
end

function ns.Char(key)
	key = key or ns.CharKey()
	if not key then
		return nil
	end
	local c = ns.db.chars[key]
	if not c then
		local name, realm = strsplit("-", key, 2)
		c = { name = name, realm = realm, created = time(), journal = {}, album = {}, visited = {}, bosses = {}, money = {} }
		ns.db.chars[key] = c
		c.isNew = true
	end
	return c
end

-- Where the player is: names for display, map ID for matching.
function ns.Where()
	local mapID = C_Map.GetBestMapForUnit("player")
	local zone = GetRealZoneText() or GetZoneText() or ""
	local sub = GetSubZoneText() or ""
	local x, y
	if mapID then
		local pos = C_Map.GetPlayerMapPosition(mapID, "player")
		if pos then
			x, y = pos:GetXY()
			x, y = ns.Plain(x), ns.Plain(y)
			if x and y then
				x, y = math.floor(x * 1000 + 0.5) / 10, math.floor(y * 1000 + 0.5) / 10
			end
		end
	end
	return { mapID = mapID, zone = zone, sub = sub ~= zone and sub or "", x = x, y = y }
end
