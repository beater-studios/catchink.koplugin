"""Draws the icon masks of CatchInk with Pillow (white shape on black, 96 x 96): the plugin paints them in any color.
Also draws the sleep screen cover, assets/screensaver.png, with the fonts of KOReader when KOREADER_DIR is set.

Usage: [KOREADER_DIR=<desktop KOReader>] make_assets.py <output assets dir>
"""
import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
SS = 4
SIZE = 96
BLACK, WHITE = 0, 255
INK = 0


class Pen:
    """The drawing calls of the mockups, on a square mask."""

    def __init__(self):
        self.image = Image.new("L", (SIZE * SS, SIZE * SS), 0)
        self.d = ImageDraw.Draw(self.image)

    def s(self, v):
        return round(v * SS)

    def pts(self, points):
        return [(self.s(x), self.s(y)) for x, y in points]

    def rect(self, x0, y0, x1, y1, fill=None, outline=None, width=0, radius=0):
        self.d.rounded_rectangle([self.s(x0), self.s(y0), self.s(x1), self.s(y1)], radius=self.s(radius), fill=fill,
                                 outline=outline, width=self.s(width) if outline is not None else 0)

    def circle(self, cx, cy, r, fill=None, outline=None, width=0):
        self.d.ellipse([self.s(cx - r), self.s(cy - r), self.s(cx + r), self.s(cy + r)], fill=fill, outline=outline,
                       width=self.s(width) if outline is not None else 0)

    def poly(self, points, fill=None, outline=None, width=0):
        p = self.pts(points)
        if fill is not None:
            self.d.polygon(p, fill=fill)
        if outline is not None:
            self.d.line(p + [p[0]], fill=outline, width=self.s(width), joint="curve")

    def line(self, points, fill=WHITE, width=2):
        self.d.line(self.pts(points), fill=fill, width=self.s(width), joint="curve")

    def save(self, name):
        small = self.image.resize((SIZE, SIZE), Image.LANCZOS)
        os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
        small.save(os.path.join(OUT, "icons", name + ".png"), optimize=True)


def icon_check(c, cx, cy, s, fill=BLACK, width=2.4):
    c.line([(cx - s * 0.35, cy), (cx - s * 0.08, cy + s * 0.28), (cx + s * 0.38, cy - s * 0.3)], fill, width)


def icon_x(c, cx, cy, s, fill=BLACK, width=2):
    c.line([(cx - s / 2, cy - s / 2), (cx + s / 2, cy + s / 2)], fill, width)
    c.line([(cx - s / 2, cy + s / 2), (cx + s / 2, cy - s / 2)], fill, width)


def icon_chevron(c, cx, cy, s, direction="left", fill=BLACK, width=2.4):
    d = -1 if direction == "left" else 1
    if direction in ("left", "right"):
        c.line([(cx - d * s * 0.2, cy - s * 0.4), (cx + d * s * 0.2, cy), (cx - d * s * 0.2, cy + s * 0.4)], fill, width)
    else:
        d = 1 if direction == "down" else -1
        c.line([(cx - s * 0.4, cy - d * s * 0.2), (cx, cy + d * s * 0.2), (cx + s * 0.4, cy - d * s * 0.2)], fill, width)


def icon_grid(c, cx, cy, s, fill=BLACK):
    q = s * 0.42
    for dx in (-1, 1):
        for dy in (-1, 1):
            x, y = cx + dx * s * 0.25, cy + dy * s * 0.25
            c.rect(x - q / 2, y - q / 2, x + q / 2, y + q / 2, outline=fill, width=1.8, radius=1.5)


def icon_list(c, cx, cy, s, fill=BLACK):
    for dy in (-0.32, 0, 0.32):
        c.circle(cx - s * 0.38, cy + dy * s, s * 0.06, fill=fill)
        c.line([(cx - s * 0.2, cy + dy * s), (cx + s * 0.45, cy + dy * s)], fill, 2)


