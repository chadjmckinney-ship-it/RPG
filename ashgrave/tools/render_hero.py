"""Render the hero (Maren, the Crimson Valkyrie) into Ashgrave's isometric sprite atlases.

Needs Blender 5.2, either the Python module (Python 3.13):
    python3.13 -m pip install bpy==5.2.2
    python3.13 tools/render_hero.py                 # every weapon variant -> art/hero/
    python3.13 tools/render_hero.py --preview run,slash --out /tmp/hero   # contact sheets only
or Blender itself:
    blender -b -P tools/render_hero.py -- [same options]

Source: art_src/hero/maren.blend (Meshy AI biped: textured mesh, 34-bone rig, Walking_Woman).
The script poses the rig frame by frame (tools/hero_anims.py, solved by tools/hero_rig.py), puts a
weapon in her right hand, and renders each frame from 8 facings with an orthographic camera at the
game's 2:1 isometric angle. Frames are downsampled to the LPC art's pixel density, given hard alpha,
trimmed and packed into art/hero/maren_<weapon>.png, described by art/hero/maren_<weapon>.json.
"""
import argparse
import json
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hero_anims  # noqa: E402
import hero_rig  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BLEND = os.path.join(ROOT, "art_src", "hero", "maren.blend")
OUT = os.path.join(ROOT, "art", "hero")

ELEVATION = 30.0          # camera pitch for a 2:1 dimetric view
PX_PER_M = 64.0           # art pixels per metre: about as tall on screen as the LPC cast at 2x,
                          # but drawn 1:1 so her realistic proportions keep their detail
SUPERSAMPLE = 2           # rendered pixels per art pixel before downsampling
FRAME = 256               # art-pixel canvas per frame before trimming (room for swings and falls)
FOOT = (128, 196)         # where the feet land on that canvas
OUTLINE = 2               # margin kept around each frame for the in-game outline (texels)
DIRECTIONS = 8            # facings, counter-clockwise on screen from east (0 = E, 2 = N, 4 = W, 6 = S)
HEAD_SCALE = 1.5          # bigger head and hair so she reads at sprite size
PALETTE = 128             # colours per atlas after quantising
# Sun lights fixed to the screen, as (name, energy, colour, direction of travel); the camera looks north.
LIGHTS = [
    ("Key", 6.5, (1.0, 0.93, 0.8), (0.8, 0.9, -1.2)),      # upper left, from the front
    ("Fill", 0.45, (0.65, 0.75, 1.0), (-1.0, 0.6, -0.3)),  # cool, from the right
    ("Rim", 3.6, (1.0, 0.75, 0.55), (-0.4, -1.0, -0.5)),   # warm, from behind
]
AMBIENT = ((0.55, 0.55, 0.6), 0.3)
GRADE = {"saturation": 1.12, "contrast": 1.15, "gamma": 1.04}


def parse_args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--blend", default=BLEND)
    ap.add_argument("--out", default=OUT)
    ap.add_argument("--variants", default=",".join(hero_anims.VARIANTS))
    ap.add_argument("--preview", default="", help="comma-separated animations: write contact sheets only")
    ap.add_argument("--dirs", default="", help="facings to preview, e.g. 6,7,0")
    ap.add_argument("--anims", default="", help="only these animations (atlas mode)")
    ap.add_argument("--samples", type=int, default=10)
    ap.add_argument("--cell", type=int, default=0, help="preview cell size in rendered pixels")
    return ap.parse_args(argv)


# ---------------------------------------------------------------------- scene


