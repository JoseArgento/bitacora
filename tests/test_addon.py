"""Bitácora in Lua 5.1 (the WoW Lua) with a stand-in for the client (tests/wow_mock.lua).

These tests drive the addon through its events and check what it saves. They cannot show that the
window looks right in the game: that needs Forever itself (see README, "Probado / sin probar").
"""

import re
from pathlib import Path

import pytest

lupa = pytest.importorskip("lupa.lua51")

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "Bitacora"
MOCK = Path(__file__).parent / "wow_mock.lua"


def toc_files():
    out = []
    for line in (ADDON / "Bitacora.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            out.append(line.replace("\\", "/"))
    return out


class Game:
    def __init__(self, locale="enUS", saved=None):
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK.read_text(encoding="utf-8"))
        self.m = self.lua.globals().MOCK
        self.m.locale = locale
        self.ns = self.lua.table()
        loader = self.lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")
        if saved is not None:
            self.lua.execute(saved)  # the SavedVariables file, as the client loads it before the addon
        for rel in toc_files():
            loader((ADDON / rel).read_text(encoding="utf-8"), rel)("Bitacora", self.ns)

    def run(self, code):
        """Lua with ns and MOCK in scope."""
        return self.lua.eval("function(ns, MOCK) " + code + " end")(self.ns, self.m)

    def fire(self, event, *args):
        self.m.fire(event, *args)

    def login(self):
        self.fire("ADDON_LOADED", "Bitacora")
        self.fire("PLAYER_LOGIN")
        self.fire("PLAYER_ENTERING_WORLD", True, False)

    @property
    def db(self):
        return self.lua.globals().BitacoraDB

    def char(self):
        return self.db.chars["Josecito-Forever"]

    def journal(self):
        j = self.char().journal
        return [j[i] for i in range(1, len(j) + 1)]

    def kinds(self):
        return [e.kind for e in self.journal()]

    def chat(self):
        c = self.m.chat
        return [c[i] for i in range(1, len(c) + 1)]

    def warnings(self):
        w = self.m.warnings
        return [w[i] for i in range(1, len(w) + 1)]


@pytest.fixture
def game():
    g = Game()
    g.login()
    return g


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


# loading and saved data -----------------------------------------------------------------------------


def test_first_login_creates_the_database_and_the_journal(game):
    db = game.db
    assert db.version == 1 and db.sections[1].name == "General"
    assert game.kinds() == ["start"]
    e = game.journal()[0]
    assert e.level == 10 and e.zone == "Elwynn Forest" and e.sub == "Goldshire" and re.match(r"\d{4}-\d\d-\d\d \d\d:\d\d", e.d)
    assert game.char()["class"] == "MAGE"


def test_saved_data_survives_a_reload():
    g = Game()
    g.login()
    g.run('ns.Notes.Create({ title = "Hogger", body = "Sur de Elwynn" })')
    saved = g.m.savedVariables("BitacoraDB")
    assert saved.startswith("\nBitacoraDB = {\n")
    g2 = Game(saved=saved)
    g2.login()
    assert g2.kinds() == ["start"]  # not a second start entry
    notes = g2.run("return ns.Notes.Search('hogger', nil, ns.CharKey())")
    assert notes[1].title == "Hogger"


# journal ---------------------------------------------------------------------------------------------


def test_level_up_and_first_visit_of_a_zone(game):
    game.m.player.level = 11
    game.fire("PLAYER_LEVEL_UP", 11)
    game.m.where.mapID, game.m.where.zone, game.m.where.sub = 1453, "Stormwind City", "Trade District"
    game.fire("ZONE_CHANGED_NEW_AREA")
    game.fire("ZONE_CHANGED_NEW_AREA")  # same zone again: nothing new
    game.m.where.mapID, game.m.where.zone = 1429, "Elwynn Forest"
    game.fire("ZONE_CHANGED_NEW_AREA")  # where the journal started: already known
    assert game.kinds() == ["start", "level", "zone"]
    assert game.journal()[2].name == "Stormwind City"


