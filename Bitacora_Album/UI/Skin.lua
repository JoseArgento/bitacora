local _, ns = ...
local L = ns.L
local UI = ns.UI

-- "Tavern book": parchment pages, a wooden title bar, dark ink, and a leather cover that opens when the
-- window does. Textures are the addon's own (Media/*.tga, made by tools/make_textures.py).

local INK = { 0.23, 0.14, 0.07 }
local INK_SOFT = { 0.42, 0.31, 0.19 }
local HEADING = { 0.50, 0.17, 0.08 }
local GOLD = { 0.85, 0.66, 0.27 }

-- which ink each font of ours takes on parchment
local ROLE = {
	GameFontNormal = HEADING,
	GameFontNormalLarge = HEADING,
	GameFontNormalSmall = HEADING,
	GameFontHighlight = INK,
	GameFontHighlightSmall = INK,
	GameFontDisable = INK_SOFT,
	GameFontDisableSmall = INK_SOFT,
}

local function tavern()
	return ns.db and ns.db.settings.skin == "tavern"
end

local original = setmetatable({}, { __mode = "k" }) -- font string -> { r, g, b, a } before the skin

function UI.SkinLabel(fs, font)
	if not original[fs] then
		original[fs] = { fs:GetTextColor() }
	end
	local color = tavern() and ROLE[font]
	if color then
		fs:SetTextColor(color[1], color[2], color[3])
	elseif original[fs][1] then
		fs:SetTextColor(unpack(original[fs]))
	end
end

function UI.SkinInset(inset)
	if not inset.tavernBg then
		local t = inset:CreateTexture(nil, "BACKGROUND", nil, 7)
		t:SetPoint("TOPLEFT", 3, -3)
		t:SetPoint("BOTTOMRIGHT", -3, 3)
		t:SetTexture(ns.MEDIA .. "parchment")
		t:SetVertexColor(0.93, 0.9, 0.84)
		inset.tavernBg = t
	end
	inset.tavernBg:SetShown(tavern())
end

local function frameParts(f)
	if f.tavern then
		return f.tavern
	end
	local parts = {}
	local page = f:CreateTexture(nil, "BACKGROUND", nil, 7)
	page:SetPoint("TOPLEFT", 4, -24)
	page:SetPoint("BOTTOMRIGHT", -6, 4)
	page:SetTexture(ns.MEDIA .. "parchment")
	parts.page = page
	local bar = f:CreateTexture(nil, "BORDER", nil, 7)
	bar:SetPoint("TOPLEFT", 2, -2)
	bar:SetPoint("TOPRIGHT", -2, -2)
	bar:SetHeight(22)
	bar:SetTexture(ns.MEDIA .. "wood")
	bar:SetTexCoord(0, 1, 0, 0.25)
	parts.bar = bar
	local trim = f:CreateTexture(nil, "BORDER", nil, 7)
	trim:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, 0)
	trim:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	trim:SetHeight(2)
	trim:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
	parts.trim = trim

	-- the cover: shown over the window, then fades and grows a little as the book opens
	local cover = CreateFrame("Frame", nil, f)
	cover:SetAllPoints()
	cover:SetFrameLevel(f:GetFrameLevel() + 60)
	cover:EnableMouse(false)
	cover:Hide()
	local tex = cover:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture(ns.MEDIA .. "cover")
	local title = cover:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	title:SetPoint("BOTTOM", cover, "CENTER", 0, 112)
	title:SetText(L.TITLE)
	title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	local ag = cover:CreateAnimationGroup()
	local fade = ag:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0)
	fade:SetStartDelay(0.35)
	fade:SetDuration(0.45)
	local grow = ag:CreateAnimation("Scale")
	grow:SetScaleFrom(1, 1)
	grow:SetScaleTo(1.06, 1.06)
	grow:SetStartDelay(0.35)
	grow:SetDuration(0.45)
	ag:SetScript("OnFinished", function()
		cover:Hide()
	end)
	parts.cover, parts.openAnim = cover, ag
	f.tavern = parts
	return parts
end

function UI.ApplySkin()
	local f = UI.frame
	local on = tavern()
	local parts = frameParts(f)
	parts.page:SetShown(on)
	parts.bar:SetShown(on)
	parts.trim:SetShown(on)
	if on then
		f.TitleText:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
	else
		f.TitleText:SetTextColor(1, 0.82, 0)
	end
	for fs, font in pairs(UI.labels) do
		UI.SkinLabel(fs, font)
	end
	for inset in pairs(UI.insets) do
		UI.SkinInset(inset)
	end
	for _, view in pairs(UI.views) do
		if view.body and view.body.SetTextColor and CreateColor then
			local c = on and INK or { 1, 1, 1 }
			view.body:SetTextColor(CreateColor(c[1], c[2], c[3]))
		end
	end
end

-- Called when the window opens: the cover plays once per opening while the skin is on.
function UI.OpenBook()
	if not tavern() or not ns.db.settings.bookIntro then
		return
	end
	local parts = frameParts(UI.frame)
	parts.cover:SetAlpha(1)
	parts.cover:Show()
	parts.openAnim:Stop()
	parts.openAnim:Play()
	if SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN then
		PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
	end
end

ns.On("settings", function(key)
	if key == "skin" then
		UI.ApplySkin()
	end
end)
ns.On("login", UI.ApplySkin)
