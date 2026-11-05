"""Round 8: Legacy milestones, the first campsite and blueprints in the journal, "where was I" at login,
reminders from the game's calendar, whispered reminders and the campsite buff warning."""

from __future__ import annotations

import pytest
from test_addon import Game


@pytest.fixture
def game():
    g = Game()
    g.login()
    g.m.runTimers()
    return g


def warnings(g):
    w = g.m.warnings
    return [w[i] for i in range(1, len(w) + 1)]


def chat(g):
    c = g.m.chat
    return [c[i] for i in range(1, len(c) + 1)]


def popups(g):
    p = g.m.popups
    return [p[i] for i in range(1, len(p) + 1)]


def reminders(g):
    r = g.db.reminders
    return [r[i] for i in range(1, len(r) + 1)]


def receive(g, text, sender="Ana-Forever", channel="WHISPER", prefix="BitacoraAviso1"):
    g.fire("CHAT_MSG_ADDON", prefix, text, channel, sender, "", 0, 0, "", 0)


def lua_list(t):
    return [t[i] for i in range(1, len(t) + 1)]


# Legacy ------------------------------------------------------------------------------------------


def test_legacy_challenge_is_an_achievement_with_points(game):
    game.m.legacy[7001] = 3
    game.fire("ACHIEVEMENT_EARNED", 7001)
    game.fire("ACHIEVEMENT_EARNED", 7002)
    j = game.journal()
    assert [e.kind for e in j[-2:]] == ["achievement", "achievement"]
    assert j[-2].legacy == 3 and j[-1].legacy is None
    assert "Legacy challenge" in game.run("return ns.Journal.Text(ns.Char().journal[#ns.Char().journal - 1])")
    assert "+3" in game.run("return ns.Journal.Text(ns.Char().journal[#ns.Char().journal - 1])")
    assert game.run("return ns.Progress.Stats().legacy") == 3
    assert game.run("return ns.Progress.LegacyPoints()") == 3
    rows = lua_list(game.run("return ns.Progress.Rows()"))
    assert any(r.left == "Legacy points (this character)" and r.right == "3" for r in rows)


def test_secret_legacy_points_count_as_none(game):
    game.m.legacy[7003] = 9
    game.m.secret[9] = True
    game.fire("ACHIEVEMENT_EARNED", 7003)
    assert game.journal()[-1].legacy is None


# campsite and blueprints --------------------------------------------------------------------------


def test_first_campfire_is_written_once(game):
    game.m.spells[91100] = "Basic Campfire"
    game.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 91100)
    game.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", 91100)
    game.fire("UNIT_SPELLCAST_SUCCEEDED", "party1", "cast-3", 91100)
    assert game.kinds().count("camp") == 1
    assert game.run("return ns.Journal.Text(ns.Char().journal[#ns.Char().journal])") == "Built a first campsite."


def test_other_spells_are_not_a_campfire(game):
    game.m.spells[133] = "Fireball"
    game.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 133)
    game.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-2", None)
    assert "camp" not in game.kinds()


def test_blueprint_learned_by_what_its_recipe_builds(game):
    game.m.recipes[500] = 279988  # the Anvil
    game.m.recipes[501] = 2996  # a bolt of linen cloth: not a blueprint
    game.fire("NEW_RECIPE_LEARNED", 500, 1, 500)
    game.fire("NEW_RECIPE_LEARNED", 500, 1, 500)
    game.fire("NEW_RECIPE_LEARNED", 501, 1, 501)
    assert game.kinds().count("blueprint") == 1
    e = game.journal()[-1]
    assert e.name == "Anvil" and e.profession == "Blacksmithing"
    assert game.run("return ns.Journal.Text(ns.Char().journal[#ns.Char().journal])") == "Learned the Anvil blueprint (Blacksmithing)."
    assert game.char().blueprints[279988] is True


# where was I ---------------------------------------------------------------------------------------


