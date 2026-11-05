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
        "en": "Bitácora journal: writes itself as you play (levels, zones, bosses, deaths, loot, gold), with your progress (time per level, companions) and the guild chronicle.",
        "es": "Diario de Bitácora: se escribe solo mientras jugás (niveles, zonas, jefes, muertes, botín, oro), con tu progreso (tiempo por nivel, compañeros) y la crónica de la guild.",
        "slash": ["/diario"],
        "logic": ["Journal.lua", "Progress.lua", "Companions.lua", "Chronicle.lua"],
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
        "en": "Bitácora reminders: by zone, level, login, mailbox, bank, vendor, auction house, day and time or before the weekly reset, plus your officers' guild reminders.",
        "es": "Recordatorios de Bitácora: por zona, nivel, al entrar, correo, banco, vendedor, subasta, día y hora o antes del reinicio semanal, y los recordatorios de guild de tus oficiales.",
        "slash": ["/recordatorios", "/recordar"],
        "logic": ["Reminders.lua", "GuildReminders.lua"],
        "ui": ["UI/RemindersTab.lua"],
        "icon": "Interface\\Icons\\INV_Misc_PocketWatch_01",
        "single": True,  # one page: the form above the list
    },
    # A truly standalone addon: its own saved data and textures, no Bitacora_Datos. Packaged in its own zip
    # (.pkgmeta-recordame) for its own CurseForge page.
    "Recordame": {
        "title": "Recordame",
        "en": "Reminders that pop up when it matters: by zone, level, login, mailbox, bank, vendor, auction house, day and time or before the weekly reset, plus your officers' guild reminders.",
        "es": "Recordatorios que saltan cuando importa: por zona, nivel, al entrar, correo, banco, vendedor, subasta, día y hora o antes del reinicio semanal, y los recordatorios de guild de tus oficiales.",
        "slash": ["/recordame"],
        "logic": ["Reminders.lua", "GuildReminders.lua"],
        "ui": ["UI/RemindersTab.lua"],
        "icon": "Interface\\Icons\\INV_Misc_PocketWatch_01",
        "standalone": True,
        "single": True,
        # "curse": 123456,  # Recordame's own CurseForge project, once it exists (then run this script)
    },
}


def lua_string(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def edition_lua(name: str, e: dict) -> str:
    slash = ", ".join(lua_string(x) for x in e["slash"])
    extra = ""
    if e.get("single"):
        extra += "\tsingle = true,\n"
    if e.get("standalone"):
        extra += f"\tstandalone = true,\n\tdb = {lua_string(name + 'DB')},\n\tmedia = {lua_string(name)},\n"
    return (
        "local _, ns = ...\n\n"
        "-- Written by tools/build_editions.py: which part of Bitácora this addon is.\n"
        f"ns.edition = {{\n\ttitle = {lua_string(e['title'])},\n\tslash = {{ {slash} }},\n{extra}}}\n"
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
        *([f"## SavedVariables: {name}DB"] if e.get("standalone") else ["## Dependencies: Bitacora_Datos"]),
        f"## IconTexture: {e['icon']}",
        *([f"## X-Curse-Project-ID: {e['curse']}"] if e.get("curse") else []),  # set "curse" once the project exists
        *([f"## X-Wago-ID: {e['wago']}"] if e.get("wago") else []),
        f"## AddonCompartmentFunc: {name}_OnAddonCompartmentClick",
        f"## AddonCompartmentFuncOnEnter: {name}_OnAddonCompartmentEnter",
        f"## AddonCompartmentFuncOnLeave: {name}_OnAddonCompartmentLeave",
        "## Category: Roleplay",
        "",
        *(["Libs\\Pergamino\\Pergamino.lua"] if e.get("standalone") else []),
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
        (dest / "Edition.lua").write_text(edition_lua(name, e), encoding="utf-8")
        if e.get("standalone"):  # its own copy of the cover texture and of the Pergamino look
            shutil.copytree(ROOT / "Bitacora_Datos" / "Media", dest / "Media")
            shutil.copytree(ROOT / "Bitacora_Datos" / "Libs", dest / "Libs")
        (dest / f"{name}.toc").write_text(toc(name, e, files), encoding="utf-8")
        (dest / "Bindings.xml").write_text(bindings(name), encoding="utf-8")
        written.append(dest)
    return written


if __name__ == "__main__":
    for d in build():
        print(f"wrote {d.relative_to(ROOT)}/")
