"""Time per level (splits), companions, and the reminders' catch-up, snooze and clock setting."""

from __future__ import annotations

import pytest
from test_addon import Game, lua_list


@pytest.fixture
def game():
    g = Game()
    g.login()
    g.m.runTimers()
    return g


def rows(g):
    r = g.ns.Progress.Rows()
    return [("#", r[i].header) if r[i].header else (r[i].left.strip(), r[i].right) for i in range(1, len(r) + 1)]


def warnings(g):
    return [w for w in lua_list(g.m.warnings)]


def level_up(g, level, after_seconds):
    g.m.now = g.m.now + after_seconds
    g.m.player.level = level
    g.fire("PLAYER_LEVEL_UP", level)


# splits ---------------------------------------------------------------------------------------------


def test_each_level_gets_the_seconds_it_took(game):
    level_up(game, 11, 3600)
    level_up(game, 12, 5400)
    level_up(game, 13, 600)
    splits = lua_list(game.ns.Progress.Splits())
    assert [(s.level, s.seconds) for s in splits] == [(10, 3600), (11, 5400), (12, 600)]


def test_the_games_played_count_anchors_the_clock(game):
    # the game says 100 h played (the addon only saw this session): the next level reads from that
    game.fire("TIME_PLAYED_MSG", 360000, 1000)
    level_up(game, 11, 900)
    assert game.journal()[-1].played == 360900
    assert lua_list(game.ns.Progress.Splits())[0].seconds == 900


def test_time_away_does_not_count():
    g = Game()
    g.login()
    g.m.runTimers()
    g.m.now = g.m.now + 1800
    g.m.tick()  # the ticker folds the session in
    g.fire("PLAYER_LOGOUT")
    saved = g.m.savedVariables("BitacoraDB")
    g2 = Game(saved=saved)
    g2.m.now = g.m.now + 7 * 86400  # a week off
    g2.login()
    g2.m.runTimers()
    level_up(g2, 11, 600)
    assert lua_list(g2.ns.Progress.Splits())[0].seconds == 1800 + 600


def test_the_fastest_character_of_the_account_wins():
    g = Game()
    g.login()
    g.m.runTimers()
    level_up(g, 11, 7200)
    # a second character, quicker
    g.m.player.name, g.m.player.level = "Anabel", 10
    g.ns.charKey = None
    g.fire("PLAYER_LOGIN")
    g.m.runTimers()
    level_up(g, 11, 1800)
    best = g.ns.Progress.BestSplits()
    assert best[10].seconds == 1800 and best[10].name == "Anabel"
    # Josecito's row says who did it faster; Anabel's row is just green
    assert ("Level 10", "7200s · your best: Anabel 1800s") in rows_for(g, "Josecito-Forever")
    assert ("Level 10", "|cff40c0401800s|r") in rows_for(g, "Anabel-Forever")


def rows_for(g, key):
    r = g.run(f'return ns.Progress.Rows("{key}")')
    return [(r[i].left.strip(), r[i].right) for i in range(1, len(r) + 1) if not r[i].header]


def test_no_splits_without_two_marks(game):
    assert rows(game)[0] == ("#", "Your numbers")
    assert ("#", "Time per level") not in rows(game)


# companions -----------------------------------------------------------------------------------------


def group(g, **units):
    for unit, name in units.items():
        g.m.group[unit] = name
    g.fire("GROUP_ROSTER_UPDATE")


def test_grouping_with_someone_writes_them_down(game):
    game.m.groupClass["party1"] = "WARRIOR"
    group(game, party1="Ana")
    people = lua_list(game.ns.Companions.Sorted())
    assert len(people) == 1
    p = people[0]
    assert (p.key, p.label, p["class"], p.times, p.zone) == ("Ana-Forever", "Ana", "WARRIOR", 1, "Elwynn Forest")
    today = game.run('return date("%d/%m")')
    assert ("#", "Companions") in rows(game) and ("|cffc69b6dAna|r", f"1 group · {today} · Elwynn Forest") in rows(game)