def test_where_was_after_days_away():
    g = Game()
    g.login()
    g.m.runTimers()
    g.run('ns.Journal.AddManual("Buscar a Hogger")')
    g.m.player.level = 12
    g.fire("PLAYER_LEVEL_UP", 12)
    saved = g.m.savedVariables("BitacoraDB")
    # a day later: nothing said
    g2 = Game(saved=saved)
    g2.m.now = g.m.now + 86400
    g2.login()
    assert not any("Last time" in line for line in chat(g2))
    # six days later: one line, with the zone, the level and the last note
    g3 = Game(saved=saved)
    g3.m.now = g.m.now + 6 * 86400 + 100
    g3.login()
    lines = [line for line in chat(g3) if "Last time" in line]
    assert len(lines) == 1
    assert "6 days ago" in lines[0] and "Elwynn Forest" in lines[0] and "level 12" in lines[0] and "Buscar a Hogger" in lines[0]


def test_where_was_is_quiet_for_a_new_character(game):
    assert not any("Last time" in line for line in chat(game))


# the game's calendar ----------------------------------------------------------------------------------


def event(g, title, days_ahead, hour, minute=30, kind="GUILD_EVENT"):
    t = g.lua.eval("function(n) return date('*t', n) end")(g.m.now + days_ahead * 86400)
    g.m.calendar[len(g.m.calendar) + 1] = g.lua.table(title, t.year, t.month, t.day, hour, minute, kind)


def test_calendar_events_are_offered_once_each():
    g = Game()
    g.m.now = g.lua.eval("os.time({ year = 2026, month = 11, day = 10, hour = 9 })")
    event(g, "Onyxia", 2, 20)
    event(g, "Fiesta de la guild", 5, 21, 0, "GUILD_ANNOUNCEMENT")
    event(g, "Darkmoon Faire", 1, 12, 0, "HOLIDAY")  # the game's own: not ours
    event(g, "Raid de la semana que viene", 9, 20)  # beyond the week
    g.login()
    g.m.runTimers()  # the login timers, including the calendar scan
    assert g.m.calendarOpened == 1
    g.m.runTimers()  # the popups come a moment apart
    asked = [p for p in popups(g) if p.which == "BITACORA_CALENDAR"]
    assert [p.text for p in asked] == ["Onyxia", "Fiesta de la guild"]
    # "Yes" for the first: a reminder an hour before; "No" for the second
    g.run("StaticPopupDialogs.BITACORA_CALENDAR.OnAccept(nil, MOCK.popups[1].data)")
    rs = [r for r in reminders(g) if r.kind == "calendar"]
    assert len(rs) == 1 and rs[0].text == "Onyxia" and rs[0].value.minutes == 60
    assert rs[0].value.at == g.lua.eval("os.time({ year = 2026, month = 11, day = 12, hour = 20, min = 30 })")
    assert "60 min before" in g.run("return ns.Reminders.Describe(ns.db.reminders[#ns.db.reminders])")
    # another look at the calendar: nothing is offered twice
    g.m.popups = g.lua.table()
    g.run("ns.Reminders.ScanCalendar()")
    g.m.runTimers()
    assert popups(g) == []
    # it rings an hour before the raid, once
    g.m.now = rs[0].value.at - 50 * 60
    g.m.tick()
    assert warnings(g) == ["Reminder: Onyxia"]
    g.m.tick()
    assert len(warnings(g)) == 1


def test_calendar_always_makes_reminders_without_asking():
    g = Game()
    g.m.now = g.lua.eval("os.time({ year = 2026, month = 11, day = 10, hour = 9 })")
    event(g, "Onyxia", 2, 20)
    g.login()
    g.m.runTimers()
    g.m.runTimers()
    g.run("StaticPopupDialogs.BITACORA_CALENDAR.OnAlt(nil, MOCK.popups[1].data)")
    assert g.db.settings.calendarAuto is True
    assert [r.text for r in reminders(g) if r.kind == "calendar"] == ["Onyxia"]
    event(g, "Hyjal", 3, 20)
    g.m.popups = g.lua.table()
    g.run("ns.Reminders.ScanCalendar()")
    g.m.runTimers()
    assert popups(g) == []
    assert [r.text for r in reminders(g) if r.kind == "calendar"] == ["Onyxia", "Hyjal"]


