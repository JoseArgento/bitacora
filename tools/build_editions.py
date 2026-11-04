#!/usr/bin/env python3
"""Writes the standalone parts of Bitácora (Bitacora_Libreta, Bitacora_Diario, Bitacora_Album,
Bitacora_Recordatorios) from the full addon's source in Bitacora/.

Each part is its own addon folder: the shared core, only its own module, its own Edition.lua, TOC and
Bindings.xml. All of them depend on Bitacora_Datos, which holds the saved data, so any mix of parts (or the
full Bitácora plus parts) shares one BitacoraDB. Run it after changing Bitacora/; a test fails when the
generated folders are out of date.

  python tools/build_editions.py
"""

from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "Bitacora"

CORE_BEFORE = ["Locales.lua", "Core.lua"]
CORE_AFTER = ["Events.lua", "UI/Widgets.lua", "UI/Main.lua"]
CORE_END = ["UI/Options.lua", "UI/Skin.lua"]

EDITIONS = {
    "Bitacora_Libreta": {
        "title": "Bitácora · Libreta",
        "en": "Bitácora notebook: notes with tabs, links, images, and notes attached to NPCs, items and zones.",
        "es": "Libreta de Bitácora: notas con pestañas, links, imágenes y notas pegadas a PNJ, ítems y zonas.",
        "slash": ["/libreta"],
        "logic": ["Notes.lua"],
        "ui": ["UI/NotesTab.lua", "UI/Tooltip.lua"],
        "icon": "Interface\\Icons\\INV_Misc_Note_01",
    },
    "Bitacora_Diario": {
        "title": "Bitácora · Diario",
        "en": "Bitácora journal: writes itself as you play (levels, zones, bosses, deaths, loot, gold), with your progress and the guild chronicle.",
        "es": "Diario de Bitácora: se escribe solo mientras jugás (niveles, zonas, jefes, muertes, botín, oro), con tu progreso y la crónica de la guild.",
        "slash": ["/diario"],
        "logic": ["Journal.lua", "Progress.lua", "Chronicle.lua"],
        "ui": ["UI/JournalTab.lua", "UI/ProgressTab.lua", "UI/ChronicleTab.lua"],
        "icon": "Interface\\Icons\\INV_Misc_Book_09",
    },
    "Bitacora_Album": {
        "title": "Bitácora · Álbum",
        "en": "Bitácora album: notes when, where and with whom you took each screenshot.",
        "es": "Álbum de Bitácora: anota cuándo, dónde y con quién sacaste cada captura.",
        "slash": ["/album"],
        "logic": ["Album.lua"],
        "ui": ["UI/AlbumTab.lua"],
        "icon": "Interface\\Icons\\INV_Misc_Spyglass_03",
    },
    "Bitacora_Recordatorios": {
        "title": "Bitácora · Recordatorios",
        "en": "Bitácora reminders: by zone, level, login, mailbox, bank, vendor, auction house or day and time.",
        "es": "Recordatorios de Bitácora: por zona, nivel, al entrar, correo, banco, vendedor, subasta o día y hora.",
        "slash": ["/recordatorios", "/recordar"],
        "logic": ["Reminders.lua"],
        "ui": ["UI/RemindersTab.lua"],
        "icon": "Interface\\Icons\\INV_Misc_PocketWatch_01",
    },
}


def lua_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def edition_lua(e: dict) -> str:
    slash = ", ".join(lua_string(x) for x in e["slash"])
    return (
        "local _, ns = ...\n\n"
        "-- Written by tools/build_editions.py: which part of Bitácora this addon is.\n"
        f"ns.edition = {{\n\ttitle = {lua_string(e['title'])},\n\tslash = {{ {slash} }},\n}}\n"
    )


def toc(name: str, e: dict, files: list[str]) -> str:
    lines = [
        "## Interface: 16001",
        f"## Title: {e['title']}",
        f"## Notes: {e['en']}",
        f"## Notes-esES: {e['es']}",
        f"## Notes-esMX: {e['es']}",
        "## Author: José Argento",
        "## Version: @project-version@",
        "## Dependencies: Bitacora_Datos",
        f"## IconTexture: {e['icon']}",
        f"## AddonCompartmentFunc: {name}_OnAddonCompartmentClick",
        f"## AddonCompartmentFuncOnEnter: {name}_OnAddonCompartmentEnter",
        f"## AddonCompartmentFuncOnLeave: {name}_OnAddonCompartmentLeave",
        "## Category: Roleplay",
        "",
        *[f.replace("/", "\\") for f in files],
        "Bindings.xml",
        "",
    ]
    return "\n".join(lines)


def bindings(name: str) -> str:
    key = name.upper()
    return f'<Bindings>\n\t<Binding name="{key}_TOGGLE" header="{key}" category="ADDONS">\n\t\t{name}_Toggle()\n\t</Binding>\n</Bindings>\n'


def build(out_root: Path = ROOT) -> list[Path]:
    written = []
    for name, e in EDITIONS.items():
        dest = out_root / name
        if dest.exists():
            shutil.rmtree(dest)
        (dest / "UI").mkdir(parents=True)
        files = ["Edition.lua", *CORE_BEFORE, *e["logic"], *CORE_AFTER, *e["ui"], *CORE_END]
        for f in files[1:]:
            shutil.copyfile(SRC / f, dest / f)
        (dest / "Edition.lua").write_text(edition_lua(e), encoding="utf-8")
        (dest / f"{name}.toc").write_text(toc(name, e, files), encoding="utf-8")
        (dest / "Bindings.xml").write_text(bindings(name), encoding="utf-8")
        written.append(dest)
    return written


if __name__ == "__main__":
    for d in build():
        print(f"wrote {d.relative_to(ROOT)}/")
