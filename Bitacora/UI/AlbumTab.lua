local _, ns = ...
local L = ns.L
local UI = ns.UI
local A = ns.Album

UI.builders[3] = function(panel)
	local view = {}

	local hint = UI.Label(panel, L.ALBUM_HINT, "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 4, -6)

	local inset = UI.Inset(panel)
	inset:SetPoint("TOPLEFT", 0, -26)
	inset:SetPoint("BOTTOMRIGHT", 0, 0)

	local list = UI.List(inset, 40, function(row, item)
		if not row.icon then
			row.icon = row:CreateTexture(nil, "ARTWORK")
			row.icon:SetSize(28, 28)
			row.icon:SetPoint("LEFT", 6, 0)
			row.icon:SetTexture("Interface\\Icons\\INV_Misc_Spyglass_03")
			row.top = UI.Label(row, "", "GameFontHighlight")
			row.top:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, 0)
			row.top:SetPoint("RIGHT", -8, 0)
			row.top:SetWordWrap(false)
			row.bottom = UI.Label(row, "", "GameFontDisableSmall")
			row.bottom:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 0)
			row.bottom:SetPoint("RIGHT", -8, 0)
			row.bottom:SetWordWrap(false)
		end
		local shot = item.shot
		row.top:SetText(shot.caption or A.Describe(shot))
		local bits = { "WoWScrnShot_" .. (shot.stamp or "?") .. ".jpg" }
		if shot.caption then
			table.insert(bits, 1, A.Describe(shot))
		end
		if shot.x and shot.y then
			table.insert(bits, ("%.1f, %.1f"):format(shot.x, shot.y))
		end
		row.bottom:SetText(table.concat(bits, " · "))
	end, function(item, button, row)
		if button == "RightButton" then
			UI.Menu(row, function(root)
				root:CreateButton(L.DELETE, function()
					A.Delete(item.index)
				end)
			end)
		else
			UI.Prompt(L.CAPTION, item.shot.caption or "", function(text)
				A.SetCaption(item.index, text)
			end)
		end
	end)
	list.box:SetPoint("TOPLEFT", 4, -4)
	list.box:SetPoint("BOTTOMRIGHT", -20, 4)

	local empty = UI.Label(inset, L.ALBUM_EMPTY, "GameFontDisable", "CENTER")
	empty:SetPoint("TOPLEFT", 20, -40)
	empty:SetPoint("TOPRIGHT", -20, -40)

	function view.Refresh()
		local shots = A.List()
		local items = {}
		for i = #shots, 1, -1 do
			table.insert(items, { shot = shots[i], index = i })
		end
		list:SetData(items)
		empty:SetShown(#items == 0)
	end

	return view
end
