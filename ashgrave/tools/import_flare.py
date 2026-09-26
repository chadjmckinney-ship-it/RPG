#!/usr/bin/env python3
"""Repack Flare (flareteam/flare-game, CC-BY-SA 3.0) art for Ashgrave.

Creatures: keeps only the animations the game uses, scales frames to game size and packs
them into a compact atlas with a JSON index:
    art/flare/creatures/<key>.png + <key>.json
    {"anims": {name: {"ms": duration, "type": looped|play_once|back_forth, "frames": n,
                      "dirs": [[[x, y, w, h, ox, oy], ...frames] x 8 directions]}}}
Flare direction order in screen terms: 0=W 1=NW 2=N 3=NE 4=E 5=SE 6=S 7=SW.
Portraits: copies the chosen painted portraits to art/flare/portraits/.

Usage: python3 tools/import_flare.py [--flare /tmp/flare]   (needs Pillow and git)
"""
import argparse, json, os, re, shutil, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.path.join(GAME, "art", "flare")
REPO = "https://github.com/flareteam/flare-game.git"

# key: (animation file, scale)
CREATURES = {
    # key: (animation file, scale, animations kept)
    "skeleton": ("enemies/skeleton.txt", 0.62, ["idle", "walk", "attack", "hit", "die"]),
    "skeleton_mage": ("enemies/skeleton_mage.txt", 0.62, ["idle", "walk", "attack", "cast", "hit", "die"]),
    "skeleton_knight_boss": ("enemies/skeleton_knight_boss.txt", 0.62, ["idle", "walk", "attack", "hit", "die"]),
    "zombie": ("enemies/zombie.txt", 0.62, ["idle", "walk", "attack", "hit", "die"]),
    "zombie_dark": ("enemies/zombie_dark.txt", 0.62, ["idle", "walk", "attack", "hit", "die"]),
    "goblin_runner": ("enemies/goblin_runner.txt", 0.62, ["idle", "walk", "attack", "hit", "die"]),
    "ice_ant": ("enemies/ice_ant.txt", 0.5, ["idle", "walk", "attack", "hit", "die"]),
    "antlion": ("enemies/antlion.txt", 0.55, ["idle", "walk", "attack", "hit", "die"]),
    "antlion_small": ("enemies/antlion_small.txt", 0.55, ["idle", "walk", "attack", "hit", "die"]),
    "cursed_grave": ("enemies/cursed_grave.txt", 0.55, ["idle"]),
}
ANIMS = {"stance": "idle", "run": "walk", "swing": "attack", "cast": "cast", "hit": "hit", "die": "die"}
PORTRAITS = ["female01", "female02", "female04", "female05", "female06", "female09", "female12", "female13", "female14",
             "male01", "male02", "male03", "male05", "male06", "male10", "male11", "male14", "male16", "male18", "male19", "male20"]


def find(root, rel):
    for mod in ("fantasycore", "empyrean_campaign"):
        p = os.path.join(root, "mods", mod, rel)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(rel)


def parse(path):
    anims, cur, image = {}, None, None
    for line in open(path):
        line = line.strip()
        if line.startswith("image="):
            image = line.split("=", 1)[1]
        m = re.match(r"\[(\w+)\]", line)
        if m:
            cur = m.group(1)
            anims[cur] = {"frames": {}, "count": 0, "ms": 500, "type": "looped"}
        elif cur and line.startswith("frames="):
            anims[cur]["count"] = int(line.split("=")[1])
        elif cur and line.startswith("duration="):
            v = line.split("=")[1]
            anims[cur]["ms"] = int(float(v[:-2])) if v.endswith("ms") else int(float(v.rstrip("s")) * 1000)
        elif cur and line.startswith("type="):
            anims[cur]["type"] = line.split("=")[1]
        elif cur and line.startswith("frame="):
            v = [int(x) for x in line.split("=")[1].split(",")]
            anims[cur]["frames"][(v[0], v[1])] = v[2:]
    return image, anims


def pack(frames, width=2048):
    """Shelf-pack a list of images; returns positions and atlas size."""
    order = sorted(range(len(frames)), key=lambda i: -frames[i].size[1])
    pos, x, y, row_h = [None] * len(frames), 0, 0, 0
    for i in order:
        w, h = frames[i].size
        if x + w > width:
            x, y, row_h = 0, y + row_h + 1, 0
        pos[i] = (x, y)
        x += w + 1
        row_h = max(row_h, h)
    return pos, (width, y + row_h)


def creature(root, key, rel, scale, keep):
    image, anims = parse(find(root, "animations/" + rel))
    src = Image.open(find(root, image)).convert("RGBA")
    crops, refs, meta = [], [], {"anims": {}, "scale": scale}
    for fa, name in ANIMS.items():
        if fa not in anims or name not in keep:
            continue
        a = anims[fa]
        dirs = []
        for d in range(8):
            rects = []
            for i in range(a["count"]):
                f = a["frames"].get((i, d))
                if not f:
                    continue
                x, y, w, h, ox, oy = f
                im = src.crop((x, y, x + w, y + h))
                sw, sh = max(1, round(w * scale)), max(1, round(h * scale))
                crops.append(im.resize((sw, sh), Image.LANCZOS))
                refs.append((name, d, len(rects)))
                rects.append([0, 0, sw, sh, round(ox * scale), round(oy * scale)])
            dirs.append(rects)
        meta["anims"][name] = {"ms": a["ms"], "type": a["type"], "frames": a["count"], "dirs": dirs}
    pos, size = pack(crops)
    atlas = Image.new("RGBA", size, (0, 0, 0, 0))
    for im, p, (name, d, i) in zip(crops, pos, refs):
        atlas.alpha_composite(im, p)
        meta["anims"][name]["dirs"][d][i][0] = p[0]
        meta["anims"][name]["dirs"][d][i][1] = p[1]
    os.makedirs(os.path.join(OUT, "creatures"), exist_ok=True)
    # 256-colour palette keeps the files small; the pre-rendered art survives it well.
    atlas.quantize(colors=256, method=Image.FASTOCTREE, dither=Image.NONE).save(os.path.join(OUT, "creatures", key + ".png"), optimize=True)
    json.dump(meta, open(os.path.join(OUT, "creatures", key + ".json"), "w"), separators=(",", ":"))
    return atlas.size


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flare", default="/tmp/flare")
    args = ap.parse_args()
    if not os.path.isdir(os.path.join(args.flare, "mods")):
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", REPO, args.flare], check=True)
        subprocess.run(["git", "-C", args.flare, "sparse-checkout", "set", "mods/fantasycore/images", "mods/fantasycore/animations",
                        "mods/empyrean_campaign/images", "mods/empyrean_campaign/animations", "mods/fantasycore/tilesetdefs"], check=True)
    for key, (rel, scale, keep) in CREATURES.items():
        print(key, creature(args.flare, key, rel, scale, keep))
    os.makedirs(os.path.join(OUT, "portraits"), exist_ok=True)
    for p in PORTRAITS:
        im = Image.open(find(args.flare, "images/portraits/%s.png" % p)).convert("RGBA").resize((160, 160), Image.LANCZOS)
        im.save(os.path.join(OUT, "portraits", p + ".png"), optimize=True)
    shutil.copy(os.path.join(args.flare, "LICENSE.txt"), os.path.join(OUT, "LICENSE_CC-BY-SA-3.0.txt"))
    shutil.copy(os.path.join(args.flare, "CREDITS.txt"), os.path.join(OUT, "CREDITS_FLARE.txt"))


if __name__ == "__main__":
    main()
