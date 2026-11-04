#!/usr/bin/env python3
"""Builds dist/bitacora.html: the page with core.js and the example SavedVariables inlined (one file, works offline)."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    page = (ROOT / "web" / "page.html").read_text(encoding="utf-8")
    core = (ROOT / "web" / "core.js").read_text(encoding="utf-8").replace("</script", "<\\/script")
    demo = (ROOT / "tests" / "fixtures" / "BitacoraDB.lua").read_text(encoding="utf-8")
    page = page.replace("/*__CORE__*/", core)
    page = page.replace("/*__DEMO__*/", "var BITACORA_DEMO = " + json.dumps(demo, ensure_ascii=False).replace("</", "<\\/") + ";")
    out = ROOT / "dist" / "bitacora.html"
    out.parent.mkdir(exist_ok=True)
    out.write_text(page, encoding="utf-8")
    print(f"wrote {out} ({out.stat().st_size // 1024} KB)")


if __name__ == "__main__":
    main()
