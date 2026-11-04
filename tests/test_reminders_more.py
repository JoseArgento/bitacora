"""Reminders before the weekly reset, and the officers' guild reminders."""

from __future__ import annotations

import pytest
from test_addon import Game


@pytest.fixture
def game():
    g = Game()
    g.login()
    g.m.runTimers()
    return g


def sent(g, prefix="BitacoraAviso1"):
    s = g.m.sent
    return [s[i].text for i in range(1, len(s) + 1) if s[i].prefix == prefix]


def receive(g, text, sender="Ofi-Forever", channel="GUILD", prefix="BitacoraAviso1"):
    g.fire("CHAT_MSG_ADDON", prefix, text, channel, sender, "", 0, 0, "", 0)


def warnings(g):
    w = g.m.warnings
    return [w[i] for i in range(1, len(w) + 1)]


# before the weekly reset --------------------------------------------------------------------------


def test_reset_reminder_fires_once_a_week(game):
    reset = game.m.resetAt
    game.run('ns.Reminders.Create({ text = "Onyxia antes del reinicio", kind = "reset", value = 6, repeating = true })')
    game.m.now = reset - 7 * 3600
    game.m.tick()
    assert warnings(game) == []
    game.m.now = reset - 5 * 3600
    game.m.tick()
    game.m.tick()
    assert warnings(game) == ["Reminder: Onyxia antes del reinicio"]
    game.m.now = reset + 6 * 86400 + 20 * 3600  # 4 h before the next reset
    game.m.tick()
    assert len(warnings(game)) == 2


def test_reset_reminder_once_only(game):
    reset = game.m.resetAt
    game.run('ns.Reminders.Create({ text = "una vez", kind = "reset", value = 2 })')
    game.m.now = reset - 3600
    game.m.tick()
    game.m.now = reset + 7 * 86400 - 3600
    game.m.tick()
    assert warnings(game) == ["Reminder: una vez"]


@pytest.mark.parametrize("hours", [0, 169, "x"])
def test_reset_reminder_hours_must_make_sense(game, hours):
    v = f'"{hours}"' if isinstance(hours, str) else hours
    assert game.run(f'return ns.Reminders.Create({{ text = "a", kind = "reset", value = {v} }})') is None


def test_reset_reminder_without_reset_time_does_nothing(game):
    game.m.resetAt = None
    game.run('ns.Reminders.Create({ text = "a", kind = "reset", value = 6, repeating = true })')
    game.m.tick()
    assert warnings(game) == []


def test_reset_reminder_describes_itself():
    g = Game(locale="esES")
    g.login()
    r = g.run('return ns.Reminders.Create({ text = "a", kind = "reset", value = 6 })')
    assert g.ns.Reminders.Describe(r) == "6 h antes del reinicio semanal"


# guild reminders ----------------------------------------------------------------------------------


def officer():
    g = Game()
    g.m.player.name = "Ofi"
    g.m.officer = True
    g.login()
    g.m.runTimers()
    return g


def test_an_officer_sends_and_everyone_gets_it():
    ofi, me = officer(), Game()
    me.login()
    me.m.runTimers()
    at = ofi.m.now + 3600
    rid = ofi.ns.GuildReminders.Create("Raid de Onyxia: traigan pociones", at, 604800)
    assert rid
    for text in sent(ofi):
        if text.startswith("A|"):
            receive(me, text)
    lst = me.ns.GuildReminders.Sorted()
    assert len(lst) == 1 and lst[1].text == "Raid de Onyxia: traigan pociones" and lst[1].by == "Ofi"
    me.m.now = at + 60
    me.m.tick()
    assert warnings(me) == ["Ofi (guild): Raid de Onyxia: traigan pociones"]
    me.m.tick()
    assert len(warnings(me)) == 1  # once
    me.m.now = at + 604800 + 30  # next week
    me.m.tick()
    assert len(warnings(me)) == 2


def test_not_an_officer_cannot_send(game):
    assert game.ns.GuildReminders.Create("hola", game.m.now + 60, 0) is None


def test_only_officers_are_believed(game):
    receive(game, f"A|1|abc|{game.m.now + 60}|0|Darme oro", sender="Ana-Forever")  # rank 2
    assert dict(game.ns.GuildReminders.List().items()) == {}
    receive(game, f"A|1|abc|{game.m.now + 60}|0|Junta de guild", sender="Lider-Forever")
    assert list(game.ns.GuildReminders.List().keys()) == ["abc"]


def test_the_officer_deletes_it(game):
    receive(game, f"A|1|abc|{game.m.now + 60}|0|Junta")
    receive(game, "X|1|abc", sender="Lider-Forever")  # another officer: not theirs
    assert "abc" in game.ns.GuildReminders.List()
    receive(game, "X|1|abc")
    assert dict(game.ns.GuildReminders.List().items()) == {}


@pytest.mark.parametrize(
    "text",
    [
        "A|1|abc|123|5|cada cinco segundos",  # only once, daily or weekly
        "A|1|abc|notanumber|0|x",
        "A|1|zzz|123|0|x",  # the id is hex
        "A|1|abc|123|0|",
        "A|2|abc|123|0|otra version",
        "loadstring('x')()",
    ],
)
def test_bad_messages_are_ignored(game, text):
    receive(game, text)
    assert dict(game.ns.GuildReminders.List().items()) == {}


def test_text_is_cleaned(game):
    receive(game, "A|1|abc|123|0|Raid|cffff0000 roja|r\nya")
    assert game.ns.GuildReminders.List()["abc"].text == "Raidcffff0000 rojar ya"


def test_a_late_player_asks_and_the_officer_answers():
    ofi = officer()
    ofi.ns.GuildReminders.Create("Raid", ofi.m.now + 3600, 0)
    ofi.m.sent = ofi.lua.table()
    receive(ofi, "Q|1", sender="Josecito-Forever")
    ofi.m.runTimers()
    assert any(t.startswith("A|1|") for t in sent(ofi))


def test_turned_off_it_asks_nothing_and_shows_nothing():
    g = Game()
    g.login()
    g.db.settings.guildReminders = False
    g.m.sent = g.lua.table()
    g.m.runTimers()
    assert sent(g) == []
    receive(g, f"A|1|abc|{g.m.now + 60}|0|Junta")
    assert dict(g.ns.GuildReminders.List().items()) == {}


def test_next_at_is_the_next_such_day(game):
    game.m.now = game.run("return time({ year = 2026, month = 11, day = 4, hour = 10 })")  # a Wednesday
    at = game.ns.GuildReminders.NextAt(5, 20, 30)  # Thursday 20:30
    assert game.run(f"return date('%A %H:%M', {at})") == "Thursday 20:30"
    assert at - game.m.now == 34 * 3600 + 1800


def test_the_tab_shows_guild_reminders_for_officers():
    ofi = officer()
    ofi.ns.GuildReminders.Create("Raid", ofi.m.now + 3600, 0)
    i = ofi.ns.UI.tabOfTopic.reminders
    ofi.run("ns.Toggle()")
    ofi.run(f"ns.UI.SelectTab({i})")
    assert ofi.ns.UI.views[i] is not None
