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
		return L.R_DESC_LOGIN
	elseif r.kind == "place" then
		return L.R_DESC_PLACE:format(L[R.PLACE_LABEL[r.value] or "PLACE_MAIL"])
	elseif r.kind == "time" then
		local v = r.value
		local day = v.wday and v.wday >= 1 and v.wday <= 7 and L.WEEKDAYS[v.wday] or L.EVERY_DAY
		return L.R_DESC_TIME:format(day, v.hour, v.min)
	elseif r.kind == "reset" then
		return L.R_DESC_RESET:format(r.value)
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
