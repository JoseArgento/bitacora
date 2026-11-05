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
    # the client's own Spanish loot lines (GlobalStrings esMX)
    gl = g.lua.globals()
    gl.LOOT_ITEM_SELF, gl.LOOT_ITEM_SELF_MULTIPLE = "Recibes botín: %s", "Recibes botín: %sx%d"
    gl.LOOT_ITEM_PUSHED_SELF, gl.LOOT_ITEM_PUSHED_SELF_MULTIPLE = "Recibes: %s", "Recibes: %sx%d"
    t(g, 4, 15, 10)
    g.login()
    g.m.runTimers()
    g.db.settings.lootQuality = 3
    g.run('ns.Journal.AddManual("Primer día de Forever. Fila de 40 minutos, valió la pena.")')
    for lvl, minute in ((2, 25), (3, 33), (4, 44), (5, 58)):
        t(g, 4, 15, minute)
        m.player.level = lvl
        g.fire("PLAYER_LEVEL_UP", lvl)
    m.where.sub = "Villadorada"
    t(g, 4, 16, 5)
    m.group["party1"] = "Ana"
    m.groupClass["party1"] = "WARRIOR"
    g.fire("GROUP_ROSTER_UPDATE")
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
    g.arrive()  # the zone is read a moment after arriving
    g.fire("QUEST_TURNED_IN", 184, 900, 0)
    t(g, 4, 18, 20)
    g.fire("PLAYER_DEAD")
    g.run('ns.Journal.AddManual("Me mató un murloc. Otra vez.")')
    t(g, 5, 21, 0)
    m.player.level = 18
    g.fire("PLAYER_LEVEL_UP", 18)
    m.group["party2"] = "Beto"
    m.group["party3"] = "Caro"
    m.groupClass["party2"], m.groupClass["party3"] = "PRIEST", "ROGUE"
    m.where.mapID, m.where.zone, m.where.sub, m.where.x = 291, "Las Minas de la Muerte", "", None
    m.maps[291] = "Las Minas de la Muerte"
    g.arrive()  # the zone is read a moment after arriving
    g.fire("GROUP_ROSTER_UPDATE")
    t(g, 5, 22, 10)
    g.fire("ENCOUNTER_END", 2969, "Edwin VanCleef", 1, 5, 1)
    g.fire("CHAT_MSG_LOOT", "Recibes botín: " + RARE, "Josecito")
    t(g, 5, 22, 12)
    g.fire("SCREENSHOT_SUCCEEDED")
    g.run("ns.Album.SetCaption(2, 'VanCleef caído, primer intento')")
    t(g, 5, 23, 0)
    g.fire("TIME_PLAYED_MSG", 6 * 3600 + 1800, 1200)
    # Forever's own things: a Legacy challenge (an achievement that pays points), the first campsite, a blueprint
    gl.GetAchievementInfo = g.lua.eval(
        'function(id) return id, ({ [7001] = "Explorador de Elwynn", [7002] = "Diez misiones" })[id] or "Logro" end'
    )
    m.legacy[7001] = 3
    t(g, 5, 23, 5)
    g.fire("ACHIEVEMENT_EARNED", 7001)
    m.spells[91100] = "Fogata básica"
    t(g, 5, 23, 12)
    g.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast-1", 91100)
    m.recipes[500] = 279988
    t(g, 5, 23, 20)
    g.fire("NEW_RECIPE_LEARNED", 500, 1, 500)
    # the guild chronicle: what guildmates with Bitácora shared this week
    g.db.settings.chronicle = True
    m.itemNamesByID = g.lua.table_from({17078: "Sapphiron Drape"})
    for day, hour, sender, msg in (
        (3, 21, "Ana-Forever", "M|1|start|0"),
        (4, 20, "Beto-Forever", "M|1|level|10"),
        (4, 22, "Ana-Forever", "M|1|level|20"),
        (5, 21, "Caro-Forever", "M|1|boss|2969|Edwin VanCleef"),
        (5, 22, "Beto-Forever", "M|1|achievement|7002"),
        (6, 19, "Ana-Forever", "M|1|loot|17078"),
    ):
        t(g, day, hour, 15)
        g.fire("CHAT_MSG_ADDON", "BitacoraCron1", msg, "GUILD", sender, "", 0, 0, "", 0)
    t(g, 5, 23, 30)

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
    g.m.runTimers()
    # levels 2 to 6 over the evening: 12, 20, 25, 30 and 40 minutes each (the splits of the Progress tab)
    minute = 0
    for lvl, took in ((2, 12), (3, 20), (4, 25), (5, 30), (6, 40)):
        minute += took
        t(g, 6, 19 + minute // 60, minute % 60)
        m.player.level = lvl
        g.fire("PLAYER_LEVEL_UP", lvl)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(m.savedVariables("BitacoraDB"), encoding="utf-8")
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
