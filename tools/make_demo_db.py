#!/usr/bin/env python3
"""Plays a short scripted session through the real addon (Lua 5.1 + tests/wow_mock.lua) and writes the
SavedVariables file the client would write: tests/fixtures/BitacoraDB.lua. The web page uses it as its
example, and its tests parse it. Needs `pip install lupa`.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tests"))

from test_addon import Game  # noqa: E402

OUT = ROOT / "tests" / "fixtures" / "BitacoraDB.lua"

EPIC = "|cffa335ee|Hitem:17078::::::::60:::::|h[Sapphiron Drape]|h|r"
RARE = "|cff0070dd|Hitem:2244::::::::25:::::|h[Krol Blade]|h|r"


def t(g, day, hour, minute=0):
    g.m.now = g.lua.eval(f"os.time({{ year = 2026, month = 11, day = {day}, hour = {hour}, min = {minute} }})")
    g.m.gametime = g.m.now


def main() -> None:
    g = Game(locale="esMX")
    m = g.m
    m.player.name, m.player.level, m.player.money = "Josecito", 1, 0
    m.where.mapID, m.where.zone, m.where.sub = 1429, "Bosque de Elwynn", "Abadía de Northshire"
    m.maps[1429], m.maps[1453], m.maps[1455], m.maps[1436] = "Bosque de Elwynn", "Ciudad de Ventormenta", "Forjaz", "Páramos de Poniente"
    m.quests[176] = "Se busca: Hogger"
    m.quests[184] = "Las tierras de Furlbrow"
    m["items"][17078], m["items"][2244] = 4, 3
    t(g, 4, 15, 10)
    g.login()
    g.db.settings.lootQuality = 3
    g.run('ns.Journal.AddManual("Primer día de Forever. Fila de 40 minutos, valió la pena.")')
    t(g, 4, 15, 40)
    for lvl in (2, 3, 4, 5):
        m.player.level = lvl
        g.fire("PLAYER_LEVEL_UP", lvl)
    m.where.sub = "Villadorada"
    t(g, 4, 16, 5)
    m.group["party1"] = "Ana"
    g.fire("SCREENSHOT_SUCCEEDED")
    g.run("ns.Album.SetCaption(1, 'Con Ana en la posada de Villadorada')")
    t(g, 4, 17, 30)
    m.player.level = 10
    g.fire("PLAYER_LEVEL_UP", 10)
    g.fire("QUEST_TURNED_IN", 176, 1200, 4000)
    m.player.money = 12000
    g.fire("PLAYER_MONEY")
    t(g, 4, 18, 0)
    m.where.mapID, m.where.zone, m.where.sub = 1436, "Páramos de Poniente", "Colina del Centinela"
    g.fire("ZONE_CHANGED_NEW_AREA")
    g.fire("QUEST_TURNED_IN", 184, 900, 0)
    t(g, 4, 18, 20)
    g.fire("PLAYER_DEAD")
    g.run('ns.Journal.AddManual("Me mató un murloc. Otra vez.")')
    t(g, 5, 21, 0)
    m.player.level = 18
    g.fire("PLAYER_LEVEL_UP", 18)
    m.group["party2"] = "Beto"
    m.group["party3"] = "Caro"
    m.where.mapID, m.where.zone, m.where.sub, m.where.x = 291, "Las Minas de la Muerte", "", None
    m.maps[291] = "Las Minas de la Muerte"
    g.fire("ZONE_CHANGED_NEW_AREA")
    t(g, 5, 22, 10)
    g.fire("ENCOUNTER_END", 2969, "Edwin VanCleef", 1, 5, 1)
    g.fire("CHAT_MSG_LOOT", "Recibes botín: " + RARE, "Josecito")
    t(g, 5, 22, 12)
    g.fire("SCREENSHOT_SUCCEEDED")
    g.run("ns.Album.SetCaption(2, 'VanCleef caído, primer intento')")
    t(g, 5, 23, 0)
    g.fire("TIME_PLAYED_MSG", 6 * 3600 + 1800, 1200)

    # notebook and reminders
    g.run(
        """
        local N = ns.Notes
        local s = N.AddSection("Onyxia")
        local a = N.Create({ title = "Pasos del amuleto", section = s.id,
          body = "1. Misión en Ventormenta\\n2. Hablar con Marshal Windsor\\n3. |cffffff00|Hquest:4182|h[Dragonkin Menace]|h|r" })
        N.Update(a.id, { pinned = true })
        local b = N.Create({ title = "Recetas a comprar", body = "En Forjaz, el vendedor de la zona de los enanos.\\nNecesito " .. MOCK.epic })
        N.Attach(b.id, "zone", 1455, "Forjaz")
        local c = N.Create({ title = "Hogger", body = "Al sur, cerca del río. Ir con grupo.", char = ns.CharKey() })
        N.Attach(c.id, "npcname", "hogger", "Hogger")
        N.AddImage(a.id, "amuleto_ruta.png")
        ns.Reminders.Create({ text = "Vender el paño", kind = "zone", value = "Forjaz" })
        ns.Reminders.Create({ text = "Raid de Onyxia", kind = "time", value = { wday = 3, hour = 20, min = 30 }, repeating = true })
        ns.Reminders.Create({ text = "La montura", kind = "level", value = 40, char = ns.CharKey() })
        """.replace("MOCK.epic", '"' + EPIC.replace("|", "|") + '"')
    )

    # a second character on the same account
    m.player.name, m.player.level, m.player.money = "Anabel", 1, 0
    m.group = g.lua.table()
    m.where.mapID, m.where.zone, m.where.sub, m.where.x, m.where.y = 1429, "Bosque de Elwynn", "Abadía de Northshire", 0.48, 0.42
    m.player["class"] = "PRIEST"
    g.ns.charKey = None
    t(g, 6, 19, 0)
    g.fire("PLAYER_LOGIN")
    m.player.level = 6
    g.fire("PLAYER_LEVEL_UP", 6)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(m.savedVariables("BitacoraDB"), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