def test_calendar_time_is_moved_from_the_realm_clock():
    g = Game()
    g.m.now = g.lua.eval("os.time({ year = 2026, month = 11, day = 10, hour = 9 })")
    g.m.realmOffset = 3 * 3600  # the realm is three hours ahead
    event(g, "Onyxia", 2, 20)  # 20:30 realm time = 17:30 on this computer
    g.login()
    g.m.runTimers()
    g.m.runTimers()
    g.run("StaticPopupDialogs.BITACORA_CALENDAR.OnAccept(nil, MOCK.popups[1].data)")
    rs = [r for r in reminders(g) if r.kind == "calendar"]
    assert rs[0].value.at == g.lua.eval("os.time({ year = 2026, month = 11, day = 12, hour = 17, min = 30 })")


def test_calendar_can_be_turned_off_and_survives_a_missing_api():
    g = Game()
    g.m.now = g.lua.eval("os.time({ year = 2026, month = 11, day = 10, hour = 9 })")
    event(g, "Onyxia", 2, 20)
    g.login()
    g.db.settings.calendar = False
    g.m.runTimers()
    g.m.runTimers()
    assert popups(g) == []
    g.db.settings.calendar = True
    g.lua.execute("C_Calendar = nil")
    assert lua_list(g.run("return ns.Reminders.ScanCalendar()")) == []


def test_calendar_events_crossing_the_month(game):
    game.m.now = game.lua.eval("os.time({ year = 2026, month = 11, day = 28, hour = 9 })")
    event(game, "Primera raid de diciembre", 4, 20)
    found = lua_list(game.run("return ns.Reminders.CalendarEvents()"))
    assert [e.title for e in found] == ["Primera raid de diciembre"]


# whispered reminders ------------------------------------------------------------------------------


def test_whisper_a_reminder_to_a_guildmate(game):
    game.run('SlashCmdList.BITACORA("a Ana: traé agua para la raid")')
    s = game.m.sent
    last = s[len(s)]
    assert last.chatType == "WHISPER" and last.target == "Ana" and last.text == "W|1|traé agua para la raid"
    assert chat(game)[-1].endswith("Reminder sent to Ana.")


def test_whisper_to_someone_offline(game):
    game.m.sendResult = 12  # TargetOffline
    game.run('SlashCmdList.BITACORA("a Beto traé agua")')
    assert "not online" in chat(game)[-1]
    game.m.sendResult = 0


def test_whisper_usage_line(game):
    game.run('SlashCmdList.BITACORA("a")')
    assert "a Name: text" in chat(game)[-1]


def test_received_whisper_from_a_guildmate_rings_and_is_kept(game):
    receive(game, "W|1|Traé agua", sender="Ana-Forever")
    assert warnings(game) == ["Reminder: Ana says: Traé agua"]
    r = reminders(game)[-1]
    assert r.kind == "login" and r.done is True and getattr(r, "from") == "Ana"
    assert game.run("return ns.Reminders.Describe(ns.db.reminders[#ns.db.reminders])") == "whispered by Ana"


def test_received_whisper_from_a_friend(game):
    game.m.guild = None
    game.m.friends[1] = "Caro"
    receive(game, "W|1|Fiesta a las 9", sender="Caro-Forever")
    assert warnings(game) == ["Reminder: Caro says: Fiesta a las 9"]


def test_whisper_from_a_stranger_is_ignored_silently(game):
    receive(game, "W|1|Gold cheap www.scam.example", sender="Desconocido-Forever")
    assert warnings(game) == [] and reminders(game) == []
    assert not any("Desconocido" in line for line in chat(game))


