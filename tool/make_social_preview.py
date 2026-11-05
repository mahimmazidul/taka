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


def phone(path: pathlib.Path, height: int, radius: int = 34) -> Image.Image:
    """A screenshot inside a phone body: bezel, island, side buttons, shadow.

    A bare rounded screenshot on a green field reads as a picture of a screen; the
    bezel and the island are what make it read as the handset the app runs on.
    """
    shot = Image.open(path).convert("RGBA")
    bezel = max(7, round(height * 0.022))
    width = round(shot.width * height / shot.height)
    shot = shot.resize((width, height), Image.LANCZOS)

    body_w, body_h = width + bezel * 2, height + bezel * 2
    body = Image.new("RGBA", (body_w, body_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(body)

    # The handset: near-black, with a faint highlight along the top edge so the
    # frame does not look like a flat sticker.
    draw.rounded_rectangle((0, 0, body_w, body_h), radius, fill=(18, 24, 22, 255))
    draw.rounded_rectangle(
        (0, 0, body_w, body_h), radius, outline=(96, 112, 105, 255), width=2
    )
    draw.rounded_rectangle(
        (3, 3, body_w - 3, body_h * 0.45),
        radius - 3,
        fill=(34, 44, 40, 255),
    )
    draw.rounded_rectangle(
        (3, body_h * 0.45, body_w - 3, body_h - 3),
        radius - 3,
        fill=(18, 24, 22, 255),
    )

    # Screen, clipped to its own rounding.
    mask = Image.new("L", shot.size, 0)
    screen_radius = max(6, radius - bezel)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, width - 1, height - 1), screen_radius, fill=255
    )
    body.paste(shot, (bezel, bezel), mask)

    # The island, and the two side buttons that make a phone a phone.
    island_w, island_h = round(width * 0.30), max(8, round(height * 0.021))
    island = Image.new("RGBA", (island_w, island_h), (0, 0, 0, 0))
    ImageDraw.Draw(island).rounded_rectangle(
        (0, 0, island_w - 1, island_h - 1), island_h // 2, fill=(10, 13, 12, 255)
    )
    body.alpha_composite(
        island, (bezel + (width - island_w) // 2, bezel + round(height * 0.012))
    )
    for i, (side, length, offset) in enumerate(
        (("left", 0.045, 0.16), ("left", 0.045, 0.26), ("right", 0.075, 0.22))
    ):
        btn_h = round(body_h * length)
        btn_w = max(3, round(body_w * 0.012))
        y = round(body_h * offset)
        x = -btn_w + 1 if side == "left" else body_w - 1
        draw.rounded_rectangle(
            (x, y, x + btn_w, y + btn_h), btn_w // 2, fill=(58, 70, 65, 255)
        )

    # Soft drop shadow under the whole handset.
    pad = 44
    out = Image.new("RGBA", (body_w + pad * 2, body_h + pad * 2), (0, 0, 0, 0))
    ImageDraw.Draw(out).rounded_rectangle(
        (pad, pad + 14, pad + body_w, pad + body_h + 14),
        radius,
        fill=(3, 30, 24, 130),
    )
    out = out.filter(ImageFilter.GaussianBlur(20))
    out.alpha_composite(body, (pad, pad))
    return out


def main() -> None:
    canvas = vertical_gradient(TAKA_DEEP, DEEPEST).convert("RGBA")
    glow(canvas)

    # ── phones on the right, inside the frame ────────────────────────────────
    # Both fit entirely: a card cropped mid-screen looks like a mistake, not a
    # design. The extra 46 px each side is the shadow's padding.
    # Two handsets, two modes: the bright card and the dark one, side by side so
    # the card shows both without a caption claiming it.
    dark = phone(SHOTS / "home_dark.png", height=430)
    light = phone(SHOTS / "home_light.png", height=486)
    canvas.alpha_composite(dark, (906, 116))
    canvas.alpha_composite(light, (676, 38))

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
