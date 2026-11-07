local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local P = UI.P
local N = ns.Notes

local MAX_THUMBS = 4

-- Left page: the sections as chips, the search, the list of notes, "New note".
-- Right page: the note itself (title, scope, body, images, pin / attach / more).
UI.RegisterTab("TAB_NOTES", "notes", function(page)
	local view = { section = nil, selected = nil }
	local left, right = page.left, page.right or page.left

	-- left page -------------------------------------------------------------------------------------
	local search = UI.Input(left, 120, nil, L.SEARCH)
	search:SetPoint("TOPRIGHT", 0, 0)
	search:HookScript("OnTextChanged", function()
		view.RefreshList()
	end)

	local sections = UI.ChipRow(left, left:GetWidth() - 130)
	sections:SetPoint("TOPLEFT", 0, 0)

	local rule = UI.Rule(left)
	rule:SetPoint("TOPLEFT", sections, "BOTTOMLEFT", 0, -8)
	rule:SetPoint("RIGHT", left, "RIGHT", 0, 0)

	local listFrame = CreateFrame("Frame", nil, left)
	listFrame:SetPoint("TOPLEFT", rule, "BOTTOMLEFT", 0, -4)
	listFrame:SetPoint("BOTTOMRIGHT", left, "BOTTOMRIGHT", 0, 34)

	local list = UI.List(listFrame, 40, function(row, note)
		if not row.title then
			row.title = UI.Label(row, "", "strong")
			row.title:SetPoint("TOPLEFT", 4, -4)
			row.title:SetPoint("RIGHT", -60, 0)
			row.title:SetWordWrap(false)
			row.sub = UI.Label(row, "", "small")
			row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -1)
			row.sub:SetPoint("RIGHT", -4, 0)
			row.sub:SetWordWrap(false)
			row.tag = UI.Tag(row, L.PINNED, "pinned")
			row.tag:SetPoint("TOPRIGHT", -4, -6)
		end
		row.title:SetText(N.DisplayTitle(note))
		local sub = ns.Preview(note.body, 50)
		if note.attach then
			sub = "@" .. (note.attach.label or "") .. (sub ~= "" and " · " .. sub or "")
		end
		row.sub:SetText(sub)
		row.tag:SetShown(note.pinned and true or false)
		row.selected:SetShown(view.selected == note.id)
	end, function(note)
		view.Select(note.id)
	end)
	list.box:SetPoint("TOPLEFT", 0, 0)
	list.box:SetPoint("BOTTOMRIGHT", -16, 0)

	local empty = UI.Label(listFrame, L.NO_NOTES, "muted", "CENTER")
	empty:SetPoint("TOPLEFT", 10, -20)
	empty:SetPoint("TOPRIGHT", -10, -20)

	local newNote = UI.Button(left, L.NEW_NOTE, 120, function()
		local note = N.Create({ section = view.section })
		view.Select(note.id, true)
	end)
	newNote:SetPoint("BOTTOMLEFT", 0, 0)

	-- right page: the note -----------------------------------------------------------------------------
	local editor = CreateFrame("Frame", nil, right)
	editor:SetAllPoints()

	local title = UI.Input(editor, 300, nil, L.NOTE_TITLE_HINT)
	title:SetPoint("TOPLEFT", 0, 0)
	title:SetPoint("RIGHT", 0, 0)
	title:SetFontObject(P.fonts.big)
	title:SetHeight(28)

	local function current()
		return view.selected and N.Get(view.selected)
	end

	local pending
	local function touch()
		-- the list is refreshed a moment after typing stops, not on every key
		local note = current()
		if note then
			note.updated = time()
		end
		if not pending then
			pending = true
			C_Timer.After(0.8, function()
				pending = false
				view.RefreshList(true)
			end)
		end
	end

	title:HookScript("OnTextChanged", function(self, userInput)
		local note = current()
		if note and userInput then
			note.title = self:GetText()
			touch()
		end
	end)

	local scopeLabel = UI.Label(editor, "", "small")
	scopeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 2, -4)
	scopeLabel:SetPoint("RIGHT", 0, 0)
	scopeLabel:SetWordWrap(false)

	local area = P.TextArea(editor)
	area:SetPoint("TOPLEFT", scopeLabel, "BOTTOMLEFT", -2, -8)
	-- room under the text for: the hint (14), 12, the images row (28), 8, thumbnails with names (78), and
	-- the bottom buttons (28) with a gap
	area:SetPoint("BOTTOMRIGHT", editor, "BOTTOMRIGHT", 0, 176)
	local body = area.box
	body:RegisterCallback("OnTextChanged", function(_, editBox, userChanged)
		local note = current()
		if note and userChanged then
			note.body = editBox:GetText()
			touch()
		end
	end, view)

	local hint = UI.Label(editor, L.NOTE_HINT, "muted")
	hint:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 2, -2)
	hint:SetPoint("RIGHT", 0, 0)
	hint:SetWordWrap(false)

	-- images strip: one row with the label and the button centred on each other, 12 px under the hint
	local imagesRow = CreateFrame("Frame", nil, editor)
	imagesRow:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)
	imagesRow:SetPoint("RIGHT", 0, 0)
	imagesRow:SetHeight(28)
	view.imagesRow = imagesRow
	local imagesLabel = UI.Label(imagesRow, L.IMAGES, "subheading")
	imagesLabel:SetPoint("LEFT", imagesRow, "LEFT", 0, 0)
	view.imagesLabel = imagesLabel
	local addImage = UI.Button(editor, L.ADD_IMAGE, 130, function()
		local note = current()
		if not note then
			return
		end
		UI.Prompt(L.IMAGE_FILE, "", function(text)
			if not N.AddImage(note.id, text) then
				ns.Print(L.IMAGE_BAD_NAME)
			else
				ns.Print(L.IMAGE_HELP)
			end
			view.ShowNote()
		end)
	end)
	addImage:SetPoint("LEFT", imagesLabel, "RIGHT", 12, 0)
	view.addImage = addImage

	local preview = P.Card(ADDON .. "ImagePreview", 548, 566, "")
	preview.tex = preview.body:CreateTexture(nil, "ARTWORK")
	preview.tex:SetPoint("TOP", 0, 0)
	preview.tex:SetSize(512, 512)
	UI.imagePreview = preview

	local thumbs = {}
	for i = 1, MAX_THUMBS do
		local b = CreateFrame("Button", nil, editor)
		b:SetSize(64, 64)
		b:SetPoint("TOPLEFT", imagesRow, "BOTTOMLEFT", (i - 1) * 72, -8)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.bg:SetColorTexture(0.23, 0.14, 0.07, 0.15)
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetPoint("TOPLEFT", 2, -2)
		b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
		b.name = UI.Label(b, "", "small", "CENTER")
		b.name:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, -1)
		b.name:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, -1)
		b.name:SetWordWrap(false)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetScript("OnEnter", function(self)
			if self.file then
				GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
				GameTooltip:SetText(self.file, 1, 1, 1)
				GameTooltip:AddLine(L.IMAGE_TIP, nil, nil, nil, true)
				GameTooltip:Show()
			end
		end)
		b:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		b:SetScript("OnClick", function(self, button)
			local note = current()
			if not note or not self.file then
				return
			end
			if button == "RightButton" then
				UI.Menu(self, function(root)
					root:CreateTitle(self.file)
					root:CreateButton(L.DELETE, function()
						N.RemoveImage(note.id, self.index)
						view.ShowNote()
					end)
				end)
			else
				preview.title:SetText(self.file)
				preview.tex:SetTexture(N.ImagePath(self.file))
				preview:Show()
			end
		end)
		b:Hide()
		thumbs[i] = b
	end

	-- the bottom row: scope, pin, attach, more
	local more = UI.Button(editor, "…", 34, nil)
	more:SetPoint("BOTTOMRIGHT", 0, 0)
	local attach = UI.Button(editor, L.ATTACH, 100, nil)
	attach:SetPoint("RIGHT", more, "LEFT", -6, 0)
	local pin = UI.Button(editor, L.PIN, 80, function()
		local note = current()
		if note then
			N.Update(note.id, { pinned = not note.pinned })
			view.ShowNote()
		end
	end)
	pin:SetPoint("RIGHT", attach, "LEFT", -6, 0)

	local nothing = UI.Label(right, L.NO_NOTE_OPEN, "muted", "CENTER")
	nothing:SetPoint("CENTER", 0, 40)
	nothing:SetPoint("LEFT", 20, 0)
	nothing:SetPoint("RIGHT", -20, 0)

	-- link insertion: shift-click on an item while the note has focus. Pergamino takes the link for us and
	-- tells the game it was used, so shift-clicking a stack no longer opens the split dialog.
	P.AcceptLinks(body, function(text)
		if left:IsVisible() then
			body:Insert(text)
		end
	end)
	P.AcceptLinks(title, function(text)
		if left:IsVisible() then
			title:Insert(ns.PlainText(text))
		end
	end)

	-- menus ----------------------------------------------------------------------------------------
	attach:SetScript("OnClick", function(self)
		local note = current()
		if not note then
			return
		end
		UI.Menu(self, function(root)
			root:CreateButton(L.ATTACH_TARGET, function()
				local guid = UnitExists("target") and ns.Plain(UnitGUID("target"))
				local npc = N.NpcIDFromGUID(guid)
				local name = ns.Plain(UnitName("target"))
				if npc then
					N.Attach(note.id, "npc", npc, name)
				elseif name and not UnitIsPlayer("target") then
					N.Attach(note.id, "npcname", string.lower(name), name)
				else
					ns.Print(L.ATTACH_NO_TARGET)
					return
				end
				view.ShowNote()
			end)
			root:CreateButton(L.ATTACH_ITEM, function()
				local itemID, name = N.FirstItemLink(note)
				if itemID then
					N.Attach(note.id, "item", itemID, name)
					view.ShowNote()
				else
					ns.Print(L.ATTACH_NO_ITEM)
				end
			end)
			root:CreateButton(L.ATTACH_ZONE, function()
				local w = ns.Where()
				if w.mapID then
					N.Attach(note.id, "zone", w.mapID, w.zone)
					view.ShowNote()
				end
			end)
			if note.attach then
				root:CreateButton(L.ATTACH_NONE, function()
					N.Attach(note.id, nil)
					view.ShowNote()
				end)
			end
		end)
	end)

	more:SetScript("OnClick", function(self)
		local note = current()
		if not note then
			return
		end
		UI.Menu(self, function(root)
			root:CreateTitle(N.DisplayTitle(note))
			for _, s in ipairs(N.Sections()) do
				root:CreateRadio(s.name, function()
					return note.section == s.id
				end, function()
					N.Update(note.id, { section = s.id })
				end)
			end
			root:CreateDivider()
			root:CreateCheckbox(L.CHAR_NOTE:format(ns.CharKey() or "?"), function()
				return note.char ~= nil
			end, function()
				note.char = note.char == nil and ns.CharKey() or nil
				view.ShowNote()
			end)
			root:CreateDivider()
			root:CreateButton(L.DELETE, function()
				UI.Confirm(L.DELETE_NOTE_CONFIRM:format(N.DisplayTitle(note)), function()
					N.Delete(note.id)
					view.selected = nil
					view.ShowNote()
				end)
			end)
		end)
	end)

	-- refresh ----------------------------------------------------------------------------------------
	function view.RefreshSections()
		local all = N.Sections()
		if view.section and not N.Section(view.section) then
			view.section = nil
		end
		local items = {
			{
				text = L.FILTER_ALL,
				selected = view.section == nil,
				onClick = function()
					view.section = nil
					view.Refresh()
				end,
			},
		}
		for i, s in ipairs(all) do
			table.insert(items, {
				text = s.name,
				selected = view.section == s.id,
				onClick = function(self, mouse)
					if mouse == "RightButton" then
						UI.Menu(self, function(root)
							root:CreateTitle(s.name)
							root:CreateButton(L.RENAME, function()
								UI.Prompt(L.SECTION_NAME, s.name, function(text)
									N.RenameSection(s.id, text)
								end)
							end)
							if i > 1 then
								root:CreateButton(L.DELETE, function()
									UI.Confirm(L.DELETE_SECTION_CONFIRM:format(s.name, all[1].name), function()
										N.DeleteSection(s.id)
									end)
								end)
							end
						end)
					else
						view.section = s.id
						view.Refresh()
					end
				end,
			})
		end
		table.insert(items, {
			text = "+",
			selected = false,
			onClick = function()
				UI.Prompt(L.SECTION_NAME, "", function(text)
					local s = N.AddSection(text)
					if s then
						view.section = s.id
						view.Refresh()
					end
				end)
			end,
		})
		sections:Set(items)
		rule:ClearAllPoints()
		rule:SetPoint("TOPLEFT", sections, "BOTTOMLEFT", 0, -8)
		rule:SetPoint("RIGHT", left, "RIGHT", 0, 0)
	end

	function view.RefreshList(keepScroll)
		local notes = N.Search(search:GetText(), view.section, ns.CharKey())
		list:SetData(notes, keepScroll)
		empty:SetShown(#notes == 0)
	end

	function view.ShowNote()
		local note = current()
		editor:SetShown(note ~= nil)
		nothing:SetShown(note == nil)
		if not note then
			view.RefreshList(true)
			return
		end
		title:SetText(note.title or "")
		body:SetText(note.body or "")
		pin:SetText(note.pinned and L.UNPIN or L.PIN)
		local scope = note.char and L.CHAR_NOTE:format(note.char) or L.ACCOUNT_NOTE
		if note.attach then
			scope = scope .. " · " .. L.ATTACHED_TO:format(note.attach.label or note.attach.key)
		end
		scopeLabel:SetText(scope)
		local images = note.images or {}
		for i, b in ipairs(thumbs) do
			local file = images[i]
			b.file, b.index = file, i
			if file then
				b.tex:SetTexture(N.ImagePath(file))
				b.name:SetText(ns.ShortName(file, 11))
				b:Show()
			else
				b:Hide()
			end
		end
		addImage:SetEnabled(#images < MAX_THUMBS)
		view.RefreshList(true)
	end

	view.title, view.body, view.sections, view.list, view.pin = title, body, sections, list, pin

	function view.Select(id, focusTitle)
		view.selected = id
		view.ShowNote()
		if focusTitle then
			title:SetFocus()
		end
	end

	function view.Refresh(fromEvent)
		view.RefreshSections()
		if fromEvent then
			view.RefreshList(true)
			return
		end
		view.ShowNote()
	end

	return view
end)
