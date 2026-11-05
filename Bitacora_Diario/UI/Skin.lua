local _, ns = ...
local L = ns.L
local UI = ns.UI
local P = UI.P

-- The leather cover that lies over the book when it opens, then fades and grows a little as the book opens.
-- The texture is Bitácora's own (Bitacora_Datos/Media/cover.tga, drawn by tools/make_textures.py for the
-- window's shape; the Pergamino look does the rest).

local function cover(f)
	if f.cover then
		return f.cover
	end
	local c = CreateFrame("Frame", nil, f)
	c:SetAllPoints()
	c:SetFrameLevel(f:GetFrameLevel() + 60)
	c:EnableMouse(false)
	c:Hide()
	local tex = c:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture(ns.MEDIA .. "cover")
	-- the texture is square; its art is drawn for the window's shape, so show only that middle band
	local w, h = f:GetSize()
	local pad = (1 - h / w) / 2
	tex:SetTexCoord(0, 1, pad, 1 - pad)
	local title = P.Label(c, ns.edition.title or L.TITLE, "title", "CENTER")
	title:SetPoint("BOTTOM", c, "CENTER", 0, 126)
	local ag = c:CreateAnimationGroup()
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
		c:Hide()
	end)
	c.anim = ag
	f.cover = c
	return c
end

-- Called when the window opens: the cover plays once per opening unless it was turned off.
function UI.OpenBook()
	if not ns.db.settings.bookIntro then
		return
	end
	local c = cover(UI.frame)
	c:SetAlpha(1)
	c:Show()
	c.anim:Stop()
	c.anim:Play()
	if SOUNDKIT and SOUNDKIT.IG_ABILITY_PAGE_TURN then
		PlaySound(SOUNDKIT.IG_ABILITY_PAGE_TURN)
	end
end
