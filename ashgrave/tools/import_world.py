#!/usr/bin/env python3
"""Bake world art for Ashgrave from Eliza Wyatt's revised LPC set (github.com/ElizaWy/LPC).

Writes (all at 1x; the game scales by 2 with nearest filtering):
    art/world/ground.png       one 128x128 seamless fill per terrain, in WorldGen.Terrain order
    art/world/ground.json      terrain -> average colour (for the map)
    art/world/props.png/.json  trees, rocks, plants, village props on a 16 px grid:
                               {name: [x, y, w, h, foot_x, foot_y]} (grid-aligned rect, foot in rect)
    art/world/buildings/<kind>.png (+ _glow.png)   re-skinned cottages
    art/world/landmarks/<kind>.png                 barrow, chapel, ashen tower
    art/world/CREDITS_WORLD.txt

Usage: python3 tools/import_world.py [--src /tmp/eliza]   (needs Pillow and git)
"""
import argparse, colorsys, json, os, random, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.path.join(GAME, "art", "world")
REPO = "https://github.com/ElizaWy/LPC.git"
FOLDERS = ["Terrain", "Structure/Structures", "Structure/Walls", "Structure/Pillars", "Structure/Doors",
           "Objects/Furniture", "Credits.txt"]
T = "Terrain/"
FURN = "Objects/Furniture/"
GRID = 16


# ------------------------------------------------------------------ colour grading

def grade(img, sat=1.0, val=1.0, tint=(1.0, 1.0, 1.0), hue=0.0):
    """Desaturate / darken / tint an RGBA image (keeps alpha)."""
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


# ------------------------------------------------------------------ ground fills

# Terrain order must match WorldGen.Terrain: WATER, MOOR, FOREST, FEN, HILLS, ROCK, ROAD, ASHFIELD.
GRASS = [(3, 1), (4, 1), (5, 1), (3, 2), (4, 2), (5, 2), (1, 1)]
DIRT = [(3, 3), (4, 3), (5, 3), (3, 4), (4, 4), (5, 4)]
WATER = [(12, 16), (13, 16), (14, 16), (15, 16), (12, 17), (13, 17), (14, 17), (15, 17)]
CLIFF = [(5, 3), (6, 3), (5, 4), (6, 4)]
GROUND = [
    # name, [(sheet, tiles, weight)], grade kwargs
    ("water", [("terrain_summer", WATER, 1)], dict(sat=0.55, val=0.45, tint=(0.85, 0.95, 1.0))),
    ("moor", [("terrain_autumn", GRASS, 1)], dict(sat=0.5, val=0.62, tint=(1.0, 0.97, 0.9))),
    ("forest", [("terrain_summer", GRASS, 1)], dict(sat=0.55, val=0.48, tint=(0.9, 1.0, 0.9))),
    ("fen", [("terrain_summer", GRASS, 1)], dict(sat=0.45, val=0.45, tint=(0.85, 1.0, 0.95), hue=0.04)),
    ("hills", [("terrain_autumn", GRASS, 1)], dict(sat=0.35, val=0.55, tint=(0.92, 1.0, 0.95), hue=0.05)),
    ("rock", [("cliff_summer", CLIFF, 1)], dict(sat=0.12, val=0.62, tint=(0.95, 0.97, 1.0))),
    ("road", [("terrain_summer", DIRT, 1)], dict(sat=0.55, val=0.66)),
    ("ashfield", [("terrain_summer", DIRT, 1)], dict(sat=0.1, val=0.4, tint=(1.0, 0.96, 0.94))),
]


def build_ground(src):
    rng = random.Random(7)
    sheets = {}
    atlas = Image.new("RGBA", (128 * len(GROUND), 128), (0, 0, 0, 0))
    colors = {}
    for i, (name, parts, g) in enumerate(GROUND):
        pool = []
        for sheet, tiles, weight in parts:
            if sheet not in sheets:
                sheets[sheet] = Image.open(os.path.join(src, T + sheet + ".png")).convert("RGBA")
            for t in tiles:
                pool += [(sheet, t)] * weight
        fill = Image.new("RGBA", (128, 128))
        for ty in range(4):
            for tx in range(4):
                sheet, (cx, cy) = rng.choice(pool)
                fill.alpha_composite(sheets[sheet].crop((cx * 32, cy * 32, cx * 32 + 32, cy * 32 + 32)), (tx * 32, ty * 32))
        fill = grade(fill, **g)
        atlas.alpha_composite(fill, (i * 128, 0))
        r, gg, b = fill.convert("RGB").resize((1, 1), Image.BOX).getpixel((0, 0))
        colors[name] = "#%02x%02x%02x" % (r, gg, b)
    atlas.save(os.path.join(OUT, "ground.png"), optimize=True)
    json.dump({"order": [n for n, _, _ in GROUND], "colors": colors}, open(os.path.join(OUT, "ground.json"), "w"), indent=1)


