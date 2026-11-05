local _, ns = ...
local L = ns.L
local UI = ns.UI
local R = ns.Reminders
local G = ns.GuildReminders

local KINDS = {
	{ "zone", "R_ZONE" },
	{ "level", "R_LEVEL" },
	{ "login", "R_LOGIN" },
	{ "place", "R_PLACE" },
	{ "time", "R_TIME" },
	{ "reset", "R_RESET" },
}

-- Left page: the form for a new reminder. Right page: the reminders (on a single page, one under the other).
UI.RegisterTab("TAB_REMINDERS", "reminders", function(page)
	local view = { kind = "zone", place = "MAIL", wday = 0 }
	local left, right = page.left, page.right
	local stacked = right == nil
	right = right or left

	-- form -------------------------------------------------------------------------------------------
	local form = CreateFrame("Frame", nil, left)
	form:SetPoint("TOPLEFT", 0, 0)
	form:SetPoint("TOPRIGHT", 0, 0)
	form:SetHeight(220) -- layout() sets the real height

	local head = UI.Label(form, L.NEW_REMINDER_HEAD, "heading")
	head:SetPoint("TOPLEFT", 0, 0)

	local text = UI.Input(form, 300, nil, L.REMINDER_TEXT)
	text:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -10)
	text:SetPoint("RIGHT", form, "RIGHT", 0, 0)

	local whenLabel = UI.Label(form, L.WHEN, "subheading")
	whenLabel:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	local kindButton = UI.Button(form, "", 150, nil)
	kindButton:SetPoint("LEFT", whenLabel, "RIGHT", 10, 0)

	local value = UI.Input(form, 150, nil, "")
	local valueHint = UI.Label(form, "", "small")
	valueHint:SetJustifyH("LEFT")
	valueHint:SetWordWrap(true)
	local optionButton = UI.Button(form, "", 140, nil) -- place or weekday
	optionButton:SetPoint("TOPLEFT", whenLabel, "BOTTOMLEFT", 0, -12)
	local minute = UI.Input(form, 40, nil, "00")

	local onlyChar = UI.Check(form, L.ONLY_THIS_CHAR)
	local repeating = UI.Check(form, L.REPEAT)
	-- officers can send a day-and-time reminder to the whole guild
	local forGuild = UI.Check(form, L.FOR_GUILD)

	local create = UI.Button(form, L.NEW_REMINDER, 160, nil)

	local function layout()
		local k = view.kind
		for _, pair in ipairs(KINDS) do
			if pair[1] == k then
				kindButton:SetText(L[pair[2]])
			end
		end
		value:SetShown(k == "zone" or k == "level" or k == "time" or k == "reset")
		minute:SetShown(k == "time")
		optionButton:SetShown(k == "place" or k == "time")
		value:ClearAllPoints()
		valueHint:ClearAllPoints()
		-- the second line: option button and/or value
		local anchor
		if k == "time" then
			optionButton:SetText(view.wday == 0 and L.EVERY_DAY or L.WEEKDAYS[view.wday])
			value:SetWidth(40)
			value:SetPoint("LEFT", optionButton, "RIGHT", 10, 0)
			minute:ClearAllPoints()
			minute:SetPoint("LEFT", value, "RIGHT", 6, 0)
			-- the help goes under the line, page-wide: to the right it ran past the page (seen in the client)
			valueHint:SetPoint("TOPLEFT", optionButton, "BOTTOMLEFT", 0, -4)
			valueHint:SetPoint("RIGHT", form, "RIGHT", 0, 0)
			valueHint:SetText(L.R_TIME_HINT)
			anchor = valueHint
		elseif k == "place" then
			optionButton:SetText(L[R.PLACE_LABEL[view.place]])
			anchor = optionButton
		else
			value:SetWidth((k == "level" or k == "reset") and 50 or 220)
			value:SetPoint("TOPLEFT", whenLabel, "BOTTOMLEFT", 0, -12)
			valueHint:SetText(k == "zone" and L.R_ZONE_HINT or k == "level" and L.R_LEVEL_HINT or k == "reset" and L.R_RESET_HINT or "")
			if k == "zone" then
				-- a wide field: its help goes under it, page-wide, never past the page's edge
				valueHint:SetPoint("TOPLEFT", value, "BOTTOMLEFT", 0, -4)
				valueHint:SetPoint("RIGHT", form, "RIGHT", 0, 0)
				anchor = valueHint
			else
				valueHint:SetPoint("LEFT", value, "RIGHT", 8, 0)
				anchor = value
			end
		end
		if k == "login" then
			anchor = kindButton
		end
		valueHint:SetShown(value:IsShown())
		-- the checks under that line
		onlyChar:ClearAllPoints()
		onlyChar:SetPoint("TOPLEFT", anchor == kindButton and whenLabel or anchor, "BOTTOMLEFT", 0, -14)
		repeating:ClearAllPoints()
		forGuild:ClearAllPoints()
		repeating:SetShown(k ~= "level")
		forGuild:SetShown(G ~= nil and G.IAmOfficer() and k == "time")
		onlyChar:SetShown(not (forGuild:IsShown() and forGuild:GetChecked()))
		local prev = onlyChar:IsShown() and onlyChar or nil
		if repeating:IsShown() then
			if prev then
				repeating:SetPoint("LEFT", prev.label, "RIGHT", 16, 0)
			else
				repeating:SetPoint("TOPLEFT", anchor == kindButton and whenLabel or anchor, "BOTTOMLEFT", 0, -14)
			end
			prev = repeating
		end
		local last = prev
		if forGuild:IsShown() then
			if prev then
				forGuild:SetPoint("TOPLEFT", onlyChar:IsShown() and onlyChar or repeating, "BOTTOMLEFT", 0, -8)
			else
				forGuild:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -14)
			end
			last = forGuild
		end
		-- the button goes under the last row of checks (never over them), and the form is as tall as
		-- its rows so what hangs from its bottom (help text, the list on a single page) follows
		create:ClearAllPoints()
		if last then
			create:SetPoint("TOPLEFT", last == repeating and onlyChar:IsShown() and onlyChar or last, "BOTTOMLEFT", 0, -14)
		else
			create:SetPoint("TOPLEFT", anchor == kindButton and whenLabel or anchor, "BOTTOMLEFT", 0, -14)
		end
		local rows = 20 + 10 + 24 + 14 + 26 -- heading, text, "when" line
		if anchor ~= kindButton then
			rows = rows + 12 + 26 -- the value line
		end
		if anchor == valueHint then
			rows = rows + 4 + math.max(14, valueHint:GetStringHeight() or 14) -- its help, under it
		end
		if prev then
			rows = rows + 14 + 18 -- the checks
		end
		if forGuild:IsShown() and prev then
			rows = rows + 8 + 18
		end
		rows = rows + 14 + 26 -- the button
		form:SetHeight(rows)
	end
	forGuild:HookScript("OnClick", layout)

	kindButton:SetScript("OnClick", function(self)
		UI.Menu(self, function(root)
			for _, pair in ipairs(KINDS) do
				root:CreateRadio(L[pair[2]], function()
					return view.kind == pair[1]
				end, function()
					view.kind = pair[1]
					value:SetText("")
					minute:SetText("")
					layout()
				end)
			end
		end)
	end)

	optionButton:SetScript("OnClick", function(self)
		UI.Menu(self, function(root)
			if view.kind == "place" then
				for _, place in ipairs(R.PLACES) do
					root:CreateRadio(L[R.PLACE_LABEL[place]], function()
						return view.place == place
					end, function()
						view.place = place
						layout()
					end)
				end
			else
				root:CreateRadio(L.EVERY_DAY, function()
					return view.wday == 0
				end, function()
					view.wday = 0
					layout()
				end)
				for i, day in ipairs(L.WEEKDAYS) do
					root:CreateRadio(day, function()
						return view.wday == i
					end, function()
						view.wday = i
						layout()
					end)
				end
			end
		end)
	end)

	create:SetScript("OnClick", function()
		local fields = {
			text = text:GetText(),
			kind = view.kind,
			char = onlyChar:GetChecked() and ns.CharKey() or nil,
			repeating = view.kind ~= "level" and repeating:GetChecked(),
		}
		if view.kind == "zone" then
			fields.value = ns.Trim(value:GetText())
			if fields.value == "" then
				local w = ns.Where()
				fields.value, fields.mapID = w.zone, w.mapID
			end
		elseif view.kind == "level" or view.kind == "reset" then
			fields.value = tonumber(value:GetText())
		elseif view.kind == "place" then
			fields.value = view.place
		elseif view.kind == "time" then
			fields.value = { wday = view.wday, hour = tonumber(value:GetText()), min = tonumber(minute:GetText()) or 0 }
		end
		if view.kind == "time" and forGuild:IsShown() and forGuild:GetChecked() then
			local v = fields.value
			local at = v.hour and G.NextAt(v.wday, v.hour % 24, v.min % 60)
			local every = fields.repeating and (v.wday == 0 and 86400 or 604800) or 0
			if at and G.Create(fields.text, at, every) then
				text:SetText("")
				value:SetText("")
				minute:SetText("")
				text:ClearFocus()
			end
			return
		end
		if R.Create(fields) then
			text:SetText("")
			value:SetText("")
			minute:SetText("")
			text:ClearFocus()
		end
	end)

	-- the help under the form, left page
	if not stacked then
		local help = UI.Label(left, L.REMINDERS_HELP, "muted")
		help:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -16)
		help:SetPoint("RIGHT", 0, 0)
		help:SetWordWrap(true)
		help:SetSpacing(3)
	end

	-- list -------------------------------------------------------------------------------------------
	local listHead = UI.Label(right, L.TAB_REMINDERS, "heading")
	if stacked then
		listHead:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -16)
	else
		listHead:SetPoint("TOPLEFT", 0, 0)
	end
	local rule = UI.Rule(right)
	rule:SetPoint("TOPLEFT", listHead, "BOTTOMLEFT", 0, -6)
	rule:SetPoint("RIGHT", right, "RIGHT", 0, 0)

	local listFrame = CreateFrame("Frame", nil, right)
	listFrame:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	listFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

	local list = UI.List(listFrame, 40, function(row, r)
		if not row.text then
			row.text = UI.Label(row, "", "body")
			row.text:SetPoint("TOPLEFT", 4, -4)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetWordWrap(false)
			row.when = UI.Label(row, "", "small")
			row.when:SetPoint("BOTTOMLEFT", 4, 4)
			row.when:SetPoint("RIGHT", -4, 0)
			row.when:SetWordWrap(false)
		end
		if r.guild then
			row.text:SetText("|cff2b5da8" .. r.text .. "|r")
			row.when:SetText(L.GUILD_TAG:format(r.by, date("%a %d/%m %H:%M", r.next - (GetServerTime() - time()))))
			return
		end
		row.text:SetText(r.done and ("|cff6c4e31" .. r.text .. "|r") or r.text)
		local when = R.Describe(r)
		if r.char then
			when = when .. " · " .. r.char
		end
		if r.done then
			when = when .. " · " .. L.DONE
		end
		row.when:SetText(when)
	end, function(r, _, row)
		UI.Menu(row, function(root)
			root:CreateTitle(r.text)
			if r.guild then
				if r.by == UnitName("player") then
					root:CreateButton(L.DELETE, function()
						G.Delete(r.id)
					end)
				end
				return
			end
			if r.done then
				root:CreateButton(L.REACTIVATE, function()
					R.Reactivate(r.id)
				end)
			end
			root:CreateButton(L.DELETE, function()
				R.Delete(r.id)
			end)
		end)
	end)
	list.box:SetPoint("TOPLEFT", 0, 0)
	list.box:SetPoint("BOTTOMRIGHT", -16, 0)

	local empty = UI.Label(listFrame, L.REMINDERS_EMPTY, "muted", "CENTER")
	empty:SetPoint("TOPLEFT", 10, -30)
	empty:SetPoint("TOPRIGHT", -10, -30)
	empty:SetWordWrap(true)

	function view.Refresh()
		layout()
		local items = R.List(ns.CharKey())
		-- active first, then by creation
		table.sort(items, function(a, b)
			if (a.done and 1 or 0) ~= (b.done and 1 or 0) then
				return not a.done
			end
			return (a.created or 0) < (b.created or 0)
		end)
		if G then
			for _, g in ipairs(G.Sorted()) do
				g.guild = true
				table.insert(items, 1, g)
			end
		end
		list:SetData(items)
		empty:SetShown(#items == 0)
	end

	view.list = list
	view.form, view.create, view.onlyChar, view.repeating = form, create, onlyChar, repeating
	return view
end)