def icon_filter(c, cx, cy, s, fill=BLACK):
    c.poly([(cx - s * 0.45, cy - s * 0.38), (cx + s * 0.45, cy - s * 0.38), (cx + s * 0.1, cy + s * 0.02), (cx + s * 0.1, cy + s * 0.4), (cx - s * 0.1, cy + s * 0.3), (cx - s * 0.1, cy + s * 0.02)], outline=fill, width=1.8)


def icon_search(c, cx, cy, s, fill=BLACK):
    c.circle(cx - s * 0.08, cy - s * 0.08, s * 0.28, outline=fill, width=2)
    c.line([(cx + s * 0.13, cy + s * 0.13), (cx + s * 0.42, cy + s * 0.42)], fill, 2.6)


def icon_chart(c, cx, cy, s, fill=BLACK):
    for i, hgt in enumerate((0.35, 0.6, 0.85)):
        x = cx - s * 0.3 + i * s * 0.3
        c.rect(x - s * 0.09, cy + s * 0.42 - hgt * s, x + s * 0.09, cy + s * 0.42, fill=fill)


def icon_menu(c, cx, cy, s, fill=BLACK):
    for dy in (-0.3, 0, 0.3):
        c.line([(cx - s * 0.4, cy + dy * s), (cx + s * 0.4, cy + dy * s)], fill, 2.2)


def icon_dots(c, cx, cy, s, fill=BLACK):
    for dy in (-0.3, 0, 0.3):
        c.circle(cx, cy + dy * s, s * 0.08, fill=fill)


def icon_eye(c, cx, cy, s, fill=BLACK):
    c.poly([(cx - s * 0.5, cy), (cx - s * 0.2, cy - s * 0.28), (cx + s * 0.2, cy - s * 0.28), (cx + s * 0.5, cy), (cx + s * 0.2, cy + s * 0.28), (cx - s * 0.2, cy + s * 0.28)], outline=fill, width=1.6)
    c.circle(cx, cy, s * 0.14, fill=fill)


def icon_download(c, cx, cy, s, fill=BLACK):
    c.line([(cx, cy - s * 0.42), (cx, cy + s * 0.12)], fill, 2.2)
    c.line([(cx - s * 0.25, cy - s * 0.12), (cx, cy + s * 0.14), (cx + s * 0.25, cy - s * 0.12)], fill, 2.2)
    c.line([(cx - s * 0.42, cy + s * 0.2), (cx - s * 0.42, cy + s * 0.42), (cx + s * 0.42, cy + s * 0.42), (cx + s * 0.42, cy + s * 0.2)], fill, 2)


def icon_trash(c, cx, cy, s, fill=BLACK):
    c.line([(cx - s * 0.42, cy - s * 0.28), (cx + s * 0.42, cy - s * 0.28)], fill, 2)
    c.line([(cx - s * 0.12, cy - s * 0.28), (cx - s * 0.12, cy - s * 0.42), (cx + s * 0.12, cy - s * 0.42), (cx + s * 0.12, cy - s * 0.28)], fill, 1.8)
    c.poly([(cx - s * 0.32, cy - s * 0.2), (cx + s * 0.32, cy - s * 0.2), (cx + s * 0.25, cy + s * 0.45), (cx - s * 0.25, cy + s * 0.45)], outline=fill, width=1.8)


def icon_pencil(c, cx, cy, s, fill=BLACK):
    c.poly([(cx - s * 0.4, cy + s * 0.4), (cx - s * 0.35, cy + s * 0.15), (cx + s * 0.22, cy - s * 0.42), (cx + s * 0.42, cy - s * 0.22), (cx - s * 0.15, cy + s * 0.35)], outline=fill, width=1.8)


def icon_star(c, cx, cy, s, fill=BLACK):
    pts = []
    for i in range(10):
        r = s * 0.5 if i % 2 == 0 else s * 0.21
        a = -math.pi / 2 + i * math.pi / 5
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    c.poly(pts, fill=fill)


