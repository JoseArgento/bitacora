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

-- The page lives in the game's own Options window, which is dark: so it uses the game's fonts and check boxes
-- (white and gold), not the book's ink, which is unreadable there. Only the leather buttons stay ours.
local function settingsLabel(parent, text, font)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	return fs
end

local function settingsCheck(parent, text, onClick)
	local c = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	c:SetSize(24, 24)
	local label = c.Text or c.text
	if not label then
		label = c:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		label:SetPoint("LEFT", c, "RIGHT", 4, 0)
	end
	label:SetFontObject("GameFontHighlight")
	label:SetText(text or "")
	c.label = label
	if onClick then
		c:SetScript("OnClick", onClick)
	end
	return c
end
UI.SettingsLabel, UI.SettingsCheck = settingsLabel, settingsCheck

-- "Libreta, Diario y Recordatorios. La ventana se abre con /bita." from the parts this edition has.
function UI.OptionsIntro()
	local parts = {}
	if ns.Notes then
		parts[#parts + 1] = L.TAB_NOTES
	end
	if ns.Journal then
		parts[#parts + 1] = L.TAB_JOURNAL
	end
	if ns.Album then
		parts[#parts + 1] = L.TAB_ALBUM
	end
	if ns.Reminders then
		parts[#parts + 1] = L.TAB_REMINDERS
	end
	local list
	if #parts <= 1 then
		list = parts[1] or ""
	else
		list = table.concat(parts, ", ", 1, #parts - 1) .. L.LIST_AND .. parts[#parts]
	end
	local slash = ns.edition.slash and ns.edition.slash[#ns.edition.slash] or "/bita"
	return L.OPTIONS_INTRO:format(list, slash)
end

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
	local title = settingsLabel(panel, ns.edition.title or L.TITLE, "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	local sub = settingsLabel(panel, UI.OptionsIntro(), "GameFontHighlightSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	panel.title, panel.intro = title, sub

	local y = -64
	local function add(key, text, part)
		if not part then
			return
		end
		local c = settingsCheck(panel, text, function(self)
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
	add("minimapMerged", L.OPT_MINIMAP_MERGED, true)

	-- the pickers: a label and a button each, one under the other
	local last
	local function picker(labelKey, button, shown)
		local label = settingsLabel(panel, L[labelKey], "GameFontNormal")
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
