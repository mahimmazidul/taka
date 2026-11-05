#!/usr/bin/env python3
"""Draw the GitHub social preview (1280 x 640).

GitHub shows this card whenever the repository is linked anywhere — a chat, a
tweet, a search result — so it is the first thing most people see. It is built
from the same colours as the app and the same real screenshots the README uses,
so it cannot drift into a lie about what the app looks like.

Run from the repository root:

    python3 tool/make_social_preview.py

Output: docs/social-preview.png
"""

from __future__ import annotations

import pathlib

from PIL import Image, ImageDraw, ImageFilter, ImageFont

WIDTH, HEIGHT = 1280, 640

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "docs" / "screenshots"
FONTS = ROOT / "assets" / "fonts"
OUT = ROOT / "docs" / "social-preview.png"

# App palette, straight out of lib/core/app_theme.dart.
TAKA = (0x0E, 0x9F, 0x6E)
TAKA_DEEP = (0x0A, 0x6E, 0x58)
DEEPEST = (0x08, 0x4A, 0x3D)
CREAM = (0xF6, 0xF7, 0xF5)
WHITE = (0xFF, 0xFF, 0xFF)


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONTS / name), size)


def vertical_gradient(top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """A two-stop gradient, drawn one line at a time — cheap and exact."""
    base = Image.new("RGB", (1, HEIGHT), top)
    pixels = base.load()
    for y in range(HEIGHT):
        t = y / (HEIGHT - 1)
        pixels[0, y] = tuple(
            round(top[i] + (bottom[i] - top[i]) * t) for i in range(3)
        )
    return base.resize((WIDTH, HEIGHT))


def glow(canvas: Image.Image) -> None:
    """One soft light behind the words, so the card has a centre of gravity."""
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    draw.ellipse((60, -260, 820, 520), fill=(20, 195, 145, 90))
    layer = layer.filter(ImageFilter.GaussianBlur(140))
    canvas.alpha_composite(layer)


def phone(path: pathlib.Path, height: int, radius: int) -> Image.Image:
    """A screenshot in a rounded frame with a soft shadow, the way a phone looks."""
    shot = Image.open(path).convert("RGBA")
    width = round(shot.width * height / shot.height)
    shot = shot.resize((width, height), Image.LANCZOS)

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, width, height), radius, fill=255)
    shot.putalpha(mask)

    pad = 46
    shadow = Image.new("RGBA", (width + pad * 2, height + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        (pad, pad + 16, pad + width, pad + height + 16),
        radius,
        fill=(4, 40, 32, 120),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(22))
    shadow.alpha_composite(shot, (pad, pad))
    return shadow


def main() -> None:
    canvas = vertical_gradient(TAKA_DEEP, DEEPEST).convert("RGBA")
    glow(canvas)

    # ── phones on the right, inside the frame ────────────────────────────────
    # Both fit entirely: a card cropped mid-screen looks like a mistake, not a
    # design. The extra 46 px each side is the shadow's padding.
    back = phone(SHOTS / "savings.png", height=420, radius=26)
    front = phone(SHOTS / "home_light.png", height=486, radius=28)
    canvas.alpha_composite(back, (924, 120))
    canvas.alpha_composite(front, (694, 40))

    draw = ImageDraw.Draw(canvas)

    # ── the mark ────────────────────────────────────────────────────────────
    draw.text((72, 96), "টাকা", font=font("HindSiliguri-Bold.ttf", 128), fill=WHITE)
    draw.text(
        (78, 250),
        "Taka",
        font=font("HindSiliguri-SemiBold.ttf", 46),
        fill=(255, 255, 255, 235),
    )

    # ── what it is ──────────────────────────────────────────────────────────
    body = font("HindSiliguri-Regular.ttf", 26)
    lines = [
        "A daily khata for hall life — what you ate, what",
        "you spent, who owes you, and how much of the",
        "month is left.",
    ]
    y = 330
    for line in lines:
        draw.text((78, y), line, font=body, fill=(255, 255, 255, 225))
        y += 40

    # ── the quiet footer ────────────────────────────────────────────────────
    draw.text(
        (78, 486),
        "Offline  ·  Android  ·  ৳ BDT",
        font=font("HindSiliguri-Medium.ttf", 21),
        fill=(255, 255, 255, 165),
    )
    draw.text(
        (78, 526),
        "Built by Mazidul Islam Mahim",
        font=font("HindSiliguri-SemiBold.ttf", 25),
        fill=(255, 255, 255, 235),
    )
    draw.text(
        (78, 574),
        "github.com/mahimmazidul/taka",
        font=font("HindSiliguri-Regular.ttf", 19),
        fill=(255, 255, 255, 150),
    )

    OUT.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT, "PNG", optimize=True)
    print(f"wrote {OUT.relative_to(ROOT)} ({WIDTH}x{HEIGHT})")


if __name__ == "__main__":
    main()
