local _, ns = ...
local L = ns.L

local A = {}
ns.Album = A

-- The game names screenshots WoWScrnShot_MMDDYY_HHMMSS.jpg (local time). The addon cannot read the image;
-- it writes down the same stamp plus where and with whom, and the web page puts the two together.

local function groupNames()
	local names = {}
	for _, unit in ipairs(ns.GroupUnits()) do
		local name = ns.Plain(UnitName(unit))
		if name then
			table.insert(names, name)
		end
	end
	return names
end

function A.OnScreenshot()
	local c = ns.Char()
	if not c then
		return
	end
	local t, d = ns.Now()
	local where = ns.Where()
	local shot = {
		t = t,
		d = d,
		stamp = date("%m%d%y_%H%M%S", t),
		level = UnitLevel("player"),
		zone = where.zone,
		sub = where.sub ~= "" and where.sub or nil,
		mapID = where.mapID,
		x = where.x,
		y = where.y,
		group = groupNames(),
	}
	table.insert(c.album, shot)
	ns.Fire("album", shot)
	if ns.db.settings.screenshotChat then
		ns.Print(L.SCREENSHOT_SAVED:format(shot.sub and (shot.sub .. ", " .. shot.zone) or shot.zone))
	end
	return shot
end

function A.List(charKey)
	local c = ns.Char(charKey)
	return c and c.album or {}
end

function A.SetCaption(index, text, charKey)
	local list = A.List(charKey)
	local shot = list[index]
	if not shot then
		return nil
	end
	text = ns.Trim(text)
	shot.caption = text ~= "" and text or nil
	ns.Fire("album", shot)
	return shot
end

function A.Delete(index, charKey)
	local list = A.List(charKey)
	if list[index] then
		table.remove(list, index)
		ns.Fire("album")
		return true
	end
	return false
end

function A.Describe(shot)
	local where = shot.sub and (shot.sub .. ", " .. (shot.zone or "")) or (shot.zone or "")
	local bits = { shot.d or "", where }
	if shot.group and #shot.group > 0 then
		table.insert(bits, L.WITH:format(table.concat(shot.group, ", ")))
	end
	return table.concat(bits, " · ")
end