def test_whisper_text_is_cleaned(game):
    receive(game, "W|1|Hola |cffff0000rojo|r |Hitem:1|h[x]|h", sender="Ana-Forever")
    assert warnings(game) == ["Reminder: Ana says: Hola cffff0000rojor Hitem:1h[x]h"]


def test_guild_messages_on_whisper_channel_are_not_guild_reminders(game):
    receive(game, "A|1|abc|1762300800|0|Raid", sender="Ofi-Forever", channel="WHISPER")
    assert lua_list(game.run("return ns.GuildReminders.Sorted()")) == []


# the campsite buff --------------------------------------------------------------------------------


def test_camp_buff_warns_once_five_minutes_before_it_ends(game):
    game.m.gametime = 1000
    game.m.auras[1] = game.lua.table("Campsite", 91200, 1000 + 20 * 60, 7)
    game.m.tick()
    assert warnings(game) == []
    game.m.gametime = 1000 + 16 * 60
    game.m.tick()
    assert warnings(game) == ["Your camp ends in 4 min."]
    game.m.gametime = 1000 + 18 * 60
    game.m.tick()
    assert len(warnings(game)) == 1
    # a new camp (another aura instance) warns again
    game.m.auras[1] = game.lua.table("Campsite", 91200, 1000 + 60 * 60, 8)
    game.m.gametime = 1000 + 57 * 60
    game.m.tick()
    assert len(warnings(game)) == 2


def test_camp_buff_with_a_secret_time_says_nothing(game):
    game.m.auras[1] = game.lua.table("Campsite", 91200, 77, 9)
    game.m.secret[77] = True
    game.m.gametime = 0
    game.m.tick()
    assert warnings(game) == []


def test_camp_buff_warning_can_be_turned_off(game):
    game.db.settings.campBuff = False
    game.m.auras[1] = game.lua.table("Campsite", 91200, 1000 + 60, 7)
    game.m.gametime = 1000
    game.m.tick()
    assert warnings(game) == []


def test_camp_buff_read_that_errors_is_caught_and_not_tried_again(game):
    # Forever: "GetAuraDataByIndex(): Auras cannot be accessed when secret while tainted by 'Bitacora'"
    game.run(
        "MOCK.auraCalls = 0; local real = C_UnitAuras.GetAuraDataByIndex;"
        " C_UnitAuras.GetAuraDataByIndex = function(...) MOCK.auraCalls = MOCK.auraCalls + 1;"
        " error('Auras cannot be accessed when secret while tainted by Bitacora') end"
    )
    game.m.gametime = 1000
    game.m.tick()
    assert game.ns.Reminders.CampCheckOff()
    calls = game.m.auraCalls
    assert calls == 1
    game.m.tick()
    game.m.tick()
    assert game.m.auraCalls == calls
    assert warnings(game) == []


def test_camp_buff_is_not_read_in_combat_or_under_a_restriction(game):
    game.run("MOCK.auraCalls = 0; local real = C_UnitAuras.GetAuraDataByIndex;"
             " C_UnitAuras.GetAuraDataByIndex = function(...) MOCK.auraCalls = MOCK.auraCalls + 1; return real(...) end")
    game.m.auras[1] = game.lua.table("Campsite", 91200, 1000 + 60, 7)
    game.m.gametime = 1000
    game.run("InCombatLockdown = function() return true end")
    game.m.tick()
    assert game.m.auraCalls == 0
    game.run(
        "InCombatLockdown = function() return false end;"
        " Enum.AddOnRestrictionType = { Combat = 0, Encounter = 1, ChallengeMode = 2, PvPMatch = 3, Map = 4 };"
        " C_RestrictedActions = { IsAddOnRestrictionActive = function(t) return t == 4 end }"
    )
    game.m.tick()
    assert game.m.auraCalls == 0
    assert warnings(game) == []
    game.run("C_RestrictedActions = nil")
    game.m.tick()
    assert game.m.auraCalls >= 1
    assert warnings(game) == ["Your camp ends in 1 min."]