def test_a_boss_kill_is_written_once_and_first_kills_are_marked(game):
    game.fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 1)
    game.fire("BOSS_KILL", 1084, "Onyxia")  # same kill, second event
    game.fire("ENCOUNTER_END", 1084, "Onyxia", 9, 40, 0)  # a wipe
    game.m.gametime = 1000 + 7 * 86400
    game.fire("BOSS_KILL", 1084, "Onyxia")  # next week
    bosses = [e for e in game.journal() if e.kind == "boss"]
    assert [(e.name, e.first) for e in bosses] == [("Onyxia", True), ("Onyxia", None)]
    milestones = lua_list(game.run("return ns.Journal.Entries(nil, 'milestones')"))
    assert [e.kind for e in milestones] == ["start", "boss"]  # repeat kills are not milestones


def test_loot_of_the_chosen_quality_only_and_only_your_own(game):
    epic = "|cffa335ee|Hitem:17078::::::::60:::::|h[Sapphiron Drape]|h|r"
    green = "|cff1eff00|Hitem:2000::::::::60:::::|h[Green]|h|r"
    game.m["items"][17078], game.m["items"][2000] = 4, 2
    game.fire("CHAT_MSG_LOOT", "You receive loot: " + epic, "Josecito")
    game.fire("CHAT_MSG_LOOT", "You receive loot: " + green, "Josecito")
    game.fire("CHAT_MSG_LOOT", "Ana receives loot: " + epic, "Ana")
    game.fire("CHAT_MSG_LOOT", "You receive loot: " + epic + "x2", "Josecito")
    loot = [e for e in game.journal() if e.kind == "loot"]
    assert [(e.item, e.quality, e.name) for e in loot] == [(17078, 4, "[Sapphiron Drape]")] * 2


def test_secret_chat_text_is_ignored(game):
    text = "You receive loot: |cffa335ee|Hitem:17078::|h[Drape]|h|r"
    game.m["items"][17078] = 4
    game.m.secret[text] = True
    game.fire("CHAT_MSG_LOOT", text, "Josecito")
    assert "loot" not in game.kinds()


def test_money_steps_already_passed_are_not_news():
    g = Game()
    g.m.player.money = 50 * 10000  # 50 gold when the journal starts
    g.login()
    g.m.player.money = 150 * 10000
    g.fire("PLAYER_MONEY")
    g.fire("PLAYER_MONEY")
    money = [e.amount for e in g.journal() if e.kind == "money"]
    assert money == [1000000]  # only the 100 gold step


def test_quests_deaths_achievements_and_played(game):
    game.fire("QUEST_TURNED_IN", 176, 1000, 50)
    game.fire("QUEST_TURNED_IN", 99999, 0, 0)
    game.fire("PLAYER_DEAD")
    game.fire("ACHIEVEMENT_EARNED", 6)
    game.fire("TIME_PLAYED_MSG", 7200, 600)
    game.fire("TIME_PLAYED_MSG", 7300, 700)  # same day: only stored
    assert game.kinds() == ["start", "quest", "quest", "death", "achievement", "played"]
    j = game.journal()
    assert j[1].title == "Wanted: Hogger" and j[2].title is None and j[2].quest == 99999
    assert game.char().played.total == 7300
    game.m.e = j[2]
    assert game.run("return ns.Journal.Text(MOCK.e)") == "Completed quest 99999."


def test_quests_can_be_left_out(game):
    game.db.settings.journalQuests = False
    game.fire("QUEST_TURNED_IN", 176, 1000, 50)
    assert "quest" not in game.kinds()


def test_manual_entry_and_slash_commands(game):
    slash = game.lua.globals().SlashCmdList.BITACORA
    slash("entrada Primer día en Forever")
    slash("nota  comprar paño  ")
    slash("help")
    assert game.journal()[-1].text == "Primer día en Forever"
    notes = game.run("return ns.Notes.Search('paño', nil, ns.CharKey())")
    assert notes[1].body == "comprar paño"
    assert "/bitacora" in game.chat()[-1]


# album -----------------------------------------------------------------------------------------------


