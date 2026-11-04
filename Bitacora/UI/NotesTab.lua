local _, ns = ...
local L = ns.L
local UI = ns.UI
local N = ns.Notes

local MAX_THUMBS = 4

UI.builders[1] = function(panel)
	local view = { section = nil, selected = nil }

	-- tabs of the notebook (sections) ----------------------------------------------------------
	local sectionBar = CreateFrame("Frame", nil, panel)
	sectionBar:SetPoint("TOPLEFT", 0, 0)
	sectionBar:SetPoint("TOPRIGHT", -190, 0)
	sectionBar:SetHeight(24)
	local sectionButtons = {}

	local search = CreateFrame("EditBox", nil, panel, "SearchBoxTemplate")
	search:SetSize(170, 20)
	search:SetPoint("TOPRIGHT", -4, -2)
	search:HookScript("OnTextChanged", function()
		view.RefreshList()
	end)

	-- note list (left) ---------------------------------------------------------------------------
	local listFrame = UI.Inset(panel)
	listFrame:SetPoint("TOPLEFT", 0, -30)
	listFrame:SetPoint("BOTTOMLEFT", 0, 30)
	listFrame:SetWidth(240)

	local list = UI.List(listFrame, 36, function(row, note)
		if not row.title then
			row.title = UI.Label(row, "", "GameFontHighlight")
			row.title:SetPoint("TOPLEFT", 6, -4)
			row.title:SetPoint("RIGHT", -6, 0)
			row.title:SetWordWrap(false)
			row.sub = UI.Label(row, "", "GameFontDisableSmall")
			row.sub:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
			row.sub:SetPoint("RIGHT", -6, 0)
			row.sub:SetWordWrap(false)
		end
		row.title:SetText((note.pinned and "|TInterface\\Buttons\\UI-GuildButton-PublicNote-Up:12|t " or "") .. N.DisplayTitle(note))
		local sub = ns.Preview(note.body, 50)
		if note.attach then
			sub = "@" .. (note.attach.label or "") .. (sub ~= "" and " · " .. sub or "")
		end
		row.sub:SetText(sub)
		row.selected:SetShown(view.selected == note.id)
	end, function(note)
		view.Select(note.id)
	end)
	list.box:SetPoint("TOPLEFT", 4, -4)
	list.box:SetPoint("BOTTOMRIGHT", -20, 4)

	local empty = UI.Label(listFrame, L.NO_NOTES, "GameFontDisable", "CENTER")
	empty:SetPoint("TOPLEFT", 10, -20)
	empty:SetPoint("TOPRIGHT", -10, -20)

	local newNote = UI.Button(panel, L.NEW_NOTE, 120, function()
		local note = N.Create({ section = view.section })
		view.Select(note.id, true)
	end)
	newNote:SetPoint("BOTTOMLEFT", 0, 2)

	-- editor (right) -----------------------------------------------------------------------------
	local editor = CreateFrame("Frame", nil, panel)
	editor:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 10, 0)
	editor:SetPoint("BOTTOMRIGHT", 0, 0)

	local title = UI.Input(editor, 300)
	title:SetPoint("TOPLEFT", 6, 0)
	title:SetPoint("RIGHT", -200, 0)
	title:SetFontObject("GameFontNormalLarge")

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

	local pin = UI.Button(editor, L.PIN, 60, function()
		local note = current()
		if note then
			N.Update(note.id, { pinned = not note.pinned or nil })
			view.ShowNote()
		end
	end)
	pin:SetPoint("TOPRIGHT", -130, 1)

	local more = UI.Button(editor, "…", 30, nil)
	more:SetPoint("TOPRIGHT", -96, 1)

	local attach = UI.Button(editor, L.ATTACH, 90, nil)
	attach:SetPoint("TOPRIGHT", 0, 1)

	local scopeLabel = UI.Label(editor, "", "GameFontDisableSmall")
	scopeLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", -4, -6)
	local attachLabel = UI.Label(editor, "", "GameFontDisableSmall")
	attachLabel:SetPoint("LEFT", scopeLabel, "RIGHT", 12, 0)

	local bodyFrame = UI.Inset(editor)
	bodyFrame:SetPoint("TOPLEFT", 0, -44)
	bodyFrame:SetPoint("BOTTOMRIGHT", 0, 140)
	local body = CreateFrame("Frame", nil, bodyFrame, "ScrollingEditBoxTemplate")
	body:SetPoint("TOPLEFT", 8, -8)
	body:SetPoint("BOTTOMRIGHT", -24, 8)
	local bodyBar = CreateFrame("EventFrame", nil, bodyFrame, "MinimalScrollBar")
	bodyBar:SetPoint("TOPLEFT", body, "TOPRIGHT", 6, 0)
	bodyBar:SetPoint("BOTTOMLEFT", body, "BOTTOMRIGHT", 6, 0)
	ScrollUtil.RegisterScrollBoxWithScrollBar(body:GetScrollBox(), bodyBar)
	body:RegisterCallback("OnTextChanged", function(_, editBox, userChanged)
		local note = current()
		if note and userChanged then
			note.body = editBox:GetText()
			touch()
		end
	end, view)

	local hint = UI.Label(editor, L.NOTE_HINT, "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", bodyFrame, "BOTTOMLEFT", 2, -4)

	-- images strip
	local imagesLabel = UI.Label(editor, L.IMAGES, "GameFontNormalSmall")
	imagesLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
	local addImage = UI.Button(editor, L.ADD_IMAGE, 120, function()
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
	addImage:SetPoint("LEFT", imagesLabel, "RIGHT", 10, 0)

	local preview = CreateFrame("Frame", "BitacoraImagePreview", UIParent, "BasicFrameTemplateWithInset")
	preview:SetSize(540, 562)
	preview:SetPoint("CENTER")
	preview:SetFrameStrata("DIALOG")
	preview:Hide()
	preview.tex = preview:CreateTexture(nil, "ARTWORK")
	preview.tex:SetPoint("TOPLEFT", 14, -36)
	preview.tex:SetSize(512, 512)
	tinsert(UISpecialFrames, "BitacoraImagePreview")

	local thumbs = {}
	for i = 1, MAX_THUMBS do
		local b = CreateFrame("Button", nil, editor)
		b:SetSize(96, 96)
		b:SetPoint("TOPLEFT", imagesLabel, "BOTTOMLEFT", (i - 1) * 104, -6)
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.bg:SetColorTexture(0, 0, 0, 0.4)
		b.tex = b:CreateTexture(nil, "ARTWORK")
		b.tex:SetPoint("TOPLEFT", 2, -2)
		b.tex:SetPoint("BOTTOMRIGHT", -2, 2)
		b.name = UI.Label(b, "", "GameFontHighlightSmall", "CENTER")
		b.name:SetPoint("BOTTOMLEFT", 2, 2)
		b.name:SetPoint("BOTTOMRIGHT", -2, 2)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
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
				preview.TitleText:SetText(self.file)
				preview.tex:SetTexture(N.ImagePath(self.file))
				preview:Show()
			end
		end)
		b:Hide()
		thumbs[i] = b
	end

	-- link insertion: shift-click while the note has focus (Forever's ChatFrameUtil.InsertLink)
	if ChatFrameUtil and ChatFrameUtil.InsertLink then
		hooksecurefunc(ChatFrameUtil, "InsertLink", function(text)
			if not text or not panel:IsVisible() then
				return
			end
			if body:HasFocus() then
				body:Insert(text)
			elseif title:HasFocus() then
				title:Insert(ns.PlainText(text))
			end
		end)
	end

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
		local sections = N.Sections()
		if view.section and not N.Section(view.section) then
			view.section = nil
		end
		local x = 0
		local function button(i, text, selected, onClick)
			local b = sectionButtons[i]
			if not b then
				b = CreateFrame("Button", nil, sectionBar, "UIPanelButtonTemplate")
				b:SetHeight(22)
				b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				sectionButtons[i] = b
			end
			b:SetText(text)
			b:SetWidth(math.max(50, b:GetFontString():GetStringWidth() + 24))
			b:ClearAllPoints()
			b:SetPoint("LEFT", sectionBar, "LEFT", x, 0)
			x = x + b:GetWidth() + 4
			if selected then
				b:LockHighlight()
			else
				b:UnlockHighlight()
			end
			b:SetScript("OnClick", onClick)
			b:Show()
		end
		button(1, L.FILTER_ALL, view.section == nil, function()
			view.section = nil
			view.Refresh()
		end)
		for i, s in ipairs(sections) do
			button(i + 1, s.name, view.section == s.id, function(self, mouse)
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
								UI.Confirm(L.DELETE_SECTION_CONFIRM:format(s.name, sections[1].name), function()
									N.DeleteSection(s.id)
								end)
							end)
						end
					end)
				else
					view.section = s.id
					view.Refresh()
				end
			end)
		end
		button(#sections + 2, "+", false, function()
			UI.Prompt(L.SECTION_NAME, "", function(text)
				local s = N.AddSection(text)
				if s then
					view.section = s.id
					view.Refresh()
				end
			end)
		end)
		for i = #sections + 3, #sectionButtons do
			sectionButtons[i]:Hide()
		end
	end

	function view.RefreshList(keepScroll)
		local notes = N.Search(search:GetText(), view.section, ns.CharKey())
		list:SetData(notes, keepScroll)
		empty:SetShown(#notes == 0)
	end

	function view.ShowNote()
		local note = current()
		editor:SetShown(note ~= nil)
		if not note then
			view.RefreshList(true)
			return
		end
		title:SetText(note.title or "")
		body:SetText(note.body or "")
		pin:SetText(note.pinned and L.UNPIN or L.PIN)
		scopeLabel:SetText(note.char and L.CHAR_NOTE:format(note.char) or L.ACCOUNT_NOTE)
		attachLabel:SetText(note.attach and L.ATTACHED_TO:format(note.attach.label or note.attach.key) or "")
		local images = note.images or {}
		for i, b in ipairs(thumbs) do
			local file = images[i]
			b.file, b.index = file, i
			if file then
				b.tex:SetTexture(N.ImagePath(file))
				b.name:SetText(file)
				b:Show()
			else
				b:Hide()
			end
		end
		addImage:SetEnabled(#images < MAX_THUMBS)
		view.RefreshList(true)
	end

	view.title, view.body = title, body

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
end
