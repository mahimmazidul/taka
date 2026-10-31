"""Renders the Taka launcher icon.

One 1024 px master, then every Android density from it, so the mark is the same
shape everywhere. Run: python3 tool/make_icon.py
"""

from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
FONT = os.path.join(ROOT, "assets", "fonts", "HindSiliguri-Bold.ttf")

MASTER = 1024

# A calm, muted green: sage at the top, deeper eucalyptus at the bottom.
TOP = (150, 214, 188)
BOTTOM = (58, 132, 106)


def gradient(size: int) -> Image.Image:
    """Vertical gradient with a soft diagonal light so it is not a flat block."""
    img = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        # ease so the darker half arrives late — keeps it airy
        e = t * t * (3 - 2 * t)
        r = round(TOP[0] + (BOTTOM[0] - TOP[0]) * e)
        g = round(TOP[1] + (BOTTOM[1] - TOP[1]) * e)
        b = round(TOP[2] + (BOTTOM[2] - TOP[2]) * e)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

    # radial highlight, top-left
    glow = Image.new("L", (size, size), 0)
    gd = ImageDraw.Draw(glow)
    radius = int(size * 0.85)
    cx, cy = int(size * 0.24), int(size * 0.16)
    for i in range(radius, 0, -2):
        alpha = int(46 * (1 - i / radius) ** 1.6)
        gd.ellipse([cx - i, cy - i, cx + i, cy + i], fill=alpha)
    glow = glow.filter(ImageFilter.GaussianBlur(size * 0.06))
    light = Image.new("RGB", (size, size), (255, 255, 255))
    return Image.composite(light, img, glow.point(lambda v: v)).convert("RGB")


def glyph(size: int) -> Image.Image:
    """The taka sign, white, optically centred."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    font = ImageFont.truetype(FONT, int(size * 0.60))
    text = "৳"
    box = draw.textbbox((0, 0), text, font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    x = (size - w) / 2 - box[0]
    # optical centre: a touch above true centre reads as centred
    y = (size - h) / 2 - box[1] - size * 0.015
    draw.text((x, y), text, font=font, fill=(255, 255, 255, 255))
    return layer


def ring(size: int) -> Image.Image:
    """A single hairline arc: depth without decoration."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    inset = int(size * 0.13)
    draw.arc(
        [inset, inset, size - inset, size - inset],
        start=200,
        end=340,
        fill=(255, 255, 255, 34),
        width=max(2, int(size * 0.012)),
    )
    return layer


def rounded_mask(size: int, radius_ratio: float) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size - 1, size - 1],
        radius=int(size * radius_ratio),
        fill=255,
    )
    return mask


def squircle(size: int) -> Image.Image:
    """Legacy launcher icon: gradient + glyph, rounded like a modern app icon."""
    base = gradient(size).convert("RGBA")
    base.alpha_composite(glyph(size))
    base.alpha_composite(ring(size))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(base, (0, 0), rounded_mask(size, 0.235))
    return out


def round_icon(size: int) -> Image.Image:
    base = gradient(size).convert("RGBA")
    base.alpha_composite(glyph(size))
    base.alpha_composite(ring(size))
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    out.paste(base, (0, 0), mask)
    return out


def adaptive_foreground(size: int) -> Image.Image:
    """Adaptive icon foreground: the glyph inside the 66% safe zone."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    inner = int(size * 0.56)
    mark = glyph(inner)
    off = (size - inner) // 2
    layer.alpha_composite(mark, (off, off))
    return layer


def main() -> None:
    master = squircle(MASTER)
    master.save(os.path.join(ROOT, "docs", "icon.png"))
    master.save(os.path.join(ROOT, "docs", "icon-512.png"))

    # Legacy launcher bitmaps
    for density, px in {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }.items():
        folder = os.path.join(RES, f"mipmap-{density}")
        os.makedirs(folder, exist_ok=True)
        squircle(px).save(os.path.join(folder, "ic_launcher.png"))
        round_icon(px).save(os.path.join(folder, "ic_launcher_round.png"))
        # Adaptive foregrounds are 108dp: 108/48 of the legacy size
        adaptive_foreground(round(px * 108 / 48)).save(
            os.path.join(folder, "ic_launcher_foreground.png")
        )

    # Adaptive icon description + its background colour
    anydpi = os.path.join(RES, "mipmap-anydpi-v26")
    os.makedirs(anydpi, exist_ok=True)
    adaptive = """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
"""
    for name in ("ic_launcher.xml", "ic_launcher_round.xml"):
        with open(os.path.join(anydpi, name), "w", encoding="utf-8") as handle:
            handle.write(adaptive)

    values = os.path.join(RES, "values")
    os.makedirs(values, exist_ok=True)
    with open(os.path.join(values, "colors.xml"), "w", encoding="utf-8") as handle:
        handle.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            "<resources>\n"
            '    <color name="ic_launcher_background">#5FA98D</color>\n'
            "</resources>\n"
        )

    print("wrote docs/icon.png and all mipmap densities")


if __name__ == "__main__":
    main()