def test_screenshot_is_noted_with_the_file_stamp_and_the_group(game):
    game.m.group["party1"] = "Ana"
    game.m.group["party2"] = "Beto"
    game.m.secret["Beto"] = True  # a name the game hides
    game.fire("SCREENSHOT_SUCCEEDED")
    shot = game.char().album[1]
    assert shot.stamp == game.lua.eval("date('%m%d%y_%H%M%S', MOCK.now)")
    assert lua_list(shot.group) == ["Ana"]
    assert (shot.x, shot.y) == (42.3, 65.1) and shot.zone == "Elwynn Forest" and shot.sub == "Goldshire"
    assert "screenshot noted (Goldshire, Elwynn Forest)." in game.chat()[-1]
    game.run("ns.Album.SetCaption(1, '  Con Ana en Villadorada  ')")
    assert game.char().album[1].caption == "Con Ana en Villadorada"


def test_screenshot_inside_an_instance_has_no_coordinates(game):
    game.m.where.x = None
    game.fire("SCREENSHOT_SUCCEEDED")
    assert game.char().album[1].x is None


# reminders -------------------------------------------------------------------------------------------


def make(game, **fields):
    game.m.f = game.lua.table_from(fields)
    return game.run("return ns.Reminders.Create(MOCK.f)")


def test_zone_reminder_by_name_any_case_and_by_subzone(game):
    make(game, text="vender el paño", kind="zone", value="  ironforge ")
    make(game, text="posada", kind="zone", value="The Commons")
    game.m.where.mapID, game.m.where.zone, game.m.where.sub = 1455, "Ironforge", ""
    game.fire("ZONE_CHANGED_NEW_AREA")
    game.m.where.sub = "The Commons"
    game.fire("ZONE_CHANGED")
    game.fire("ZONE_CHANGED")  # once only
    assert game.warnings() == ["Reminder: vender el paño", "Reminder: posada"]
    assert game.m.sounds[1] == 8959


def test_repeating_place_reminder(game):
    make(game, text="mandar hierbas al alt", kind="place", value="MAIL", repeating=True)
    game.fire("MAIL_SHOW")
    game.fire("MERCHANT_SHOW")
    game.fire("MAIL_SHOW")
    assert game.warnings() == ["Reminder: mandar hierbas al alt"] * 2


def test_level_reminder_fires_at_or_after_the_level(game):
    make(game, text="la montura", kind="level", value=40)
    game.m.player.level = 39
    game.fire("PLAYER_LEVEL_UP", 39)
    assert game.warnings() == []
    game.fire("PLAYER_LEVEL_UP", 40)
    game.fire("PLAYER_LEVEL_UP", 41)
    assert game.warnings() == ["Reminder: la montura"]


def test_login_reminders_wait_for_the_loading_screen():
    g = Game()
    g.fire("ADDON_LOADED", "Bitacora")
    g.run('ns.Reminders.Create({ text = "hola", kind = "login" })')
    g.fire("PLAYER_LOGIN")
    assert g.warnings() == []
    g.m.runTimers()
    assert g.warnings() == ["Reminder: hola"]


def test_reminder_for_one_character_only(game):
    make(game, text="solo el mago", kind="place", value="BANK", char="Otro-Forever")
    game.fire("BANKFRAME_OPENED")
    assert game.warnings() == []


def test_weekly_time_reminder(game):
    # 2026-11-03 is a Tuesday (wday 3). Created on Monday, due Tuesday 20:00.
    game.m.now = game.lua.eval("os.time({ year = 2026, month = 11, day = 2, hour = 12, min = 0 })")
    make(game, text="raid", kind="time", value=game.lua.table_from({"wday": 3, "hour": 20, "min": 0}), repeating=True)
    for day, hour, minute in [(3, 19, 55), (3, 20, 1), (3, 20, 5), (3, 21, 0), (10, 20, 2)]:
        game.m.now = game.lua.eval(f"os.time({{ year = 2026, month = 11, day = {day}, hour = {hour}, min = {minute} }})")
        game.m.tick()
    assert game.warnings() == ["Reminder: raid", "Reminder: raid"]  # Tuesday 3rd and Tuesday 10th


