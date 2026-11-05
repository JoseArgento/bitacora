local _, ns = ...
local L = ns.L
local UI = ns.UI

-- A page in the game's Options → AddOns list. Forever loads Blizzard_Settings_Shared, whose
-- Settings.RegisterCanvasLayoutCategory takes any frame we draw ourselves.
-- The page is drawn the first time it is needed (never at file load), so its texts are in the chosen language.

local QUALITIES = { { 2, "QUALITY_UNCOMMON" }, { 3, "QUALITY_RARE" }, { 4, "QUALITY_EPIC" }, { 5, "QUALITY_LEGENDARY" } }
local CLOCKS = { { "local", "CLOCK_LOCAL" }, { "realm", "CLOCK_REALM" } }
local CHATS = { { "never", "CHAT_NEVER" }, { "important", "CHAT_IMPORTANT" }, { "all", "CHAT_ALL" } }
local LANGS = { { "auto", "LANG_AUTO" }, { "es", "LANG_ES" }, { "en", "LANG_EN" } }

local panel = CreateFrame("Frame")
panel:Hide()
UI.options = panel
panel.checks = {}

local function labelOf(pairs_, value)
	for _, pair in ipairs(pairs_) do
		if pair[1] == value then
			return L[pair[2]]
		end
	end
	return tostring(value)
end

-- A button that opens a radio menu over `pairs_` and stores the pick in settings[key].
local function chooser(key, pairs_, default, width, onPick)
	local b = UI.Button(panel, "", width or 200, nil)
	b:SetScript("OnClick", function(self)
		UI.Menu(self, function(root)
			for _, pair in ipairs(pairs_) do
				root:CreateRadio(L[pair[2]], function()
					return (ns.db.settings[key] or default) == pair[1]
				end, function()
					ns.db.settings[key] = pair[1]
					if onPick then
						onPick(pair[1])
					end
					panel.Refresh()
					ns.Fire("settings", key)
				end)
			end
		end)
	end)
	b.key, b.pairs, b.default = key, pairs_, default
	return b
end

function panel.Build()
	if panel.built then
		return
	end
	panel.built = true
	local title = UI.Label(panel, ns.edition.title or L.TITLE, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	local sub = UI.Label(panel, L.OPTIONS_INTRO, "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)

	local y = -64
	local function add(key, text, part)
		if not part then
			return
		end
		local c = UI.Check(panel, text, function(self)
			ns.db.settings[key] = self:GetChecked() and true or false
			ns.Fire("settings", key)
		end)
		c:SetPoint("TOPLEFT", 12, y)
		panel.checks[key] = c
		y = y - 28
	end
	-- only the options of the parts this edition has
	add("tooltipNotes", L.OPT_TOOLTIP, ns.Notes)
	add("zoneNotes", L.OPT_ZONE, ns.Notes)
	add("journalQuests", L.OPT_QUESTS, ns.Journal)
	add("chronicle", L.OPT_CHRONICLE, ns.Chronicle)
	add("guildReminders", L.OPT_GUILD_REMINDERS, ns.GuildReminders)
	add("reminderPopup", L.OPT_REMINDER_POPUP, ns.Reminders)
	add("calendar", L.OPT_CALENDAR, ns.Reminders)
	add("calendarAuto", L.OPT_CALENDAR_AUTO, ns.Reminders)
	add("campBuff", L.OPT_CAMP_BUFF, ns.Reminders)
	add("bookIntro", L.OPT_BOOK_INTRO, true)
	add("minimap", L.OPT_MINIMAP, true)

	-- the pickers: a label and a button each, one under the other
	local last
	local function picker(labelKey, button, shown)
		local label = UI.Label(panel, L[labelKey], "GameFontNormal")
		if last then
			label:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -18)
		else
			label:SetPoint("TOPLEFT", 16, y - 12)
		end
		button:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -6)
		label:SetShown(shown)
		button:SetShown(shown)
		if shown then
			last = button
		end
		return label
	end
	panel.loot = chooser("lootQuality", QUALITIES, 4, 160)
	picker("SETTINGS_LOOT", panel.loot, ns.Journal ~= nil)
	panel.clock = chooser("clock", CLOCKS, "local", 200)
	picker("OPT_CLOCK", panel.clock, ns.Reminders ~= nil)
	panel.chat = chooser("chat", CHATS, "important", 260)
	picker("OPT_CHAT", panel.chat, true)
	panel.lang = chooser("lang", LANGS, "auto", 200, function(code)
		ns.SetLocale(code)
	end)
	picker("OPT_LANG", panel.lang, true)
end

function panel.Refresh()
	panel.Build()
	for key, c in pairs(panel.checks) do
		c:SetChecked(ns.db.settings[key] and true or false)
	end
	for _, b in ipairs({ panel.loot, panel.clock, panel.chat, panel.lang }) do
		b:SetText(labelOf(b.pairs, ns.db.settings[b.key] or b.default))
	end
end

panel:SetScript("OnShow", panel.Refresh)

function UI.RegisterOptions()
	if UI.optionsCategory or not (Settings and Settings.RegisterCanvasLayoutCategory) then
		return
	end
	if ns.disabled then
		return
	end
	panel.Build()
	local category = Settings.RegisterCanvasLayoutCategory(panel, ns.edition.title or L.TITLE)
	Settings.RegisterAddOnCategory(category)
	UI.optionsCategory = category
end

function ns.OpenOptions()
	UI.RegisterOptions()
	if UI.optionsCategory then
		Settings.OpenToCategory(UI.optionsCategory:GetID())
	end
end

ns.On("login", UI.RegisterOptions)
