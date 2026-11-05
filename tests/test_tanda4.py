"""Tanda 4 (José's screenshots of 5/11, 12:04): the notebook's images row, the album's footer, the
reminders form with chips, tags and "Edit", and the Legacy note in Progress."""

from __future__ import annotations

from test_addon import Game
from test_recordame import recordame


def opened(tab="reminders", g=None):
    if g is None:
        g = Game()
        g.login()
    g.run(f"ns.Toggle(); ns.UI.SelectTab('{tab}')")
    i = g.run(f"return ns.UI.tabOfTopic.{tab}")
    return g, i


def test_the_kind_is_a_row_of_chips_and_only_its_field_shows():
    g, i = opened()
    v = f"ns.UI.views[{i}]"
    texts = [c._text for c in g.run(f"return {v}.kinds.chips").values()]
    assert texts == ["A zone", "A place", "Day and time", "Before the reset", "A level", "Logging in"]
    assert g.run(f"return {v}.kinds.chips[1].pressed") is True
    # day and time: the weekday button, hour and minute; the zone field gives way
    g.run(f"{v}.kinds.chips[3]:GetScript('OnClick')()")
    assert g.run(f"return {v}.dayButton:IsShown(), {v}.minute:IsShown(), {v}.places:IsShown()") == (True, True, False)
    assert g.run(f"return {v}.kinds.chips[3].pressed, {v}.kinds.chips[1].pressed") == (True, False)
    # a place: its own chips, mail first
    g.run(f"{v}.kinds.chips[2]:GetScript('OnClick')()")
    assert g.run(f"return {v}.places:IsShown(), {v}.value:IsShown()") == (True, False)
    g.run(f"{v}.places.chips[2]:GetScript('OnClick')()")
    g.run(f"{v}.text:SetText('Sell the cloth'); {v}.create:GetScript('OnClick')()")
    r = g.run("return ns.db.reminders[#ns.db.reminders]")
    assert r.kind == "place" and r.value == "BANK" and r.text == "Sell the cloth"
    # logging in: no field at all, just a short help
    g.run(f"{v}.kinds.chips[6]:GetScript('OnClick')()")
    assert g.run(f"return {v}.valueHint._text") == "The next time you log in."


def test_a_reminder_can_be_edited_from_its_menu():
    g, i = opened()
    v = f"ns.UI.views[{i}]"
    r = g.run("return ns.Reminders.Create({ text = 'Buy bags', kind = 'zone', value = 'Goldshire' })")
    rid = r.id
    g.run(f"{v}.Edit(ns.Reminders.Get('{rid}'))")
    assert g.run(f"return {v}.text:GetText(), {v}.value:GetText(), {v}.create:GetText()") == ("Buy bags", "Goldshire", "Save changes")
    assert g.run(f"return {v}.cancel:IsShown(), {v}.head._text") == (True, "Editing a reminder")
    g.run(f"{v}.text:SetText('Buy bigger bags'); {v}.value:SetText('Stormwind'); {v}.create:GetScript('OnClick')()")
    assert g.run("return #ns.db.reminders") == 1
    edited = g.run(f"return ns.Reminders.Get('{rid}')")
    assert edited.text == "Buy bigger bags" and edited.value == "Stormwind"
    # back to a new one
    assert g.run(f"return {v}.create:GetText(), {v}.cancel:IsShown()") == ("Add reminder", False)


def test_update_checks_like_create_and_reactivates():
    g = Game()
    g.login()
    r = g.run("local r = ns.Reminders.Create({ text = 'Lvl', kind = 'level', value = 20 }); r.done = true; return r")
    assert g.run(f"return ns.Reminders.Update('{r.id}', {{ text = 'Lvl', kind = 'level', value = 'x' }})") is None
    assert g.run(f"return ns.Reminders.Update('{r.id}', {{ text = 'Lvl 30', kind = 'level', value = 30 }}).value") == 30
    assert g.run(f"return ns.Reminders.Get('{r.id}').done") is None


def test_each_reminder_in_the_list_wears_a_tag_of_its_kind():
    g, i = opened()
    g.run("ns.Reminders.Create({ text = 'Hello', kind = 'login' })")
    g.run(f"ns.UI.views[{i}].Refresh()")
    tags = g.run(f"local out = {{}} ns.UI.views[{i}].list.box:ForEachFrame(function(row) if row.tag then out[#out + 1] = row.tag.text._text end end) return out")
    assert "LOGIN" in list(tags.values())


def test_the_long_help_is_a_tooltip_not_a_block_on_the_page():
    for g in (None, recordame()):
        g, i = opened(g=g)
        how = g.run(f"return ns.UI.views[{i}].how")
        assert how.label._text == "How does it work?"
        g.run(f"ns.UI.views[{i}].how:GetScript('OnEnter')(ns.UI.views[{i}].how)")
        lines = [c for c in g.run("return GameTooltip._lines or {}").values()] if g.run("return GameTooltip._lines ~= nil") else []
        assert any("pops up" in str(x) for x in lines) or g.run("return GameTooltip:IsShown()")


def test_notebook_images_row_has_air_and_one_line():
    g, i = opened("notes")
    v = f"ns.UI.views[{i}]"
    row = g.run(f"return {v}.imagesRow")
    assert row is not None and row.height == 28
    p = g.run(f"return {v}.imagesRow._points[1]")
    assert p[1] == "TOPLEFT" and p[5] == -12
    # label and button are both centred on the row
    assert g.run(f"return {v}.imagesLabel._points[1][1], {v}.addImage._points[1][1]") == ("LEFT", "LEFT")


def test_album_buttons_sit_above_the_folder_note():
    g, i = opened("album")
    v = f"ns.UI.views[{i}]"
    assert g.run(f"local p = {v}.setCaption._points[1]; return p[1], p[2] == {v}.footRule, p[3]") == ("BOTTOMLEFT", True, "TOPLEFT")
    assert g.run(f"local p = {v}.footRule._points[1]; return p[2] == {v}.folder, p[3]") == (True, "TOPLEFT")


def test_progress_explains_the_achievements_and_clicking_opens_the_legacy_window():
    g, i = opened("progress")
    g.run("MOCK.legacy = 0; function ToggleLegacyChallenges() MOCK.legacy = MOCK.legacy + 1 end")
    assert g.run("return ns.UI.OpenLegacy()") == "ToggleLegacyChallenges"
    assert g.m.legacy == 1
    # a missing function falls through to the next one; none at all does nothing
    g.run("ToggleLegacyChallenges = nil; ToggleLegacySystemUI = nil; ToggleAchievementFrame = function() end")
    assert g.run("return ns.UI.OpenLegacy()") == "ToggleAchievementFrame"
