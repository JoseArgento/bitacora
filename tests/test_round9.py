"""Round 9, the experience in the client: the start entry without a zone, level-ups folded in the
milestones view, chat with measure, a language of your own, the welcome card and bookmark tooltips."""

from __future__ import annotations

import pytest
from test_addon import Game


@pytest.fixture
def game():
    g = Game()
    g.login()
    g.m.runTimers()
    return g


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


# the journal --------------------------------------------------------------------------------------


def test_the_start_entry_without_a_zone_reads_fine_and_fills_in_later():
    g = Game()
    g.m.where.mapID, g.m.where.zone, g.m.where.sub = None, "", ""  # the zone text is empty right at login
    g.login()
    start = g.journal()[0]
    assert start.kind == "start" and (start.zone or "") == ""
    assert g.run("return ns.Journal.Text(ns.Char().journal[1])") == "Started the journal at level 10."
    g.m.where.mapID, g.m.where.zone, g.m.where.sub = 1429, "Elwynn Forest", "Goldshire"
    g.arrive()
    assert g.journal()[0].zone == "Elwynn Forest" and g.journal()[0].sub == "Goldshire"
    assert g.run("return ns.Journal.Text(ns.Char().journal[1])") == "Started the journal at level 10 in Elwynn Forest."


def test_consecutive_level_ups_of_a_day_fold_into_one_milestone_row(game):
    for lv in (11, 12, 13):
        game.m.player.level = lv
        game.fire("PLAYER_LEVEL_UP", lv)
    game.m.where.mapID, game.m.where.zone = 1436, "Westfall"
    game.arrive()
    game.m.player.level = 14
    game.fire("PLAYER_LEVEL_UP", 14)
    rows = lua_list(game.run("return ns.Journal.Grouped(ns.Journal.Entries(nil, 'milestones'))"))
    assert [(r.kind, bool(r.group)) for r in rows] == [("start", False), ("level", True), ("zone", False), ("level", False)]
    folded = rows[1]
    assert (folded["from"], folded.level, len(folded.entries)) == (11, 13, 3)
    assert game.run("return ns.Journal.Text(ns.Journal.Grouped(ns.Journal.Entries(nil, 'milestones'))[2])") == "Levels 11 to 13"
    # the "all" view keeps every entry
    assert game.run("return #ns.Journal.Entries(nil, 'all')") == 6
    # and the window's milestones list shows the folded row
    game.run("ns.Toggle('journal')")
    assert game.run("return ns.UI.views[ns.UI.tabOfTopic.journal].filter") == "milestones"
    # the row reads "Levels 11 to 13 · Elwynn Forest": no period before the place
    texts = lua_list(game.run("local t = {}; for _, r in ipairs(ns.UI.views[ns.UI.tabOfTopic.journal].list.box.rows) do t[#t + 1] = r.text:GetText() end; return t"))
    assert "Levels 11 to 13 |cff6c4e31· Elwynn Forest|r" in texts and not [t for t in texts if ". |cff6c4e31·" in t]


# chat with measure ----------------------------------------------------------------------------------


def shoot(g, n):
    for _ in range(n):
        g.fire("SCREENSHOT_SUCCEEDED")


def test_screenshot_lines_once_per_session_by_default(game):
    before = len(game.chat())
    shoot(game, 3)
    assert len(game.chat()) == before + 1
    assert "screenshot noted" in game.chat()[-1]


def test_chat_modes_all_and_never(game):
    game.lua.globals().SlashCmdList.BITACORA("chat todo")
    assert game.db.settings.chat == "all" and "Chat: Everything." in game.chat()[-1]
    before = len(game.chat())
    shoot(game, 3)
    assert len(game.chat()) == before + 3
    game.lua.globals().SlashCmdList.BITACORA("chat never")
    assert game.db.settings.chat == "never"
    before = len(game.chat())
    shoot(game, 2)
    assert len(game.chat()) == before
    # answers to commands always come through
    game.lua.globals().SlashCmdList.BITACORA("help")
    assert "/bitacora" in game.chat()[-1]


def test_the_old_quiet_setting_migrates():
    g = Game(saved="BitacoraDB = { settings = { screenshotChat = false } }")
    g.login()
    assert g.db.settings.chat == "never" and g.db.settings.screenshotChat is None


# language -------------------------------------------------------------------------------------------