class Scene:
    def __init__(self, blend: str):
        bpy.ops.wm.open_mainfile(filepath=blend)
        self.scene = bpy.context.scene
        self.arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
        self.body = next(o for o in bpy.data.objects if o.type == "MESH" and o.parent == self.arm)
        for o in bpy.data.objects:
            if o.type == "LIGHT":
                bpy.data.objects.remove(o)
        self.walk = self.arm.animation_data.action if self.arm.animation_data else None
        if self.arm.animation_data:
            self.arm.animation_data.action = None
        for pb in self.arm.pose.bones:
            pb.rotation_mode = "QUATERNION"
        self.rig = hero_rig.Rig(self.arm, HEAD_SCALE)
        self.weapons = {}

    def setup(self, samples: int, px: int):
        """Render settings, plus (once) the world, lights and sprite camera."""
        s = self.scene
        s.render.engine = "CYCLES"
        s.cycles.device = "CPU"
        s.cycles.samples = samples
        s.cycles.use_denoising = True
        s.cycles.max_bounces = 4
        s.render.film_transparent = True
        s.render.resolution_x = px
        s.render.resolution_y = px
        s.render.resolution_percentage = 100
        s.render.image_settings.file_format = "PNG"
        s.render.image_settings.color_mode = "RGBA"
        s.view_settings.view_transform = "Standard"
        s.view_settings.look = "None"
        s.frame_set(1)
        if getattr(self, "cam", None) is None:
            self._build_stage()
        self._sprite_camera()

    def _build_stage(self):
        s = self.scene
        world = bpy.data.worlds.new("SpriteWorld")
        if world.node_tree is None:
            world.use_nodes = True
        bg = world.node_tree.nodes["Background"]
        bg.inputs[0].default_value = (*AMBIENT[0], 1.0)
        bg.inputs[1].default_value = AMBIENT[1]
        s.world = world
        self.cam = bpy.data.objects.new("SpriteCam", bpy.data.cameras.new("SpriteCam"))
        s.collection.objects.link(self.cam)
        self.cam.data.type = "ORTHO"
        s.camera = self.cam
        for name, energy, color, travel in LIGHTS:
            light = bpy.data.lights.new(name, "SUN")
            light.energy = energy
            light.color = color
            light.angle = math.radians(10.0)
            ob = bpy.data.objects.new(name, light)
            s.collection.objects.link(ob)
            ob.rotation_euler = Vector(travel).normalized().to_track_quat("-Z", "Y").to_euler()

    def _sprite_camera(self):
        """Orthographic, looking north and down at ELEVATION, with the canvas point FOOT on the origin."""
        cam = self.cam
        cam.data.ortho_scale = FRAME / PX_PER_M
        pitch = math.radians(ELEVATION)
        view = Vector((0.0, math.cos(pitch), -math.sin(pitch)))
        cam.rotation_euler = (-view).to_track_quat("Z", "Y").to_euler()
        right = Vector((1.0, 0.0, 0.0))
        up = right.cross(view).normalized()
        off_x = (FOOT[0] - FRAME / 2.0) / PX_PER_M
        off_y = (FRAME / 2.0 - FOOT[1]) / PX_PER_M
        cam.location = -view * 10.0 - right * off_x - up * off_y

    # ------------------------------------------------------------------ weapons

    def weapon(self, name: str):
        if name not in self.weapons:
            ob = hero_anims.build_weapon(name)
            ob.parent = self.arm
            ob.parent_type = "BONE"
            ob.parent_bone = "hand.R"
            self.weapons[name] = ob
        return self.weapons[name]

    def hold(self, name: str):
        for n, ob in self.weapons.items():
            ob.hide_render = n != name
        if name and name in hero_anims.WEAPONS:
            ob = self.weapon(name)
            ob.hide_render = False
            # grip in the closed fist: just behind the knuckles (bone tail), towards the palm
            bone = self.arm.data.bones["hand.R"]
            ob.matrix_parent_inverse = Matrix.Identity(4)
            ob.matrix_basis = Matrix.Translation((hero_rig.PALM_SIGN["R"] * 0.028, -0.035 * bone.length / 0.122, 0.0))

    # ------------------------------------------------------------------ posing

    def apply(self, basis: dict):
        for name, (loc, q, sc) in basis.items():
            pb = self.arm.pose.bones[name]
            pb.location = loc
            pb.rotation_quaternion = q
            pb.scale = (sc, sc, sc)
        bpy.context.view_layer.update()

    def action_basis(self, frame: float) -> dict:
        """The Meshy walk's pose at a frame, as pose-bone basis values."""
        vals = {}
        bag = self.walk.layers[0].strips[0].channelbags[0]
        for fc in bag.fcurves:
            if not fc.data_path.startswith("pose.bones"):
                continue
            name = fc.data_path.split('"')[1]
            prop = fc.data_path.rsplit(".", 1)[1]
            vals.setdefault(name, {}).setdefault(prop, {})[fc.array_index] = fc.evaluate(frame)
        out = {}
        for name in self.rig.order:
            v = vals.get(name, {})
            loc = Vector([v.get("location", {}).get(i, 0.0) for i in range(3)])
            rq = v.get("rotation_quaternion", {})
            q = Quaternion([rq.get(0, 1.0), rq.get(1, 0.0), rq.get(2, 0.0), rq.get(3, 0.0)])
            out[name] = (loc, q.normalized(), 1.0)
        return out

    def face(self, d: int, extra=0.0):
        """Turn her to facing d (0 = east, counter-clockwise, 6 = towards the viewer), plus extra degrees."""
        # d=6 (south/towards camera) is the model's own facing (-Y); each step is 45 degrees on the ground.
        self.arm.rotation_euler = (0.0, 0.0, math.radians((d - 6) * 45.0 + extra))
        bpy.context.view_layer.update()

    def render(self, path: str):
        self.scene.render.filepath = path
        bpy.ops.render.render(write_still=True)