def icon_sparkle(c, cx, cy, s, fill=BLACK):
    pts = []
    for i in range(8):
        r = s * 0.5 if i % 2 == 0 else s * 0.14
        a = -math.pi / 2 + i * math.pi / 4
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    c.poly(pts, fill=fill)


def icon_info(c, cx, cy, s, fill=BLACK):
    c.circle(cx, cy, s * 0.45, outline=fill, width=1.8)
    c.circle(cx, cy - s * 0.2, s * 0.06, fill=fill)
    c.line([(cx, cy - s * 0.05), (cx, cy + s * 0.25)], fill, 2.2)


def icon_male(c, cx, cy, s, fill=BLACK):
    r = s * 0.28
    ox, oy = cx - s * 0.1, cy + s * 0.1
    c.circle(ox, oy, r, outline=fill, width=1.6)
    c.line([(ox + r * 0.7, oy - r * 0.7), (cx + s * 0.42, cy - s * 0.42)], fill, 1.6)
    c.line([(cx + s * 0.12, cy - s * 0.42), (cx + s * 0.42, cy - s * 0.42), (cx + s * 0.42, cy - s * 0.12)], fill, 1.6)


def icon_female(c, cx, cy, s, fill=BLACK):
    r = s * 0.28
    oy = cy - s * 0.14
    c.circle(cx, oy, r, outline=fill, width=1.6)
    c.line([(cx, oy + r), (cx, cy + s * 0.48)], fill, 1.6)
    c.line([(cx - s * 0.18, cy + s * 0.3), (cx + s * 0.18, cy + s * 0.3)], fill, 1.6)


def logo(c, cx, cy, s, fill=WHITE, bg=INK):
    r = s * 0.34
    oy = cy + s * 0.12
    c.circle(cx, oy, r, fill=fill)
    c.poly([(cx - r * 0.72, oy - r * 0.7), (cx, cy - s * 0.5), (cx + r * 0.72, oy - r * 0.7)], fill=fill)
    icon_check(c, cx, oy, r * 1.1, bg, 2.2)




def icon_plus(c, cx, cy, s, fill=WHITE):
    c.line([(cx - s * 0.4, cy), (cx + s * 0.4, cy)], fill, 2.4)
    c.line([(cx, cy - s * 0.4), (cx, cy + s * 0.4)], fill, 2.4)


def icon_minus(c, cx, cy, s, fill=WHITE):
    c.line([(cx - s * 0.4, cy), (cx + s * 0.4, cy)], fill, 2.6)


def icon_undo(c, cx, cy, s, fill=WHITE):
    c.d.arc([c.s(cx - s * 0.36), c.s(cy - s * 0.3), c.s(cx + s * 0.4), c.s(cy + s * 0.42)], 200, 90, fill=fill, width=c.s(2.2))
    c.poly([(cx - s * 0.48, cy - s * 0.2), (cx - s * 0.2, cy - s * 0.42), (cx - s * 0.16, cy - s * 0.04)], fill=fill)


def icon_globe(c, cx, cy, s, fill=WHITE):
    c.circle(cx, cy, s * 0.42, outline=fill, width=1.8)
    c.d.ellipse([c.s(cx - s * 0.18), c.s(cy - s * 0.42), c.s(cx + s * 0.18), c.s(cy + s * 0.42)], outline=fill, width=c.s(1.6))
    c.line([(cx - s * 0.42, cy), (cx + s * 0.42, cy)], fill, 1.6)


def icon_image(c, cx, cy, s, fill=WHITE):
    c.rect(cx - s * 0.42, cy - s * 0.34, cx + s * 0.42, cy + s * 0.34, outline=fill, width=1.8, radius=2)
    c.poly([(cx - s * 0.32, cy + s * 0.24), (cx - s * 0.08, cy - s * 0.06), (cx + s * 0.08, cy + s * 0.1), (cx + s * 0.18, cy), (cx + s * 0.32, cy + s * 0.24)], fill=fill)
    c.circle(cx + s * 0.2, cy - s * 0.16, s * 0.07, fill=fill)