# ------------------------------------------------------------------ props

DARK_TREE = dict(sat=0.65, val=0.8, tint=(0.92, 1.0, 0.94))
PLANT = dict(sat=0.6, val=0.7, tint=(0.92, 1.0, 0.92))
STONE = dict(sat=0.35, val=0.72)
PROPS = {
    # name: (file, loose rect, grade or None, shadow)   foot = bottom centre of the trimmed sprite
    "oak_a": (T + "trees_summer.png", (129, 272, 223, 365), DARK_TREE, True),
    "oak_b": (T + "trees_summer.png", (225, 272, 319, 372), DARK_TREE, True),
    "oak_c": (T + "trees_summer.png", (321, 272, 415, 397), DARK_TREE, True),
    "pine_a": (T + "trees_summer.png", (132, 389, 217, 493), DARK_TREE, True),
    "pine_b": (T + "trees_summer.png", (228, 389, 313, 500), DARK_TREE, True),
    "pine_c": (T + "trees_summer.png", (324, 421, 409, 512), DARK_TREE, True),
    "pine_d": (T + "trees_summer.png", (420, 357, 505, 493), DARK_TREE, True),
    "dead_tree": (T + "trees_summer.png", (3, 274, 93, 397), dict(sat=0.5, val=0.7), True),
    "stump": (T + "trees_summer.png", (26, 437, 69, 468), dict(sat=0.6, val=0.75), False),
    "charred_stump": (T + "trees_summer.png", (26, 437, 69, 468), dict(sat=0.2, val=0.6), False),
    "log": (T + "trees_summer.png", (36, 493, 61, 557), dict(sat=0.6, val=0.75), False),   # rotated below
    "boulder_big": (T + "Rocks, Grasslands.png", (0, 256, 64, 350), STONE, False),
    "boulder_tall": (T + "Rocks, Grasslands.png", (66, 256, 120, 320), STONE, False),
    "boulder_round": (T + "Rocks, Grasslands.png", (128, 256, 192, 316), STONE, False),
    "boulder_low": (T + "Rocks, Grasslands.png", (64, 320, 124, 352), STONE, False),
    "rock_small": (T + "Rocks, Grasslands.png", (128, 324, 162, 352), STONE, False),
    "rock_small_b": (T + "Rocks, Grasslands.png", (128, 352, 162, 383), STONE, False),
    "pebbles": (T + "Rocks, Grasslands.png", (162, 330, 192, 350), STONE, False),
    "standing_stone": (T + "Rocks, Grasslands.png", (66, 0, 120, 64), dict(sat=0.3, val=0.8), False),
    "bush": (T + "plants_summer.png", (0, 0, 32, 32), PLANT, False),
    "leafy": (T + "plants_summer.png", (64, 0, 96, 32), PLANT, False),
    "leafy_b": (T + "plants_summer.png", (128, 0, 160, 32), PLANT, False),
    "fern": (T + "plants_summer.png", (99, 77, 154, 128), PLANT, False),
    "fern_big": (T + "plants_summer.png", (160, 76, 247, 128), PLANT, False),
    "shrub": (T + "plants_summer.png", (67, 77, 95, 126), PLANT, False),
    "reeds": (T + "plants_summer.png", (355, 0, 380, 53), PLANT, False),
    "reeds_b": (T + "plants_summer.png", (386, 0, 413, 53), PLANT, False),
    "grass_tuft": (T + "plants_summer.png", (263, 23, 285, 51), dict(sat=0.5, val=0.65), False),
    "grass_tuft_b": (T + "plants_summer.png", (259, 63, 286, 106), dict(sat=0.5, val=0.65), False),
    "lily": (T + "plants_summer.png", (386, 74, 412, 90), PLANT, False),
    "cattail": (T + "plants_summer.png", (456, 69, 469, 87), PLANT, False),
    "flower_w": (T + "plants_summer.png", (459, 43, 468, 49), dict(sat=0.6, val=0.8), False),
    "mushroom_red": (T + "mushrooms.png", (104, 35, 119, 55), dict(sat=0.7, val=0.8), False),
    "mushroom_brown": (T + "mushrooms.png", (136, 35, 151, 55), dict(sat=0.7, val=0.8), False),
    "mushrooms": (T + "mushrooms.png", (38, 98, 56, 121), dict(sat=0.7, val=0.8), False),
    "barrel": (FURN + "Barrel.png", (2, 10, 30, 47), None, False),
    "barrels": (FURN + "Barrel.png", (96, 2, 144, 63), None, False),
    "crate": (FURN + "Crate.png", (69, 37, 91, 61), None, False),
    "crate_b": (FURN + "Crate.png", (69, 101, 91, 125), None, False),
    "trough": (FURN + "Trough.png", (198, 80, 255, 118), None, False),
    "lamp": (FURN + "Lighting, Outdoors.png", (7, 4, 25, 84), None, False),
    "anvil": (FURN + "Smithing/Anvils.png", (75, 3, 121, 30), None, False),
    "coal": (FURN + "Smithing/Coal Piles.png", (259, 8, 318, 52), None, False),
    "cauldron": (FURN + "Cauldron.png", (1, 97, 32, 128), None, False),
    "sawhorse": (FURN + "Sawhorse.png", (5, 10, 32, 42), None, False),
}