def test_time_reminder_created_after_todays_time_waits_for_the_next(game):
    game.m.now = game.lua.eval("os.time({ year = 2026, month = 11, day = 4, hour = 21, min = 0 })")
    make(game, text="regar", kind="time", value=game.lua.table_from({"wday": 0, "hour": 20, "min": 55}))
    game.m.tick()
    assert game.warnings() == []
    game.m.now = game.lua.eval("os.time({ year = 2026, month = 11, day = 5, hour = 20, min = 56 })")
    game.m.tick()
    game.m.tick()
    assert game.warnings() == ["Reminder: regar"]


def test_invalid_reminders_are_refused(game):
    assert make(game, text="  ", kind="login") is None
    assert make(game, text="x", kind="level", value="cuarenta") is None
    assert make(game, text="x", kind="zone", value="") is None
    assert make(game, text="x", kind="time", value=game.lua.table_from({"hour": "a"})) is None


# notebook --------------------------------------------------------------------------------------------


def test_sections_and_search(game):
    r = game.run(
        """
        local N = ns.Notes
        local s = N.AddSection("Misiones")
        N.Create({ title = "Onyxia", body = "Amuleto: paso 3 en |cffffff00|Hquest:4182|h[Dragonkin Menace]|h|r", section = s.id })
        N.Create({ title = "Recetas", body = "Comprar en Forjaz" })
        local found = N.Search("dragonkin amuleto", nil, ns.CharKey())
        local inSection = N.Search("", s.id, ns.CharKey())
        local okFirst = N.DeleteSection(ns.db.sections[1].id)
        local ok = N.DeleteSection(s.id)
        local moved = N.Search("onyxia", ns.db.sections[1].id, ns.CharKey())
        return #found, found[1].title, #inSection, okFirst, ok, #moved
        """
    )
    assert r == (1, "Onyxia", 1, False, True, 1)


def test_character_notes_and_pinning(game):
    r = game.run(
        """
        local N = ns.Notes
        local a = N.Create({ title = "Mía", char = ns.CharKey() })
        local b = N.Create({ title = "De otro", char = "Otro-Forever" })
        local c = N.Create({ title = "Vieja" })
        N.Update(c.id, { pinned = true })
        local list = N.Search("", nil, ns.CharKey())
        return #list, list[1].title
        """
    )
    assert r == (2, "Vieja")


@pytest.mark.parametrize(
    "name, ok",
    [
        ("mapa.png", True),
        ("Ruta_ony-2.JPG", True),
        ("icono.blp", True),
        ("../../WTF/Config.wtf", False),
        ("..\\x.png", False),
        ("a..png", False),
        ("sin_extension", False),
        ("script.lua", False),
        ("C:\\x.png", False),
        ("", False),
    ],
)
def test_image_names_stay_in_the_images_folder(game, name, ok):
    game.m.n = name
    assert (game.run("return ns.Notes.ValidImageName(MOCK.n)") is not None) == ok


def test_images_on_a_note(game):
    r = game.run(
        """
        local N = ns.Notes
        local n = N.Create({ title = "Mapa" })
        N.AddImage(n.id, "mapa.png")
        N.AddImage(n.id, "mapa.png")
        N.AddImage(n.id, "../x.png")
        return #n.images, N.ImagePath(n.images[1])
        """
    )
    assert r == (1, "Interface\\AddOns\\BitacoraImagenes\\mapa.png")


def test_npc_note_shows_in_its_tooltip(game):
    game.run(
        """
        local N = ns.Notes
        local n = N.Create({ title = "Vende el patrón", body = "Solo los martes" })
        N.Attach(n.id, "npc", N.NpcIDFromGUID("Creature-0-4372-0-17-5494-00007A1B2C"), "Catherine Leland")
        """
    )
    tip = game.lua.globals().GameTooltip
    tip.unit = "mouseover"
    game.m.target = game.lua.table_from({"guid": "Creature-0-4372-0-17-5494-0000FFFFFF", "name": "Catherine Leland"})
    callbacks = game.m.tooltipCalls[2]
    callbacks[1](tip, game.lua.table())
    lines = lua_list(tip.lines)
    assert any("Vende el patrón" in str(x) for x in lines) and any("Solo los martes" in str(x) for x in lines)


