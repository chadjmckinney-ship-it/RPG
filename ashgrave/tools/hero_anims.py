"""The hero's animation set and weapons (used by tools/render_hero.py).

Each animation is {"frames", "fps", "loop", "pose": f(frame, variant) -> pose-bone basis}. Walk
replays the Meshy Walking_Woman action with the sword hand overridden; the rest are posed here
with tools/hero_rig.py (all positions in metres, in the armature's frame: she faces -Y).
"""
import math

import bmesh
import bpy
from mathutils import Matrix, Vector

from hero_rig import BACK, DOWN, FWD, LEFT, RIGHT, UP, dir_, lerp_pose

# Weapon art per variant, and the attacks each variant rotates through (as in LPC layout.json).
VARIANTS = {
    "longsword": {"weapon": "longsword", "attacks": ["slash", "slash_rev", "thrust"]},
    "spear": {"weapon": "spear", "attacks": ["thrust"]},
}
WEAPONS = ("longsword", "spear")


# ---------------------------------------------------------------------- weapons


def _mat(name, color, metallic=0.0, rough=0.5):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    if m.node_tree is None:
        m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = rough
    return m


def _blade(bm, z0, z1, tip, w0, w1, thick, mat_index):
    """Diamond-section blade along +Z: width along Y, thickness along X."""
    rings = []
    for z, w in ((z0, w0), (z1, w1)):
        rings.append([bm.verts.new(v) for v in ((0, w / 2, z), (thick / 2, 0, z), (0, -w / 2, z), (-thick / 2, 0, z))])
    point = bm.verts.new((0, 0, tip))
    faces = [bm.faces.new((rings[0][i], rings[0][(i + 1) % 4], rings[1][(i + 1) % 4], rings[1][i])) for i in range(4)]
    faces += [bm.faces.new((rings[1][i], rings[1][(i + 1) % 4], point)) for i in range(4)]
    faces.append(bm.faces.new(list(reversed(rings[0]))))
    for f in faces:
        f.material_index = mat_index


def _prim(bm, kind, mat_index, matrix, **kw):
    before = set(bm.faces)
    if kind == "cube":
        bmesh.ops.create_cube(bm, size=1.0, matrix=matrix)
    elif kind == "cyl":
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=kw.get("segments", 8),
                              radius1=kw["r1"], radius2=kw["r2"], depth=kw["depth"], matrix=matrix)
    elif kind == "ball":
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=kw["r"], matrix=matrix)
    for f in set(bm.faces) - before:
        f.material_index = mat_index


def build_weapon(name: str):
    """A low-poly weapon with its grip centred on the origin and the blade/point along +Z."""
    # mostly diffuse: there is little around a sprite for polished metal to reflect
    steel = _mat("hero_steel", (0.86, 0.88, 0.92), metallic=0.3, rough=0.3)
    brass = _mat("hero_brass", (0.9, 0.64, 0.24), metallic=0.5, rough=0.35)
    crimson = _mat("hero_crimson", (0.5, 0.05, 0.05), rough=0.6)
    wood = _mat("hero_wood", (0.36, 0.22, 0.12), rough=0.7)
    bm = bmesh.new()
    T = Matrix.Translation
    if name == "longsword":
        mats = [steel, brass, crimson]
        _blade(bm, 0.10, 0.84, 1.0, 0.062, 0.05, 0.014, 0)
        _prim(bm, "cube", 1, T((0, 0, 0.088)) @ Matrix.Diagonal((0.036, 0.25, 0.03, 1)))
        _prim(bm, "cyl", 2, T((0, 0, -0.01)), r1=0.018, r2=0.018, depth=0.17)
        _prim(bm, "ball", 1, T((0, 0, -0.115)), r=0.032)
    elif name == "spear":
        mats = [steel, brass, crimson, wood]
        _prim(bm, "cyl", 3, T((0, 0, 0.3)), r1=0.017, r2=0.015, depth=1.8)
        _prim(bm, "cyl", 1, T((0, 0, 1.235)), r1=0.019, r2=0.024, depth=0.07)
        _prim(bm, "cyl", 2, T((0, 0, 1.15)), r1=0.03, r2=0.022, depth=0.1)
        _blade(bm, 1.27, 1.38, 1.62, 0.03, 0.085, 0.016, 0)
    else:
        raise ValueError(name)
    me = bpy.data.meshes.new("hero_" + name)
    bm.to_mesh(me)
    bm.free()
    for m in mats:
        me.materials.append(m)
    for poly in me.polygons:
        poly.use_smooth = False
    ob = bpy.data.objects.new("hero_" + name, me)
    bpy.context.scene.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------------- helpers


