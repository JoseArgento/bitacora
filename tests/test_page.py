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
            pg.set_default_timeout(90_000)  # a busy machine can be slow; a real failure still shows
            pg.goto(page_file.as_uri())
            pg.wait_for_selector("#particulars li")
            bad = []
            for who in ["Anabel", "Josecito"]:
                pg.click(f'#crew button:has-text("{who}")')
                for view in ["diario", "personajes", "guild", "album", "libreta", "imagenes"]:
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
            pg.set_default_timeout(90_000)  # a busy machine can be slow; a real failure still shows
            pg.goto(page_file.as_uri())
            pg.wait_for_selector("#particulars li")
            for view in ["diario", "personajes", "guild", "album", "libreta", "imagenes"]:
                pg.click(f".tabs a[data-view={view}]")
                pg.wait_for_timeout(50)
                width = pg.evaluate("document.documentElement.scrollWidth")
                if width > 375:
                    wide.append((page_file.name, view, width))
            pg.close()
        browser.close()
        assert not wide, wide


def test_a_postcard_of_a_day(pages):
    with sync_api.sync_playwright() as p:
        browser = p.chromium.launch()
        for page_file in pages:
            pg = browser.new_page(accept_downloads=True)
            errors: list[str] = []
            pg.on("pageerror", lambda e, errors=errors: errors.append(str(e)))
            pg.set_default_timeout(90_000)  # a busy machine can be slow; a real failure still shows
            pg.goto(page_file.as_uri())
            pg.wait_for_selector(".postcard-btn")
            with pg.expect_download() as dl:
                pg.click(".postcard-btn >> nth=0")
            assert dl.value.suggested_filename.startswith("postal-") and dl.value.suggested_filename.endswith(".png")
            pg.wait_for_selector("figure.postcard img")
            size = pg.evaluate(
                "(() => { const i = document.querySelector('figure.postcard img'); return [i.naturalWidth, i.naturalHeight]; })()"
            )
            assert size == [1200, 630]
            with pg.expect_download() as md:
                pg.click("text=Bajar .md")
            assert md.value.suggested_filename.endswith(".md")
            assert not errors, errors
            pg.close()
        browser.close()


def test_time_per_level_and_companions_show_up(pages):
    with sync_api.sync_playwright() as p:
        browser = p.chromium.launch()
        for page_file in pages:
            for width in (1200, 375):
                pg = browser.new_page(viewport={"width": width, "height": 800})
                pg.set_default_timeout(90_000)
                pg.goto(page_file.as_uri())
                pg.wait_for_selector("#particulars li")
                pg.click('#crew button:has-text("Anabel")')
                pg.click(".tabs a[data-view=diario]")
                splits = pg.inner_text(".splits")
                assert "Nivel 5" in splits and "40 min" in splits, splits
                pg.click('#crew button:has-text("Josecito")')
                splits = pg.inner_text(".splits")
                assert "mejor: Anabel" in splits, splits  # Anabel did level 1 faster
                people = pg.inner_text(".companions")
                assert "Beto" in people and "Caro" in people and "Ana" in people, people
                assert pg.evaluate("document.documentElement.scrollWidth") <= width
                pg.close()
        browser.close()


def test_characters_side_by_side_and_the_guild_week(pages):
    with sync_api.sync_playwright() as p:
        browser = p.chromium.launch()
        for page_file in pages:
            for width in (1200, 375):
                pg = browser.new_page(viewport={"width": width, "height": 800}, accept_downloads=True)
                errors: list[str] = []
                pg.on("pageerror", lambda e, errors=errors: errors.append(str(e)))
                pg.set_default_timeout(90_000)
                pg.goto(page_file.as_uri())
                pg.wait_for_selector("#particulars li")
                pg.click('#crew button:has-text("Josecito")')
                # the Legacy points of the demo character show in the header and the journal
                assert "3 puntos del Legado" in pg.inner_text("#particulars")
                pg.click(".tabs a[data-view=diario]")
                pg.wait_for_timeout(50)
                journal = pg.inner_text("#view")
                assert "Desafío del Legado" in journal and "campamento" in journal and "plano de Anvil" in journal, journal
                # every character in one table; a name there picks the character
                pg.click(".tabs a[data-view=personajes]")
                pg.wait_for_selector(".compare")
                table = pg.inner_text(".compare")
                assert "Josecito" in table and "Anabel" in table and "6 h 30 min" in table, table
                pg.click('.compare button:has-text("Anabel")')
                pg.wait_for_timeout(50)
                assert "Anabel" in pg.inner_text('#crew button[aria-pressed="true"]') and pg.evaluate("location.hash") == "#diario"
                # the guild's chronicle, and its week as a 1200x630 card
                pg.click(".tabs a[data-view=guild]")
                pg.wait_for_selector(".guild")
                guild = pg.inner_text("#view")
                assert "Los Del Fondo" in guild and "Caro mató por primera vez a Edwin VanCleef" in guild, guild
                with pg.expect_download() as dl:
                    pg.click('button:has-text("Postal de la semana")')
                assert dl.value.suggested_filename.startswith("guild-") and dl.value.suggested_filename.endswith(".png")
                pg.wait_for_selector("figure.postcard img")
                size = pg.evaluate(
                    "(() => { const i = document.querySelector('figure.postcard img'); return [i.naturalWidth, i.naturalHeight]; })()"
                )
                assert size == [1200, 630]
                # a week back there is less; forward is capped at the newest entry
                pg.click('button:has-text("Semana anterior")')
                pg.wait_for_timeout(50)
                assert "Ana empezó una aventura nueva" in pg.inner_text("#view") or "Nada en esos siete días" in pg.inner_text("#view")
                assert pg.evaluate("document.documentElement.scrollWidth") <= width
                assert not errors, errors
                pg.close()
        browser.close()
