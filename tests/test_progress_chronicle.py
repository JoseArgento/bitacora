"""The Progress tab (#26) and the guild chronicle (#27), in Lua 5.1 with the client stand-in."""

from __future__ import annotations

import pytest
from test_addon import Game


@pytest.fixture
def game():
    g = Game()
    g.login()
    g.m.runTimers()
    return g


def rows(g, part=None):
    r = g.ns.Progress.Rows()
    out = []
    for i in range(1, len(r) + 1):
        out.append(("#", r[i].header) if r[i].header else (r[i].left, r[i].right))
    return out


def sent(g, prefix="BitacoraCron1"):
    s = g.m.sent
    return [(s[i].prefix, s[i].text, s[i].chatType) for i in range(1, len(s) + 1) if s[i].prefix == prefix]


def receive(g, text, sender="Ana-Forever", channel="GUILD", prefix="BitacoraCron1"):
    g.fire("CHAT_MSG_ADDON", prefix, text, channel, sender, "", 0, 0, "", 0)


def entries(g):
    e = g.ns.Chronicle.Entries()
    return [g.ns.Chronicle.Describe(e[i]) for i in range(1, len(e) + 1)]


# Progress -----------------------------------------------------------------------------------------


def test_numbers_from_the_journal(game):
    game.fire("PLAYER_DEAD")
    game.m.gametime = game.m.gametime + 60
    game.fire("PLAYER_DEAD")
    game.m.gametime = game.m.gametime + 60
    game.m.where.zone = "Westfall"
    game.fire("PLAYER_DEAD")
    game.fire("QUEST_TURNED_IN", 176, 0, 0)
    game.fire("ENCOUNTER_END", 2741, "Rhahk'Zor", 1, 5, 1)
    s = game.ns.Progress.Stats()
    assert (s.deaths, s.quests, s.bosses, s.firsts) == (3, 1, 1, 1)
    assert (s.worstZone, s.worstDeaths) == ("Elwynn Forest", 2)
    assert s.days == 1 and s.zones >= 1


def test_dungeons_and_raids_from_the_encounter_journal(game):
    game.fire("ENCOUNTER_END", 2741, "Rhahk'Zor", 1, 5, 1)
    game.m.gametime = game.m.gametime + 60
    game.fire("ENCOUNTER_END", 2746, "Edwin VanCleef", 1, 5, 1)
    r = rows(game)
    assert ("#", "Dungeons") in r and ("#", "Raids") in r
    assert ("Deadmines", "|cff94701f2 of 3|r") in r
    assert ("Shadowfang Keep", "|cff6b4f300 of 1|r") in r
    assert ("Onyxia's Lair", "|cff6b4f300 of 1|r") in r
    assert game.m.ej.tier == 1  # the Encounter Journal's own selection was put back


def test_a_full_clear_is_green(game):
    game.fire("ENCOUNTER_END", 2750, "Arugal", 1, 5, 1)
    assert ("Shadowfang Keep", "|cff1c6e0f1 of 1|r") in rows(game)


def test_the_encounter_journal_is_left_alone_while_it_is_open():
    g = Game()
    g.run("EncounterJournal = CreateFrame('Frame'); EncounterJournal:Show()")
    g.login()
    r = rows(g)
    assert ("Close the Adventure Guide to see dungeons and raids here.", "") in r
    assert g.m.ej.selected is None


def test_achievement_categories_add_up_their_subcategories(game):
    r = rows(game)
    # some done: deep gold; with a note first that says where they come from
    assert ("General", "|cff94701f3 of 10|r") in r
    assert ("Quests", "|cff94701f7 of 28|r") in r
    assert ("The game's Legacy challenges (Y), by category.", "") in r
    assert not any(left == "Eastern Kingdoms" for left, _ in r)


def test_the_tab_opens(game):
    game.run("ns.Toggle(UI and nil)")
    i = game.ns.UI.tabOfTopic.progress
    game.run(f"ns.UI.SelectTab({i})")
    assert game.ns.UI.views[i] is not None


def test_spanish():
    g = Game(locale="esES")
    g.login()
    r = rows(g)
    assert ("#", "Tus números") in r and ("#", "Mazmorras") in r
    assert ("Deadmines", "|cff6b4f300 de 3|r") in r


# Chronicle ----------------------------------------------------------------------------------------


def test_off_by_default_sends_nothing(game):
    assert game.db.settings.chronicle is False
    game.fire("PLAYER_LEVEL_UP", 10)
    assert sent(game) == []
    assert "off" in game.ns.Chronicle.Status()


def test_milestones_go_to_the_guild_when_on(game):
    game.db.settings.chronicle = True
    game.fire("PLAYER_LEVEL_UP", 9)
    game.fire("PLAYER_LEVEL_UP", 10)
    game.fire("ENCOUNTER_END", 2741, "Rhahk'Zor", 1, 5, 1)
    game.m.gametime = game.m.gametime + 120
    game.fire("ENCOUNTER_END", 2741, "Rhahk'Zor", 1, 5, 1)  # second kill: not news
    assert sent(game) == [
        ("BitacoraCron1", "M|1|level|10", "GUILD"),
        ("BitacoraCron1", "M|1|boss|2741|Rhahk'Zor", "GUILD"),
    ]