def cyc(i, n, phase=0.0):
    """Cosine over a loop of n frames."""
    return math.cos(2.0 * math.pi * (i / n + phase))


def keyed(keys, i, n):
    """Pose at frame i of n from [(frame, pose)] keys, eased between keys."""
    keys = sorted(keys, key=lambda k: k[0])
    if i <= keys[0][0]:
        return dict(keys[0][1])
    for (f0, p0), (f1, p1) in zip(keys, keys[1:]):
        if f0 <= i <= f1:
            u = (i - f0) / (f1 - f0) if f1 > f0 else 1.0
            u = u * u * (3.0 - 2.0 * u)
            return lerp_pose(p0, p1, u)
    return dict(keys[-1][1])


def over(base: dict, **changes) -> dict:
    """base with keys replaced; keyword names use _ for . (hand_R -> hand.R)."""
    out = dict(base)
    for k, v in changes.items():
        out[k.replace("_R", ".R").replace("_L", ".L") if k[-2:] in ("_R", "_L") else k] = v
    return out


# ---------------------------------------------------------------------- the set


def build(sc) -> dict:
    """All animations for Scene sc (render_hero.Scene)."""
    rig = sc.rig
    sh = {s: rig.shoulder(s) for s in "RL"}
    ank = {s: rig.ankle(s) for s in "RL"}

    def spear(variant):
        return VARIANTS[variant]["weapon"] == "spear"

    # -- stances ---------------------------------------------------------

    def idle_pose(variant):
        p = {
            "hips": RIGHT * 0.015 + DOWN * 0.012, "hips_rot": (-5, 0, -3),
            "chest": (5, 2, 2.5), "head": (-4, 3, -2),
            "foot.R": ank["R"] + RIGHT * 0.03 + BACK * 0.02, "toe_yaw.R": 14,
            "foot.L": ank["L"] + LEFT * 0.03 + FWD * 0.07, "toe_yaw.L": 8,
            # left hand on the hip, elbow out
            "hand.L": Vector((0.2, 0.0, 1.0)), "elbow.L": LEFT + BACK * 0.7, "curl.L": 35,
            "curl.R": 90,
        }
        if spear(variant):
            # spear upright beside her, forearm level, thumb up
            p.update({"hand.R": sh["R"] + RIGHT * 0.1 + FWD * 0.2 + DOWN * 0.3, "blade.R": dir_(6, 86),
                      "elbow.R": BACK + DOWN + RIGHT * 0.3})
        else:
            p.update({"hand.R": sh["R"] + RIGHT * 0.1 + FWD * 0.07 + DOWN * 0.34, "blade.R": dir_(28, -52)})
        return p

    def ready_pose(variant):
        p = {
            "hips": DOWN * 0.07 + BACK * 0.02, "hips_rot": (22, 5, 0),
            "chest": (-10, 7, 0), "head": (-12, -4, 0),
            "foot.L": ank["L"] + FWD * 0.17 + LEFT * 0.07, "toe_yaw.L": 12,
            "foot.R": ank["R"] + BACK * 0.15 + RIGHT * 0.1, "toe_yaw.R": 45, "heel.R": 8,
            "hand.L": Vector((0.2, -0.2, 1.12)), "elbow.L": DOWN + LEFT * 0.6 + BACK * 0.3, "curl.L": 40,
            "elbow.R": BACK + DOWN * 0.6 + RIGHT * 0.5, "curl.R": 90,
        }
        if spear(variant):
            # low underarm guard, point towards the foe
            p.update({"hand.R": Vector((-0.16, -0.16, 1.05)), "blade.R": dir_(-4, 16),
                      "hand.L": Vector((0.1, -0.4, 1.12)), "elbow.L": DOWN + LEFT * 0.6})
        else:
            # middle guard, blade angled across the body so it reads from every side
            p.update({"hand.R": Vector((-0.1, -0.28, 1.1)), "blade.R": dir_(-40, 52)})
        return p

    def idle(i, variant):
        c = cyc(i, 6)
        p = idle_pose(variant)
        p["chest"] = (5, 2 + 1.3 * c, 2.5)
        p["head"] = (-4, 3 - 0.8 * c, -2)
        p["hips"] = p["hips"] + UP * 0.004 * c
        p["hand.R"] = p["hand.R"] + UP * 0.006 * c
        return rig.solve(p)

    def ready(i, variant):
        c = cyc(i, 6)
        p = ready_pose(variant)
        p["hips"] = p["hips"] + UP * 0.012 * c
        p["chest"] = (-10, 7 + 1.5 * c, 0)
        p["hand.R"] = p["hand.R"] + UP * 0.012 * c
        p["hand.L"] = p["hand.L"] + UP * 0.01 * c
        return rig.solve(p)

    # -- locomotion ------------------------------------------------------

    def walk(i, variant):
        base = sc.action_basis(1 + i * 3)
        carry = {"blade.R": dir_(8, 84) if spear(variant) else dir_(24, -50), "curl.R": 90}
        return rig.solve(carry, base)

    # foot path through a run cycle: (phase, forward offset, lift, heel pitch)
    stride = [(0.0, 0.22, 0.0, 0.0), (0.35, -0.2, 0.0, 30.0), (0.5, -0.3, 0.2, 55.0),
              (0.7, -0.02, 0.22, 20.0), (0.86, 0.24, 0.1, -8.0), (1.0, 0.22, 0.0, 0.0)]

    def foot_at(phase):
        phase %= 1.0
        for (p0, f0, h0, a0), (p1, f1, h1, a1) in zip(stride, stride[1:]):
            if p0 <= phase <= p1:
                u = (phase - p0) / (p1 - p0)
                if p0 > 0.0:
                    u = u * u * (3.0 - 2.0 * u)
                return f0 + (f1 - f0) * u, h0 + (h1 - h0) * u, a0 + (a1 - a0) * u
        return stride[0][1:]

    def run(i, variant):
        ph = i / 8
        c = cyc(i, 8)  # +1 when the right foot lands
        p = {"hips": DOWN * (0.06 - 0.022 * math.cos(4.0 * math.pi * (ph - 0.42))),
             "hips_rot": (-8 * c, 7, 0), "chest": (14 * c, 9, 0), "head": (-6 * c, -10, 0)}
        for s, off in (("R", 0.0), ("L", 0.5)):
            f, h, a = foot_at(ph + off)
            p["foot." + s] = ank[s] + FWD * f + UP * h
            p["heel." + s] = a
            p["toe_yaw." + s] = 4
        p["hand_rel.L"] = LEFT * 0.07 + FWD * (0.05 + 0.16 * c) + DOWN * (0.26 - 0.06 * c)
        p["elbow.L"] = BACK + DOWN * 0.2 + LEFT * 0.3
        p["curl.L"] = 60
        p["hand_rel.R"] = RIGHT * 0.09 + FWD * (0.04 - 0.12 * c) + DOWN * (0.29 + 0.03 * c)
        p["elbow.R"] = BACK + DOWN * 0.2 + RIGHT * 0.3
        p["curl.R"] = 90
        p["blade.R"] = dir_(-5, 22) if spear(variant) else dir_(165, -48)
        return rig.solve(p)

    # -- attacks ---------------------------------------------------------
    # Six frames each: anticipation, chamber, swing, impact, follow-through, recovery.
    # Hand targets and blades are in the chest's frame (hand_rel), so the torso drives the arc.

    def attack(frames):
        def f(i, variant):
            base = ready_pose(variant)
            for k in ("hand.R", "hand.L"):
                base.pop(k)
            base["hand_rel.L"] = LEFT * 0.1 + FWD * 0.14 + DOWN * 0.22
            base["elbow.L"] = DOWN + LEFT * 0.5 + BACK * 0.4
            keys = [(k, over(base, **changes)) for k, changes in enumerate(frames)]
            p = keyed(keys, i, len(frames))
            return rig.solve(p)
        return f

    lunge_l = ank["L"] + FWD * 0.3 + LEFT * 0.07
    slash = attack([
        dict(chest=(30, -4, 0), hips_rot=(28, 2, 0), hips=DOWN * 0.06 + BACK * 0.05,
             hand_rel_R=RIGHT * 0.14 + BACK * 0.04 + UP * 0.1, blade_R=dir_(150, 45), elbow_R=RIGHT + DOWN * 0.3),
        dict(chest=(40, -6, 0), hips_rot=(30, 0, 0), hips=DOWN * 0.05 + BACK * 0.06,
             hand_rel_R=RIGHT * 0.07 + BACK * 0.07 + UP * 0.26, blade_R=dir_(172, 8), elbow_R=RIGHT + UP * 0.3),
        dict(chest=(10, 8, 0), hips_rot=(12, 6, 0), hips=DOWN * 0.08,
             hand_rel_R=RIGHT * 0.06 + FWD * 0.25 + UP * 0.2, blade_R=dir_(20, 70), elbow_R=RIGHT + DOWN * 0.2),
        dict(chest=(-25, 18, 0), hips_rot=(-6, 10, 0), hips=DOWN * 0.11 + FWD * 0.06, foot_L=lunge_l,
             hand_rel_R=LEFT * 0.12 + FWD * 0.36 + DOWN * 0.02, blade_R=dir_(-60, -15), elbow_R=RIGHT + DOWN),
        dict(chest=(-38, 22, 0), hips_rot=(-10, 12, 0), hips=DOWN * 0.12 + FWD * 0.07, foot_L=lunge_l,
             hand_rel_R=LEFT * 0.28 + FWD * 0.18 + DOWN * 0.2, blade_R=dir_(-130, -40), elbow_R=RIGHT + DOWN),
        dict(chest=(-18, 12, 0), hips_rot=(8, 7, 0), hips=DOWN * 0.09 + FWD * 0.02,
             hand_rel_R=LEFT * 0.08 + FWD * 0.28 + DOWN * 0.1, blade_R=dir_(-45, 20), elbow_R=RIGHT + DOWN),
    ])
    slash_rev = attack([
        dict(chest=(-25, 4, 0), hips_rot=(10, 5, 0),
             hand_rel_R=LEFT * 0.2 + FWD * 0.14 + DOWN * 0.12, blade_R=dir_(-150, -5), elbow_R=DOWN + RIGHT * 0.5),
        dict(chest=(-42, 6, 0), hips_rot=(4, 6, 0), hips=DOWN * 0.08,
             hand_rel_R=LEFT * 0.27 + FWD * 0.06 + DOWN * 0.02, blade_R=dir_(-175, 15), elbow_R=DOWN + FWD * 0.3),
        dict(chest=(-10, 10, 0), hips_rot=(14, 8, 0), hips=DOWN * 0.1 + FWD * 0.03, foot_L=lunge_l,
             hand_rel_R=LEFT * 0.06 + FWD * 0.34 + DOWN * 0.02, blade_R=dir_(-70, 10), elbow_R=DOWN + RIGHT * 0.3),
        dict(chest=(25, 10, 0), hips_rot=(26, 8, 0), hips=DOWN * 0.1 + FWD * 0.05, foot_L=lunge_l,
             hand_rel_R=RIGHT * 0.18 + FWD * 0.32 + UP * 0.04, blade_R=dir_(50, 12), elbow_R=DOWN + RIGHT * 0.5),
        dict(chest=(40, 4, 0), hips_rot=(32, 5, 0), hips=DOWN * 0.09 + FWD * 0.04, foot_L=lunge_l,
             hand_rel_R=RIGHT * 0.33 + FWD * 0.06 + UP * 0.12, blade_R=dir_(125, 30), elbow_R=DOWN + RIGHT),
        dict(chest=(12, 6, 0), hips_rot=(24, 5, 0), hips=DOWN * 0.08,
             hand_rel_R=RIGHT * 0.12 + FWD * 0.2 + DOWN * 0.04, blade_R=dir_(30, 40), elbow_R=DOWN + RIGHT * 0.6),
    ])
    thrust = attack([
        dict(chest=(28, 0, 0), hips_rot=(30, 3, 0), hips=DOWN * 0.07 + BACK * 0.06,
             hand_rel_R=RIGHT * 0.1 + BACK * 0.1 + DOWN * 0.24, blade_R=dir_(-5, 8), elbow_R=BACK + RIGHT * 0.4),
        dict(chest=(34, -3, 0), hips_rot=(32, 2, 0), hips=DOWN * 0.08 + BACK * 0.09,
             hand_rel_R=RIGHT * 0.1 + BACK * 0.16 + DOWN * 0.2, blade_R=dir_(0, 10), elbow_R=BACK + RIGHT * 0.4),
        dict(chest=(-5, 12, 0), hips_rot=(18, 10, 0), hips=DOWN * 0.11 + FWD * 0.1, foot_L=lunge_l,
             hand_rel_R=FWD * 0.34 + DOWN * 0.08 + RIGHT * 0.04, blade_R=dir_(0, 20), elbow_R=RIGHT + DOWN),
        dict(chest=(-12, 16, 0), hips_rot=(14, 12, 0), hips=DOWN * 0.13 + FWD * 0.15, foot_L=lunge_l + FWD * 0.05,
             hand_rel_R=FWD * 0.39 + DOWN * 0.06, blade_R=dir_(0, 26), elbow_R=RIGHT + DOWN),
        dict(chest=(-6, 10, 0), hips_rot=(18, 8, 0), hips=DOWN * 0.11 + FWD * 0.1, foot_L=lunge_l,
             hand_rel_R=FWD * 0.3 + DOWN * 0.1 + RIGHT * 0.03, blade_R=dir_(0, 18), elbow_R=RIGHT + DOWN),
        dict(chest=(8, 7, 0), hips_rot=(20, 6, 0), hips=DOWN * 0.08,
             hand_rel_R=RIGHT * 0.05 + FWD * 0.18 + DOWN * 0.14, blade_R=dir_(-10, 25), elbow_R=BACK + RIGHT * 0.5),
    ])

    # -- death: struck, staggers back, knees give, falls on her back ------

    def die(i, variant):
        lying_feet = {"foot_R": ank["R"] + FWD * 0.5 + DOWN * 0.09 + RIGHT * 0.05, "heel_R": -70,
                      "foot_L": ank["L"] + FWD * 0.48 + DOWN * 0.09 + LEFT * 0.08, "heel_L": -65}
        keys = [
            dict(hips=BACK * 0.03 + DOWN * 0.02, hips_rot=(0, -6, 0), chest=(0, -14, 0), head=(0, -18, 0),
                 hand_rel_R=RIGHT * 0.2 + FWD * 0.1 + DOWN * 0.2, blade_R=dir_(60, -30),
                 hand_rel_L=LEFT * 0.2 + FWD * 0.12 + DOWN * 0.18),
            dict(hips=BACK * 0.08 + DOWN * 0.12, hips_rot=(0, -12, 4), chest=(0, -18, 4), head=(5, -12, 6),
                 foot_R=ank["R"] + BACK * 0.18, hand_rel_R=RIGHT * 0.24 + DOWN * 0.24, blade_R=dir_(80, -45),
                 hand_rel_L=LEFT * 0.24 + FWD * 0.05 + DOWN * 0.2),
            dict(hips=BACK * 0.12 + DOWN * 0.42, hips_rot=(0, 5, 6), chest=(0, 25, 5), head=(0, 20, 5),
                 foot_R=ank["R"] + BACK * 0.12, foot_L=ank["L"] + FWD * 0.05,
                 hand_rel_R=RIGHT * 0.12 + FWD * 0.1 + DOWN * 0.34, blade_R=dir_(40, -70),
                 hand_rel_L=LEFT * 0.1 + FWD * 0.1 + DOWN * 0.34),
            dict(hips=BACK * 0.3 + DOWN * 0.7, hips_rot=(0, -40, 5), chest=(0, -20, 0), head=(0, -10, 0),
                 foot_R=ank["R"] + FWD * 0.2 + UP * 0.05, foot_L=ank["L"] + FWD * 0.25 + UP * 0.05,
                 hand_rel_R=RIGHT * 0.3 + UP * 0.05, blade_R=dir_(100, -20),
                 hand_rel_L=LEFT * 0.3 + UP * 0.05),
            dict(hips=BACK * 0.38 + DOWN * 0.85, hips_rot=(0, -80, 3), chest=(0, -8, 0), head=(0, 5, 0),
                 hand_rel_R=RIGHT * 0.34 + UP * 0.12, blade_R=dir_(110, -5),
                 hand_rel_L=LEFT * 0.34 + UP * 0.12, **lying_feet),
            dict(hips=BACK * 0.4 + DOWN * 0.86, hips_rot=(0, -88, 0), chest=(0, -3, 0), head=(20, -5, 0),
                 hand_rel_R=RIGHT * 0.36 + UP * 0.06, blade_R=dir_(100, 0),
                 hand_rel_L=LEFT * 0.35 + UP * 0.1, **lying_feet),
            dict(hips=BACK * 0.4 + DOWN * 0.87, hips_rot=(0, -89, 0), chest=(0, -2, 0), head=(32, -4, 0),
                 hand_rel_R=RIGHT * 0.36 + UP * 0.04, blade_R=dir_(98, 2),
                 hand_rel_L=LEFT * 0.33 + UP * 0.08, **lying_feet),
        ]
        base = idle_pose(variant)
        for k in ("hand.R", "hand.L", "elbow.L"):
            base.pop(k)
        base["curl.L"] = 20
        return rig.solve(over(base, **keys[i]))

    fall = [0.0, 0.0, 0.15, 0.55, 0.9, 1.0, 1.0]

    def die_yaw(i, d):
        """Extra turn (degrees, counter-clockwise from above) for facing d at frame i: lying
        towards or away from the camera would foreshorten her, so she twists to land across it."""
        back = (d * 45.0 + 180.0) % 360.0
        target = 0.0 if math.cos(math.radians(back)) >= -1e-6 else 180.0
        delta = (target - back + 180.0) % 360.0 - 180.0
        return delta * fall[i]

    return {
        "idle": {"frames": 6, "fps": 5.0, "loop": True, "pose": idle},
        "ready": {"frames": 6, "fps": 6.0, "loop": True, "pose": ready},
        "walk": {"frames": 8, "fps": 10.0, "loop": True, "pose": walk},
        "run": {"frames": 8, "fps": 13.0, "loop": True, "pose": run},
        "slash": {"frames": 6, "fps": 13.0, "loop": False, "pose": slash},
        "slash_rev": {"frames": 6, "fps": 13.0, "loop": False, "pose": slash_rev},
        "thrust": {"frames": 6, "fps": 13.0, "loop": False, "pose": thrust},
        "die": {"frames": 7, "fps": 9.0, "loop": False, "pose": die, "yaw": die_yaw},
    }
