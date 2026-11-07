local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = UI.P
local R = ns.Reminders
local G = ns.GuildReminders

-- The kinds the form offers, in this order (a chip each), with their tag in the list. "calendar" reminders
-- come from the game's calendar, not from the form, but are listed with their own tag.
local KINDS = {
	{ "zone", "K_ZONE" },
	{ "place", "K_PLACE" },
	{ "time", "K_TIME" },
	{ "reset", "K_RESET" },
	{ "level", "K_LEVEL" },
	{ "login", "K_LOGIN" },
}
UI.REMINDER_KINDS = KINDS
local TAG = {
	zone = { "TAG_ZONE", "zone" },
	place = { "TAG_PLACE", "money" },
	time = { "TAG_TIME", "note" },
	reset = { "TAG_RESET", "boss" },
	level = { "TAG_LEVEL", "level" },
	login = { "TAG_LOGIN", "start" },
	calendar = { "TAG_CALENDAR", "guild" },
	guild = { "TAG_GUILD", "guild" },
}
UI.REMINDER_TAGS = TAG

-- Left page: the form (what, when, for whom). Right page: the reminders. On a single page (Recordame), the
-- form on top, a rule, and the list under it.
UI.RegisterTab("TAB_REMINDERS", "reminders", function(page)
	local view = { kind = "zone", place = "MAIL", wday = 0, editing = nil }
	local left, right = page.left, page.right
	local stacked = right == nil
	right = right or left

	-- form -------------------------------------------------------------------------------------------
	local form = CreateFrame("Frame", nil, left)
	form:SetPoint("TOPLEFT", 0, 0)
	form:SetPoint("TOPRIGHT", 0, 0)
	form:SetHeight(220) -- layout() sets the real height
	local width = (left:GetWidth() and left:GetWidth() > 0) and left:GetWidth() or 360

	local head = UI.Label(form, L.NEW_REMINDER_HEAD, "heading")
	head:SetPoint("TOPLEFT", 0, 0)

	-- "How does it work?": the long explanation lives in its tooltip, not as a block of text on the page
	local how = CreateFrame("Button", nil, stacked and form or left)
	how.label = UI.Label(how, L.HOW_IT_WORKS, "muted")
	how.label:SetPoint("LEFT", 0, 0)
	how:SetSize(math.max(60, (how.label:GetStringWidth() or 100) + 4), 16)
	how:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(L.HOW_IT_WORKS)
		GameTooltip:AddLine(L.REMINDERS_HELP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	how:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	if stacked then
		how:SetPoint("RIGHT", form, "TOPRIGHT", 0, -8)
	else
		how:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -14)
	end
	view.how = how

	-- what to remember: one wide field in the big hand
	local text = P.Edit(form, 300, { placeholder = L.REMINDER_TEXT, font = P.fonts.big })
	text:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -12)
	text:SetPoint("RIGHT", form, "RIGHT", 0, 0)
	text:SetHeight(26)

	-- when: a row of chips, one per kind
	local whenLabel = UI.Label(form, L.WHEN, "subheading")
	whenLabel:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -14)
	local kinds = UI.ChipRow(form, width)
	kinds:SetPoint("TOPLEFT", whenLabel, "BOTTOMLEFT", 0, -6)
	kinds:SetPoint("RIGHT", form, "RIGHT", 0, 0)

	-- a rule 12 px under the last row of chips; the detail of the kind chosen 12 px under it: only the
	-- field that kind needs (full width, with a placeholder so the field itself is visible), help under it
	local kindsRule = UI.Rule(form)
	kindsRule:SetPoint("TOPLEFT", kinds, "BOTTOMLEFT", 0, -12)
	kindsRule:SetPoint("RIGHT", form, "RIGHT", 0, 0)
	local detail = CreateFrame("Frame", nil, form)
	detail:SetPoint("TOPLEFT", kindsRule, "BOTTOMLEFT", 0, -12)
	detail:SetPoint("RIGHT", form, "RIGHT", 0, 0)
	detail:SetHeight(26)
	local value = UI.Input(detail, 150, nil, "")
	local minute = UI.Input(detail, 40, nil, "00")
	local dayButton = UI.Button(detail, "", 130, nil) -- the weekday of a day-and-time reminder
	local places = UI.ChipRow(detail, width) -- mail / bank / vendor / auction house
	local valueHint = UI.Label(form, "", "muted")
	valueHint:SetJustifyH("LEFT")
	valueHint:SetWordWrap(true)
	valueHint:SetPoint("TOPLEFT", detail, "BOTTOMLEFT", 0, -10)
	valueHint:SetPoint("RIGHT", form, "RIGHT", 0, 0)

	-- for whom, and how often: the checks on one row, the button under them on the right
	local checks = CreateFrame("Frame", nil, form)
	checks:SetPoint("RIGHT", form, "RIGHT", 0, 0)
	checks:SetHeight(20)
	local onlyChar = UI.Check(checks, L.ONLY_THIS_CHAR)
	onlyChar:SetPoint("LEFT", checks, "LEFT", 0, 0)
	local repeating = UI.Check(checks, L.REPEAT)
	-- officers can send a day-and-time reminder to the whole guild
	local forGuild = UI.Check(form, L.FOR_GUILD)

	local create = UI.Button(form, L.ADD_REMINDER, 180, nil)
	create:SetPoint("TOPRIGHT", form, "RIGHT", 0, 0) -- layout() anchors it under the checks
	local cancel = UI.Button(form, L.CANCEL_EDIT, 100, nil)
	cancel:SetPoint("RIGHT", create, "LEFT", -8, 0)
	cancel:Hide()

	local function layout()
		local k = view.kind
		local items = {}
		for _, pair in ipairs(KINDS) do
			table.insert(items, {
				text = L[pair[2]],
				selected = pair[1] == k,
				onClick = function()
					if view.kind ~= pair[1] then
						view.kind = pair[1]
						value:SetText("")
						minute:SetText("")
					end
					layout()
				end,
			})
		end
		kinds:Set(items)

		value:ClearAllPoints()
		minute:ClearAllPoints()
		dayButton:ClearAllPoints()
		places:ClearAllPoints()
		value:SetShown(k == "zone" or k == "level" or k == "time" or k == "reset")
		minute:SetShown(k == "time")
		dayButton:SetShown(k == "time")
		places:SetShown(k == "place")
		local hint = ""
		local detailH = 26
		if value.SetPlaceholder then
			value:SetPlaceholder(k == "zone" and L.R_ZONE_FIELD or k == "level" and L.R_LEVEL_HINT or k == "reset" and L.R_RESET_FIELD or k == "time" and L.R_HOUR_FIELD or "")
		end
		if k == "zone" then
			value:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
			value:SetPoint("RIGHT", detail, "RIGHT", 0, 0)
			hint = L.R_ZONE_HINT
		elseif k == "level" or k == "reset" then
			value:SetWidth(k == "level" and 60 or 90)
			value:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
			hint = k == "level" and L.R_LEVEL_HINT or L.R_RESET_HINT
		elseif k == "time" then
			dayButton:SetText(view.wday == 0 and L.EVERY_DAY or L.WEEKDAYS[view.wday])
			dayButton:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
			value:SetWidth(40)
			value:SetPoint("LEFT", dayButton, "RIGHT", 12, 0)
			minute:SetPoint("LEFT", value, "RIGHT", 6, 0)
			hint = L.R_TIME_HINT
		elseif k == "place" then
			places:SetPoint("TOPLEFT", detail, "TOPLEFT", 0, 0)
			places:SetPoint("RIGHT", detail, "RIGHT", 0, 0)
			local list = {}
			for _, place in ipairs(R.PLACES) do
				table.insert(list, {
					text = L[R.PLACE_LABEL[place]],
					selected = view.place == place,
					onClick = function()
						view.place = place
						layout()
					end,
				})
			end
			places:Set(list)
			detailH = places:GetHeight() or 20
			hint = L.R_PLACE_HINT
		elseif k == "login" then
			detailH = 0
			hint = L.R_LOGIN_HINT
		end
		detail:SetHeight(math.max(1, detailH))
		valueHint:SetText(hint)
		valueHint:SetShown(hint ~= "")

		-- the checks under the help (or under the detail when there is none)
		checks:ClearAllPoints()
		checks:SetPoint("TOPLEFT", hint ~= "" and valueHint or detail, "BOTTOMLEFT", 0, -14)
		checks:SetPoint("RIGHT", form, "RIGHT", 0, 0)
		repeating:ClearAllPoints()
		repeating:SetShown(k ~= "level")
		forGuild:ClearAllPoints()
		forGuild:SetShown(G ~= nil and G.IAmOfficer() and k == "time" and not view.editing)
		onlyChar:SetShown(not (forGuild:IsShown() and forGuild:GetChecked()))
		if onlyChar:IsShown() then
			repeating:SetPoint("LEFT", onlyChar.label or onlyChar, "RIGHT", 18, 0)
		else
			repeating:SetPoint("LEFT", checks, "LEFT", 0, 0)
		end
		create:ClearAllPoints()
		if forGuild:IsShown() then
			forGuild:SetPoint("TOPLEFT", checks, "BOTTOMLEFT", 0, -8)
			create:SetPoint("TOP", checks, "BOTTOM", 0, -(8 + 18 + 12))
		else
			create:SetPoint("TOP", checks, "BOTTOM", 0, -12)
		end
		create:SetPoint("RIGHT", form, "RIGHT", 0, 0)
		create:SetText(view.editing and L.SAVE_REMINDER or L.ADD_REMINDER)
		cancel:SetShown(view.editing ~= nil)
		head:SetText(view.editing and L.EDIT_REMINDER_HEAD or L.NEW_REMINDER_HEAD)

		-- the form is as tall as its rows, so what hangs from its bottom (the list on one page) follows
		local h = 20 + 12 + 26 -- heading, the text
		h = h + 14 + 14 + 6 + (kinds:GetHeight() or 20) -- "when" and its chips
		h = h + 12 + 1 + 12 + math.max(1, detailH) -- the rule and the detail
		if hint ~= "" then
			h = h + 10 + math.max(14, valueHint:GetStringHeight() or 14)
		end
		h = h + 14 + 20 -- the checks
		if forGuild:IsShown() then
			h = h + 8 + 18
		end
		h = h + 12 + 26 -- the button
		form:SetHeight(h)
	end
	forGuild:HookScript("OnClick", layout)

	dayButton:SetScript("OnClick", function(self)
		UI.Menu(self, function(root)
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
		end)
	end)

	local function clear()
		view.editing = nil
		text:SetText("")
		value:SetText("")
		minute:SetText("")
		text:ClearFocus()
		layout()
	end
	cancel:SetScript("OnClick", clear)

	-- Load one reminder into the form to change it ("Edit" in its menu).
	function view.Edit(r)
		view.editing = r.id
		view.kind = r.kind
		text:SetText(r.text or "")
		value:SetText("")
		minute:SetText("")
		if r.kind == "zone" or r.kind == "level" or r.kind == "reset" then
			value:SetText(tostring(r.value or ""))
		elseif r.kind == "place" then
			view.place = r.value or "MAIL"
		elseif r.kind == "time" and type(r.value) == "table" then
			view.wday = r.value.wday or 0
			value:SetText(tostring(r.value.hour or ""))
			minute:SetText(("%02d"):format(r.value.min or 0))
		end
		onlyChar:SetChecked(r.char ~= nil)
		repeating:SetChecked(r.repeating and true or false)
		layout()
	end

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
		if view.editing then
			if R.Update(view.editing, fields) then
				clear()
			end
			return
		end
		if view.kind == "time" and forGuild:IsShown() and forGuild:GetChecked() then
			local v = fields.value
			local at = v.hour and G.NextAt(v.wday, v.hour % 24, v.min % 60)
			local every = fields.repeating and (v.wday == 0 and 86400 or 604800) or 0
			if at and G.Create(fields.text, at, every) then
				clear()
			end
			return
		end
		if R.Create(fields) then
			clear()
		end
	end)

	-- list -------------------------------------------------------------------------------------------
	local listHead = UI.Label(right, L.TAB_REMINDERS, "heading")
	if stacked then
		local sep = UI.Rule(right)
		sep:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -14)
		sep:SetPoint("RIGHT", right, "RIGHT", 0, 0)
		view.sep = sep
		listHead:SetPoint("TOPLEFT", sep, "BOTTOMLEFT", 0, -12)
	else
		listHead:SetPoint("TOPLEFT", 0, 0)
	end
	local rule = UI.Rule(right)
	rule:SetPoint("TOPLEFT", listHead, "BOTTOMLEFT", 0, -6)
	rule:SetPoint("RIGHT", right, "RIGHT", 0, 0)

	local listFrame = CreateFrame("Frame", nil, right)
	listFrame:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	listFrame:SetPoint("BOTTOMRIGHT", right, "BOTTOMRIGHT", 0, 0)

	-- each reminder: its kind as a tag, the text, and "when · who" under it
	local list = UI.List(listFrame, 44, function(row, r)
		if not row.text then
			row.tag = UI.Tag(row, "", "note")
			row.tag:SetPoint("TOPLEFT", 4, -7)
			row.text = UI.Label(row, "", "body")
			row.text:SetPoint("TOPLEFT", row.tag, "TOPRIGHT", 8, 2)
			row.text:SetPoint("RIGHT", -4, 0)
			row.text:SetWordWrap(false)
			row.when = UI.Label(row, "", "small")
			row.when:SetPoint("BOTTOMLEFT", 4, 5)
			row.when:SetPoint("RIGHT", -4, 0)
			row.when:SetWordWrap(false)
		end
		local t = TAG[r.guild and "guild" or r.kind] or TAG.login
		row.tag:Set(L[t[1]], r.done and "done" or t[2])
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
			if r.kind ~= "calendar" then
				root:CreateButton(L.EDIT, function()
					view.Edit(r)
				end)
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
	view.text, view.value, view.minute, view.kinds, view.places, view.checks = text, value, minute, kinds, places, checks
	view.valueHint, view.cancel, view.head, view.dayButton, view.detail, view.kindsRule = valueHint, cancel, head, dayButton, detail, kindsRule
	return view
end)
