local _, ns = ...
local L = ns.L
local UI = ns.UI
local R = ns.Reminders

local KINDS = { { "zone", "R_ZONE" }, { "level", "R_LEVEL" }, { "login", "R_LOGIN" }, { "place", "R_PLACE" }, { "time", "R_TIME" } }

UI.RegisterTab("TAB_REMINDERS", "reminders", function(panel)
	local view = { kind = "zone", place = "MAIL", wday = 0 }

	-- form -------------------------------------------------------------------------------------------
	local form = UI.Inset(panel)
	form:SetPoint("TOPLEFT", 0, 0)
	form:SetPoint("TOPRIGHT", 0, 0)
	form:SetHeight(96)

	local textLabel = UI.Label(form, L.REMINDER_TEXT, "GameFontNormal")
	textLabel:SetPoint("TOPLEFT", 12, -12)
	local text = UI.Input(form, 420)
	text:SetPoint("LEFT", textLabel, "RIGHT", 12, 0)
	text:SetPoint("RIGHT", form, "RIGHT", -16, 0)

	local whenLabel = UI.Label(form, L.WHEN, "GameFontNormal")
	whenLabel:SetPoint("TOPLEFT", textLabel, "BOTTOMLEFT", 0, -16)
	local kindButton = UI.Button(form, "", 150, nil)
	kindButton:SetPoint("LEFT", whenLabel, "RIGHT", 12, 0)

	local value = UI.Input(form, 200)
	value:SetPoint("LEFT", kindButton, "RIGHT", 12, 0)
	local valueHint = UI.Label(form, "", "GameFontDisableSmall")
	valueHint:SetPoint("LEFT", value, "RIGHT", 8, 0)

	local optionButton = UI.Button(form, "", 140, nil) -- place or weekday
	optionButton:SetPoint("LEFT", kindButton, "RIGHT", 12, 0)
	local minute = UI.Input(form, 40)
	minute:SetPoint("LEFT", value, "RIGHT", 6, 0)

	local onlyChar = UI.Check(form, L.ONLY_THIS_CHAR)
	onlyChar:SetPoint("TOPLEFT", whenLabel, "BOTTOMLEFT", -4, -10)
	local repeating = UI.Check(form, L.REPEAT)
	repeating:SetPoint("LEFT", onlyChar.label, "RIGHT", 16, 0)

	local create = UI.Button(form, L.NEW_REMINDER, 160, nil)
	create:SetPoint("BOTTOMRIGHT", -12, 10)

	local function layout()
		local k = view.kind
		for _, pair in ipairs(KINDS) do
			if pair[1] == k then
				kindButton:SetText(L[pair[2]])
			end
		end
		value:SetShown(k == "zone" or k == "level" or k == "time")
		minute:SetShown(k == "time")
		optionButton:SetShown(k == "place" or k == "time")
		value:ClearAllPoints()
		if k == "time" then
			optionButton:SetText(view.wday == 0 and L.EVERY_DAY or L.WEEKDAYS[view.wday])
			value:SetWidth(40)
			value:SetPoint("LEFT", optionButton, "RIGHT", 12, 0)
			valueHint:ClearAllPoints()
			valueHint:SetPoint("LEFT", minute, "RIGHT", 8, 0)
			valueHint:SetText(L.R_TIME_HINT)
		else
			value:SetWidth(k == "level" and 50 or 200)
			value:SetPoint("LEFT", kindButton, "RIGHT", 12, 0)
			valueHint:ClearAllPoints()
			valueHint:SetPoint("LEFT", value, "RIGHT", 8, 0)
			valueHint:SetText(k == "zone" and L.R_ZONE_HINT or k == "level" and L.R_LEVEL_HINT or "")
			optionButton:SetText(L[R.PLACE_LABEL[view.place]])
		end
		valueHint:SetShown(value:IsShown())
		repeating:SetShown(k ~= "level")
	end

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
		elseif view.kind == "level" then
			fields.value = tonumber(value:GetText())
		elseif view.kind == "place" then
			fields.value = view.place
		elseif view.kind == "time" then
			fields.value = { wday = view.wday, hour = tonumber(value:GetText()), min = tonumber(minute:GetText()) or 0 }
		end
		if R.Create(fields) then
			text:SetText("")
			value:SetText("")
			minute:SetText("")
			text:ClearFocus()
		end
	end)

	-- list -------------------------------------------------------------------------------------------
	local inset = UI.Inset(panel)
	inset:SetPoint("TOPLEFT", form, "BOTTOMLEFT", 0, -8)
	inset:SetPoint("BOTTOMRIGHT", 0, 0)

	local list = UI.List(inset, 30, function(row, r)
		if not row.text then
			row.text = UI.Label(row, "", "GameFontHighlight")
			row.text:SetPoint("LEFT", 10, 0)
			row.text:SetPoint("RIGHT", -220, 0)
			row.text:SetWordWrap(false)
			row.when = UI.Label(row, "", "GameFontDisableSmall", "RIGHT")
			row.when:SetPoint("RIGHT", -10, 0)
			row.when:SetWidth(200)
		end
		row.text:SetText(r.done and ("|cff808080" .. r.text .. "|r") or r.text)
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
	list.box:SetPoint("TOPLEFT", 4, -4)
	list.box:SetPoint("BOTTOMRIGHT", -20, 4)

	local empty = UI.Label(inset, L.REMINDERS_EMPTY, "GameFontDisable", "CENTER")
	empty:SetPoint("CENTER")

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
		list:SetData(items)
		empty:SetShown(#items == 0)
	end

	return view
end)
