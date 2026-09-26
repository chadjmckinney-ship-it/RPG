#!/usr/bin/env python3
"""Bake Ashgrave's UI art: item icons, pixel fonts and panel frames.

    art/ui/icons.png + icons.json   one 32x32 cell per item id (1x; drawn at 1x or 2x, nearest)
    art/ui/frame.png, button*.png   9-slice pixel frames (2x pixels already)
    art/ui/fonts/*.ttf + OFL files  Jersey 10 (body) and UnifrakturCook (titles), SIL OFL 1.1

Icons are cut from Eliza Wyatt's LPC small items (github.com/ElizaWy/LPC, same checkout as
import_world.py) and the game's baked LPC outfits (import_lpc.py); weapons and coins are drawn here.

Usage: python3 tools/import_ui.py [--src /tmp/eliza]   (needs Pillow, git and curl)
"""
import argparse, colorsys, json, os, subprocess, urllib.request
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.path.join(GAME, "art", "ui")
LPC = os.path.join(GAME, "art", "lpc")
SMALL = "Objects/Small Items/"
CELL = 32
FONTS = {
    "Jersey10.ttf": "ofl/jersey10/Jersey10-Regular.ttf",
    "OFL_Jersey10.txt": "ofl/jersey10/OFL.txt",
    "UnifrakturCook-Bold.ttf": "ofl/unifrakturcook/UnifrakturCook-Bold.ttf",
    "OFL_UnifrakturCook.txt": "ofl/unifrakturcook/OFL.txt",
}


def grade(img, sat=1.0, val=1.0, tint=(1.0, 1.0, 1.0), hue=0.0):
    img = img.copy()
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            h, s, v = colorsys.rgb_to_hsv(r / 255, g / 255, b / 255)
            r2, g2, b2 = colorsys.hsv_to_rgb((h + hue) % 1.0, min(1.0, s * sat), min(1.0, v * val))
            px[x, y] = (int(min(255, r2 * 255 * tint[0])), int(min(255, g2 * 255 * tint[1])), int(min(255, b2 * 255 * tint[2])), a)
    return img


def trim(img):
    box = img.getbbox()
    return img.crop(box) if box else img


# ------------------------------------------------------------------ icons

def small(src, f, rect, **g):
    im = trim(Image.open(os.path.join(src, SMALL + f)).convert("RGBA").crop(rect))
    return grade(im, **g) if g else im


def _diag(im, x0, y0, n, col, width=1):
    """A 45-degree line going up and right from (x0, y0)."""
    for i in range(n):
        for w in range(width):
            x, y = x0 + i + w, y0 - i
            if 0 <= x < im.size[0] and 0 <= y < im.size[1]:
                im.putpixel((x, y), col)


def blade(length, steel, edge, guard, grip, pommel, broad=False):
    """A pixel sword lying on the diagonal, point at the top right."""
    im = Image.new("RGBA", (28, 28), (0, 0, 0, 0))
    hilt = 7
    _diag(im, 3, 24, hilt, grip)                          # grip
    im.putpixel((2, 25), pommel); im.putpixel((3, 25), pommel); im.putpixel((2, 24), pommel)
    for i in range(-3, 4):                                 # crossguard, perpendicular
        x, y = 3 + hilt + i, 24 - hilt + i
        im.putpixel((x, y), guard)
    _diag(im, 3 + hilt + 1, 24 - hilt - 1, length, steel, 2 if broad else 1)
    _diag(im, 3 + hilt + 1, 24 - hilt - 2, length - 1, edge)   # bright edge
    return trim(im)


