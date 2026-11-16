"""The capture helper (ayudante/Capturas.ps1): a Windows PowerShell script that does from outside the game what an
addon cannot (create the pictures folder, save the clipboard, bring the game's screenshots).

The first tests read the files and run anywhere. The rest run the script for real and only on Windows (the CI has
a windows job for them), with Windows PowerShell 5.1 and PowerShell 7 when they are installed: a made-up game
folder, pictures drawn with Pillow, and what comes out is opened with Pillow and loaded by the addon's own Lua.
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "ayudante"
SCRIPT = HELPER / "Capturas.ps1"

# reading the files (anywhere) --------------------------------------------------------------------------


def test_the_script_is_saved_the_way_windows_powershell_needs_it():
    raw = SCRIPT.read_bytes()
    # Windows PowerShell 5.1 reads a file without a BOM as ANSI: "Bitácora" would come out broken
    assert raw.startswith(b"\xef\xbb\xbf")
    text = raw.decode("utf-8-sig")
    assert "\r\n" in text and "\n" not in text.replace("\r\n", "")
    for bat in HELPER.glob("*.bat"):
        b = bat.read_bytes()
        assert b.isascii() and b"\r\n" in b and b"\n" not in b.replace(b"\r\n", b""), bat.name
        assert b'-File "%~dp0Capturas.ps1"' in b and b"-ExecutionPolicy Bypass" in b and b"-STA" in b, bat.name
    attrs = (ROOT / ".gitattributes").read_text(encoding="utf-8")
    assert "ayudante/*.ps1 -text" in attrs and "ayudante/*.bat -text" in attrs


def test_the_script_keeps_its_promises():
    text = SCRIPT.read_text(encoding="utf-8-sig")
    code = "\n".join(line for line in text.splitlines() if not line.lstrip().startswith("#"))
    # no network, no elevation, nothing run from a string
    for word in ("Invoke-WebRequest", "Invoke-RestMethod", "WebClient", "HttpClient", "Start-BitsTransfer", "Net.Sockets", "RunAs", "Invoke-Expression", "iex ", "DownloadString", "FromBase64String"):
        assert word.lower() not in code.lower(), word
    # nothing newer than Windows PowerShell 5.1 understands
    assert "??" not in code and "?." not in code and " ? " not in code
    assert "ForEach-Object -Parallel" not in code
    # it never deletes anything but its own temporary file
    removes = re.findall(r"Remove-Item[^\n]*", code)
    assert removes == ["Remove-Item -LiteralPath $temporal -Force"]


def test_no_two_script_level_names_differ_only_in_case():
    # PowerShell variable names are case-insensitive: $CARPETA and $carpeta would be one variable
    text = SCRIPT.read_text(encoding="utf-8-sig")
    top = set(re.findall(r"^\$([A-Za-z_]\w*) = ", text, flags=re.M))
    params = set(re.findall(r"^\s+\[(?:string|int|switch)\]\$(\w+)", text.split(")\n\nSet-StrictMode")[0].replace("\r", ""), flags=re.M))
    names = top | params
    lowered = [n.lower() for n in names]
    assert len(lowered) == len(set(lowered)), sorted(names)
    # and no function parameter hides one of the constants
    for const in (n for n in top if n.isupper() or "_" in n):
        assert not re.search(r"function [\w-]+\([^)]*\$" + const + r"\b", text, flags=re.I), const


def test_the_helper_stays_out_of_the_addon_zips():
    for meta in (".pkgmeta", ".pkgmeta-recordame"):
        assert "  - ayudante\n" in (ROOT / meta).read_text(encoding="utf-8"), meta


# running it (Windows) -----------------------------------------------------------------------------------

windows = pytest.mark.skipif(sys.platform != "win32", reason="the helper is a Windows script")
SHELLS = [s for s in ("powershell", "pwsh") if shutil.which(s)] if sys.platform == "win32" else ["powershell"]


def run(shell, game, action, *more, expect=0):
    cmd = [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-STA", "-File", str(SCRIPT), "-Accion", action, "-Juego", str(game), "-Silencioso", *more]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180, encoding="utf-8", errors="replace")
    assert r.returncode == expect, f"{action}: rc {r.returncode}\n{r.stdout}\n{r.stderr}"
    return r.stdout


def picture(path, size=(1920, 1080), top=(200, 30, 30), bottom=(30, 30, 200)):
    """Top half one colour, bottom half another: the orientation can be checked after the conversion."""
    from PIL import Image, ImageDraw

    im = Image.new("RGB", size, bottom)
    ImageDraw.Draw(im).rectangle([0, 0, size[0], size[1] // 2], fill=top)
    im.save(path)


@pytest.fixture
def fake_game(tmp_path):
    game = tmp_path / "World of Warcraft" / "_forever_"
    (game / "Interface" / "AddOns").mkdir(parents=True)
    shots = game / "Screenshots"
    shots.mkdir()
    now = time.time()
    for i, stamp in enumerate(("111426_101010", "111526_202020", "111626_005316")):
        f = shots / f"WoWScrnShot_{stamp}.jpg"
        picture(f)
        os.utime(f, (now - 3000 + i * 1000, now - 3000 + i * 1000))
    (shots / "notas.txt").write_text("not a screenshot", encoding="utf-8")
    return game


def folder(game):
    return game / "Interface" / "AddOns" / "BitacoraImagenes"


def free_slots(game):
    return sorted(f.name for f in folder(game).glob("captura_*.tga") if f.stat().st_size < 200)


def index(game):
    """The helper's Indice.lua, read by the addon's own code (Bitacora/Images.lua)."""
    from test_addon import Game

    g = Game()
    g.login()
    g.lua.execute((folder(game) / "Indice.lua").read_text(encoding="utf-8"))
    entries = g.run("return ns.Images.Index()")
    return [entries[i] for i in range(1, len(entries) + 1)]


@windows
@pytest.mark.parametrize("shell", SHELLS)
def test_install_creates_the_folder_the_list_and_the_slots(shell, fake_game):
    out = run(shell, fake_game, "Instalar", "-SinAtajo")
    d = folder(fake_game)
    assert "BitacoraImagenes" in out
    toc = (d / "BitacoraImagenes.toc").read_bytes()
    assert not toc.startswith(b"\xef\xbb\xbf") and b"## Interface: 16001" in toc and b"Indice.lua" in toc
    assert "Bitácora · Imágenes" in toc.decode("utf-8")
    assert len(free_slots(fake_game)) == 24 and free_slots(fake_game)[0] == "captura_001.tga"
    lua = (d / "Indice.lua").read_bytes()
    assert not lua.startswith(b"\xef\xbb\xbf") and b"BitacoraImagenesIndice = {" in lua
    assert index(fake_game) == []
    # installing again changes nothing
    run(shell, fake_game, "Instalar", "-SinAtajo")
    assert len(free_slots(fake_game)) == 24 and index(fake_game) == []


@windows
@pytest.mark.parametrize("shell", SHELLS)
def test_pictures_that_were_already_in_the_folder_become_textures(shell, fake_game):
    d = folder(fake_game)
    d.mkdir()
    picture(d / "arg.jpg", size=(3000, 2000))
    picture(d / "postal de ana.png", size=(1200, 630))
    run(shell, fake_game, "Instalar", "-SinAtajo")
    from PIL import Image

    by_file = {e.file: e for e in index(fake_game)}
    assert set(by_file) == {"arg.tga", "postal_de_ana.tga"}
    # the picture's own size is kept for its shape; "from" lets a note that says arg.jpg (or arg.png) find it
    assert (by_file["arg.tga"].w, by_file["arg.tga"]["h"], by_file["arg.tga"]["from"]) == (3000, 2000, "arg.jpg")
    assert by_file["postal_de_ana.tga"]["from"] is None  # a name with spaces is not one the addon accepts
    with Image.open(d / "arg.tga") as im:
        # 32 bits, like the textures the game already loads from these addons; opaque
        assert im.size == (1024, 512) and im.mode == "RGBA"
        r, g, b, a = im.getpixel((10, 10))
        assert r > 150 and b < 90 and a == 255  # the top is still the top
        r, g, b, a = im.getpixel((10, 500))
        assert b > 150 and r < 90 and a == 255
    assert (d / "arg.jpg").exists()  # the original is left alone


@windows
@pytest.mark.parametrize("shell", SHELLS)
def test_paste_fills_a_slot_and_bring_copies_the_screenshots(shell, fake_game, tmp_path):
    run(shell, fake_game, "Instalar", "-SinAtajo")
    d = folder(fake_game)
    src = tmp_path / "Molten Core.png"
    picture(src, size=(1920, 1080))
    run(shell, fake_game, "Pegar", "-Imagen", str(src))
    from PIL import Image

    # it went into the first slot (a file the running game already knows), and the slots were topped up
    with Image.open(d / "captura_001.tga") as im:
        assert im.size == (1024, 512)
        assert im.getpixel((500, 5))[0] > 150 and im.getpixel((500, 505))[2] > 150
    assert (d / "captura_001.tga").stat().st_size == 18 + 1024 * 512 * 4
    assert len(free_slots(fake_game)) == 24 and "captura_001.tga" not in free_slots(fake_game)
    entries = index(fake_game)
    assert [(e.file, e.title, e.w, e.h) for e in entries] == [("captura_001.tga", "Molten Core", 1920, 1080)]
    assert abs(entries[0].t - time.time()) < 600

    # the two newest game screenshots, then the one that was left, then nothing more
    out = run(shell, fake_game, "Traer", "-Cuantas", "2")
    assert out.strip().startswith("2 ")
    shots = sorted(e.shot for e in index(fake_game) if e.shot)
    assert shots == ["111526_202020", "111626_005316"]
    run(shell, fake_game, "Traer")
    assert sorted(e.shot for e in index(fake_game) if e.shot) == ["111426_101010", "111526_202020", "111626_005316"]
    assert run(shell, fake_game, "Traer").strip().startswith("0 ")
    assert len(index(fake_game)) == 4 and len(free_slots(fake_game)) == 24
    newest_shot = next(e for e in index(fake_game) if e.shot == "111626_005316")
    assert newest_shot.title.startswith("Game screenshot ") or newest_shot.title.startswith("Captura del juego ")

    # a picture deleted by hand leaves the list; with no slot free the picture gets a name of its own
    (d / "captura_001.tga").unlink()
    for name in free_slots(fake_game):
        (d / name).unlink()
    run(shell, fake_game, "Pegar", "-Imagen", str(src))
    files = [e.file for e in index(fake_game)]
    assert "captura_001.tga" not in files and any(f.startswith("imagen_") for f in files)
    assert len(free_slots(fake_game)) == 24


@windows
@pytest.mark.parametrize("shell", SHELLS)
def test_paste_with_an_empty_clipboard_brings_the_last_game_screenshot_or_says_so(shell, fake_game):
    run(shell, fake_game, "Instalar", "-SinAtajo")
    # the CI has no picture in its clipboard (when it has no clipboard at all, the script treats it as empty)
    clear = "Add-Type -AssemblyName System.Windows.Forms; try { [System.Windows.Forms.Clipboard]::Clear() } catch { }"
    subprocess.run([shell, "-NoProfile", "-STA", "-Command", clear], timeout=60)
    run(shell, fake_game, "Pegar")
    assert [e.shot for e in index(fake_game)] == ["111626_005316"]
    run(shell, fake_game, "Pegar")
    run(shell, fake_game, "Pegar")
    assert len(index(fake_game)) == 3
    out = run(shell, fake_game, "Pegar", expect=2)
    assert "Win+Shift+S" in out


@windows
@pytest.mark.parametrize("shell", SHELLS)
def test_paste_saves_the_picture_in_the_clipboard(shell, fake_game):
    put = (
        "Add-Type -AssemblyName System.Windows.Forms; Add-Type -AssemblyName System.Drawing;"
        "$b = New-Object System.Drawing.Bitmap(800, 600);"
        "$g = [System.Drawing.Graphics]::FromImage($b); $g.Clear([System.Drawing.Color]::FromArgb(30, 160, 60)); $g.Dispose();"
        "[System.Windows.Forms.Clipboard]::SetImage($b);"
        "if (-not [System.Windows.Forms.Clipboard]::ContainsImage()) { exit 3 }"
    )
    r = subprocess.run([shell, "-NoProfile", "-STA", "-Command", put], capture_output=True, text=True, timeout=60)
    if r.returncode != 0:
        pytest.skip("this session has no clipboard")
    run(shell, fake_game, "Pegar")
    from PIL import Image

    entries = index(fake_game)
    assert len(entries) == 1 and (entries[0].w, entries[0].h) == (800, 600) and entries[0].shot is None
    with Image.open(folder(fake_game) / entries[0].file) as im:
        assert im.size == (1024, 512)
        r_, g_, b_, a_ = im.getpixel((300, 300))
        assert g_ > 120 and r_ < 80 and b_ < 110 and a_ == 255


@windows
def test_a_folder_that_is_not_the_game_is_refused(tmp_path):
    (tmp_path / "vacio").mkdir()
    out = run(SHELLS[0], tmp_path / "vacio", "Instalar", "-SinAtajo", expect=1)
    assert "_forever_" in out
    assert not (tmp_path / "vacio" / "Interface").exists()
    # the World of Warcraft folder is accepted too: its _forever_ is the game
    wow = tmp_path / "World of Warcraft"
    (wow / "_forever_" / "Interface" / "AddOns").mkdir(parents=True)
    run(SHELLS[0], wow, "Instalar", "-SinAtajo")
    assert (wow / "_forever_" / "Interface" / "AddOns" / "BitacoraImagenes" / "Indice.lua").exists()


def test_the_pictures_folder_is_a_download_of_its_own_and_matches_what_the_helper_writes():
    # an updater deletes an addon's folders before installing the new ones: inside Bitácora's zip the player's
    # pictures would go with every update. So the folder is published once, by itself, and never in the zips.
    for meta in (".pkgmeta", ".pkgmeta-recordame"):
        assert "  - BitacoraImagenes\n" in (ROOT / meta).read_text(encoding="utf-8"), meta
    folder = ROOT / "BitacoraImagenes"
    toc = (folder / "BitacoraImagenes.toc").read_text(encoding="utf-8")
    assert "## Interface: 16001" in toc and toc.rstrip().endswith("Indice.lua") and "@project-version@" not in toc
    # no code in it, and nothing that looks like the helper's list (Bitácora would think the helper is installed)
    lua = (folder / "Indice.lua").read_text(encoding="utf-8")
    assert all(line.startswith("--") or not line.strip() for line in lua.splitlines())
    # the helper writes the same title, so installing it afterwards changes nothing the game notices
    script = SCRIPT.read_text(encoding="utf-8-sig")
    assert "'## Title: Bitácora · Imágenes'," in script and "## Title: Bitácora · Imágenes" in toc