def test_trial_accounts_do_not_send(game):
    game.db.settings.chronicle = True
    game.m.trial = True
    game.fire("PLAYER_LEVEL_UP", 10)
    assert sent(game) == []
    assert "Trial" in game.ns.Chronicle.Status()


def test_receiving_builds_text_with_our_own_strings(game):
    receive(game, "M|1|level|20")
    receive(game, "M|1|achievement|6")  # the name comes from our client
    receive(game, "M|1|boss|2746|Edwin VanCleef")
    receive(game, "M|1|start|0")
    assert entries(game) == [
        "Ana reached level 20",
        "Ana earned Level 10",
        "Ana killed Edwin VanCleef for the first time",
        "Ana started a new adventure",
    ]


def test_names_lose_escape_codes(game):
    receive(game, "M|1|boss|1|Evil|cffff0000|Hitem:1|h[Click]|h|r")
    e = game.ns.Chronicle.Entries()[1]
    assert "|" not in e.name
    assert len(e.name) <= 40


@pytest.mark.parametrize(
    "kwargs",
    [
        {"channel": "PARTY"},
        {"prefix": "Other"},
        {"text": "M|1|level|99"},
        {"text": "M|1|level|0"},
        {"text": "M|1|teleport|1"},
        {"text": "M|1|level|abc"},
        {"text": "M|2|level|10"},
        {"text": "loadstring('x')()"},
        {"text": "M|1|boss|1|" + "x" * 200},
        {"text": "M|1|loot|99999999999"},
        {"sender": "Josecito-Forever"},
    ],
)
def test_bad_messages_are_ignored(game, kwargs):
    text = kwargs.pop("text", "M|1|level|10")
    receive(game, text, **kwargs)
    assert entries(game) == []


def test_secret_senders_are_ignored(game):
    game.m.secret["Ana-Forever"] = True
    receive(game, "M|1|level|10")
    assert entries(game) == []


def test_one_sender_cannot_flood(game):
    for _ in range(9):
        receive(game, "M|1|level|10")
    assert len(entries(game)) == 5
    game.m.now = game.m.now + 11
    receive(game, "M|1|level|20")
    assert len(entries(game)) == 6


def test_keeps_the_last_300(game):
    for i in range(320):
        receive(game, "M|1|level|10", sender=f"P{i}-Forever")
    assert len(entries(game)) == 300
    assert game.ns.Chronicle.Entries()[1].who == "P20"


def test_two_players_share_their_milestones():
    a, b = Game(), Game()
    b.m.player.name = "Ana"
    for g in (a, b):
        g.login()
        g.db.settings.chronicle = True
    a.fire("PLAYER_LEVEL_UP", 30)
    for _prefix, text, _chat in sent(a):
        receive(b, text, sender="Josecito-Forever")
    assert entries(b) == ["Josecito reached level 30"]


def test_the_guild_tab_explains_itself(game):
    i = game.ns.UI.tabOfTopic.chronicle
    game.run("ns.Toggle()")
    game.run(f"ns.UI.SelectTab({i})")
    v = game.ns.UI.views[i]
    assert "off" in v.status.GetText(v.status)
    game.db.settings.chronicle = True
    receive(game, "M|1|level|10")
    assert v.status.GetText(v.status) == ""


def test_saved_with_the_rest(game):
    receive(game, "M|1|level|40")
    g2 = Game(saved=game.m.savedVariables("BitacoraDB"))
    g2.login()
    assert entries(g2) == ["Ana reached level 40"]


def test_an_empty_journal_is_read_again_later():
    g = Game()
    g.run("MOCK.ej.saved = MOCK.ej.dungeons; MOCK.ej.dungeons = {}; MOCK.ej.raids_saved = MOCK.ej.raids; MOCK.ej.raids = {}")
    g.login()
    assert len(g.ns.Progress.Instances()) == 0
    g.run("MOCK.ej.dungeons = MOCK.ej.saved; MOCK.ej.raids = MOCK.ej.raids_saved")
    assert len(g.ns.Progress.Instances()) == 3


def test_the_guides_own_instance_is_put_back():
    g = Game()
    g.run("EncounterJournal = CreateFrame('Frame'); EncounterJournal:Hide(); EncounterJournal.instanceID = 64")
    g.login()
    g.ns.Progress.Instances()
    assert g.m.ej.selected == 64


def test_a_guide_never_opened_has_tier_zero_and_its_tiers_are_walked():
    # In the game EJ_GetCurrentTier() is 0 until the Adventure Guide was opened once: EJ_SelectTier(0) errors
    # and the journal lists nothing, so each tier is selected and read in turn
    g = Game()
    g.run("MOCK.ej.tier = 0; MOCK.ej.numTiers = 2")
    g.login()
    assert len(g.ns.Progress.Instances()) == 3
    # the tier is not put back to 0
    assert g.m.ej.tier != 0


def test_a_journal_that_lists_nothing_in_any_tier_says_so():
    g = Game()
    g.run("MOCK.ej.tier = 0; MOCK.ej.numTiers = 0")
    g.login()
    assert len(g.ns.Progress.Instances()) == 0
