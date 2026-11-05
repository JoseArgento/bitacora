local ADDON, ns = ...
local L = ns.L

local R = {}
ns.Reminders = R

-- A reminder: { id, text, kind, value, char = "Name-Realm" or nil, repeating, done, fired = epoch }
--   kind "zone":  value = zone or subzone name (any case), mapID optional
--   kind "level": value = level number
--   kind "login": no value
--   kind "place": value = "MAIL" | "BANK" | "MERCHANT" | "AUCTION"
--   kind "time":  value = { wday = 1-7 (1 = Sunday) or 0 for every day, hour = 0-23, min = 0-59 }
--   kind "reset": value = hours before the weekly reset (1-168); week = the reset it last fired for
--   kind "calendar": value = { at = epoch (on your computer's clock), title, minutes }: an event of the game's
--                    calendar, rung `minutes` before it starts (once)

R.PLACES = { "MAIL", "BANK", "MERCHANT", "AUCTION" }
R.PLACE_LABEL = { MAIL = "PLACE_MAIL", BANK = "PLACE_BANK", MERCHANT = "PLACE_MERCHANT", AUCTION = "PLACE_AUCTION" }

function R.Create(fields)
	local text = ns.Trim(fields.text)
	if text == "" or not fields.kind then
		return nil
	end
	local r = {
		id = ns.NewID("r"),
		text = text,
		kind = fields.kind,
		value = fields.value,
		mapID = fields.mapID,
		char = fields.char,
		repeating = fields.repeating and true or nil,
		created = time(),
	}
	if r.kind == "level" then
		r.value = tonumber(r.value)
		if not r.value then
			return nil
		end
	elseif r.kind == "zone" then
		r.value = ns.Trim(r.value)
		if r.value == "" and not r.mapID then
			return nil
		end
	elseif r.kind == "reset" then
		r.value = tonumber(r.value)
		if not r.value or r.value < 1 or r.value > 168 then
			return nil
		end
		r.value = math.floor(r.value)
	elseif r.kind == "time" then
		local v = r.value
		if type(v) ~= "table" or not tonumber(v.hour) or not tonumber(v.min) then
			return nil
		end
		r.value = { wday = tonumber(v.wday) or 0, hour = tonumber(v.hour) % 24, min = tonumber(v.min) % 60 }
	elseif r.kind == "calendar" then
		local v = r.value
		if type(v) ~= "table" or not tonumber(v.at) then
			return nil
		end
		r.value = { at = math.floor(tonumber(v.at)), title = ns.Trim(v.title), minutes = math.max(1, math.floor(tonumber(v.minutes) or 60)) }
	end
	table.insert(ns.db.reminders, r)
	ns.Fire("reminders")
	return r
end

function R.Delete(id)
	for i, r in ipairs(ns.db.reminders) do
		if r.id == id then
			table.remove(ns.db.reminders, i)
			ns.Fire("reminders")
			return true
		end
	end
	return false
end

function R.Reactivate(id)
	for _, r in ipairs(ns.db.reminders) do
		if r.id == id then
			r.done, r.fired = nil, nil
			ns.Fire("reminders")
			return r
		end
	end
end

function R.List(charKey)
	local out = {}
	for _, r in ipairs(ns.db.reminders) do
		if r.char == nil or r.char == charKey then
			table.insert(out, r)
		end
	end
	return out
end

function R.Describe(r)
	if r.kind == "zone" then
		return L.R_DESC_ZONE:format(r.value ~= "" and r.value or "?")
	elseif r.kind == "level" then
		return L.R_DESC_LEVEL:format(r.value)
	elseif r.kind == "login" then
		if r.from then
			return L.R_DESC_FROM:format(r.from)
		end
		return L.R_DESC_LOGIN
	elseif r.kind == "place" then
		return L.R_DESC_PLACE:format(L[R.PLACE_LABEL[r.value] or "PLACE_MAIL"])
	elseif r.kind == "time" then
		local v = r.value
		local day = v.wday and v.wday >= 1 and v.wday <= 7 and L.WEEKDAYS[v.wday] or L.EVERY_DAY
		return L.R_DESC_TIME:format(day, v.hour, v.min)
	elseif r.kind == "reset" then
		return L.R_DESC_RESET:format(r.value)
	elseif r.kind == "calendar" then
		local v = r.value
		return L.R_DESC_CALENDAR:format(v.minutes or 60, date("%d/%m %H:%M", v.at or 0))
	end
	return r.kind
end

-- Most recent moment (epoch) at or before now when a "time" reminder was due.
function R.LastDue(v, now)
	local t = date("*t", now)
	local base = time({ year = t.year, month = t.month, day = t.day, hour = v.hour, min = v.min, sec = 0 })
	for back = 0, 7 do
		local cand = base - back * 86400
		-- re-normalise through date/time so daylight saving changes do not shift the hour
		local ct = date("*t", cand)
		cand = time({ year = ct.year, month = ct.month, day = ct.day, hour = v.hour, min = v.min, sec = 0 })
		if cand <= now and (v.wday == 0 or date("*t", cand).wday == v.wday) then
			return cand
		end
	end
	return nil
end

-- The next weekly reset (epoch, rounded to the hour) from the game; nil when the game does not say.
function R.NextReset()
	local f = C_DateAndTime and C_DateAndTime.GetSecondsUntilWeeklyReset
	local secs = f and f()
	if type(secs) ~= "number" or issecretvalue(secs) or secs <= 0 then
		return nil
	end
	return math.floor((GetServerTime() + secs) / 3600 + 0.5) * 3600, secs
end

-- The clock day-and-time reminders go by: your computer's (settings.clock = "local") or the realm's
-- ("realm"). As an epoch that date()/time() read in local time, so the same arithmetic serves both.
function R.Now(now)
	now = now or time()
	if ns.db.settings.clock ~= "realm" then
		return now
	end
	local ct = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
	if type(ct) ~= "table" or not tonumber(ct.year) then
		return now
	end
	return time({ year = ct.year, month = ct.month, day = ct.monthDay, hour = ct.hour, min = ct.minute, sec = 0 })
end

-- How far back a login looks for day-and-time reminders that came due while you were out: since the last
-- time the addon was running (kept in settings.lastSeen), at most 30 days; 6 hours if it never ran.
R.CATCHUP_MAX = 30 * 86400
R.CATCHUP_DEFAULT = 6 * 3600

local POPUP = string.upper(ADDON) .. "_REMINDER"

local function fire(r)
	r.fired = time()
	r.snooze = nil
	if not r.repeating then
		r.done = true
	end
	ns.Alert(L.REMINDER_FIRED:format(r.text))
	if ns.db.settings.reminderPopup ~= false and StaticPopupDialogs[POPUP] then
		StaticPopup_Show(POPUP, r.text, nil, { id = r.id })
	end
	ns.Fire("reminders")
end

-- Snooze: ring again in `minutes`, even a one-time reminder that was just marked done.
function R.Snooze(id, minutes)
	minutes = tonumber(minutes)
	if not minutes or minutes <= 0 then
		return nil
	end
	for _, r in ipairs(ns.db.reminders) do
		if r.id == id then
			r.done = nil
			r.snooze = time() + math.floor(minutes * 60)
			ns.Fire("reminders")
			return r
		end
	end
end

StaticPopupDialogs[POPUP] = {
	text = "%s",
	button1 = OKAY,
	button2 = L.SNOOZE:format(5),
	button3 = L.SNOOZE:format(10),
	button4 = L.SNOOZE:format(15),
	OnButton2 = function(_, data)
		R.Snooze(data and data.id, 5)
	end,
	OnButton3 = function(_, data)
		R.Snooze(data and data.id, 10)
	end,
	OnButton4 = function(_, data)
		R.Snooze(data and data.id, 15)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- ctx: { event = "zone", zone, sub, mapID } | { event = "level", level } | { event = "login" }
--      | { event = "place", place } | { event = "tick", now }
function R.Check(ctx, charKey)
	local fired = {}
	local real = ctx.now or time()
	local now = R.Now(real)
	local shift = now - real -- the realm clock, as an offset on your computer's
	-- a login looks back to the last tick the addon saw (real time), moved to the same clock
	local since
	if ctx.event == "login" then
		local lastSeen = tonumber(ns.db.settings.lastSeen)
		if lastSeen and real - lastSeen <= R.CATCHUP_MAX and real - lastSeen >= 0 then
			since = lastSeen + shift
		else
			since = now - R.CATCHUP_DEFAULT
		end
	end
	for _, r in ipairs(R.List(charKey)) do
		if r.snooze and (ctx.event == "tick" or ctx.event == "login") then
			if real >= r.snooze then
				fire(r)
				table.insert(fired, r)
			end
		elseif not r.done then
			local hit = false
			if r.kind == "zone" and ctx.event == "zone" then
				local want = ns.Lower(r.value)
				hit = (r.mapID ~= nil and r.mapID == ctx.mapID)
					or (want ~= "" and (want == ns.Lower(ctx.zone) or want == ns.Lower(ctx.sub)))
			elseif r.kind == "level" and (ctx.event == "level" or ctx.event == "login") then
				hit = (ctx.level or 0) >= r.value
			elseif r.kind == "login" and ctx.event == "login" then
				hit = true
			elseif r.kind == "place" and ctx.event == "place" then
				hit = r.value == ctx.place
			elseif r.kind == "reset" and (ctx.event == "tick" or ctx.event == "login") then
				local nextReset, secs = R.NextReset()
				-- once per week, from N hours before the reset until it happens
				hit = nextReset ~= nil and secs <= r.value * 3600 and r.week ~= nextReset
				if hit then
					r.week = nextReset
				end
			elseif r.kind == "calendar" and (ctx.event == "tick" or ctx.event == "login") then
				local v = r.value
				-- from `minutes` before the event until it starts; not again once rung
				hit = type(v) == "table" and v.at ~= nil and real >= v.at - (v.minutes or 60) * 60 and real <= v.at and not r.fired
			elseif r.kind == "time" and (ctx.event == "tick" or ctx.event == "login") then
				local due = R.LastDue(r.value, now)
				-- due now (within 10 minutes), or while you were out (since the addon last ran) when logging in;
				-- never twice for the same moment, and not for a moment before it was written
				local okWindow = ctx.event == "login" and (due ~= nil and due > since) or (due ~= nil and now - due <= 600)
				hit = okWindow and (r.fired or 0) + shift < due and (r.created or 0) + shift <= due
			end
			if hit then
				fire(r)
				table.insert(fired, r)
			end
		end
	end
	if ctx.event == "tick" or ctx.event == "login" then
		ns.db.settings.lastSeen = real
	end
	return fired
end

-- The game's calendar ---------------------------------------------------------------------------
-- Guild events (and the ones you were invited to) of the next 7 days. Each new one is offered once as a
-- reminder `settings.calendarMinutes` before it starts: a popup with Yes / No / Always, or made without
-- asking once "Always" was chosen (settings.calendarAuto). Times come in the realm's clock
-- (C_DateAndTime.GetCurrentCalendarTime) and are moved to your computer's.

R.CALENDAR_DAYS = 7
local CALENDAR_TYPES = { GUILD_EVENT = true, GUILD_ANNOUNCEMENT = true, PLAYER = true }
local CALENDAR_POPUP = string.upper(ADDON) .. "_CALENDAR"

-- seconds the realm's calendar clock is ahead of your computer's (0 when the game does not say)
local function realmShift()
	local ct = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
	if type(ct) ~= "table" or not tonumber(ct.year) then
		return 0
	end
	return time({ year = ct.year, month = ct.month, day = ct.monthDay, hour = ct.hour, min = ct.minute, sec = 0 }) - time()
end

local function calendarTime(t)
	if type(t) ~= "table" or not tonumber(t.year) or not tonumber(t.month) or not tonumber(t.monthDay) then
		return nil
	end
	return time({ year = t.year, month = t.month, day = t.monthDay, hour = tonumber(t.hour) or 0, min = tonumber(t.minute) or 0, sec = 0 })
end

-- The upcoming events as { key, title, at (your clock), kind }; empty when the calendar is not there.
function R.CalendarEvents()
	local out = {}
	local C = C_Calendar
	if not C or not C.GetNumDayEvents or not C.GetDayEvent or not C.GetMonthInfo then
		return out
	end
	local today = C_DateAndTime and C_DateAndTime.GetCurrentCalendarTime and C_DateAndTime.GetCurrentCalendarTime()
	if type(today) ~= "table" or not tonumber(today.monthDay) then
		return out
	end
	local shift = realmShift()
	local offset, day = 0, today.monthDay
	local month = C.GetMonthInfo(0)
	local numDays = type(month) == "table" and tonumber(month.numDays) or 31
	for _ = 1, R.CALENDAR_DAYS do
		local n = ns.Plain(C.GetNumDayEvents(offset, day))
		for i = 1, (type(n) == "number" and n or 0) do
			local e = C.GetDayEvent(offset, day, i)
			local title = e and ns.Plain(e.title)
			local at = e and calendarTime(e.startTime)
			local kind = e and ns.Plain(e.calendarType)
			if type(title) == "string" and title ~= "" and at and CALENDAR_TYPES[kind] then
				at = at - shift
				local key = string.format("%s@%d", title, at)
				table.insert(out, { key = key, title = title, at = at, kind = kind })
			end
		end
		day = day + 1
		if day > numDays then
			offset, day = offset + 1, 1
			local next = C.GetMonthInfo(offset)
			numDays = type(next) == "table" and tonumber(next.numDays) or 31
		end
	end
	return out
end

-- A reminder for one event, if none exists for it yet.
function R.FromCalendar(e)
	for _, r in ipairs(ns.db.reminders) do
		if r.kind == "calendar" and r.value and r.value.key == e.key then
			return nil
		end
	end
	local r = R.Create({ text = e.title, kind = "calendar", value = { at = e.at, title = e.title, minutes = ns.db.settings.calendarMinutes or 60 } })
	if r then
		r.value.key = e.key
	end
	return r
end

-- Look at the calendar: new events are offered (or taken, with calendarAuto); each event is offered once.
function R.ScanCalendar()
	if ns.db.settings.calendar == false then
		return {}
	end
	if C_Calendar and C_Calendar.OpenCalendar then
		C_Calendar.OpenCalendar()
		ns.calendarWanted = true -- CALENDAR_UPDATE_EVENT_LIST brings the data; Events.lua looks again then
	end
	ns.db.calendarSeen = ns.db.calendarSeen or {}
	local seen = ns.db.calendarSeen
	local now = time()
	-- forget the ones that went by
	for key, at in pairs(seen) do
		if type(at) == "number" and at < now - 86400 then
			seen[key] = nil
		end
	end
	local new = {}
	for _, e in ipairs(R.CalendarEvents()) do
		if not seen[e.key] and e.at > now then
			seen[e.key] = e.at
			table.insert(new, e)
		end
	end
	table.sort(new, function(a, b)
		return a.at < b.at
	end)
	for i, e in ipairs(new) do
		if ns.db.settings.calendarAuto then
			R.FromCalendar(e)
		elseif StaticPopupDialogs[CALENDAR_POPUP] then
			-- one popup per event, a moment apart so they stack in order
			C_Timer.After(0.2 * (i - 1), function()
				StaticPopup_Show(CALENDAR_POPUP, e.title, date("%a %d/%m %H:%M", e.at), { event = e })
			end)
		end
	end
	return new
end

StaticPopupDialogs[CALENDAR_POPUP] = {
	text = L.CALENDAR_ASK,
	button1 = YES,
	button2 = NO,
	button3 = L.CALENDAR_ALWAYS,
	OnAccept = function(_, data)
		if data and data.event then
			R.FromCalendar(data.event)
		end
	end,
	OnAlt = function(_, data)
		ns.db.settings.calendarAuto = true
		if data and data.event then
			R.FromCalendar(data.event)
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- The campsite buff -------------------------------------------------------------------------------
-- "Your camp is almost over": 5 minutes before the campsite buff ends, once per buff. Aura times can be
-- secret (in combat, in instances): then nothing is said. ⏳ The buffs' spell IDs are not known yet:
-- matched by ID when the table has one, else by name.

R.CAMP_BUFF_SPELLS = {}
R.CAMP_BUFF_NAMES = { ["campsite"] = true, ["campfire"] = true, ["well rested"] = true, ["campamento"] = true, ["fogata"] = true, ["hoguera"] = true }
R.CAMP_WARN = 5 * 60
local campWarned = {} -- auraInstanceID -> true

function R.CheckCampBuff(now)
	if ns.db.settings.campBuff == false or not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then
		return nil
	end
	now = now or GetTime()
	for i = 1, 40 do
		local a = C_UnitAuras.GetAuraDataByIndex("player", i, "HELPFUL")
		if not a then
			break
		end
		local spellId, name, expires, instance = ns.Plain(a.spellId), ns.Plain(a.name), ns.Plain(a.expirationTime), ns.Plain(a.auraInstanceID)
		local isCamp = (type(spellId) == "number" and R.CAMP_BUFF_SPELLS[spellId]) or (type(name) == "string" and R.CAMP_BUFF_NAMES[string.lower(name)])
		if isCamp and type(expires) == "number" and expires > 0 then
			local key = instance or spellId or name
			local left = expires - now
			if left > 0 and left <= R.CAMP_WARN and not campWarned[key] then
				campWarned[key] = true
				ns.Alert(L.CAMP_ENDING:format(math.ceil(left / 60)))
				return key
			end
		end
	end
	return nil
end
