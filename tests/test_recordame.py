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
    assert (ROOT / "Recordame" / "Media" / "parchment.tga").is_file()
    g = recordame()
    assert g.lua.globals().RecordameDB is not None and g.lua.globals().BitacoraDB is None
    assert g.ns.MEDIA == "Interface\\AddOns\\Recordame\\Media\\"


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
