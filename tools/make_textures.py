#!/usr/bin/env python3
"""Draws the tavern skin's textures: Bitacora_Datos/Media/{parchment,wood,cover}.tga.

Everything is generated here from noise and shapes (no game art). Sizes are powers of 2 and the files are
32-bit TGA, which every WoW client loads. Needs Pillow. Deterministic: the same seed gives the same files.
"""

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Bitacora_Datos" / "Media"


def noise(size: int, scale: int, seed: int) -> Image.Image:
    rnd = random.Random(seed)
    small = Image.new("L", (max(2, size // scale), max(2, size // scale)))
    small.putdata([rnd.randint(0, 255) for _ in range(small.width * small.height)])
    return small.resize((size, size), Image.BICUBIC)


def fractal(size: int, seed: int) -> Image.Image:
    layers = [(noise(size, s, seed + i), w) for i, (s, w) in enumerate([(64, 0.45), (16, 0.3), (4, 0.18), (1, 0.07)])]
    out = Image.new("L", (size, size), 0)
    for layer, w in layers:
        out = ImageChops.add(out, layer.point(lambda v, w=w: int(v * w)))
    return out


def tint(gray: Image.Image, dark: tuple, light: tuple) -> Image.Image:
    r = gray.point(lambda v: int(dark[0] + (light[0] - dark[0]) * v / 255))
    g = gray.point(lambda v: int(dark[1] + (light[1] - dark[1]) * v / 255))
    b = gray.point(lambda v: int(dark[2] + (light[2] - dark[2]) * v / 255))
    return Image.merge("RGB", (r, g, b))


def vignette(size: int, strength: float) -> Image.Image:
    v = Image.new("L", (size, size))
    px = v.load()
    c = (size - 1) / 2
    for y in range(size):
        for x in range(size):
            d = math.hypot((x - c) / c, (y - c) / c) / math.sqrt(2)
            px[x, y] = int(255 * min(1.0, max(0.0, (d - 0.45) / 0.55)) ** 1.6 * strength)
    return v


def parchment() -> Image.Image:
    size = 256
    base = tint(fractal(size, 7), (214, 190, 140), (247, 234, 202))
    fibers = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(fibers)
    rnd = random.Random(11)
    for _ in range(130):
        x, y = rnd.randrange(size), rnd.randrange(size)
        length, ang = rnd.randint(6, 26), rnd.uniform(-0.4, 0.4)
        d.line((x, y, x + length * math.cos(ang), y + length * math.sin(ang)), fill=rnd.randint(30, 70), width=1)
    fibers = fibers.filter(ImageFilter.GaussianBlur(0.6))
    base = Image.composite(Image.new("RGB", (size, size), (150, 115, 70)), base, fibers)
    edge = vignette(size, 0.75)
    base = Image.composite(Image.new("RGB", (size, size), (120, 82, 40)), base, edge)
    return base.convert("RGBA")


def wood() -> Image.Image:
    w, h = 256, 256
    img = Image.new("L", (w, h))
    px = img.load()
    n = fractal(256, 23).load()
    for y in range(h):
        for x in range(w):
            v = math.sin((y + n[x, y] * 0.09) * 0.55) * 0.5 + 0.5
            v = 0.55 * v + 0.45 * (n[(x * 3) % 256, y] / 255)
            px[x, y] = int(255 * v)
    img = img.filter(ImageFilter.GaussianBlur(0.7))
    return tint(img, (48, 28, 14), (120, 76, 42)).convert("RGBA")


def cover() -> Image.Image:
    size = 512
    leather = tint(fractal(size, 41), (58, 26, 18), (118, 52, 34))
    leather = Image.composite(Image.new("RGB", (size, size), (30, 12, 8)), leather, vignette(size, 0.9))
    d = ImageDraw.Draw(leather)
    gold, gold_dark = (222, 176, 76), (140, 100, 30)
    for inset, width in [(22, 6), (40, 2)]:
        d.rectangle((inset, inset, size - 1 - inset, size - 1 - inset), outline=gold_dark, width=width + 2)
        d.rectangle((inset, inset, size - 1 - inset, size - 1 - inset), outline=gold, width=width)
    # corner ornaments: a diamond with a ring
    for cx, cy in [(40, 40), (size - 41, 40), (40, size - 41), (size - 41, size - 41)]:
        d.polygon([(cx, cy - 20), (cx + 20, cy), (cx, cy + 20), (cx - 20, cy)], fill=gold, outline=gold_dark)
        d.ellipse((cx - 7, cy - 7, cx + 7, cy + 7), fill=(90, 30, 22), outline=gold_dark, width=2)
    # center: a compass rose (a logbook's mark)
    c = size / 2
    for r, col in [(92, gold_dark), (88, gold), (80, (80, 34, 22))]:
        d.ellipse((c - r, c - r, c + r, c + r), fill=col)
    for k in range(8):
        a = k * math.pi / 4
        long_ = 74 if k % 2 == 0 else 46
        tip = (c + long_ * math.sin(a), c - long_ * math.cos(a))
        left = (c + 12 * math.sin(a - math.pi / 2), c - 12 * math.cos(a - math.pi / 2))
        right = (c + 12 * math.sin(a + math.pi / 2), c - 12 * math.cos(a + math.pi / 2))
        d.polygon([tip, left, (c, c), right], fill=gold if k % 2 == 0 else (196, 150, 60), outline=gold_dark)
    d.ellipse((c - 10, c - 10, c + 10, c + 10), fill=gold, outline=gold_dark, width=2)
    # a strap with a clasp on the right edge
    d.rectangle((size - 70, c - 26, size, c + 26), fill=(70, 30, 18), outline=(30, 12, 8), width=2)
    d.rounded_rectangle((size - 92, c - 20, size - 52, c + 20), radius=6, fill=gold, outline=gold_dark, width=3)
    return leather.filter(ImageFilter.SMOOTH).convert("RGBA")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, make in [("parchment", parchment), ("wood", wood), ("cover", cover)]:
        img = make()
        assert img.width == img.height and img.width & (img.width - 1) == 0, name
        path = OUT / f"{name}.tga"
        img.save(path, compression=None)
        print(f"wrote {path} ({img.width}x{img.height})")


if __name__ == "__main__":
    main()
