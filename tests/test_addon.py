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


def toc_files(folder="Bitacora"):
    out = []
    for line in (ROOT / folder / f"{folder}.toc").read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if line and not line.startswith("#") and line.endswith(".lua"):
            out.append(line.replace("\\", "/"))
    return out


class Game:
    """The client with some addons loaded, in order. Bitacora_Datos (the shared saved data) always comes first."""

    def __init__(self, locale="enUS", saved=None, addons=("Bitacora",), datos=True):
        self.lua = lupa.LuaRuntime(unpack_returned_tuples=True)
        self.lua.execute(MOCK.read_text(encoding="utf-8"))
        self.lua.execute((MOCK.parent / "guild_mock.lua").read_text(encoding="utf-8"))
        self.m = self.lua.globals().MOCK
        self.m.locale = locale
        self.addons = ["Bitacora_Datos", *addons] if datos else list(addons)
        self.m.loaded = self.lua.table_from({name: True for name in self.addons})
        # the TOC titles, as C_AddOns.GetAddOnMetadata gives them
        titles = {}
        for name in self.addons:
            toc = ROOT / name / f"{name}.toc"
            if toc.is_file():
                fields = {}
                for line in toc.read_text(encoding="utf-8").splitlines():
                    for field in ("Title", "IconTexture"):
                        if line.startswith(f"## {field}:"):
                            fields[field] = line.split(":", 1)[1].strip()
                titles[name] = self.lua.table_from(fields)
        self.m.metadata = self.lua.table_from(titles)
        self.nss = {}
        loader = self.lua.eval("function(src, name) return assert(loadstring(src, '@' .. name)) end")
        if saved is not None:
            self.lua.execute(saved)  # Bitacora_Datos' SavedVariables file, as the client loads it before the addons
        for name in self.addons:
            ns = self.lua.table()
            self.nss[name] = ns
            for rel in toc_files(name):
                loader((ROOT / name / rel).read_text(encoding="utf-8"), f"{name}/{rel}")(name, ns)
        self.ns = self.nss[self.addons[1]] if datos and len(self.addons) > 1 else self.nss[self.addons[0]]

    def run(self, code):
        """Lua with ns and MOCK in scope."""
        return self.lua.eval("function(ns, MOCK) " + code + " end")(self.ns, self.m)

    def fire(self, event, *args):
        self.m.fire(event, *args)

    def arrive(self):
        """A zone change, and the moment Bitácora waits before reading the zone (it can be stale right away)."""
        self.fire("ZONE_CHANGED_NEW_AREA")
        self.m.runTimers()

    def login(self):
        for name in self.addons:
            self.fire("ADDON_LOADED", name)
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
    game.arrive()
    game.arrive()  # same zone again: nothing new
    game.m.where.mapID, game.m.where.zone = 1429, "Elwynn Forest"
    game.arrive()  # where the journal started: already known
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
    game.arrive()
    game.m.where.sub = "The Commons"
    game.fire("ZONE_CHANGED")
    game.fire("ZONE_CHANGED")  # once only
    assert game.warnings() == ["Reminder: vender el paño", "Reminder: posada"]
    assert game.m.sounds[1] == 8959


def test_repeating_place_reminder(game):
    make(game, text="mandar hierbas al alt", kind="place", value="MAIL", repeating=True)
    game.fire("MAIL_SHOW")
    game.fire("MERCHANT_SHOW")
    game.m.gametime = game.m.gametime + 60
    game.fire("MAIL_SHOW")
    assert game.warnings() == ["Reminder: mandar hierbas al alt"] * 2


def test_a_window_that_opens_twice_is_one_visit(game):
    """Some window events fire twice in Forever (beta report, 18/10): one reminder per visit."""
    make(game, text="vender el paño", kind="place", value="MERCHANT", repeating=True)
    game.fire("MERCHANT_SHOW")
    game.fire("MERCHANT_SHOW")
    assert game.warnings() == ["Reminder: vender el paño"]


