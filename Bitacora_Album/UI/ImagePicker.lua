local ADDON, ns = ...
local L = ns.L
local UI = ns.UI
local P = UI.P
local I = ns.Images

-- The pictures to choose from, as a card: the list on the left (the capture helper's index, newest first,
-- then the names typed by hand in other notes), the chosen one on the right, big. UI.PickImage(function(file)
-- ... end) opens it; picking closes it. Nobody has to type a file name any more, though they still can.

local ROW, THUMB = 46, 38
local PREVIEW_W, PREVIEW_H = 272, 190

local card

-- A texture inside a box, shaped like the picture (the helper squeezes textures to powers of two).
function UI.FitImage(tex, box, name, boxW, boxH)
	local w, h = I.Fit(name, boxW, boxH)
	tex:ClearAllPoints()
	tex:SetPoint("CENTER", box, "CENTER", 0, 0)
	tex:SetSize(w, h)
	tex:SetTexture(I.Path(name))
end

local function subText(item)
	local bits = {}
	if item.t and item.t > 0 then
		bits[#bits + 1] = date("%d/%m %H:%M", item.t)
	end
	if item.unsure then
		bits[#bits + 1] = L.IMG_UNSURE
	elseif item.shot then
		bits[#bits + 1] = L.IMG_SHOT
	elseif item.typed then
		bits[#bits + 1] = L.IMG_TYPED
	end
	if item.w and item.h then
		bits[#bits + 1] = ("%d×%d"):format(item.w, item.h)
	end
	if (item.uses or 0) > 0 then
		bits[#bits + 1] = item.uses == 1 and L.IMG_USE_ONE or L.IMG_USES:format(item.uses)
	end
	return table.concat(bits, " · ")
end

local function build()
	card = P.Card(ADDON .. "ImagePicker", 640, 470, L.IMG_PICK_TITLE)
	card:SetFrameStrata("DIALOG")
	local body = card.body

	-- left: the list -------------------------------------------------------------------------------
	local listFrame = CreateFrame("Frame", nil, body)
	listFrame:SetPoint("TOPLEFT", 0, 0)
	listFrame:SetPoint("BOTTOMLEFT", 0, 62)
	listFrame:SetWidth(300)
	local list
	list = UI.List(listFrame, ROW, function(row, item)
		if not row.title then
			row.frame = CreateFrame("Frame", nil, row)
			row.frame:SetSize(THUMB, THUMB)
			row.frame:SetPoint("LEFT", 4, 0)
			row.bg = row.frame:CreateTexture(nil, "BACKGROUND")
			row.bg:SetAllPoints()
			row.bg:SetColorTexture(0.23, 0.14, 0.07, 0.15)
			row.tex = row.frame:CreateTexture(nil, "ARTWORK")
			row.title = UI.Label(row, "", "strong")
			row.title:SetPoint("TOPLEFT", row.frame, "TOPRIGHT", 8, -3)
			row.title:SetPoint("RIGHT", -4, 0)
			row.title:SetWordWrap(false)
			row.sub = UI.Label(row, "", "small")
			row.sub:SetPoint("BOTTOMLEFT", row.frame, "BOTTOMRIGHT", 8, 3)
			row.sub:SetPoint("RIGHT", -4, 0)
			row.sub:SetWordWrap(false)
		end
		UI.FitImage(row.tex, row.frame, item.file, THUMB - 2, THUMB - 2)
		row.title:SetText(item.title)
		row.sub:SetText(subText(item))
		row.selected:SetShown(card.selected == item.file)
	end, function(item)
		card.selected = item.file
		list:Refresh()
		card.ShowSelected()
	end)
	list.box:SetPoint("TOPLEFT", 0, 0)
	list.box:SetPoint("BOTTOMRIGHT", -16, 0)
	card.list = list

	-- no pictures at all: what the helper is and where to get it
	local empty = UI.Label(listFrame, "", "body")
	empty:SetPoint("TOPLEFT", 4, -4)
	empty:SetPoint("RIGHT", -8, 0)
	empty:SetWordWrap(true)
	empty:SetSpacing(3)
	card.empty = empty

	-- right: the chosen one -----------------------------------------------------------------------
	local right = CreateFrame("Frame", nil, body)
	right:SetPoint("TOPLEFT", listFrame, "TOPRIGHT", 16, 0)
	right:SetPoint("BOTTOMRIGHT", 0, 62)
	local frame = CreateFrame("Frame", nil, right)
	frame:SetSize(PREVIEW_W + 8, PREVIEW_H + 8)
	frame:SetPoint("TOP", 0, 0)
	local bg = frame:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0.23, 0.14, 0.07, 0.12)
	local tex = frame:CreateTexture(nil, "ARTWORK")
	card.frame, card.tex = frame, tex
	local name = UI.Label(right, "", "big")
	name:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", 0, -8)
	name:SetPoint("RIGHT", 0, 0)
	name:SetWordWrap(false)
	local sub = UI.Label(right, "", "small")
	sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
	sub:SetPoint("RIGHT", 0, 0)
	sub:SetWordWrap(false)
	card.name, card.sub = name, sub
	local use = UI.Button(right, L.IMG_USE, 150, function()
		local file, fn = card.selected, card.onPick
		if file and fn then
			card:Hide()
			fn(file)
		end
	end)
	use:SetPoint("BOTTOMLEFT", 0, 0)
	local rename = UI.Button(right, L.RENAME, 100, function()
		local file = card.selected
		if file then
			UI.Prompt(L.IMG_RENAME_PROMPT, I.Title(file), function(text)
				I.SetTitle(file, text)
				card.Refresh()
			end)
		end
	end)
	rename:SetPoint("LEFT", use, "RIGHT", 8, 0)
	card.use, card.rename = use, rename
	local pick = UI.Label(right, L.IMG_PICK_ONE, "muted", "CENTER")
	pick:SetPoint("CENTER", frame, "CENTER", 0, 0)
	pick:SetPoint("LEFT", frame, "LEFT", 12, 0)
	pick:SetPoint("RIGHT", frame, "RIGHT", -12, 0)
	pick:SetWordWrap(true)
	card.pick = pick

	-- bottom: how pictures get here, the helper's address, typing a name, reloading ----------------------
	local rule = UI.Rule(body)
	rule:SetPoint("BOTTOMLEFT", 0, 54)
	rule:SetPoint("RIGHT", 0, 0)
	local reload = UI.Button(body, L.IMG_RELOAD, 96, function()
		C_UI.Reload()
	end)
	reload:SetPoint("BOTTOMRIGHT", 0, 0)
	reload:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(L.IMG_RELOAD)
		GameTooltip:AddLine(L.IMG_RELOAD_TIP, 1, 1, 1, true)
		GameTooltip:Show()
	end)
	reload:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)
	local typeIt = UI.Button(body, L.IMG_TYPE, 140, function()
		UI.Prompt(L.IMAGE_FILE, "", function(text)
			local file = I.ValidName(text)
			if not file then
				ns.Print(L.IMAGE_BAD_NAME)
				return
			end
			local fn = card.onPick
			card:Hide()
			if fn then
				fn(file)
			end
		end)
	end)
	typeIt:SetPoint("RIGHT", reload, "LEFT", -8, 0)
	card.reload, card.typeIt = reload, typeIt
	local hint = UI.Label(body, "", "small")
	hint:SetPoint("BOTTOMLEFT", 0, 26)
	hint:SetPoint("RIGHT", typeIt, "LEFT", -12, 0)
	hint:SetWordWrap(true)
	card.hint = hint
	-- the helper's address, to select and copy (an addon cannot open a browser)
	local url = UI.Input(body, 330, nil, nil)
	url:SetPoint("BOTTOMLEFT", 0, 0)
	url:HookScript("OnTextChanged", function(self, userInput)
		if userInput then -- it is there to be copied, not edited
			self:SetValue(L.IMG_HELPER_URL)
			self:HighlightText()
		end
	end)
	url:HookScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	card.url = url

	function card.ShowSelected()
		local file = card.selected
		local has = file ~= nil
		tex:SetShown(has)
		name:SetShown(has)
		sub:SetShown(has)
		pick:SetShown(not has and #card.items > 0)
		use:SetEnabled(has and card.onPick ~= nil)
		rename:SetEnabled(has)
		if not has then
			return
		end
		UI.FitImage(tex, frame, file, PREVIEW_W, PREVIEW_H)
		name:SetText(I.Title(file))
		local item
		for _, it in ipairs(card.items) do
			if it.file == file then
				item = it
			end
		end
		local e = I.Find(file)
		local shown = e and e.file or file
		sub:SetText(shown .. (item and subText(item) ~= "" and (" · " .. subText(item)) or ""))
	end

	function card.Refresh()
		local items = I.List()
		card.items = items
		if card.selected then
			local still = false
			for _, it in ipairs(items) do
				still = still or it.file == card.selected
			end
			if not still then
				card.selected = nil
			end
		end
		list:SetData(items, true)
		local helper = I.HasHelper()
		empty:SetShown(#items == 0)
		list.box:SetShown(#items > 0)
		empty:SetText(helper and L.IMG_EMPTY_HELPER or L.IMG_NO_HELPER)
		-- the helper's address only while there is nothing to show: with pictures in the list, how to add more
		local showUrl = not helper and #items == 0
		hint:SetText(helper and L.IMG_HELPER_HINT or (showUrl and L.IMG_GET_HELPER or L.IMG_COPY_HINT))
		url:SetShown(showUrl)
		url:SetValue(L.IMG_HELPER_URL)
		hint:ClearAllPoints()
		hint:SetPoint("BOTTOMLEFT", 0, showUrl and 26 or 4)
		hint:SetPoint("RIGHT", typeIt, "LEFT", -12, 0)
		card.ShowSelected()
	end
end

-- Opens the card. onPick(file) is called with the chosen picture's file name; without it the card only shows
-- what there is (and lets you rename).
function UI.PickImage(onPick)
	if not card then
		build()
	end
	card.onPick = onPick
	card.selected = nil
	card.Refresh()
	card:Show()
	UI.imagePicker = card
	return card
end

ns.On("images", function()
	if card and card:IsShown() then
		card.Refresh()
	end
end)
