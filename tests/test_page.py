"""The built page in a real browser (skipped without Playwright): every view, both languages, both demo
characters, no stray "null"/"undefined" and no script errors."""

import subprocess
import sys
from pathlib import Path

import pytest

sync_api = pytest.importorskip("playwright.sync_api")

ROOT = Path(__file__).resolve().parents[1]


@pytest.fixture(scope="module")
def pages():
    subprocess.run([sys.executable, str(ROOT / "tools" / "build_web.py")], check=True, capture_output=True)
    return sorted((ROOT / "dist").glob("*.html"))


def test_no_stray_null_in_any_view(pages):
    with sync_api.sync_playwright() as p:
        browser = p.chromium.launch()
        for page_file in pages:
            pg = browser.new_page()
            errors: list[str] = []
            pg.on("pageerror", lambda e, errors=errors: errors.append(str(e)))
            pg.goto(page_file.as_uri())
            pg.wait_for_selector("#particulars li")
            bad = []
            for who in ["Anabel", "Josecito"]:
                pg.click(f'#crew button:has-text("{who}")')
                for view in ["diario", "album", "libreta", "imagenes"]:
                    pg.click(f".tabs a[data-view={view}]")
                    pg.wait_for_timeout(50)
                    for lang in ["es", "en"]:
                        pg.click(f"button[data-lang={lang}]")
                        text = pg.inner_text("body")
                        bad += [(page_file.name, who, view, lang, w) for w in ("null", "undefined", "NaN", "[object") if w in text]
            assert not bad and not errors, (bad, errors)
            pg.close()
        browser.close()


def test_no_sideways_scroll_on_a_phone(pages):
    with sync_api.sync_playwright() as p:
        browser = p.chromium.launch()
        wide = []
        for page_file in pages:
            pg = browser.new_page(viewport={"width": 375, "height": 740})
            pg.goto(page_file.as_uri())
            pg.wait_for_selector("#particulars li")
            for view in ["diario", "album", "libreta", "imagenes"]:
                pg.click(f".tabs a[data-view={view}]")
                pg.wait_for_timeout(50)
                width = pg.evaluate("document.documentElement.scrollWidth")
                if width > 375:
                    wide.append((page_file.name, view, width))
            pg.close()
        browser.close()
        assert not wide, wide
