local _, ns = ...
local L = ns.L

-- Thin wrappers over Pergamino (the shared book look, vendored in Bitacora_Datos/Libs/Pergamino), plus the
-- popups and menus the tabs share. The old GameFont* names map to Pergamino roles so the tabs read the same.

local P = Pergamino
local UI = {}
ns.UI = UI
UI.P = P

local ROLE = {
	GameFontNormal = "heading",
	GameFontNormalLarge = "big",
	GameFontNormalSmall = "subheading",
	GameFontHighlight = "body",
	GameFontHighlightSmall = "small",
	GameFontDisable = "muted",
	GameFontDisableSmall = "small",
}

function UI.Label(parent, text, font, justify)
	return P.Label(parent, text, ROLE[font] or font or "body", justify)
end

function UI.Inset(parent)
	return P.Panel(parent)
end

function UI.Button(parent, text, width, onClick)
	return P.Button(parent, text, width, onClick)
end

function UI.Chip(parent, text, onClick)
	return P.Chip(parent, text, onClick)
end

function UI.Input(parent, width, onEnter, placeholder)
	return P.Edit(parent, width, { onEnter = onEnter, placeholder = placeholder })
end

function UI.Check(parent, text, onClick)
	return P.Check(parent, text, onClick)
end

function UI.Rule(parent)
	return P.Rule(parent)
end

function UI.Tag(parent, text, kind)
	return P.Tag(parent, text, kind)
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

function UI.List(parent, rowHeight, init, onClick)
	return P.List(parent, rowHeight, init, onClick)
end

-- A row of chips that wraps when the page is too narrow. items = { { text, selected, onClick } }
function UI.ChipRow(parent, width)
	local row = CreateFrame("Frame", nil, parent)
	row:SetWidth(width or 300)
	row:SetHeight(20)
	row.chips = {}
	function row:Set(items)
		local x, y, maxX = 0, 0, self:GetWidth()
		for i, it in ipairs(items) do
			local c = self.chips[i]
			if not c then
				c = P.Chip(self, "")
				c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				self.chips[i] = c
			end
			c:SetText(it.text)
			c:Fit()
			c:SetPressed(it.selected)
			c:SetScript("OnClick", it.onClick)
			if x > 0 and x + c:GetWidth() > maxX then
				x, y = 0, y + 24
			end
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
			x = x + c:GetWidth() + 4
			c:Show()
		end
		for i = #items + 1, #self.chips do
			self.chips[i]:Hide()
		end
		self:SetHeight(y + 20)
	end
	return row
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
