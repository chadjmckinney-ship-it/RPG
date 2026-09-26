#!/usr/bin/env python3
"""Bake LPC (Liberated Pixel Cup) characters into single atlases for Ashgrave.

Reads recipes from tools/lpc_recipes.json, fetches only the needed sprite sheets from
the Universal LPC Spritesheet Character Generator (sparse git clone), recolours them with
the LPC palettes, composites the layers by z-order and writes, per character:
    art/lpc/chars/<id>.png   body + clothes (no weapon)
    art/lpc/weapons/<id>_front.png / _behind.png   per weapon, same layout
    art/lpc/layout.json      shared animation layout
and art/lpc/CREDITS_LPC.csv with the authors/licenses of every source file used.

Usage: python3 tools/import_lpc.py [--lpc /tmp/lpc]   (needs Pillow and git)
"""
import argparse, csv, glob, json, os, subprocess, sys
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.path.join(GAME, "art", "lpc")
REPO = "https://github.com/LiberatedPixelCup/Universal-LPC-Spritesheet-Character-Generator.git"

# name, frame size, frames, direction rows, source file (body sheet), custom-animation names
LAYOUT = [
    ("idle", 64, 2, 4, "idle", None),
    ("walk", 64, 9, 4, "walk", None),
    ("slash", 64, 6, 4, "slash", None),
    ("slash_big", 192, 6, 4, "slash", ("slash_oversize", "slash_128")),
    ("thrust", 64, 8, 4, "thrust", None),
    ("shoot", 64, 13, 4, "shoot", None),
    ("cast", 64, 7, 4, "spellcast", None),
    ("hurt", 64, 6, 1, "hurt", None),
]
WIDTH = max(size * frames for _, size, frames, _, _, _ in LAYOUT)


def layout_json():
    y, out = 0, {}
    for name, size, frames, rows, _, _ in LAYOUT:
        out[name] = {"y": y, "size": size, "frames": frames, "rows": rows}
        y += size * rows
    return out, y


class Lpc:
    def __init__(self, root):
        self.root = root
        self.defs = {os.path.basename(f)[:-5]: json.load(open(f)) for f in glob.glob(os.path.join(root, "sheet_definitions/**/*.json"), recursive=True)}
        self.fetched = set()
        self.used = set()

    # ---- palettes
    def palette(self, material, pal, color):
        f = os.path.join(self.root, "palette_definitions", material, "%s_%s.json" % (material, pal))
        if not os.path.exists(f):
            return None
        return json.load(open(f)).get(color)

    def find_colors(self, material, palettes, color):
        for p in palettes + ["ulpc", "lpcr"]:
            mat, pal = (p.split(".") + [None])[:2] if "." in p else (material, p)
            if pal is None:
                mat, pal = material, mat
            c = self.palette(mat, pal, color)
            if c:
                return c
        raise SystemExit("colour %r not found for %s %s" % (color, material, palettes))

    def recolor_map(self, rec, colors):
        """rec: recolors dict from a sheet definition; colors: {'color_1': name, ...} or {'color': name}."""
        out = {}
        specs = {k: v for k, v in rec.items() if k.startswith("color_")} or {"color": rec}
        for key, spec in specs.items():
            want = colors.get(key) or colors.get("color")
            if not want or "material" not in spec:
                continue
            mat = spec["material"]
            base = spec.get("base") or json.load(open(os.path.join(self.root, "palette_definitions", mat, "meta_%s.json" % mat)))["base"]
            src = self.find_colors(mat, spec.get("palettes", ["ulpc"]), base)
            dst = self.find_colors(mat, spec.get("palettes", ["ulpc"]), want)
            for a, b in zip(src, dst):
                out[a.lower()] = tuple(int(b[i:i + 2], 16) for i in (1, 3, 5))
        return out

    # ---- files
    def fetch(self, paths):
        need = sorted({p for p in paths if p not in self.fetched})
        if need:
            subprocess.run(["git", "-C", self.root, "sparse-checkout", "add"] + ["spritesheets/" + p.rstrip("/") for p in need], check=True, capture_output=True)
            self.fetched.update(need)

    def file(self, path, anim, variant):
        for cand in (f"{path}{anim}.png", f"{path}{anim}/{variant}.png", f"{path}{variant}.png"):
            full = os.path.join(self.root, "spritesheets", cand)
            if os.path.exists(full):
                return cand
        return None

    def layers(self, item, body):
        d = self.defs.get(item["def"])
        if d is None:
            raise SystemExit("unknown LPC item %r" % item["def"])
        out = []
        for key, layer in d.items():
            if not key.startswith("layer_"):
                continue
            path = layer.get(body) or layer.get("male") or layer.get("female")
            if path:
                variant = item.get("variant") or (d.get("variants") or [None])[0]
                out.append({"z": layer.get("zPos", 0) + item.get("z_bias", 0), "path": path, "custom": layer.get("custom_animation"),
                            "variant": variant.replace(" ", "_") if variant else None, "def": d, "item": item})
        return out