def spear():
    im = Image.new("RGBA", (30, 30), (0, 0, 0, 0))
    _diag(im, 2, 27, 20, (120, 84, 50, 255))               # shaft
    _diag(im, 3, 27, 19, (86, 58, 34, 255))
    for i in range(6):                                      # leaf-shaped head
        w = [1, 2, 2, 2, 1, 1][i]
        for k in range(-w // 2, w // 2 + 1):
            im.putpixel((22 + i + k, 7 - i + k), (190, 196, 204, 255) if k <= 0 else (120, 126, 136, 255))
    return trim(im)


def bow():
    im = Image.new("RGBA", (26, 28), (0, 0, 0, 0))
    wood, dark, string = (150, 98, 52, 255), (98, 62, 32, 255), (220, 214, 196, 255)
    for y in range(2, 26):
        t = (y - 14) / 12.0
        x = int(round(6 + 9 * (1 - t * t)))
        im.putpixel((x, y), wood)
        im.putpixel((x - 1, y), dark)
        im.putpixel((6, y), string)
    for y in (13, 14, 15):
        im.putpixel((15, y), (70, 44, 26, 255))                # grip wrap
    return trim(im)


def outfit(cid, **g):
    """Chest and shoulders of a baked LPC outfit, facing the viewer."""
    meta = json.load(open(os.path.join(LPC, "layout.json")))
    y = meta["layout"]["idle"]["y"] + 2 * 64
    im = Image.open(os.path.join(LPC, "chars", cid + ".png")).convert("RGBA").crop((19, y + 33, 45, y + 52))
    return grade(trim(im), **g) if g else trim(im)


def coins():
    im = Image.new("RGBA", (18, 14), (0, 0, 0, 0))
    px = im.load()
    for i, (cx, cy) in enumerate([(5, 9), (12, 9), (8, 5)]):
        for y in range(cy - 4, cy + 5):
            for x in range(cx - 5, cx + 6):
                dx, dy = (x - cx) / 5.2, (y - cy) / 3.6
                if 0 <= x < 18 and 0 <= y < 14 and dx * dx + dy * dy <= 1.0:
                    edge = dx * dx + dy * dy > 0.55
                    px[x, y] = (150, 100, 30, 255) if edge else ((232, 188, 84, 255) if dy < 0 else (206, 156, 60, 255))
    return im


def letter(src):
    im = small(src, "Loose Paper.png", (7, 41, 22, 49), val=0.9, sat=0.5, tint=(1.0, 0.95, 0.85))
    im = im.copy()
    cx, cy = im.size[0] // 2, im.size[1] // 2
    for x, y in [(cx, cy), (cx - 1, cy), (cx, cy - 1), (cx - 1, cy - 1), (cx + 1, cy), (cx, cy + 1)]:
        im.putpixel((x, y), (150, 30, 30, 255))
    return im


def build_icons(src):
    icons = {
        "coin": coins(),
        "hide": small(src, "Fabric/Fabric Rolls.png", (137, 1, 152, 31), sat=0.5, val=0.7, hue=0.0, tint=(1.0, 0.8, 0.6)),
        "grave-dust": small(src, "Dungeon Elements.png", (0, 99, 25, 122), sat=0.25, val=0.8),
        "lurker-gland": small(src, "Dungeon Elements.png", (0, 67, 30, 87), sat=1.1, val=1.0),
        "bone-charm": small(src, "Skeletons A.png", (4, 3, 24, 23), val=0.95),
        "bitterroot": small(src, "Food/Tea, Coffee, Medicinal Herbs.png", (72, 7, 88, 25), sat=0.8, val=0.9),
        "iron-ore": small(src, "Ores & Ingots/Ore, Coal.png", (2, 3, 31, 31), val=0.95),
        "deadwood": small(src, "Lumber.png", (35, 7, 61, 23), sat=0.5, val=0.8),
        "ashbloom": small(src, "Food/Tea, Coffee, Medicinal Herbs.png", (226, 70, 251, 93), sat=0.9, val=0.95),
        "tithe-ledger": small(src, "Loose Paper.png", (41, 76, 54, 91), sat=0.5, val=0.85, tint=(1.0, 0.95, 0.85)),
        "sealed-letter": letter(src),
        "bandage": small(src, "Fabric/Fabric Rolls.png", (9, 33, 23, 63), sat=0.1, val=1.0),
        "antivenom": small(src, "Kitchen Clutter A.png", (13, 134, 19, 152)),
        "blight-draught": small(src, "Kitchen Clutter A.png", (77, 134, 83, 152)),
        "fen-tonic": small(src, "Kitchen Clutter A.png", (45, 134, 51, 152)),
        "militia-spear": spear(),
        "iron-blade": blade(13, (150, 156, 164, 255), (214, 220, 228, 255), (96, 80, 56, 255), (80, 52, 32, 255), (150, 120, 60, 255)),
        "barrow-blade": blade(14, (126, 150, 160, 255), (214, 236, 240, 255), (70, 80, 86, 255), (40, 44, 50, 255), (170, 190, 196, 255)),
        "ashen-greatsword": blade(16, (104, 94, 90, 255), (220, 110, 50, 255), (40, 34, 32, 255), (30, 24, 22, 255), (200, 80, 40, 255), broad=True),
        "yew-bow": bow(),
        "hide-jerkin": outfit("maren_hide"),
        "iron-mail": outfit("maren_mail"),
        "penitent-robes": outfit("oswin_robes"),
    }
    ids = list(icons)
    cols = 8
    atlas = Image.new("RGBA", (cols * CELL, -(-len(ids) // cols) * CELL), (0, 0, 0, 0))
    meta = {}
    for i, iid in enumerate(ids):
        im = icons[iid]
        if max(im.size) <= CELL // 2 - 1:
            im = im.resize((im.size[0] * 2, im.size[1] * 2), Image.NEAREST)    # tiny props read better doubled
        if max(im.size) > CELL:
            k = CELL / max(im.size)
            im = im.resize((max(1, int(im.size[0] * k)), max(1, int(im.size[1] * k))), Image.NEAREST)
        x, y = (i % cols) * CELL, (i // cols) * CELL
        atlas.alpha_composite(im, (x + (CELL - im.size[0]) // 2, y + (CELL - im.size[1]) // 2))
        meta[iid] = [x, y]
    atlas.save(os.path.join(OUT, "icons.png"), optimize=True)
    json.dump({"cell": CELL, "icons": meta}, open(os.path.join(OUT, "icons.json"), "w"), indent=1)


# ------------------------------------------------------------------ frames

def frame(path, fill, edge, light, dark, rivet=None, size=24):
    """A 9-slice pixel frame: dark fill, bevelled iron edge, optional brass rivets. Drawn at 2x."""
    n = size // 2
    im = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    px = im.load()
    for y in range(n):
        for x in range(n):
            ring = min(x, y, n - 1 - x, n - 1 - y)
            if ring == 0:
                c = edge
            elif ring == 1:
                c = light if (x < n // 2 and y < n // 2) or x == 1 or y == 1 else dark
            else:
                c = fill
            px[x, y] = c
    for cx, cy in ((0, 0), (n - 1, 0), (0, n - 1), (n - 1, n - 1)):
        px[cx, cy] = (0, 0, 0, 0)       # rounded corners
    if rivet:
        for cx, cy in ((2, 2), (n - 3, 2), (2, n - 3), (n - 3, n - 3)):
            px[cx, cy] = rivet
    im.resize((size, size), Image.NEAREST).save(os.path.join(OUT, path))


def build_frames():
    frame("frame.png", (18, 16, 14, 244), (8, 7, 6, 255), (122, 100, 62, 255), (70, 56, 36, 255), (214, 170, 88, 255))
    frame("button.png", (36, 31, 26, 255), (10, 9, 8, 255), (104, 88, 62, 255), (58, 48, 36, 255))
    frame("button_hover.png", (52, 42, 28, 255), (10, 9, 8, 255), (240, 176, 74, 255), (150, 104, 44, 255))
    frame("button_pressed.png", (70, 50, 26, 255), (10, 9, 8, 255), (150, 104, 44, 255), (240, 176, 74, 255))
    frame("button_disabled.png", (24, 22, 20, 255), (10, 9, 8, 255), (52, 48, 42, 255), (40, 36, 32, 255))
    frame("slot.png", (10, 9, 8, 230), (6, 5, 4, 255), (40, 34, 26, 255), (70, 58, 40, 255))


def fetch_fonts():
    os.makedirs(os.path.join(OUT, "fonts"), exist_ok=True)
    for name, rel in FONTS.items():
        dst = os.path.join(OUT, "fonts", name)
        if not os.path.exists(dst):
            urllib.request.urlretrieve("https://raw.githubusercontent.com/google/fonts/main/" + rel, dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/eliza")
    args = ap.parse_args()
    if not os.path.isdir(os.path.join(args.src, SMALL)):
        if not os.path.isdir(args.src):
            subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse",
                            "https://github.com/ElizaWy/LPC.git", args.src], check=True)
        subprocess.run(["git", "-C", args.src, "sparse-checkout", "add", "Objects/Small Items"], check=True)
    os.makedirs(OUT, exist_ok=True)
    build_icons(args.src)
    build_frames()
    fetch_fonts()
    print("UI art written to", OUT)


if __name__ == "__main__":
    main()
