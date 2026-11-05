local _, ns = ...
local L = ns.L
local UI = ns.UI
local A = ns.Album

-- Left page: the screenshots, newest first. Right page: the one you clicked, with its caption.
UI.RegisterTab("TAB_ALBUM", "album", function(page)
	local view = { selected = nil }
	local left, right = page.left, page.right or page.left

	local hint = UI.Label(left, L.ALBUM_HINT, "muted")
	hint:SetPoint("TOPLEFT", 0, 0)
	hint:SetPoint("RIGHT", 0, 0)
	hint:SetWordWrap(true)

	local rule = UI.Rule(left)
	rule:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
	rule:SetPoint("RIGHT", left, "RIGHT", 0, 0)

	local listFrame = CreateFrame("Frame", nil, left)
	listFrame:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	listFrame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 0)

	local list
	list = UI.List(listFrame, 40, function(row, item)
		if not row.top then
			row.top = UI.Label(row, "", "strong")
			row.top:SetPoint("TOPLEFT", 4, -4)
			row.top:SetPoint("RIGHT", -4, 0)
			row.top:SetWordWrap(false)
			row.bottom = UI.Label(row, "", "small")
			row.bottom:SetPoint("BOTTOMLEFT", 4, 4)
			row.bottom:SetPoint("RIGHT", -4, 0)
			row.bottom:SetWordWrap(false)
		end
		local shot = item.shot
		row.top:SetText(shot.caption or A.Describe(shot))
		local bits = { "WoWScrnShot_" .. (shot.stamp or "?") .. ".jpg" }
		if shot.caption then
			table.insert(bits, 1, A.Describe(shot))
		end
		row.bottom:SetText(table.concat(bits, " · "))
		row.selected:SetShown(view.selected == item.index)
	end, function(item, button, row)
		if button == "RightButton" then
			UI.Menu(row, function(root)
				root:CreateButton(L.DELETE, function()
					A.Delete(item.index)
				end)
			end)
		else
			view.selected = item.index
			list:Refresh()
			view.ShowShot()
		end
	end)
	list.box:SetPoint("TOPLEFT", 0, 0)
	list.box:SetPoint("BOTTOMRIGHT", -16, 0)

	local empty = UI.Label(listFrame, L.ALBUM_EMPTY, "muted", "CENTER")
	empty:SetPoint("TOPLEFT", 20, -40)
	empty:SetPoint("TOPRIGHT", -20, -40)

	-- right page: the shot
	local detail = CreateFrame("Frame", nil, right)
	detail:SetAllPoints()
	local caption = UI.Label(detail, "", "big")
	caption:SetPoint("TOPLEFT", 0, 0)
	caption:SetPoint("RIGHT", 0, 0)
	caption:SetWordWrap(true)
	local file = UI.Label(detail, "", "small")
	file:SetPoint("TOPLEFT", caption, "BOTTOMLEFT", 0, -6)
	local facts = UI.Label(detail, "", "body")
	facts:SetPoint("TOPLEFT", file, "BOTTOMLEFT", 0, -14)
	facts:SetPoint("RIGHT", 0, 0)
	facts:SetWordWrap(true)
	facts:SetSpacing(4)
	local setCaption = UI.Button(detail, L.CAPTION, 120, function()
		local shot = view.selected and A.List()[view.selected]
		if shot then
			UI.Prompt(L.CAPTION, shot.caption or "", function(text)
				A.SetCaption(view.selected, text)
			end)
		end
	end)
	setCaption:SetPoint("BOTTOMLEFT", 0, 0)
	local delete = UI.Button(detail, L.DELETE, 90, function()
		if view.selected then
			A.Delete(view.selected)
			view.selected = nil
		end
	end)
	delete:SetPoint("LEFT", setCaption, "RIGHT", 8, 0)
	local nothing = UI.Label(right, L.ALBUM_PICK, "muted", "CENTER")
	nothing:SetPoint("CENTER", 0, 40)
	nothing:SetPoint("LEFT", 20, 0)
	nothing:SetPoint("RIGHT", -20, 0)

	function view.ShowShot()
		local shot = view.selected and A.List()[view.selected]
		detail:SetShown(shot ~= nil)
		nothing:SetShown(shot == nil)
		if not shot then
			return
		end
		caption:SetText(shot.caption or A.Describe(shot))
		file:SetText("WoWScrnShot_" .. (shot.stamp or "?") .. ".jpg")
		local lines = { A.Describe(shot) }
		if shot.x and shot.y then
			table.insert(lines, ("%.1f, %.1f"):format(shot.x, shot.y))
		end
		if shot.group and #shot.group > 0 then
			table.insert(lines, L.WITH:format(table.concat(shot.group, ", ")))
		end
		facts:SetText(table.concat(lines, "\n"))
	end

	function view.Refresh()
		local shots = A.List()
		local items = {}
		for i = #shots, 1, -1 do
			table.insert(items, { shot = shots[i], index = i })
		end
		if view.selected and not shots[view.selected] then
			view.selected = nil
		end
		list:SetData(items)
		empty:SetShown(#items == 0)
		view.ShowShot()
	end

	view.list = list
	return view
end)