def load_rgba(path):
    return Image.open(path).convert("RGBA")


def recolor(img, cmap, tint=None):
    if not cmap and not tint:
        return img
    px = img.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            key = "#%02x%02x%02x" % (r, g, b)
            if key in cmap:
                r, g, b = cmap[key]
            if tint:
                r, g, b = int(r * tint[0]), int(g * tint[1]), int(b * tint[2])
            px[x, y] = (r, g, b, a)
    return img


def bake(lpc, recipe_layers, body, out_png, credits):
    """Composite the given layers into one atlas following LAYOUT."""
    layout, height = layout_json()
    atlas = Image.new("RGBA", (WIDTH, height), (0, 0, 0, 0))
    lpc.fetch([l["path"] for l in recipe_layers])
    for name, size, frames, rows, src, customs in LAYOUT:
        y0 = layout[name]["y"]
        sheet = Image.new("RGBA", (size * frames, size * rows), (0, 0, 0, 0))
        drawn = False
        for l in sorted(recipe_layers, key=lambda l: l["z"]):
            if l["custom"]:
                if not customs or l["custom"] not in customs:
                    continue
                f = lpc.file(l["path"], src, l["variant"])
                if not f:
                    continue
                img = load_rgba(os.path.join(lpc.root, "spritesheets", f))
                layer_size = 128 if l["custom"].endswith("_128") else 192
                offset = (size - layer_size) // 2
            else:
                if customs and l["def"].get("layer_1") is not None and any(
                        ll.get("custom_animation") in customs for k, ll in l["def"].items() if k.startswith("layer_")):
                    # This item draws its own oversize attack; skip its standard layers for this animation.
                    continue
                f = lpc.file(l["path"], src, l["variant"])
                if not f and name == "idle":
                    f = lpc.file(l["path"], "walk", l["variant"])  # standing frame fallback
                if not f:
                    continue
                img = load_rgba(os.path.join(lpc.root, "spritesheets", f))
                layer_size, offset = 64, (size - 64) // 2
            rec = l["def"].get("recolors") or {}
            if not l["item"].get("variant") and rec:
                img = recolor(img, lpc.recolor_map(rec, l["item"]), l["item"].get("tint"))
            elif l["item"].get("tint"):
                img = recolor(img, {}, l["item"]["tint"])
            lpc.used.add(f)
            credits.add(f)
            src_frames = img.size[0] // layer_size
            src_rows = img.size[1] // layer_size
            for row in range(rows):
                if row >= src_rows:
                    continue
                for col in range(frames):
                    c = col if col < src_frames else 0
                    if name == "idle" and src_frames > frames and "walk" in f:
                        c = 0
                    tile = img.crop((c * layer_size, row * layer_size, (c + 1) * layer_size, (row + 1) * layer_size))
                    sheet.alpha_composite(tile, (col * size + offset, row * size + offset))
                    drawn = True
        if drawn:
            atlas.alpha_composite(sheet, (0, y0))
    os.makedirs(os.path.dirname(out_png), exist_ok=True)
    atlas.save(out_png, optimize=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lpc", default="/tmp/lpc")
    ap.add_argument("--only", default="")
    args = ap.parse_args()
    if not os.path.isdir(os.path.join(args.lpc, "sheet_definitions")):
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", REPO, args.lpc], check=True)
        subprocess.run(["git", "-C", args.lpc, "sparse-checkout", "set", "sheet_definitions", "palette_definitions"], check=True)
    lpc = Lpc(args.lpc)
    recipes = json.load(open(os.path.join(HERE, "lpc_recipes.json")))
    credits = set()
    layout, height = layout_json()
    # Fetch every needed folder first: baking right after a partial fetch can miss files.
    all_layers = []
    for w in recipes["weapons"].values():
        for body in ("female", "male"):
            all_layers += lpc.layers(w, body)
    for c in recipes["characters"].values():
        for item in c["layers"]:
            ls = lpc.layers(item, c["body"])
            all_layers += ls
            for l in ls:
                if not l["custom"] and not lpc.file(l["path"], "walk", l["variant"]) and os.path.isdir(os.path.join(lpc.root, "spritesheets", l["path"])):
                    print("WARNING: %s (%s) has no walk sheet at %s" % (item["def"], l["variant"], l["path"]))
    lpc.fetch([l["path"] for l in all_layers])
    meta = {"layout": layout, "width": WIDTH, "height": height, "characters": {}, "weapons": {}}
    for wid, w in recipes["weapons"].items():
        for body in ("female", "male"):
            if args.only and args.only not in wid:
                continue
            ls = lpc.layers(w, body)
            bake(lpc, [l for l in ls if l["z"] < 10], body, os.path.join(OUT, "weapons", "%s_%s_behind.png" % (wid, body)), credits)
            bake(lpc, [l for l in ls if l["z"] >= 10], body, os.path.join(OUT, "weapons", "%s_%s_front.png" % (wid, body)), credits)
        meta["weapons"][wid] = {"attack": w.get("attack", "slash_big")}
        print("weapon", wid)
    for cid, c in recipes["characters"].items():
        if args.only and args.only not in cid:
            continue
        body = c["body"]
        ls = []
        for item in c["layers"]:
            ls += lpc.layers(item, body)
        bake(lpc, ls, body, os.path.join(OUT, "chars", cid + ".png"), credits)
        meta["characters"][cid] = {"body": body, "weapon": c.get("weapon", "")}
        print("char", cid)
    if not args.only:
        json.dump(meta, open(os.path.join(OUT, "layout.json"), "w"), indent=1)
        # credits: match each used file against LPC's CREDITS.csv
        rows = list(csv.reader(open(os.path.join(args.lpc, "CREDITS.csv"), encoding="utf-8")))
        header, body_rows = rows[0], rows[1:]
        used = sorted(credits)
        with open(os.path.join(OUT, "CREDITS_LPC.csv"), "w", newline="", encoding="utf-8") as fh:
            wr = csv.writer(fh)
            wr.writerow(header)
            by_name = {r[0]: r for r in body_rows}
            written, missing = set(), set()
            for u in used:
                # exact file, else the animation-level file ("<dir>/hurt.png" for "<dir>/hurt/white.png"), else same folder
                cands = [u, os.path.dirname(u) + ".png"]
                row = next((by_name[c] for c in cands if c in by_name), None)
                if row is None:
                    folder = os.path.dirname(os.path.dirname(u))
                    row = next((r for r in body_rows if r[0].startswith(folder + "/")), None)
                if row is None:
                    missing.add(u)
                elif row[0] not in written:
                    written.add(row[0])
                    wr.writerow(row)
            if missing:
                print("WARNING: no credits row for", sorted(missing)[:10])
        print("credits for", len(used), "source files")


if __name__ == "__main__":
    main()
