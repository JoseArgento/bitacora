local _, ns = ...
local L = ns.L

local UI = {}
ns.UI = UI

-- Widgets the skin recolors (UI/Skin.lua). Weak keys: rows that go away are not kept alive.
UI.labels = setmetatable({}, { __mode = "k" })
UI.insets = setmetatable({}, { __mode = "k" })

function UI.Label(parent, text, font, justify)
	font = font or "GameFontNormal"
	local fs = parent:CreateFontString(nil, "OVERLAY", font)
	fs:SetText(text or "")
	fs:SetJustifyH(justify or "LEFT")
	UI.labels[fs] = font
	if UI.SkinLabel then
		UI.SkinLabel(fs, font)
	end
	return fs
end

function UI.Inset(parent)
	local f = CreateFrame("Frame", nil, parent, "InsetFrameTemplate")
	UI.insets[f] = true
	if UI.SkinInset then
		UI.SkinInset(f)
	end
	return f
end

function UI.Button(parent, text, width, onClick)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(width or 100, 22)
	b:SetText(text)
	if onClick then
		b:SetScript("OnClick", onClick)
	end
	return b
end

function UI.Input(parent, width, onEnter)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(width or 150, 20)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", e.ClearFocus)
	e:SetScript("OnEnterPressed", function(self)
		if onEnter then
			onEnter(self)
		end
		self:ClearFocus()
	end)
	return e
end

function UI.Check(parent, text, onClick)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	local label = UI.Label(c, text, "GameFontHighlightSmall")
	label:SetPoint("LEFT", c, "RIGHT", 2, 0)
	c.label = label
	if onClick then
		c:SetScript("OnClick", onClick)
	end
	return c
end

-- Hyperlinks in a frame's font strings: hover shows the tooltip, click does what the chat does.
function UI.EnableLinks(frame)
	frame:SetHyperlinksEnabled(true)
	frame:SetScript("OnHyperlinkEnter", function(self, link)
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
	end)
	frame:SetScript("OnHyperlinkLeave", function()
		GameTooltip:Hide()
	end)
	frame:SetScript("OnHyperlinkClick", function(_, link, text, button)
		SetItemRef(link, text, button)
	end)
end

-- Hover and selection colors of a list row: pale on the dark default, ink and gold on parchment.
function UI.TintRow(row)
	if UI.IsTavern and UI.IsTavern() then
		row.highlight:SetColorTexture(0.23, 0.14, 0.07, 0.08)
		row.selected:SetColorTexture(0.85, 0.66, 0.27, 0.28)
	else
		row.highlight:SetColorTexture(1, 1, 1, 0.08)
		row.selected:SetColorTexture(0.56, 0.82, 0.77, 0.15)
	end
end

-- A scrolling list with the modern ScrollBox. init(row, item) fills a row; rows are plain Buttons.
function UI.List(parent, rowHeight, init, onClick)
	local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
	local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
	bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 6, 0)
	bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 6, 0)
	local view = CreateScrollBoxListLinearView()
	view:SetElementExtent(rowHeight)
	view:SetElementInitializer("Button", function(row, item)
		if not row.made then
			row.made = true
			local hl = row:CreateTexture(nil, "HIGHLIGHT")
			hl:SetAllPoints()
			hl:SetColorTexture(1, 1, 1, 0.08)
			local sel = row:CreateTexture(nil, "BACKGROUND")
			sel:SetAllPoints()
			sel:SetColorTexture(0.56, 0.82, 0.77, 0.15)
			sel:Hide()
			row.selected = sel
			row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		end
		row.item = item
		row:SetScript("OnClick", function(self, button)
			if onClick then
				onClick(self.item, button, self)
			end
		end)
		init(row, item)
	end)
	ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
	local list = { box = box, bar = bar }
	function list:SetData(items, keepScroll)
		box:SetDataProvider(CreateDataProvider(items), keepScroll and ScrollBoxConstants.RetainScrollPosition or nil)
	end
	function list:Refresh()
		box:ForEachFrame(function(row)
			if row.item then
				init(row, row.item)
			end
		end)
	end
	return list
end

-- One reusable text prompt: UI.Prompt(L.SECTION_NAME, "old", function(text) ... end)
StaticPopupDialogs.BITACORA_PROMPT = {
	text = "%s",
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 255,
	OnShow = function(dialog, data)
		local edit = dialog:GetEditBox()
		edit:SetText(data and data.initial or "")
		edit:HighlightText()
		edit:SetFocus()
	end,
	OnAccept = function(dialog, data)
		if data and data.fn then
			data.fn(dialog:GetEditBox():GetText())
		end
	end,
	EditBoxOnEnterPressed = function(editBox, data)
		if data and data.fn then
			data.fn(editBox:GetText())
		end
		editBox:GetParent():Hide()
	end,
	EditBoxOnEscapePressed = function(editBox)
		editBox:GetParent():Hide()
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

StaticPopupDialogs.BITACORA_CONFIRM = {
	text = "%s",
	button1 = YES,
	button2 = NO,
	OnAccept = function(_, data)
		if data and data.fn then
			data.fn()
		end
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function UI.Prompt(question, initial, fn)
	StaticPopup_Show("BITACORA_PROMPT", question, nil, { initial = initial, fn = fn })
end

function UI.Confirm(question, fn)
	StaticPopup_Show("BITACORA_CONFIRM", question, nil, { fn = fn })
end

function UI.Menu(owner, build)
	MenuUtil.CreateContextMenu(owner, function(_, root)
		build(root)
	end)
end

function UI.FormatDate(e)
	return e.d or date("%Y-%m-%d %H:%M", e.t or 0)
end

UI.L = L