# ---------------------------------------------------------------------- images

ALPHA_CUT = 0.42          # coverage that counts as an opaque art pixel
ATLAS_W = 1024


def _to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _to_srgb(c):
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * np.power(c, 1.0 / 2.4) - 0.055)


def pixelate(path: str, k: int) -> np.ndarray:
    """Box-filter a render k:1 in linear light and harden its alpha: uint8 RGBA art pixels."""
    img = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float32) / 255.0
    h, w = img.shape[0] // k, img.shape[1] // k
    a = img[..., 3:4]
    pre = (_to_lin(img[..., :3]) * a).reshape(h, k, w, k, 3).mean(axis=(1, 3))
    a = a.reshape(h, k, w, k, 1).mean(axis=(1, 3))
    rgb = _to_srgb(np.clip(pre / np.maximum(a, 1e-4), 0.0, 1.0))
    # grade towards the punchier LPC palette: saturation and contrast around mid grey
    lum = (rgb * np.array([0.3, 0.59, 0.11])).sum(axis=2, keepdims=True)
    rgb = lum + (rgb - lum) * GRADE["saturation"]
    rgb = np.clip(0.5 + (rgb - 0.5) * GRADE["contrast"], 0.0, 1.0) ** GRADE["gamma"]
    solid = a >= ALPHA_CUT
    out = np.concatenate([np.where(solid, rgb, 0.0), solid.astype(np.float32)], axis=2)
    return (out * 255.0 + 0.5).astype(np.uint8)


def trim(frame: np.ndarray):
    """Crop to the figure plus an OUTLINE margin (room for the in-game outline).
    Returns (pixels, (ox, oy) of the crop's corner relative to the feet, clipped?)."""
    ys, xs = np.nonzero(frame[..., 3])
    if len(xs) == 0:
        return np.zeros((1, 1, 4), np.uint8), (0, 0), False
    clipped = xs.min() == 0 or ys.min() == 0 or xs.max() == frame.shape[1] - 1 or ys.max() == frame.shape[0] - 1
    x0, y0 = max(int(xs.min()) - OUTLINE, 0), max(int(ys.min()) - OUTLINE, 0)
    x1, y1 = min(int(xs.max()) + 1 + OUTLINE, frame.shape[1]), min(int(ys.max()) + 1 + OUTLINE, frame.shape[0])
    return frame[y0:y1, x0:x1], (x0 - FOOT[0], y0 - FOOT[1]), clipped


def pack(crops: list):
    """Shelf-pack crops (tallest first) into an ATLAS_W-wide sheet; returns (sheet, [(x, y)])."""
    order = sorted(range(len(crops)), key=lambda i: (-crops[i].shape[0], -crops[i].shape[1]))
    pos = [None] * len(crops)
    x = y = shelf = 0
    for i in order:
        h, w = crops[i].shape[:2]
        if x + w > ATLAS_W:
            x, y, shelf = 0, y + shelf + 1, 0
        pos[i] = (x, y)
        x += w + 1
        shelf = max(shelf, h)
    height = y + shelf
    sheet = np.zeros((height, ATLAS_W, 4), np.uint8)
    for c, (px, py) in zip(crops, pos):
        sheet[py:py + c.shape[0], px:px + c.shape[1]] = c
    return sheet, pos


def quantize(sheet: np.ndarray, colors: int) -> np.ndarray:
    """One shared palette for the whole sheet (median cut, no dithering)."""
    rgb = Image.fromarray(sheet[..., :3]).quantize(colors=colors, method=Image.Quantize.MEDIANCUT,
                                                   dither=Image.Dither.NONE).convert("RGB")
    out = sheet.copy()
    out[..., :3] = np.asarray(rgb)
    out[sheet[..., 3] == 0] = 0
    return out