def test_a_member_whose_name_has_not_arrived_is_not_written_down(game):
    # the game names such a unit "Unknown" (UNKNOWNOBJECT) until the roster catches up
    game.run('UNKNOWNOBJECT = "Unknown"')
    group(game, party1="Unknown", party2="Beto")
    assert {p.name for p in lua_list(game.ns.Companions.Sorted())} == {"Beto"}
    group(game, party1="Ana", party2="Beto")  # the name arrived: Ana counts now
    assert {p.name for p in lua_list(game.ns.Companions.Sorted())} == {"Ana", "Beto"}


def test_a_roster_change_counts_a_person_once(game):
    group(game, party1="Ana")
    group(game, party1="Ana", party2="Beto")  # Beto joins: Ana is not a new group for her
    game.fire("GROUP_ROSTER_UPDATE")
    people = {p.name: p.times for p in lua_list(game.ns.Companions.Sorted())}
    assert people == {"Ana": 1, "Beto": 1}
    game.m.group = game.lua.table()
    game.fire("GROUP_ROSTER_UPDATE")  # everyone left
    group(game, party1="Ana")  # a new group with Ana later
    assert {p.name: p.times for p in lua_list(game.ns.Companions.Sorted())} == {"Ana": 2, "Beto": 1}


def test_other_realms_keep_their_name_and_secret_names_are_skipped(game):
    game.m.groupRealm["party1"] = "Nightslayer"
    group(game, party1="Zed")
    game.m.secret["Hidden"] = True
    group(game, party1="Zed", party2="Hidden")
    people = lua_list(game.ns.Companions.Sorted())
    assert [(p.key, p.label) for p in people] == [("Zed-Nightslayer", "Zed-Nightslayer")]


def test_the_list_is_capped_and_drops_the_oldest(game):
    game.run("ns.Companions.CAP = 3")
    for name in ["Ana", "Beto", "Caro", "Dani"]:
        game.m.now = game.m.now + 60
        game.m.group = game.lua.table()
        game.fire("GROUP_ROSTER_UPDATE")
        group(game, party1=name)
    assert [p.name for p in lua_list(game.ns.Companions.Sorted())] == ["Dani", "Caro", "Beto"]


def test_companions_are_shared_by_the_account():
    g = Game()
    g.login()
    g.m.runTimers()
    group(g, party1="Ana")
    saved = g.m.savedVariables("BitacoraDB")
    g2 = Game(saved=saved)
    g2.m.player.name = "Anabel"
    g2.login()
    assert [p.name for p in lua_list(g2.ns.Companions.Sorted())] == ["Ana"]


# reminders: catch-up, snooze, clock ------------------------------------------------------------------


def at(g, day, hour, minute=0):
    return g.run(f"return time({{ year = 2026, month = 11, day = {day}, hour = {hour}, min = {minute} }})")


def test_a_reminder_that_came_due_while_you_were_out_fires_at_login():
    g = Game()
    g.m.now = at(g, 4, 10)  # Wednesday
    g.login()
    g.m.runTimers()
    g.run('ns.Reminders.Create({ text = "Raid", kind = "time", value = { wday = 0, hour = 20, min = 0 }, repeating = true })')
    g.m.tick()  # lastSeen = Wednesday 10:00
    g.fire("PLAYER_LOGOUT")
    saved = g.m.savedVariables("BitacoraDB")
    g2 = Game(saved=saved)
    g2.m.now = at(g, 6, 9)  # Friday morning: Wednesday's and Thursday's 20:00 went by
    g2.login()
    g2.m.runTimers()
    assert warnings(g2) == ["Reminder: Raid"]  # once, not twice
    g2.m.tick()
    assert len(warnings(g2)) == 1


