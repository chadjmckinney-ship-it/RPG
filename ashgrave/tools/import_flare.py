#!/usr/bin/env python3
"""Import Flare (flareteam/flare-game, CC-BY-SA 3.0) portraits for Ashgrave.

Copies the chosen painted portraits to art/flare/portraits/ (160x160), plus Flare's
license and credits. Characters and creatures are LPC (see import_lpc.py).

Usage: python3 tools/import_flare.py [--flare /tmp/flare]   (needs Pillow and git)
"""
import argparse, os, shutil, subprocess
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
GAME = os.path.dirname(HERE)
OUT = os.path.join(GAME, "art", "flare")
REPO = "https://github.com/flareteam/flare-game.git"

PORTRAITS = ["female01", "female02", "female04", "female05", "female06", "female09", "female12", "female13", "female14",
             "male01", "male02", "male03", "male05", "male06", "male10", "male11", "male14", "male16", "male18", "male19", "male20"]


def find(root, rel):
    for mod in ("fantasycore", "empyrean_campaign"):
        p = os.path.join(root, "mods", mod, rel)
        if os.path.exists(p):
            return p
    raise FileNotFoundError(rel)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--flare", default="/tmp/flare")
    args = ap.parse_args()
    if not os.path.isdir(os.path.join(args.flare, "mods")):
        subprocess.run(["git", "clone", "-q", "--depth", "1", "--filter=blob:none", "--sparse", REPO, args.flare], check=True)
        subprocess.run(["git", "-C", args.flare, "sparse-checkout", "set", "mods/fantasycore/images/portraits"], check=True)
    os.makedirs(os.path.join(OUT, "portraits"), exist_ok=True)
    for p in PORTRAITS:
        im = Image.open(find(args.flare, "images/portraits/%s.png" % p)).convert("RGBA").resize((160, 160), Image.LANCZOS)
        im.save(os.path.join(OUT, "portraits", p + ".png"), optimize=True)
    shutil.copy(os.path.join(args.flare, "LICENSE.txt"), os.path.join(OUT, "LICENSE_CC-BY-SA-3.0.txt"))
    shutil.copy(os.path.join(args.flare, "CREDITS.txt"), os.path.join(OUT, "CREDITS_FLARE.txt"))


if __name__ == "__main__":
    main()
