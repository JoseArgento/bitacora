#!/usr/bin/env python3
"""Builds dist/bitacora.html: the page with core.js and the example SavedVariables inlined (one file, works offline)."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


PAGES = {"page.html": "bitacora.html", "tavern.html": "taberna.html"}


def main() -> None:
    def script(name: str) -> str:
        return (ROOT / "web" / name).read_text(encoding="utf-8").replace("</script", "<\\/script")

    demo = (ROOT / "tests" / "fixtures" / "BitacoraDB.lua").read_text(encoding="utf-8")
    for src, dst in PAGES.items():
        path = ROOT / "web" / src
        if not path.exists():
            continue
        page = path.read_text(encoding="utf-8")
        page = page.replace("/*__CORE__*/", script("core.js"))
        page = page.replace("/*__APP__*/", script("app.js"))
        page = page.replace("/*__DEMO__*/", "var BITACORA_DEMO = " + json.dumps(demo, ensure_ascii=False).replace("</", "<\\/") + ";")
        out = ROOT / "dist" / dst
        out.parent.mkdir(exist_ok=True)
        out.write_text(page, encoding="utf-8")
        print(f"wrote {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