def build_props(src):
    shadow = Image.open(os.path.join(src, T + "trees_summer.png")).convert("RGBA").crop((16, 25, 80, 56))
    sprites = {}
    for name, (f, rect, g, shade) in PROPS.items():
        im = trim(Image.open(os.path.join(src, f)).convert("RGBA").crop(rect))
        if name == "log":
            im = im.rotate(90, expand=True)
        if g:
            im = grade(im, **g)
        foot = (im.size[0] // 2, im.size[1] - 3)
        if shade:
            # a soft shadow under the trunk, wider than the sprite's base
            sh = shadow.copy()
            sh.putalpha(sh.split()[3].point(lambda a: a * 45 // 100))
            w = max(im.size[0], sh.size[0])
            canvas = Image.new("RGBA", (w, im.size[1] + sh.size[1] // 2), (0, 0, 0, 0))
            fx = w // 2
            fy = im.size[1] - 6
            canvas.alpha_composite(sh, (fx - sh.size[0] // 2, fy - sh.size[1] // 2))
            canvas.alpha_composite(im, (fx - im.size[0] // 2, 0))
            im, foot = canvas, (fx, fy)
        sprites[name] = (im, foot)
    # grid shelf-pack
    order = sorted(sprites, key=lambda n: -sprites[n][0].size[1])
    width, x, y, row_h, pos = 512, 0, 0, 0, {}
    for n in order:
        w = -(-sprites[n][0].size[0] // GRID) * GRID
        h = -(-sprites[n][0].size[1] // GRID) * GRID
        if x + w > width:
            x, y, row_h = 0, y + row_h, 0
        pos[n] = (x, y, w, h)
        x += w
        row_h = max(row_h, h)
    atlas = Image.new("RGBA", (width, y + row_h), (0, 0, 0, 0))
    meta = {}
    for n, (x, y, w, h) in pos.items():
        im, (fx, fy) = sprites[n]
        ox, oy = (w - im.size[0]) // 2, h - im.size[1]    # bottom-centre inside the grid cell block
        atlas.alpha_composite(im, (x + ox, y + oy))
        meta[n] = [x, y, w, h, ox + fx, oy + fy]
    atlas.save(os.path.join(OUT, "props.png"), optimize=True)
    json.dump({"grid": GRID, "props": meta}, open(os.path.join(OUT, "props.json"), "w"), indent=1)


# ------------------------------------------------------------------ buildings

BRICK = {  # brick colours per source house; everything else is graded like the roof
    "Brick House B.png": {(181, 73, 54), (149, 56, 28), (211, 139, 89), (123, 32, 8), (174, 107, 63)},
    "Brick House A.png": {(96, 52, 41), (68, 39, 37), (127, 76, 49)},
}
# Jagged Stone Walls.png: 2 columns x 3 rows of 96x96 textures
STONES = {"pale": (0, 0), "grey": (96, 0), "blue": (0, 96), "ochre": (96, 96), "dark": (0, 192), "gold": (96, 192)}
BUILDINGS = {
    # kind: (house file, stone, roof grade, mirror)
    "house_a": ("Brick House B.png", "grey", dict(sat=0.35, val=0.7, hue=0.02), False),
    "house_b": ("Brick House B.png", "pale", dict(sat=0.25, val=0.55, tint=(0.9, 0.95, 1.05)), True),
    "forge": ("Brick House B.png", "blue", dict(sat=0.2, val=0.62), False),
    "tavern": ("Brick House A.png", "grey", dict(sat=0.5, val=0.8), False),
}


def build_buildings(src):
    walls = Image.open(os.path.join(src, "Structure/Walls/Jagged Stone Walls.png")).convert("RGBA")
    os.makedirs(os.path.join(OUT, "buildings"), exist_ok=True)
    for kind, (f, stone, roof, mirror) in BUILDINGS.items():
        house = trim(Image.open(os.path.join(src, "Structure/Structures/" + f)).convert("RGBA"))
        sx, sy = STONES[stone]
        tex = walls.crop((sx, sy, sx + 96, sy + 96))
        tex = grade(tex, sat=0.7, val=0.85)
        other = grade(house, **roof)
        out = house.copy()
        glow = Image.new("RGBA", house.size, (0, 0, 0, 0))
        hp, op, tp, gp, ohp = house.load(), out.load(), tex.load(), glow.load(), other.load()
        for y in range(house.size[1]):
            for x in range(house.size[0]):
                r, g, b, a = hp[x, y]
                if a == 0:
                    continue
                if (r, g, b) in BRICK[f]:
                    op[x, y] = tp[x % 96, y % 96]
                elif (r, g, b) == (0, 0, 0):          # window panes
                    op[x, y] = (22, 20, 26, a)
                    gp[x, y] = (255, 190, 90, 255)
                else:
                    op[x, y] = ohp[x, y]
        if mirror:
            out = out.transpose(Image.FLIP_LEFT_RIGHT)
            glow = glow.transpose(Image.FLIP_LEFT_RIGHT)
        out.save(os.path.join(OUT, "buildings", kind + ".png"), optimize=True)
        glow.save(os.path.join(OUT, "buildings", kind + "_glow.png"), optimize=True)


# ------------------------------------------------------------------ landmarks

def build_landmarks(src):
    os.makedirs(os.path.join(OUT, "landmarks"), exist_ok=True)
    rocks = Image.open(os.path.join(src, T + "Rocks, Grasslands.png")).convert("RGBA")
    salt = dict(sat=0.2, val=0.75, tint=(0.95, 1.0, 1.05))
    tall = grade(trim(rocks.crop((66, 256, 120, 320))), **salt)
    big = grade(trim(rocks.crop((0, 256, 64, 350))), **salt)
    low = grade(trim(rocks.crop((64, 320, 124, 352))), **salt)
    # Barrow: a dark mound with a doorway, ringed by standing stones (back ones drawn first).
    W, H = 192, 150
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    cx, cy = W // 2, H - 44
    mound = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    mp = mound.load()
    for y in range(H):
        for x in range(W):
            dx, dy = (x - cx) / 70.0, (y - cy) / 32.0
            if dx * dx + dy * dy <= 1.0 and y <= cy + 10:
                shade = 0.75 + 0.25 * (1 - (y - (cy - 32)) / 50.0)
                n = ((x * 7 + y * 13) % 5) * 3
                mp[x, y] = (int((54 + n) * shade), int((58 + n) * shade), int((46 + n) * shade), 255)
    im.alpha_composite(mound)
    stones = [(-1.0, -0.2, tall), (-0.55, -0.85, big), (0.1, -1.0, tall), (0.7, -0.75, big), (1.0, -0.1, tall)]
    for sx, sy, st in stones:
        im.alpha_composite(st, (int(cx + sx * 74 - st.size[0] / 2), int(cy + sy * 34 - st.size[1])))
    # doorway
    for y in range(cy - 16, cy + 6):
        for x in range(cx - 10, cx + 11):
            if (x - cx) ** 2 / 100.0 + max(0, cy - 6 - y) ** 2 / 100.0 <= 1.0:
                im.putpixel((x, y), (14, 13, 12, 255))
    for sx, sy, st in [(-0.8, 0.6, low), (0.75, 0.55, low)]:
        im.alpha_composite(st, (int(cx + sx * 74 - st.size[0] / 2), int(cy + sy * 34 - st.size[1] + 10)))
    trim(im).save(os.path.join(OUT, "landmarks", "barrow.png"), optimize=True)

    walls = Image.open(os.path.join(src, "Structure/Walls/Jagged Stone Walls.png")).convert("RGBA")
    pillars = Image.open(os.path.join(src, "Structure/Pillars/Stone Pillar A.png")).convert("RGBA")
    soot = dict(sat=0.3, val=0.85)
    stone = grade(walls.crop((96, 0, 192, 96)), **soot)
    # Chapel of Ash: two broken wall stubs, a pillar pair and rubble.
    W, H = 200, 150
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    rng = random.Random(3)

    def wall(x0, w, h, base):
        for x in range(w):
            top = h - ((x // 6) * 37 % 5) * 5 - (20 if x > w * 0.6 else 0)   # broken, blocky top
            for y in range(max(0, top)):
                im.putpixel((x0 + x, base - y), stone.getpixel(((x0 + x) % 96, (base - y) % 96)))
            for y in range(max(0, top) - 2, max(0, top)):
                if y >= 0:
                    c = im.getpixel((x0 + x, base - y))
                    im.putpixel((x0 + x, base - y), (c[0] * 3 // 4, c[1] * 3 // 4, c[2] * 3 // 4, 255))
    wall(8, 70, 70, H - 20)
    wall(120, 72, 52, H - 26)
    # the sheet stacks four colourways; the top 96 px is one whole pale pillar
    p = trim(pillars.crop((0, 0, 32, 96)))
    p = grade(p, sat=0.3, val=0.7)
    im.alpha_composite(p, (82, H - 12 - p.size[1]))
    short = p.crop((0, p.size[1] - 44, p.size[0], p.size[1]))
    im.alpha_composite(short, (104, H - 10 - 44))
    for i in range(10):
        rx, ry, r = rng.randint(10, 190), rng.randint(H - 18, H - 4), rng.randint(2, 5)
        for y in range(ry - r, ry + r):
            for x in range(rx - r, rx + r):
                if 0 <= x < W and 0 <= y < H and (x - rx) ** 2 + (y - ry) ** 2 * 2 <= r * r:
                    im.putpixel((x, y), (38, 34, 32, 255) if (x + y) % 3 else (58, 52, 48, 255))
    trim(im).save(os.path.join(OUT, "landmarks", "chapel.png"), optimize=True)

    # Burnt watchtower: a round stone stump, charred toward the top.
    W, H = 90, 150
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dark = grade(walls.crop((96, 0, 192, 96)), sat=0.25, val=0.8)
    for x in range(12, 78):
        rel = (x - 45) / 33.0
        top = 20 + ((x // 5) * 29 % 4) * 6 + (30 if x > 55 else 0)
        for y in range(top, H - 8 + int(6 * (1 - rel * rel))):
            c = dark.getpixel((x % 96, y % 96))
            shade = 0.55 + 0.45 * (1 - abs(rel)) ** 0.5
            char = min(1.0, max(0.4, (y - top) / 50.0))
            im.putpixel((x, y), (int(c[0] * shade * char), int(c[1] * shade * char), int(c[2] * shade * char), 255))
    for y in range(80, 104):
        for x in range(38, 52):
            im.putpixel((x, y), (16, 12, 10, 255))
    trim(im).save(os.path.join(OUT, "landmarks", "ashen.png"), optimize=True)


# ------------------------------------------------------------------ credits

def write_credits(src):
    used = sorted({os.path.dirname(f) for f, _, _, _ in PROPS.values()} | {"Terrain", "Structure/Structures", "Structure/Walls", "Structure/Pillars"})
    with open(os.path.join(OUT, "CREDITS_WORLD.txt"), "w", encoding="utf-8") as out:
        out.write("World art for Ashgrave, derived from Eliza Wyatt's revised LPC assets:\n"
                  "https://github.com/ElizaWy/LPC  (per-folder credits below; OGA-BY 3.0 / CC-BY 3.0+ / CC0)\n"
                  "Modifications: cropped, recoloured and graded darker, recomposited (buildings re-skinned with\n"
                  "stone textures; landmarks assembled from rocks, walls and pillars).\n\n")
        for d in used:
            f = os.path.join(src, d, "Credits.txt")
            if os.path.exists(f):
                out.write("=" * 70 + "\n" + d + "\n" + "=" * 70 + "\n")
                out.write(open(f, encoding="utf-8", errors="replace").read().strip() + "\n\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="/tmp/eliza")
    args = ap.parse_args()
    if not os.path.isdir(os.path.join(args.src, "Terrain")):
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", REPO, args.src], check=True)
        subprocess.run(["git", "-C", args.src, "sparse-checkout", "set", "--no-cone"] + FOLDERS, check=True)
    os.makedirs(OUT, exist_ok=True)
    build_ground(args.src)
    build_props(args.src)
    build_buildings(args.src)
    build_landmarks(args.src)
    write_credits(args.src)
    print("world art written to", OUT)


if __name__ == "__main__":
    main()