def test_spanish_on_an_english_client_through_the_setting():
    g = Game(saved='BitacoraDB = { settings = { lang = "es" } }')
    g.login()
    assert g.run("return ns.lang") == "es"
    assert g.run("return ns.L.TAB_NOTES") == "Libreta"
    assert g.run("return ns.UI.frame.title._text") == "Bitácora"
    assert g.run("return ns.UI.tabs[1]._text") == "Libreta"
    assert g.lua.globals().BINDING_NAME_BITACORA_TOGGLE == "Abrir / cerrar"
    g.fire("SCREENSHOT_SUCCEEDED")
    assert "captura anotada" in g.chat()[-1]


def test_the_language_switches_from_the_slash_command(game):
    assert game.run("return ns.L.TAB_JOURNAL") == "Journal"
    game.lua.globals().SlashCmdList.BITACORA("idioma es")
    assert game.db.settings.lang == "es" and game.run("return ns.L.TAB_JOURNAL") == "Diario"
    assert game.run("return ns.UI.tabs[2]._text") == "Diario"
    assert "Idioma: Castellano" in game.chat()[-1]
    game.lua.globals().SlashCmdList.BITACORA("language auto")
    assert game.run("return ns.L.TAB_JOURNAL") == "Journal"
    game.lua.globals().SlashCmdList.BITACORA("idioma klingon")
    assert game.db.settings.lang == "auto"


def test_a_spanish_client_still_gets_spanish_by_default():
    g = Game(locale="esES")
    g.login()
    assert g.run("return ns.L.TAB_NOTES") == "Libreta"
    g.lua.globals().SlashCmdList.BITACORA("idioma en")
    assert g.run("return ns.L.TAB_NOTES") == "Notebook"


def test_the_options_page_offers_chat_and_language(game):
    panel = game.ns.UI.options
    panel.Refresh()
    assert panel.chat._text == "The important bits, once per session"
    assert panel.lang._text == "Same as the game"
    game.run("ns.UI.options.lang:GetScript('OnClick')(ns.UI.options.lang)")
    game.m.clickMenu("Castellano")
    assert game.db.settings.lang == "es" and game.run("return ns.L.TAB_NOTES") == "Libreta"
    assert panel.lang._text == "Castellano"
    game.run("ns.UI.options.chat:GetScript('OnClick')(ns.UI.options.chat)")
    game.m.clickMenu("Nada")
    assert game.db.settings.chat == "never"


# welcome and bookmarks --------------------------------------------------------------------------------


def test_the_welcome_card_shows_once(game):
    assert game.db.settings.welcomed is None
    game.run("ns.Toggle()")
    assert game.db.settings.welcomed is True
    card = game.run("return ns.UI.welcomeCard")
    assert card._shown is True
    text = card.text._text
    assert "Notebook" in text and "/bitacora" in text and "Guild" in text
    # the card is as tall as its text needs, with the button under the text
    assert card.height >= 40 + game.run("return ns.UI.welcomeCard.text:GetStringHeight()") + 16 + 26
    point = game.run("local p = ns.UI.welcomeCard.ok._points[1]; return p[1] .. ':' .. tostring(p[2] == ns.UI.welcomeCard.text)")
    assert point == "TOP:true"
    game.run("ns.UI.welcomeCard:Hide(); ns.Toggle(); ns.Toggle()")
    assert game.run("return ns.UI.welcomeCard._shown") is False


def test_no_welcome_card_in_a_single_page_part():
    g = Game(addons=("Bitacora_Recordatorios",))
    g.login()
    g.run("ns.Toggle()")
    assert g.run("return ns.UI.welcomeCard") is None and g.db.settings.welcomed is None


def test_bookmark_tooltips_describe_the_page_and_the_key(game):
    game.m.bindings["BITACORA_TOGGLE"] = "F9"
    tab = game.run("return ns.UI.tabs[2]")
    game.run("local t = ns.UI.tabs[2]; t:GetScript('OnEnter')(t)")
    tip = game.lua.globals().GameTooltip
    lines = lua_list(tip.lines)
    assert tip._text == "Journal" and "Writes itself" in lines[-2] and lines[-1] == "Key: F9"
    assert tab.textKey == "TAB_JOURNAL"


