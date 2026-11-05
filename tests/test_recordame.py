"""Recordame: the reminders as a truly standalone addon (its own data and textures, no Bitacora_Datos)."""

from __future__ import annotations

from test_addon import ROOT, Game


def recordame(saved=None, also=()):
    g = Game(saved=saved, addons=("Recordame", *also), datos=bool(also))
    if also:  # Bitacora_Datos comes first, then Recordame, then the rest
        g.ns = g.nss["Recordame"]
    g.login()
    g.m.runTimers()
    return g


def warnings(g):
    w = g.m.warnings
    return [w[i] for i in range(1, len(w) + 1)]


def test_needs_nothing_else():
    toc = (ROOT / "Recordame" / "Recordame.toc").read_text(encoding="utf-8")
    assert "## Dependencies" not in toc and "## SavedVariables: RecordameDB" in toc
    assert (ROOT / "Recordame" / "Media" / "cover.tga").is_file()
    assert (ROOT / "Recordame" / "Libs" / "Pergamino" / "Pergamino.lua").is_file()  # its own copy of the look
    assert toc.index("Libs\\Pergamino\\Pergamino.lua") < toc.index("Core.lua")
    g = recordame()
    assert g.lua.globals().RecordameDB is not None and g.lua.globals().BitacoraDB is None
    assert g.ns.MEDIA == "Interface\\AddOns\\Recordame\\Media\\"
    assert "Interface\\AddOns\\Recordame\\Libs\\Pergamino" in g.lua.globals().Pergamino.MEDIA
    assert g.lua.globals().RecordameFrame.single is True and g.lua.globals().RecordameFrame.right is None


def test_reminders_work_alone():
    g = recordame()
    g.run('ns.Reminders.Create({ text = "vender el paño", kind = "place", value = "MERCHANT" })')
    g.fire("MERCHANT_SHOW")
    assert warnings(g) == ["Reminder: vender el paño"]


def test_its_own_slash_window_and_compartment():
    g = recordame()
    glob = g.lua.globals()
    assert glob.SLASH_RECORDAME1 == "/recordame"
    glob.SlashCmdList.RECORDAME("")
    assert glob.RecordameFrame._shown
    glob.Recordame_OnAddonCompartmentClick()
    assert glob.RecordameFrame.TitleText.GetText(glob.RecordameFrame.TitleText) == "Recordame"


def test_saved_and_loaded():
    a = recordame()
    a.run('ns.Reminders.Create({ text = "la montura", kind = "level", value = 40 })')
    b = recordame(saved=a.m.savedVariables("RecordameDB"))
    assert [r.text for r in b.ns.Reminders.List("Josecito-Forever").values()] == ["la montura"]


def test_does_not_step_aside_for_the_full_bitacora():
    g = recordame(also=("Bitacora",))
    assert not g.nss["Recordame"].disabled
    g.run('ns.Reminders.Create({ text = "solo de Recordame", kind = "place", value = "MAIL" })')
    g.fire("MAIL_SHOW")
    assert warnings(g) == ["Reminder: solo de Recordame"]  # Bitácora has its own, separate reminders


def test_guild_reminders_pop_once_with_both_installed():
    g = recordame(also=("Bitacora",))
    at = g.m.now + 60
    for ns in (g.nss["Recordame"], g.nss["Bitacora"]):
        g.lua.eval(
            "function(ns, at) ns.GuildReminders.OnAddonMessage('BitacoraAviso1', 'A|1|abc|' .. at .. '|0|Raid', 'GUILD', 'Ofi-Forever') end"
        )(ns, at)
    g.m.now = at + 30
    g.m.tick()
    assert warnings(g) == ["Ofi (guild): Raid"]


def test_on_the_single_page_the_button_sits_under_the_checks():
    # in the game the "only this character" check was hidden behind the "new reminder" button
    g = recordame()
    g.run("ns.Toggle()")
    i = g.run("return ns.UI.tabOfTopic.reminders")
    view = g.run(f"return ns.UI.views[{i}]")
    assert view.onlyChar._shown is True and view.repeating._shown is True
    anchored = g.run(f"local v = ns.UI.views[{i}]; local p = v.create._points[1]; return p[1] .. ':' .. tostring(p[2] == v.onlyChar) .. ':' .. p[3]")
    assert anchored == "TOPLEFT:true:BOTTOMLEFT"
    # heading, text, when, value, checks and the button all fit in the form
    assert view.form.height >= 20 + 10 + 24 + 14 + 26 + 12 + 26 + 14 + 18 + 14 + 26


def test_recordame_has_its_own_minimap_button_with_the_bell():
    g = recordame()
    b = g.run("return RecordameMinimapButton")
    assert b is not None and b.icon.texture == "Interface\\AddOns\\Recordame\\Media\\icon_bell"
    g.run("RecordameMinimapButton:GetScript('OnClick')(RecordameMinimapButton, 'LeftButton')")
    assert g.run("return RecordameFrame:IsShown()") is True
    # next to the full Bitácora each has its own button, in a different place
    g2 = recordame(also=("Bitacora",))
    assert g2.run("return BitacoraMinimapButton.angle") != g2.run("return RecordameMinimapButton.angle")


def test_recordame_options_say_what_recordame_is():
    g = recordame()
    g.run("ns.UI.options.Build()")
    assert g.run("return ns.UI.options.intro._text") == "Reminders. Open the window with /recordame."


def test_the_zone_help_goes_under_the_field_and_stays_on_the_page():
    # in the game "Zone or subzone name (empty: the current one)" ran past the page's edge
    plain = Game()
    plain.login()
    for g in (recordame(), plain):
        g.run("ns.Toggle(); ns.UI.SelectTab('reminders')")
        i = g.run("return ns.UI.tabOfTopic.reminders")
        got = g.run(
            f"local v = ns.UI.views[{i}]; local hint = v.onlyChar._points[1][2];"
            " local a, b = hint._points[1], hint._points[2];"
            " return hint._text .. '|' .. a[1] .. ':' .. a[3] .. '|' .. b[1] .. ':' .. tostring(b[2] == v.form)"
        )
        assert got == "Zone or subzone (empty: where you are now)|TOPLEFT:BOTTOMLEFT|RIGHT:true"