def test_npc_guid_parsing(game):
    for guid, want in [("Creature-0-4372-0-17-5494-00007A1B2C", 5494), ("Player-1234-0ABCDEF0", None), ("Vehicle-0-1-2-3-99-0", 99)]:
        game.m.g = guid
        assert game.run("return ns.Notes.NpcIDFromGUID(MOCK.g)") == want
    game.m.secret["Creature-0-1-2-3-77-0"] = True
    game.m.g = "Creature-0-1-2-3-77-0"
    assert game.run("return ns.Notes.NpcIDFromGUID(MOCK.g)") is None


def test_item_note_uses_the_first_item_link(game):
    r = game.run(
        """
        local N = ns.Notes
        local n = N.Create({ title = "Pedir", body = "Para |cffa335ee|Hitem:17078::::|h[Sapphiron Drape]|h|r, hablar con Ana" })
        return N.FirstItemLink(n)
        """
    )
    assert r == (17078, "[Sapphiron Drape]")


def test_zone_notes_are_announced_on_arrival(game):
    game.run('local n = ns.Notes.Create({ title = "Cofre escondido" }); ns.Notes.Attach(n.id, "zone", 1455, "Ironforge")')
    game.m.where.mapID, game.m.where.zone = 1455, "Ironforge"
    game.fire("ZONE_CHANGED_NEW_AREA")
    assert "1 note(s) for Ironforge: Cofre escondido" in game.chat()[-1]


def test_plain_text_and_preview(game):
    game.m.s = "|cffa335ee|Hitem:1::|h[Espada]|h|r y |TInterface\\Icons\\x:12|t ñandú " + "á" * 80
    assert game.run("return ns.PlainText(MOCK.s)").startswith("[Espada] y  ñandú")
    preview = game.run("return ns.Preview(MOCK.s, 30)")
    assert preview.endswith("…")
    preview.encode("utf-8")  # did not cut a character in half (lupa would hand back bytes otherwise)


# UI smoke test: every tab builds and its main actions run without Lua errors -------------------------


def test_window_tabs_and_typing_a_note(game):
    game.run("ns.Toggle(); for i = 1, 4 do ns.UI.SelectTab(i) end; ns.UI.SelectTab(1)")
    frame = game.lua.globals().BitacoraFrame
    assert frame._shown and frame.selectedTab == 1 and len(frame.Tabs) == 4
    game.run(
        """
        local view = ns.UI.views[1]
        local n = ns.Notes.Create({ title = "Desde la UI" })
        view.Select(n.id)
        MOCK.noteId = n.id
        view.body:SetFocus()
        view.body:Insert("hola ")
        """
    )
    game.m.runTimers()
    assert game.run("return ns.Notes.Get(MOCK.noteId).body") == "hola "


def test_shift_click_inserts_links_into_the_focused_note(game):
    link = "|cffa335ee|Hitem:17078::|h[Sapphiron Drape]|h|r"
    game.run("ns.Toggle(1); local n = ns.Notes.Create({ title = 'Links' }); ns.UI.views[1].Select(n.id); MOCK.noteId = n.id")
    insert = game.lua.globals().ChatFrameUtil.InsertLink
    insert(link)  # editor without focus: nothing
    assert game.run("return ns.Notes.Get(MOCK.noteId).body") == ""
    game.run("ns.UI.views[1].body:SetFocus()")
    insert(link)
    assert game.run("return ns.Notes.Get(MOCK.noteId).body") == link
    game.run("ns.UI.views[1].title:SetFocus()")
    insert(link)
    assert game.run("return ns.UI.views[1].title:GetText()").endswith("[Sapphiron Drape]")


def test_journal_and_album_tabs_render_rows(game):
    game.fire("PLAYER_LEVEL_UP", 11)
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Toggle(2); ns.UI.SelectTab(3); ns.UI.SelectTab(4)")