def test_an_options_bookmark_opens_the_options(game):
    game.run("ns.Toggle()")
    tab = game.run("return ns.UI.optionsTab")
    assert tab is not None and tab.fontString._text == "Options"
    opened = game.run("local hit = false; local real = ns.OpenOptions; ns.OpenOptions = function() hit = true end; ns.UI.optionsTab:GetScript('OnClick')(ns.UI.optionsTab); ns.OpenOptions = real; return hit")
    assert opened is True
    # it is the book's own action bookmark: smaller, brown, never the open one
    assert game.run("return ns.UI.optionsTab.action ~= nil and ns.UI.optionsTab.color == Pergamino.BOOKMARK_ACTION_COLOR") is True
    assert game.run("return ns.UI.optionsTab:GetWidth(), ns.UI.optionsTab:GetHeight()") == (128, 22)
    game.run("ns.UI.frame:SelectTab('options')")
    assert game.run("return ns.UI.frame.selected") != "options"

def test_no_options_bookmark_on_a_single_page_part():
    g = Game(addons=("Bitacora_Recordatorios",))
    g.login()
    g.run("ns.Toggle()")
    assert g.run("return ns.UI.optionsTab") is None


# minimap button ---------------------------------------------------------------------------------------


def test_a_minimap_button_opens_the_book_and_the_options(game):
    b = game.run("return BitacoraMinimapButton")
    assert b is not None and b._shown is not False
    assert b.icon.texture == "Interface\\AddOns\\Bitacora_Datos\\Media\\icon"
    game.run("BitacoraMinimapButton:GetScript('OnClick')(BitacoraMinimapButton, 'LeftButton')")
    assert game.run("return BitacoraFrame:IsShown()") is True
    hit = game.run("local hit; local real = ns.OpenOptions; ns.OpenOptions = function() hit = true end; BitacoraMinimapButton:GetScript('OnClick')(BitacoraMinimapButton, 'RightButton'); ns.OpenOptions = real; return hit")
    assert hit is True


def test_the_minimap_button_keeps_where_you_dragged_it(game):
    game.m.cursorX, game.m.cursorY = 1000, 600  # straight above the minimap's centre (1000, 500)
    game.run("local b = BitacoraMinimapButton; b:GetScript('OnDragStart')(b); b:GetScript('OnUpdate')(b); b:GetScript('OnDragStop')(b)")
    assert round(game.db.settings.minimapAngle.Bitacora) == 90
    g2 = Game(saved=game.m.savedVariables("BitacoraDB"))
    g2.login()
    assert round(g2.run("return BitacoraMinimapButton.angle")) == 90


def test_the_option_hides_the_minimap_button(game):
    game.run('ns.db.settings.minimap = false; ns.Fire("settings", "minimap")')
    assert game.run("return BitacoraMinimapButton._shown") is False


def test_parts_turned_off_by_the_full_addon_draw_no_button():
    g = Game(addons=("Bitacora", "Bitacora_Diario"))
    g.login()
    assert g.run("return BitacoraMinimapButton") is not None
    assert g.run("return Bitacora_DiarioMinimapButton") is None


def test_parts_together_without_the_full_addon_do_not_overlap():
    g = Game(addons=("Bitacora_Diario", "Bitacora_Recordatorios"))
    g.login()
    a = g.run("return Bitacora_DiarioMinimapButton.angle")
    b = g.run("return Bitacora_RecordatoriosMinimapButton.angle")
    assert a != b
    assert g.run("return Bitacora_RecordatoriosMinimapButton.icon.texture").endswith("icon_bell")


def test_the_album_says_where_pictures_for_notes_go(game):
    game.run("ns.Toggle('album')")
    text = game.run("return ns.UI.views[ns.UI.tabOfTopic.album].folder:GetText()")
    assert "BitacoraImagenes" in text and "cannot create folders" in text


def test_the_game_options_page_uses_the_games_fonts_not_ink(game):
    # the Options window of the game is dark: ink on it could not be read (seen in the client on 5/11)
    game.run("ns.UI.options.Build()")
    fonts = game.run(
        "local out = {}; out[1] = ns.UI.options.title._fontObject; out[2] = ns.UI.options.intro._fontObject;"
        " for _, c in pairs(ns.UI.options.checks) do out[#out + 1] = c.label._fontObject end; return table.concat(out, ',')"
    )
    for f in fonts.split(","):
        assert f.startswith("GameFont"), fonts
    assert game.run("local c = ns.UI.options.checks.minimap; return c._template") == "UICheckButtonTemplate"
    intro = game.run("return ns.UI.options.intro._text")
    assert intro == "Notebook, Journal, Album and Reminders. Open the window with /bita."
