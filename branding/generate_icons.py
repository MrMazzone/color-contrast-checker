#!/usr/bin/env python3
"""Generates every platform icon from branding/icon-source.png.

The source is a 1254x1254 RGB image of a rounded square (corner radius ~300px)
on a white background. This script cuts the rounded square out with an
anti-aliased mask and writes:

  * branding/icon-1024.png            full-bleed, transparent corners
  * branding/icon-macos-1024.png      Apple grid: 824px artwork + shadow
  * app/macos/.../AppIcon.appiconset  macOS app icons
  * app/windows/runner/resources/app_icon.ico
  * app/linux/runner/resources/app_icon.png and packaging/linux icons
  * app/assets/images/app_icon.png    in-app logo
  * website/assets/img/*              favicons, touch icon, social image

Run from the repo root:  python3 branding/generate_icons.py
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "branding" / "icon-source.png"

# Geometry of the rounded square inside the source image, inset by 3px to drop
# the white anti-aliasing fringe.
BOX = (10, 10, 1244, 1244)
RADIUS = 297
SUPERSAMPLE = 4


def masked_source() -> Image.Image:
    """Returns the rounded square cropped to a square with transparent corners."""
    src = Image.open(SRC).convert("RGB")
    w, h = src.size
    mask = Image.new("L", (w * SUPERSAMPLE, h * SUPERSAMPLE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [c * SUPERSAMPLE for c in BOX], radius=RADIUS * SUPERSAMPLE, fill=255
    )
    mask = mask.resize((w, h), Image.LANCZOS)
    rgba = src.convert("RGBA")
    rgba.putalpha(mask)
    return rgba.crop(BOX)


def resize(img: Image.Image, size: int) -> Image.Image:
    """High-quality resize in premultiplied alpha (no light fringes)."""
    return img.convert("RGBa").resize((size, size), Image.LANCZOS).convert("RGBA")


def macos_variant(full: Image.Image) -> Image.Image:
    """Apple's icon grid: 824x824 artwork centered on 1024 with a soft shadow."""
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    art = resize(full, 824)
    shadow_alpha = art.getchannel("A").point(lambda a: int(a * 0.32))
    shadow = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    shadow_layer = Image.new("RGBA", art.size, (10, 10, 40, 255))
    shadow_layer.putalpha(shadow_alpha)
    shadow.paste(shadow_layer, (100, 112), shadow_layer)
    shadow = shadow.filter(ImageFilter.GaussianBlur(14))
    canvas.alpha_composite(shadow)
    canvas.alpha_composite(art, (100, 100))
    return canvas


def save(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, optimize=True)
    print(f"wrote {path.relative_to(ROOT)}")


def save_ico(full: Image.Image, path: Path, sizes: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    images = [resize(full, s) for s in sizes]
    largest = images[-1]
    largest.save(
        path,
        format="ICO",
        sizes=[(s, s) for s in sizes],
        append_images=images[:-1],
    )
    print(f"wrote {path.relative_to(ROOT)}")


def social_image(full: Image.Image, path: Path) -> None:
    """1200x630 Open Graph / Twitter card."""
    w, h = 1200, 630
    # Diagonal gradient echoing the icon: violet -> indigo -> sky.
    stops = [(0.0, (168, 85, 247)), (0.55, (79, 70, 229)), (1.0, (14, 165, 233))]
    grad = Image.new("RGB", (w, h))
    px = grad.load()
    for y in range(h):
        for x in range(w):
            t = (x / w) * 0.75 + (y / h) * 0.25
            for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
                if t0 <= t <= t1:
                    f = (t - t0) / (t1 - t0)
                    px[x, y] = tuple(int(c0[i] + (c1[i] - c0[i]) * f) for i in range(3))
                    break
    card = grad.convert("RGBA")
    icon = resize(full, 300)
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    sh = Image.new("RGBA", icon.size, (15, 10, 50, 255))
    sh.putalpha(icon.getchannel("A").point(lambda a: int(a * 0.35)))
    shadow.paste(sh, (96, 180), sh)
    card.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(18)))
    card.alpha_composite(icon, (90, 165))

    fonts = ROOT / "app" / "assets" / "fonts"
    title_font = ImageFont.truetype(str(fonts / "Inter-Bold.ttf"), 68)
    body_font = ImageFont.truetype(str(fonts / "Inter-Medium.ttf"), 30)
    small_font = ImageFont.truetype(str(fonts / "Inter-SemiBold.ttf"), 24)
    d = ImageDraw.Draw(card)
    x = 450
    d.text((x, 185), "Color Contrast", font=title_font, fill="white")
    d.text((x, 262), "Checker", font=title_font, fill="white")
    d.text(
        (x, 360),
        "WCAG 2.1 AA & AAA checks with an\neyedropper that works anywhere on screen.",
        font=body_font,
        fill=(237, 233, 254),
        spacing=10,
    )
    pill = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(pill).rounded_rectangle(
        [x, 470, x + 380, 516], radius=23, fill=(255, 255, 255, 46)
    )
    card.alpha_composite(pill)
    d = ImageDraw.Draw(card)
    d.text((x + 22, 480), "Windows  ·  macOS  ·  Linux", font=small_font, fill="white")
    save(card.convert("RGB"), path)


def main() -> None:
    full = masked_source()
    full1024 = resize(full, 1024)
    save(full1024, ROOT / "branding" / "icon-1024.png")

    mac = macos_variant(full)
    save(mac, ROOT / "branding" / "icon-macos-1024.png")
    appiconset = ROOT / "app/macos/Runner/Assets.xcassets/AppIcon.appiconset"
    for s in (16, 32, 64, 128, 256, 512, 1024):
        save(mac.resize((s, s), Image.LANCZOS) if s != 1024 else mac,
             appiconset / f"app_icon_{s}.png")

    save_ico(full, ROOT / "app/windows/runner/resources/app_icon.ico",
             [16, 20, 24, 32, 40, 48, 64, 96, 128, 256])

    save(resize(full, 256), ROOT / "app/linux/runner/resources/app_icon.png")
    for s in (64, 128, 256, 512):
        save(resize(full, s),
             ROOT / f"app/packaging/linux/icons/{s}x{s}/net.joemazzone.colorcontrast.png")

    save(resize(full, 512), ROOT / "app/assets/images/app_icon.png")

    web = ROOT / "website/assets/img"
    save(resize(full, 512), web / "icon-512.png")
    save(resize(full, 192), web / "icon-192.png")
    save(resize(full, 64), web / "favicon-64.png")
    touch = Image.new("RGBA", (180, 180), (255, 255, 255, 255))
    touch.alpha_composite(resize(full, 164), (8, 8))
    save(touch.convert("RGB"), web / "apple-touch-icon.png")
    save_ico(full, ROOT / "website/favicon.ico", [16, 32, 48])
    social_image(full, web / "og-image.png")


if __name__ == "__main__":
    os.chdir(ROOT)
    main()