def build_atlas(sc: "Scene", anims: dict, variant: str, args):
    spec = hero_anims.VARIANTS[variant]
    names = ["idle", "ready", "walk", "run"] + spec["attacks"] + ["die"]
    if args.anims:
        names = [n for n in names if n in args.anims.split(",")]
    sc.setup(args.samples, FRAME * SUPERSAMPLE)
    sc.hold(spec["weapon"])
    tmp = os.path.join(args.out, "_frame.png")
    crops, where = [], []
    for name in names:
        a = anims[name]
        for fi in range(a["frames"]):
            sc.apply(a["pose"](fi, variant))
            for d in range(DIRECTIONS):
                sc.face(d, a["yaw"](fi, d) if "yaw" in a else 0.0)
                sc.render(tmp)
                crop, off, clipped = trim(pixelate(tmp, SUPERSAMPLE))
                if clipped:
                    print(f"WARNING {variant} {name} frame {fi} facing {d} touches the canvas edge")
                crops.append(crop)
                where.append((name, fi, d, off))
        print(f"{variant}: {name} done ({a['frames']} frames x {DIRECTIONS})", flush=True)
    sheet, pos = pack(crops)
    sheet = quantize(sheet, PALETTE)
    meta = {
        "variant": variant, "weapon": spec["weapon"], "attacks": spec["attacks"],
        "directions": DIRECTIONS, "px_per_m": PX_PER_M, "elevation": ELEVATION,
        "anims": {},
    }
    for (name, fi, d, off), crop, (x, y) in zip(where, crops, pos):
        a = anims[name]
        entry = meta["anims"].setdefault(name, {"fps": a["fps"], "loop": a["loop"],
                                                 "frames": [[None] * DIRECTIONS for _ in range(a["frames"])]})
        entry["frames"][fi][d] = [x, y, crop.shape[1], crop.shape[0], off[0], off[1]]
    base = os.path.join(args.out, "maren_" + variant)
    Image.fromarray(sheet, "RGBA").save(base + ".png", optimize=True)
    with open(base + ".json", "w") as f:
        json.dump(meta, f, separators=(",", ":"))
    print(f"wrote {base}.png {sheet.shape[1]}x{sheet.shape[0]}, {len(crops)} frames")


PORTRAIT = 56              # portrait size in art pixels (HUD cards draw it 1:1, dialogue at 2x)


def build_portrait(sc: "Scene", anims: dict, args):
    """Head-and-shoulders close-up for the HUD: idle pose, turned a little, seen from just above."""
    k = 4
    sc.setup(args.samples * 2, PORTRAIT * k)
    sc.hold("")
    sc.apply(anims["idle"]["pose"](0, "longsword"))
    sc.face(6, -18.0)
    neck = sc.arm.matrix_world @ sc.arm.pose.bones[hero_rig.NECK].head
    target = neck + Vector((0.0, 0.0, 0.07))
    pitch = math.radians(12.0)
    view = Vector((0.0, math.cos(pitch), -math.sin(pitch)))
    sc.cam.data.ortho_scale = 0.6
    sc.cam.location = target - view * 5.0
    sc.cam.rotation_euler = (-view).to_track_quat("Z", "Y").to_euler()
    tmp = os.path.join(args.out, "_portrait.png")
    sc.render(tmp)
    px = pixelate(tmp, k)
    path = os.path.join(args.out, "maren_portrait.png")
    Image.fromarray(quantize(px, PALETTE), "RGBA").save(path, optimize=True)
    print("wrote", path)


def main():
    args = parse_args()
    os.makedirs(args.out, exist_ok=True)
    sc = Scene(args.blend)
    anims = hero_anims.build(sc)
    if args.preview:
        preview(sc, anims, args)
        return
    for variant in args.variants.split(","):
        build_atlas(sc, anims, variant, args)
    if not args.anims:
        build_portrait(sc, anims, args)


def preview(sc: Scene, anims: dict, args):
    cell = args.cell or FRAME * 2
    sc.setup(args.samples, cell)
    dirs = [int(d) for d in args.dirs.split(",")] if args.dirs else [6, 7, 0, 1, 2, 4]
    variant = args.variants.split(",")[0]
    sc.hold(hero_anims.VARIANTS[variant]["weapon"])
    tmp = os.path.join(args.out, "_frame.png")
    for name in args.preview.split(","):
        a = anims[name]
        n = a["frames"]
        sheet = Image.new("RGBA", (cell * n, cell * len(dirs)), (64, 70, 60, 255))
        for fi in range(n):
            sc.apply(a["pose"](fi, variant))
            for di, d in enumerate(dirs):
                sc.face(d, a["yaw"](fi, d) if "yaw" in a else 0.0)
                sc.render(tmp)
                im = Image.open(tmp).convert("RGBA")
                sheet.alpha_composite(im, (fi * cell, di * cell))
        sheet.save(os.path.join(args.out, f"preview_{variant}_{name}.png"))
        print("wrote", name, n, "frames")


if __name__ == "__main__":
    main()
