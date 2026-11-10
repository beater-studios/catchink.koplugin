"""Draws the icon, the README banner and the GitHub social preview, in the style of the other Beater Studios plugins.

Usage: KOREADER_DIR=<desktop KOReader> python3 -I tools/make_brand_art.py
Run tools/koreader/readme_screens.sh first: the banner and the preview show two of the README screenshots.
Needs Pillow, and the fonts that come with KOReader. The sleep screen cover is drawn by tools/make_assets.py.
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
BLACK, WHITE, FOLD, GRAY = 0, 255, 170, 88
ICON_SIZE = 1024
SUPERSAMPLE = 3
TITLE = "CatchInk"
TAGLINE = "A Pokédex tracker for e-ink."
DETAILS = [
    "27 games and the national Pokédex, several profiles,",
    "and a card for every Pokémon, made for e-ink.",
    "Unofficial and fan-made, not affiliated with Nintendo.",
]
# The sheet of paper, in icon coordinates, as in the other Beater Studios icons.
PAGE_LEFT, PAGE_TOP, PAGE_RIGHT, PAGE_BOTTOM, EAR = 222, 130, 802, 894, 170


def draw_icon():
    k = SUPERSAMPLE
    size = ICON_SIZE
    large = Image.new("L", (size * k, size * k), BLACK)
    d = ImageDraw.Draw(large)

    def box(x0, y0, x1, y1, fill, radius=0):
        d.rounded_rectangle([x0 * k, y0 * k, x1 * k, y1 * k], radius=radius * k, fill=fill)

    page = [(PAGE_LEFT, PAGE_TOP), (PAGE_RIGHT - EAR, PAGE_TOP), (PAGE_RIGHT, PAGE_TOP + EAR), (PAGE_RIGHT, PAGE_BOTTOM), (PAGE_LEFT, PAGE_BOTTOM)]
    d.polygon([(x * k, y * k) for x, y in page], fill=WHITE)
    ear = [(PAGE_RIGHT - EAR, PAGE_TOP), (PAGE_RIGHT - EAR, PAGE_TOP + EAR), (PAGE_RIGHT, PAGE_TOP + EAR)]
    d.polygon([(x * k, y * k) for x, y in ear], fill=FOLD)
    # The plugin's logo, an ink drop with a check, over a row of three box cells: caught, caught, missing.
    cx = (PAGE_LEFT + PAGE_RIGHT) / 2
    drop_size = 360
    cy = PAGE_TOP + EAR * 0.55 + 210
    r = drop_size * 0.34
    oy = cy + drop_size * 0.12
    d.ellipse([(cx - r) * k, (oy - r) * k, (cx + r) * k, (oy + r) * k], fill=BLACK)
    tip = [(cx - r * 0.72, oy - r * 0.7), (cx, cy - drop_size * 0.5), (cx + r * 0.72, oy - r * 0.7)]
    d.polygon([(x * k, y * k) for x, y in tip], fill=BLACK)
    s = r * 1.1
    check = [(cx - s * 0.35, oy), (cx - s * 0.08, oy + s * 0.28), (cx + s * 0.38, oy - s * 0.3)]
    d.line([(x * k, y * k) for x, y in check], fill=WHITE, width=round(26 * k), joint="curve")
    cell, gap = 128, 26
    left = cx - (3 * cell + 2 * gap) / 2
    top = PAGE_BOTTOM - 70 - cell
    for i, fill in enumerate((BLACK, BLACK, None)):
        x0 = left + i * (cell + gap)
        if fill is None:
            box(x0, top, x0 + cell, top + cell, GRAY, 22)
            box(x0 + 12, top + 12, x0 + cell - 12, top + cell - 12, WHITE, 14)
        else:
            box(x0, top, x0 + cell, top + cell, fill, 22)
            mark = [(x0 + cell * 0.28, top + cell * 0.52), (x0 + cell * 0.44, top + cell * 0.68), (x0 + cell * 0.74, top + cell * 0.34)]
            d.line([(x * k, y * k) for x, y in mark], fill=WHITE, width=round(16 * k), joint="curve")
    final = large.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size * 4, size * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=190 * 4, fill=255)
    icon = Image.new("LA", (size, size))
    icon.paste(final)
    icon.putalpha(mask.resize((size, size), Image.LANCZOS))
    return icon


def halftone(image, cx, cy, radius, spacing):
    d = ImageDraw.Draw(image)
    row, y = 0, cy - radius
    while y <= cy + radius:
        x = cx - radius + (spacing / 2 if row % 2 else 0)
        while x <= cx + radius:
            distance = math.hypot(x - cx, y - cy) / radius
            if distance <= 1:
                dot = spacing * 0.34 * (1 - distance * 0.72)
                d.ellipse([x - dot, y - dot, x + dot, y + dot], fill=88)
            x += spacing
        y += spacing * 0.87
        row += 1


def place_screen(image, name, center, height, angle):
    screen = Image.open(os.path.join(ROOT, "docs", "screenshots", name + ".png")).convert("L")
    screen = screen.resize((round(height * screen.width / screen.height), height), Image.LANCZOS)
    framed = Image.new("L", (screen.width + 12, screen.height + 12), WHITE)
    framed.paste(screen, (6, 6))
    rotated = framed.convert("LA").rotate(angle, expand=True, resample=Image.BICUBIC)
    image.paste(rotated.getchannel("L"), (round(center[0] - rotated.width / 2), round(center[1] - rotated.height / 2)), rotated.getchannel("A"))


def draw_header(width, height, fonts, icon, layout):
    k = 2
    image = Image.new("L", (width * k, height * k), BLACK)
    middle, screen_height, offset, text = layout["middle"], layout["screen_height"], layout["offset"], layout["text"]
    halftone(image, middle * k, height // 2 * k, round(layout["halftone"] * k), 26 * k)
    place_screen(image, "box", ((middle - offset) * k, (height // 2 + 8) * k), screen_height * k, 6)
    place_screen(image, "card", ((middle + offset) * k, (height // 2 - 8) * k), screen_height * k, -5)
    margin = 58
    icon_size = round(112 * text)
    title_size = round(68 * text)
    tagline_size = round(24 * text)
    details_size = round(18 * text)
    details = layout.get("details")
    block = icon_size + title_size + tagline_size + round(44 * text)
    if details:
        block += round(details_size * 1.45 * len(details)) + round(22 * text)
    y = (height - block) // 2
    small = icon.resize((icon_size * k, icon_size * k), Image.LANCZOS)
    # The drawing starts inside the icon's black square, which disappears on this background.
    inset = round(icon_size * PAGE_LEFT / ICON_SIZE)
    image.paste(small.getchannel("L"), ((margin - inset) * k, y * k), small.getchannel("A"))
    y += icon_size + round(6 * text)
    d = ImageDraw.Draw(image)
    d.text((margin * k, y * k), TITLE, font=ImageFont.truetype(fonts["bold"], title_size * k), fill=WHITE)
    y += title_size + round(26 * text)
    d.text((margin * k, y * k), TAGLINE, font=ImageFont.truetype(fonts["italic"], tagline_size * k), fill=WHITE)
    y += tagline_size + round(30 * text)
    if details:
        font = ImageFont.truetype(fonts["regular"], details_size * k)
        for line in details:
            d.text((margin * k, y * k), line, font=font, fill=205)
            y += round(details_size * 1.45)
    return image.resize((width, height), Image.LANCZOS)


def main():
    koreader = os.environ.get("KOREADER_DIR")
    if not koreader:
        sys.exit("Set KOREADER_DIR to the KOReader folder, which has the fonts.")
    noto = os.path.join(koreader, "fonts", "noto")
    fonts = {
        "bold": os.path.join(noto, "NotoSerif-Bold.ttf"),
        "italic": os.path.join(noto, "NotoSerif-Italic.ttf"),
        "regular": os.path.join(noto, "NotoSerif-Regular.ttf"),
    }
    brand = os.path.join(ROOT, "docs", "brand")
    os.makedirs(brand, exist_ok=True)
    icon = draw_icon()
    icon.save(os.path.join(brand, "icon.png"), optimize=True)
    draw_header(1280, 400, fonts, icon, {"middle": 1000, "screen_height": 330, "offset": 110, "text": 1, "halftone": 280}).save(os.path.join(brand, "banner.png"), optimize=True)
    draw_header(1280, 640, fonts, icon, {"middle": 960, "screen_height": 430, "offset": 112, "text": 1.02, "halftone": 360, "details": DETAILS}).save(os.path.join(ROOT, "docs", "social-preview.png"), optimize=True)
    print("Images generated in docs/brand and docs/social-preview.png")


main()
