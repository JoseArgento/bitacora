local _, ns = ...
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

local function fire(r)
	r.fired = time()
	if not r.repeating then
		r.done = true
	end
	ns.Alert(L.REMINDER_FIRED:format(r.text))
	ns.Fire("reminders")
end

-- ctx: { event = "zone", zone, sub, mapID } | { event = "level", level } | { event = "login" }
--      | { event = "place", place } | { event = "tick", now }
function R.Check(ctx, charKey)
	local fired = {}
	for _, r in ipairs(R.List(charKey)) do
		if not r.done then
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
				local now = ctx.now or time()
				local due = R.LastDue(r.value, now)
				-- due now (within 10 minutes, or since the last check when logging in) and not fired for this one yet
				local window = ctx.event == "login" and 6 * 3600 or 600
				hit = due ~= nil and now - due <= window and (r.fired or 0) < due and (r.created or 0) <= due
			end
			if hit then
				fire(r)
				table.insert(fired, r)
			end
		end
	end
	return fired
end