def test_reminder_form_creates_a_reminder(game):
    game.run("ns.Toggle(4)")
    game.run("ns.Reminders.Create({ text = 'x', kind = 'login' })")
    assert len(game.db.reminders) == 1


# locales ---------------------------------------------------------------------------------------------


def test_spanish_locale():
    g = Game(locale="esMX")
    g.login()
    assert g.ns.L.TAB_NOTES == "Libreta" and g.ns.L.TITLE == "Bitácora"
    assert g.lua.globals().BINDING_NAME_BITACORA_TOGGLE == "Abrir / cerrar"


def test_spanish_and_english_texts_have_the_same_placeholders():
    src = (ADDON / "Locales.lua").read_text(encoding="utf-8")
    en_block = src.split("local en = {", 1)[1].split("\n}\n", 1)[0]
    es_block = src.split("local es = {", 1)[1].split("\n}\n", 1)[0]
    pat = re.compile(r'^\t(\w+) = "((?:[^"\\]|\\.)*)",', re.M)
    en, es = dict(pat.findall(en_block)), dict(pat.findall(es_block))
    assert set(es) <= set(en), set(es) - set(en)
    for key, text in es.items():
        assert re.findall(r"%[\d.]*[sd]", text) == re.findall(r"%[\d.]*[sd]", en[key]), key


@pytest.mark.parametrize(
    "fmt, sample, want",
    [
        ("You receive loot: %s", "You receive loot: [X]", ("[X]",)),
        ("You receive loot: %sx%d", "You receive loot: [X]x3", ("[X]", "3")),
        ("Recibes botín: %s x%d", "Recibes botín: [X] x2", ("[X]", "2")),
        ("Creas: %s.", "Creas: [Poción].", ("[Poción]",)),
        ("%2$s erhält Beute: %1$s.", "Ana erhält Beute: [X].", ("Ana", "[X]")),
    ],
)
def test_loot_patterns_from_global_strings(game, fmt, sample, want):
    game.m.fmt = fmt
    pattern = game.run("return ns.PatternFromFormat(MOCK.fmt)")
    game.m.p, game.m.s = pattern, sample
    got = game.run("return MOCK.s:match(MOCK.p)")
    got = got if isinstance(got, tuple) else (got,)
    assert got == want


def test_options_panel_registers_and_changes_settings(game):
    calls = []
    game.lua.globals().Settings = game.lua.table_from(
        {
            "RegisterCanvasLayoutCategory": lambda frame, name: (
                calls.append(("canvas", name)) or game.lua.eval("{ GetID = function() return 7 end }")
            ),
            "RegisterAddOnCategory": lambda cat: calls.append(("addon",)),
            "OpenToCategory": lambda cid: calls.append(("open", cid)),
        }
    )
    game.lua.globals().SlashCmdList.BITACORA("opciones")
    assert calls == [("canvas", "Bitácora"), ("addon",), ("open", 7)]
    game.run("ns.UI.options:Show()")
    game.run("ns.UI.options.loot:GetScript('OnClick')(ns.UI.options.loot)")
    game.m.clickMenu("Rare (blue)")
    assert game.db.settings.lootQuality == 3
    game.run("ns.UI.options.skin:GetScript('OnClick')(ns.UI.options.skin)")
    game.m.clickMenu("Tavern book")
    assert game.db.settings.skin == "tavern"
    game.run("local c = ns.UI.options.checks.zoneNotes; c:SetChecked(false); c:GetScript('OnClick')(c)")
    assert game.db.settings.zoneNotes is False


def test_journal_search(game):
    game.fire("PLAYER_LEVEL_UP", 11)
    game.fire("PLAYER_DEAD")
    game.m.e = game.journal()[-1]
    assert game.run("return ns.Journal.Matches(MOCK.e, 'murió elwynn')") is False  # English client
    assert game.run("return ns.Journal.Matches(MOCK.e, 'died elwynn')") is True
    game.run("ns.Toggle(2); ns.UI.views[2].search:SetText('level'); ns.UI.views[2].Refresh()")