def test_one_death_is_one_entry_even_if_the_event_fires_twice(game):
    """PLAYER_DEAD fires twice for one death in Forever (beta report, 18/10)."""
    game.fire("PLAYER_DEAD")
    game.fire("PLAYER_DEAD")
    assert game.kinds().count("death") == 1
    game.m.gametime = game.m.gametime + 120
    game.fire("PLAYER_DEAD")
    assert game.kinds().count("death") == 2


def test_the_zone_is_read_after_arriving(game):
    """Right after a hearthstone or a flight the zone text can still be the old one (beta report)."""
    game.m.where.mapID, game.m.where.zone = 1453, "Elwynn Forest"  # stale text the moment you arrive
    game.fire("ZONE_CHANGED_NEW_AREA")
    assert "zone" not in game.kinds()[1:]
    game.m.where.zone = "Stormwind City"  # a moment later the game has it right
    game.m.runTimers()
    zones = [e for e in game.journal() if e.kind == "zone"]
    assert len(zones) == 1 and zones[0].zone == "Stormwind City"


def test_an_empty_zone_is_read_again(game):
    game.m.where.mapID, game.m.where.zone = None, ""
    game.fire("ZONE_CHANGED_NEW_AREA")
    game.m.runTimers()
    assert "zone" not in game.kinds()[1:]
    game.m.where.mapID, game.m.where.zone = 1455, "Ironforge"
    game.m.runTimers()
    assert [e.zone for e in game.journal() if e.kind == "zone"] == ["Ironforge"]


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
    game.arrive()
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
    assert frame._shown and frame.selectedTab == 1 and len(frame.Tabs) == 6
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
    game.run("local c = ns.UI.options.checks.zoneNotes; c:SetChecked(false); c:GetScript('OnClick')(c)")
    assert game.db.settings.zoneNotes is False


def test_journal_search(game):
    game.fire("PLAYER_LEVEL_UP", 11)
    game.fire("PLAYER_DEAD")
    game.m.e = game.journal()[-1]
    assert game.run("return ns.Journal.Matches(MOCK.e, 'murió elwynn')") is False  # English client
    assert game.run("return ns.Journal.Matches(MOCK.e, 'died elwynn')") is True
    game.run("ns.Toggle(2); ns.UI.views[2].search:SetText('level'); ns.UI.views[2].Refresh()")


def test_the_window_is_a_pergamino_book_with_a_cover_that_opens(game):
    game.run("ns.Toggle(1); ns.Toggle(); ns.UI.SelectTab(2); ns.UI.frame:Hide()")
    frame = game.lua.globals().BitacoraFrame
    # two parchment pages, a spine, a title banner, a wax seal and six bookmarks
    assert str(frame.pageL.texture).endswith("Libs\\Pergamino\\Media\\page") and frame.pageR is not None and frame.spine is not None
    assert frame.title._text == "Bitácora" and frame.close is not None and len(frame.Tabs) == 6
    assert "Bitacora_Datos" in str(frame.pageL.texture)  # the look comes from the shared data addon
    # the bookmark of the open page is the gold one
    assert game.run("return BitacoraFrame.tabs.journal.cloth:GetTexCoord()") == (0, 1, 0.5, 1)
    assert game.run("return BitacoraFrame.tabs.notes.cloth:GetTexCoord()") == (0, 1, 0, 0.5)
    # the texts wear Pergamino fonts (Alegreya / Cinzel), not the game's
    path = game.run("return Pergamino.fonts.body:GetFont()")
    assert "Alegreya" in path[0]
    assert game.run("return ns.UI.views[1].title:GetFontObject() == Pergamino.fonts.big") is True
    # the cover plays once when the book opens, then hides itself
    game.m.played = 0
    game.run("ns.Toggle(1)")
    assert game.m.played == 1 and frame.cover._shown is False
    game.db.settings.bookIntro = False
    game.run("ns.Toggle(); ns.Toggle(1)")
    assert game.m.played == 1


def test_bookmarks_switch_pages(game):
    game.run("ns.Toggle(1)")
    frame = game.lua.globals().BitacoraFrame
    game.run("BitacoraFrame.tabs.album:GetScript('OnClick')()")
    assert frame.selectedTab == 3 and game.db.settings.tab == 3
    assert game.run("return BitacoraFrame.pages.album.left:IsShown(), BitacoraFrame.pages.notes.left:IsShown()") == (True, False)