def test_nothing_from_before_the_last_session(game):
    game.m.now = at(game, 4, 21)
    game.run('ns.Reminders.Create({ text = "Raid", kind = "time", value = { wday = 0, hour = 20, min = 0 }, repeating = true })')
    game.m.tick()  # seen at 21:00, after today's 20:00: already past
    game.fire("PLAYER_LOGOUT")
    g2 = Game(saved=game.m.savedVariables("BitacoraDB"))
    g2.m.now = at(game, 5, 8)
    g2.login()
    g2.m.runTimers()
    assert warnings(g2) == []


def test_too_long_ago_falls_back_to_six_hours(game):
    game.m.now = at(game, 1, 10)
    game.run('ns.Reminders.Create({ text = "Raid", kind = "time", value = { wday = 0, hour = 20, min = 0 }, repeating = true })')
    game.m.tick()
    g2 = Game(saved=game.m.savedVariables("BitacoraDB"))
    g2.m.now = g2.run("return time({ year = 2026, month = 12, day = 15, hour = 9 })")  # 44 days later, 9:00
    g2.login()
    g2.m.runTimers()
    assert warnings(g2) == []  # yesterday's 20:00 is more than 6 h back


def test_snooze_rings_again_and_the_popup_offers_it(game):
    game.m.now = at(game, 4, 20)
    game.run('ns.Reminders.Create({ text = "Pociones", kind = "login" })')
    game.fire("PLAYER_LOGIN")
    game.m.runTimers()
    assert warnings(game) == ["Reminder: Pociones"]
    popups = lua_list(game.m.popups)
    assert popups[-1].which == "BITACORA_REMINDER" and popups[-1].text == "Pociones"
    d = game.lua.globals().StaticPopupDialogs["BITACORA_REMINDER"]
    assert (d.button1, d.button2, d.button3, d.button4) == ("Okay", "5 min later", "10 min later", "15 min later")
    d.OnButton3(None, popups[-1].data)  # 10 minutes
    r = lua_list(game.db.reminders)[0]
    assert r.done is None and r.snooze == game.m.now + 600
    game.m.now = game.m.now + 300
    game.m.tick()
    assert len(warnings(game)) == 1
    game.m.now = game.m.now + 300
    game.m.tick()
    assert warnings(game) == ["Reminder: Pociones", "Reminder: Pociones"]
    assert lua_list(game.db.reminders)[0].done is True
    game.m.tick()
    assert len(warnings(game)) == 2


def test_the_popup_can_be_turned_off(game):
    game.db.settings.reminderPopup = False
    game.run('ns.Reminders.Create({ text = "x", kind = "login" })')
    game.fire("PLAYER_LOGIN")
    game.m.runTimers()
    assert warnings(game) == ["Reminder: x"] and lua_list(game.m.popups) == []


def test_the_realm_clock(game):
    game.m.now = at(game, 4, 17, 0)
    game.m.realmOffset = 3 * 3600  # the realm says 20:00 while your computer says 17:00
    game.run('ns.Reminders.Create({ text = "Raid", kind = "time", value = { wday = 0, hour = 20, min = 0 }, repeating = true })')
    game.m.tick()
    assert warnings(game) == []
    game.db.settings.clock = "realm"
    game.m.tick()
    assert warnings(game) == ["Reminder: Raid"]
    game.m.tick()
    assert len(warnings(game)) == 1  # not again for the same 20:00
    game.m.now = game.m.now + 3 * 3600  # 20:00 on the computer: the realm is at 23:00, nothing
    game.m.tick()
    assert len(warnings(game)) == 1


def test_the_options_page_shows_the_clock(game):
    panel = game.ns.UI.options
    panel.Refresh()
    assert panel.clock._text == "My computer's clock"
    game.db.settings.clock = "realm"
    panel.Refresh()
    assert panel.clock._text == "The realm's clock"
    assert panel.checks.reminderPopup is not None