def logo_mask(c, cx, cy, s):
    r = s * 0.34
    oy = cy + s * 0.12
    c.circle(cx, oy, r, fill=WHITE)
    c.poly([(cx - r * 0.72, oy - r * 0.7), (cx, cy - s * 0.5), (cx + r * 0.72, oy - r * 0.7)], fill=WHITE)
    icon_check(c, cx, oy, r * 1.1, BLACK, 2.2)


ICONS = {
    "check": icon_check, "x": icon_x, "grid": icon_grid, "list": icon_list, "filter": icon_filter, "search": icon_search,
    "chart": icon_chart, "menu": icon_menu, "dots": icon_dots, "eye": icon_eye, "download": icon_download, "trash": icon_trash,
    "pencil": icon_pencil, "star": icon_star, "sparkle": icon_sparkle, "info": icon_info, "male": icon_male,
    "female": icon_female, "plus": icon_plus, "minus": icon_minus, "undo": icon_undo, "globe": icon_globe, "image": icon_image,
}


def unit_pen():
    """A mask pen whose drawing units are a 24-unit box, like the mockups' icon calls."""
    pen = Pen()
    k = SS * SIZE / 24
    pen.s = lambda v: round(v * k)
    return pen


def alpha_mask():
    """The Alpha symbol of the Legends games (tools/sources/alpha_glyph.webp, the one pkm-la uses): the red shield
    becomes the mask and its white eyes stay cut out."""
    source = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sources", "alpha_glyph.webp")
    if not os.path.exists(source):
        return
    img = Image.open(source).convert("RGBA")
    mask = Image.new("L", img.size, 0)
    px, out = img.load(), mask.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            red = r > 150 and g < 140 and b < 140
            out[x, y] = a if red else 0
    side = max(img.size)
    square = Image.new("L", (side, side), 0)
    square.paste(mask, ((side - img.size[0]) // 2, (side - img.size[1]) // 2))
    square = square.resize((SIZE - 8, SIZE - 8), Image.LANCZOS)
    final = Image.new("L", (SIZE, SIZE), 0)
    final.paste(square, (4, 4))
    os.makedirs(os.path.join(OUT, "icons"), exist_ok=True)
    final.save(os.path.join(OUT, "icons", "alpha.png"), optimize=True)


def cover_font(name, size):
    """A font of KOReader (fonts/noto), else Pillow's own."""
    koreader = os.environ.get("KOREADER_DIR")
    if koreader:
        path = os.path.join(koreader, "fonts", "noto", name)
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default(size)


def make_screensaver():
    """The sleep screen cover: the logo, the name and a box of the plugin, with no Pokémon and no logo of the
    games. Laid out in 600x800 units and saved at twice that (1200x1600), so larger screens get a sharp image
    and 600x800 gets a clean halving, in the 16 grays of the screen."""
    k = 2
    w, h = 600 * k, 800 * k
    image = Image.new("L", (w * SS, h * SS), 255)
    d = ImageDraw.Draw(image)

    def u(v):
        return round(v * k * SS)

    def rect(x0, y0, x1, y1, fill=None, outline=None, width=0, radius=0):
        d.rounded_rectangle([u(x0), u(y0), u(x1), u(y1)], radius=u(radius), fill=fill, outline=outline,
                            width=u(width) if outline is not None else 0)

    def line(points, fill, width):
        d.line([(u(x), u(y)) for x, y in points], fill=fill, width=u(width), joint="curve")

    def text(cx, cy, value, font, fill):
        d.text((u(cx), u(cy)), value, font=font, fill=fill, anchor="mm")

    def drop(cx, cy, size, fill, mark=None):
        r = size * 0.34
        oy = cy + size * 0.12
        d.ellipse([u(cx - r), u(oy - r), u(cx + r), u(oy + r)], fill=fill)
        d.polygon([(u(cx - r * 0.72), u(oy - r * 0.7)), (u(cx), u(cy - size * 0.5)), (u(cx + r * 0.72), u(oy - r * 0.7))], fill=fill)
        if mark is not None:
            s2 = r * 1.1
            line([(cx - s2 * 0.35, oy), (cx - s2 * 0.08, oy + s2 * 0.28), (cx + s2 * 0.38, oy - s2 * 0.3)], mark, size * 0.07)

    # Header band, like the plugin's own header, with the logo and the name.
    rect(0, 0, 600, 232, fill=0x22)
    rect(254, 30, 346, 122, fill=255, radius=20)
    drop(300, 78, 74, 0x22, 255)
    text(300, 166, "CatchInk", cover_font("NotoSerif-Bold.ttf", u(52)), 255)
    rect(262, 204, 338, 210, fill=0x88, radius=3)

    # A box of 20 entries: caught ones with the stamp, seen ones with an eye ring, missing ones faint.
    caught = {1, 2, 4, 5, 7, 8, 10, 11, 13, 16, 17, 19, 20}
    seen = {12, 14}
    number = cover_font("NotoSans-Bold.ttf", u(11))
    cols, rows = 5, 4
    x0, y0, gap = 28, 262, 10
    cw = (600 - 2 * x0 - (cols - 1) * gap) / cols
    ch = 96
    for i in range(cols * rows):
        n = i + 1
        x = x0 + (i % cols) * (cw + gap)
        y = y0 + (i // cols) * (ch + gap)
        if n in caught:
            rect(x, y, x + cw, y + ch, fill=255, outline=0, width=2.4, radius=9)
            drop(x + cw / 2, y + ch * 0.56, 52, 0x44)
            d.ellipse([u(x + cw - 24), u(y + 8), u(x + cw - 8), u(y + 24)], fill=0x22)
            line([(x + cw - 20.5, y + 16), (x + cw - 17, y + 19.5), (x + cw - 11.5, y + 12.5)], 255, 1.8)
            fill = 0
        else:
            rect(x, y, x + cw, y + ch, fill=255, outline=0xBB, width=1.4, radius=9)
            drop(x + cw / 2, y + ch * 0.56, 52, 0xBB if n in seen else 0xDD)
            if n in seen:
                d.ellipse([u(x + cw - 24), u(y + 8), u(x + cw - 8), u(y + 24)], outline=0x44, width=u(1.6))
                d.ellipse([u(x + cw - 18), u(y + 14), u(x + cw - 14), u(y + 18)], fill=0x44)
            fill = 0x88
        d.text((u(x + 9), u(y + 9)), "#%03d" % n, font=number, fill=fill, anchor="lt")

    # The progress of the box, as on the plugin's screens.
    py = y0 + rows * (ch + gap) + 20
    text(300, py + 8, "%d / %d" % (len(caught), cols * rows), cover_font("NotoSans-Bold.ttf", u(22)), 0x22)
    rect(60, py + 36, 540, py + 54, fill=255, outline=0x22, width=2, radius=9)
    rect(63, py + 39, 63 + (474 * len(caught) / (cols * rows)), py + 51, fill=0x22, radius=6)

    image = image.resize((w, h), Image.LANCZOS)
    image = image.point(lambda v: round(v / 17) * 17)
    image.save(os.path.join(OUT, "screensaver.png"), optimize=True)


def main():
    alpha_mask()
    for name, fn in ICONS.items():
        pen = unit_pen()
        fn(pen, 12, 12, 20, WHITE)
        pen.save(name)
    for name, direction in (("chevron_left", "left"), ("chevron_right", "right"), ("chevron_down", "down"), ("chevron_up", "up")):
        pen = unit_pen()
        icon_chevron(pen, 12, 12, 20, direction, WHITE, 2.6)
        pen.save(name)
    pen = unit_pen()
    logo_mask(pen, 12, 12, 22)
    pen.save("logo")
    make_screensaver()
    print("icons and cover written")


if __name__ == "__main__":
    main()