def test_textures_are_powers_of_two_tga():
    files = [ROOT / "Bitacora_Datos" / "Media" / "cover.tga", *(ROOT / "Bitacora_Datos" / "Libs" / "Pergamino" / "Media").glob("*.tga")]
    assert len(files) >= 9
    for path in files:
        name = path.name
        data = path.read_bytes()
        width, height, bpp = int.from_bytes(data[12:14], "little"), int.from_bytes(data[14:16], "little"), data[16]
        assert data[2] == 2 and bpp == 32 and width & (width - 1) == 0 and height & (height - 1) == 0, name


# standalone parts -------------------------------------------------------------------------------------

PARTS = ["Bitacora_Libreta", "Bitacora_Diario", "Bitacora_Album", "Bitacora_Recordatorios"]


def test_generated_parts_are_up_to_date(tmp_path):
    import importlib.util

    spec = importlib.util.spec_from_file_location("build_editions", ROOT / "tools" / "build_editions.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.build(tmp_path)
    for part in [*PARTS, "Recordame"]:
        fresh = {p.relative_to(tmp_path / part): p.read_bytes() for p in (tmp_path / part).rglob("*") if p.is_file()}
        repo = {p.relative_to(ROOT / part): p.read_bytes() for p in (ROOT / part).rglob("*") if p.is_file()}
        assert fresh == repo, f"{part} is out of date: run tools/build_editions.py"


@pytest.mark.parametrize("part", PARTS)
def test_each_part_loads_alone(part):
    g = Game(addons=(part,))
    g.login()
    g.m.runTimers()
    g.run("ns.Toggle()")
    frame = g.lua.globals()[part + "Frame"]
    if part == "Bitacora_Diario":  # the journal comes with its progress and the guild chronicle
        assert frame._shown and len(frame.Tabs) == 3 and frame.Tabs[1]._shown is True
    else:  # a single tab: no bookmarks
        assert frame._shown and len(frame.Tabs) == 1 and frame.Tabs[1]._shown is False
    if part == "Bitacora_Recordatorios":  # the reminders fit on one page
        assert frame.right is None and frame.single is True
    else:
        assert frame.right is not None
    assert g.lua.globals()["SLASH_" + part.upper() + "1"].startswith("/")
    assert g.db.version == 1


def test_notebook_alone_keeps_no_journal():
    g = Game(addons=("Bitacora_Libreta",))
    g.login()
    g.lua.globals().SlashCmdList.BITACORA_LIBRETA("nota comprar paño")
    g.fire("PLAYER_LEVEL_UP", 11)
    assert len(g.char().journal) == 0
    assert g.run("return #ns.Notes.Search('paño', nil, ns.CharKey())") == 1


def test_two_parts_share_the_data():
    g = Game(addons=("Bitacora_Diario", "Bitacora_Libreta"))
    g.login()
    g.fire("PLAYER_LEVEL_UP", 11)
    g.lua.globals().SlashCmdList.BITACORA_LIBRETA("nota desde la libreta")
    assert g.kinds() == ["start", "level"]
    assert len(list(g.db.notes.values())) == 1
    # and it survives a reload with the other part alone
    saved = g.m.savedVariables("BitacoraDB")
    g2 = Game(saved=saved, addons=("Bitacora_Libreta",))
    g2.login()
    assert g2.run("return #ns.Notes.Search('libreta', nil, ns.CharKey())") == 1 and len(g2.char().journal) == 2


def test_a_part_steps_aside_when_the_full_addon_is_loaded():
    g = Game(addons=("Bitacora", "Bitacora_Diario", "Bitacora_Recordatorios"))
    g.login()
    assert g.nss["Bitacora_Diario"].disabled is True and g.nss["Bitacora_Recordatorios"].disabled is True
    g.fire("PLAYER_LEVEL_UP", 11)
    assert g.kinds() == ["start", "level"]  # written once, by the full addon
    g.run('ns.Reminders.Create({ text = "x", kind = "place", value = "MAIL" })')
    g.fire("MAIL_SHOW")
    assert g.warnings() == ["Reminder: x"]  # one alert, not three
    g.lua.globals().SlashCmdList.BITACORA_DIARIO("")
    assert "is off because the full Bitácora is loaded" in g.chat()[-1]


def test_the_parts_say_they_are_off_in_one_line_once():
    g = Game(addons=("Bitacora", "Bitacora_Diario", "Bitacora_Libreta", "Bitacora_Recordatorios"))
    g.login()
    lines = [c for c in g.chat() if "are off because" in c]
    assert lines == ["|cff8fd1c4Bitácora · Diario|r: Diario, Libreta and Recordatorios are off because the full Bitácora is loaded; it already has them. (Said once.)"]
    assert g.db.settings.partsNoticed is True
    # the next login says nothing
    g2 = Game(saved=g.m.savedVariables("BitacoraDB"), addons=("Bitacora", "Bitacora_Diario", "Bitacora_Libreta"))
    g2.login()
    assert not [c for c in g2.chat() if "are off because" in c]


def test_the_parts_stay_quiet_when_the_chat_is_set_to_never():
    g = Game(saved='BitacoraDB = { settings = { chat = "never" } }', addons=("Bitacora", "Bitacora_Diario"))
    g.login()
    assert not [c for c in g.chat() if "off because" in c] and g.db.settings.partsNoticed is None


def test_all_four_parts_together_do_each_thing_once():
    g = Game(addons=tuple(PARTS))
    g.login()
    g.m.runTimers()
    g.fire("PLAYER_LEVEL_UP", 11)
    g.fire("SCREENSHOT_SUCCEEDED")
    g.lua.globals().SlashCmdList.BITACORA_LIBRETA("nota una")
    g.nss["Bitacora_Recordatorios"].Reminders.Create(g.lua.table_from({"text": "y", "kind": "place", "value": "BANK"}))
    g.fire("BANKFRAME_OPENED")
    assert g.kinds() == ["start", "level"] and len(g.char().album) == 1
    assert len(list(g.db.notes.values())) == 1 and g.warnings() == ["Reminder: y"]
    assert g.db.sections[1].name == "General" and len(g.db.sections) == 1  # the first tab is made once


# the two pages of each tab --------------------------------------------------------------------------


def test_journal_right_page_shows_the_clicked_entry(game):
    game.fire("PLAYER_LEVEL_UP", 11)
    game.run("ns.Toggle(2)")
    assert game.run("return ns.UI.views[2].list.box.rows[1].tag.text:GetText()") == "LEVEL"
    game.run("local l = ns.UI.views[2].list; l.box.rows[1]:GetScript('OnClick')(l.box.rows[1], 'LeftButton')")
    assert game.run("return ns.UI.views[2].selected.kind") == "level"


def test_album_right_page_shows_the_clicked_shot(game):
    game.fire("SCREENSHOT_SUCCEEDED")
    game.run("ns.Toggle(3)")
    game.run("local l = ns.UI.views[3].list; l.box.rows[1]:GetScript('OnClick')(l.box.rows[1], 'LeftButton')")
    assert game.run("return ns.UI.views[3].selected") == 1


def test_notebook_sections_are_chips_and_the_empty_right_page_says_so(game):
    game.run("ns.Toggle(1); ns.Notes.AddSection('Onyxia'); ns.UI.views[1].Refresh()")
    chips = game.run("local c = ns.UI.views[1].sections.chips; return c[1]:GetText(), c[2]:GetText(), c[3]:GetText(), c[1].pressed")
    assert chips[0] == "All" and chips[2] == "Onyxia" and chips[3] is True
    assert game.run("return ns.UI.views[1].selected") is None


def test_reminders_part_stacks_the_form_over_the_list():
    g = Game(addons=("Bitacora_Recordatorios",))
    g.login()
    g.run("ns.Toggle()")
    assert g.run("return ns.UI.frame.single, ns.UI.frame.right") == (True, None)
    assert g.run("return ns.UI.views[1].list ~= nil") is True
