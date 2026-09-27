"""Pose solver for the hero's Meshy biped rig (used by tools/render_hero.py).

Poses are dictionaries in the armature's own frame: the character faces -Y, her right is -X and
up is +Z (see FWD, RIGHT, UP). Keys, all optional (anything left out keeps the neutral stance):

  hips      Vector   pelvis offset from rest
  hips_rot  (turn, lean, tilt) degrees for the whole body at the pelvis
  chest     (turn, lean, tilt) spread over the four spine bones
  head      (turn, lean, tilt) for the neck/head bone
  hand.R    Vector   wrist target (two-bone IK), with optional elbow.R pole direction
  blade.R   Vector   direction of the right thumb, i.e. of the held weapon
  curl.R    degrees  finger curl (90 closes the fist around a grip)
  foot.R    Vector   ankle target, with optional knee.R pole, heel.R lift (degrees) and
            toe_yaw.R (degrees the foot turns out)
  ...and the same with .L for the left side.

Rig.solve(pose) returns {bone: (location, rotation quaternion, scale)} in pose-bone basis terms,
ready to assign to bpy pose bones.
"""
import math

from mathutils import Matrix, Quaternion, Vector

FWD = Vector((0.0, -1.0, 0.0))
BACK = -FWD
RIGHT = Vector((-1.0, 0.0, 0.0))
LEFT = -RIGHT
UP = Vector((0.0, 0.0, 1.0))
DOWN = -UP

SPINE = ("spine.001", "spine.002", "spine.003", "spine.004")
NECK = "spine.005"
ARM = {"R": ("shoulder.R", "upper_arm.R", "forearm.R", "hand.R", "RightHand_End"),
       "L": ("shoulder.L", "upper_arm.L", "forearm.L", "hand.L", "LeftHand_End")}
LEG = {"R": ("thigh.R", "shin.R", "foot.R"), "L": ("thigh.L", "shin.L", "foot.L")}
# The palm faces -X of hand.R and +X of hand.L (both thumbs point along +Z).
PALM_SIGN = {"R": -1.0, "L": 1.0}


def rot(turn=0.0, lean=0.0, tilt=0.0) -> Quaternion:
    """Rotation in the character's frame (degrees): turn to her right, lean forward, tilt to her right."""
    q_turn = Quaternion(UP, math.radians(-turn))
    q_lean = Quaternion(LEFT, math.radians(lean))
    q_tilt = Quaternion(Vector((0.0, 1.0, 0.0)), math.radians(-tilt))
    return q_turn @ q_lean @ q_tilt


def dir_(turn=0.0, pitch=0.0) -> Vector:
    """Unit direction: `turn` degrees to her right of straight ahead, `pitch` degrees above level."""
    t, p = math.radians(turn), math.radians(pitch)
    return Vector((-math.sin(t) * math.cos(p), -math.cos(t) * math.cos(p), math.sin(p)))


def two_bone(s: Vector, t: Vector, a: float, b: float, pole: Vector) -> Vector:
    """Middle joint of a two-bone chain from s towards t (lengths a, b), bending towards pole."""
    d_vec = t - s
    d = min(max(d_vec.length, abs(a - b) + 1e-4), a + b - 1e-4)
    u = d_vec.normalized() if d_vec.length > 1e-6 else DOWN.copy()
    x = (a * a - b * b + d * d) / (2.0 * d)
    h = math.sqrt(max(a * a - x * x, 0.0))
    v = pole - u * pole.dot(u)
    if v.length < 1e-6:
        v = u.orthogonal()
    return s + u * x + v.normalized() * h


def _q(m: Matrix) -> Quaternion:
    return m.to_3x3().normalized().to_quaternion()


class Rig:
    def __init__(self, arm_ob, head_scale=1.0):
        bones = arm_ob.data.bones
        self.order = []

        def visit(b):
            self.order.append(b.name)
            for c in b.children:
                visit(c)
        for b in bones:
            if b.parent is None:
                visit(b)
        self.parent = {b.name: (b.parent.name if b.parent else None) for b in bones}
        self.rest = {b.name: b.matrix_local.copy() for b in bones}
        self.rel = {n: (self.rest[p].inverted() @ self.rest[n]) if p else self.rest[n].copy()
                    for n, p in self.parent.items()}
        head = {b.name: b.head_local.copy() for b in bones}
        self.head_rest = head
        self.arm_len = {s: ((head[ARM[s][2]] - head[ARM[s][1]]).length, (head[ARM[s][3]] - head[ARM[s][2]]).length)
                        for s in ARM}
        self.leg_len = {s: ((head[LEG[s][1]] - head[LEG[s][0]]).length, (head[LEG[s][2]] - head[LEG[s][1]]).length)
                        for s in LEG}
        self.head_scale = head_scale
        self.basis = {}
        self.posed = {}

    # ------------------------------------------------------------------ neutral stance

    def shoulder(self, side) -> Vector:
        return self.head_rest[ARM[side][1]]

    def ankle(self, side) -> Vector:
        return self.head_rest[LEG[side][2]]

    def neutral(self) -> dict:
        """Relaxed standing pose: feet under the hips, arms hanging with a slight bend."""
        p = {}
        for s, out in (("R", RIGHT), ("L", LEFT)):
            p["hand." + s] = self.shoulder(s) + out * 0.07 + FWD * 0.05 + DOWN * 0.37
            p["elbow." + s] = BACK + out * 0.3
            p["foot." + s] = self.ankle(s).copy()
            p["curl." + s] = 25.0
        return p

    # ------------------------------------------------------------------ solving

    def _frame(self, n) -> Matrix:
        """Where bone n would sit with an identity basis (its parent already posed)."""
        p = self.parent[n]
        return self.posed[p] @ self.rel[n] if p else self.rel[n]

    def _fk(self, n):
        loc, q, sc = self.basis[n]
        m = Matrix.Translation(loc) @ q.to_matrix().to_4x4() @ Matrix.Diagonal((sc, sc, sc, 1.0))
        self.posed[n] = self._frame(n) @ m

    def _delta(self, n, d: Quaternion):
        """Rotate bone n (and its children) by d, expressed in armature space."""
        c = _q(self._frame(n))
        self.basis[n][1] = c.inverted() @ d @ c

    def _aim(self, n, direction: Vector):
        c = _q(self._frame(n))
        cur = c @ Vector((0.0, 1.0, 0.0))
        self.basis[n][1] = c.inverted() @ cur.rotation_difference(direction.normalized()) @ c

    def _orient(self, n, y_axis: Vector, z_axis: Vector):
        """Point bone n's Y along y_axis and its Z as close to z_axis as possible."""
        z = z_axis.normalized()
        y = y_axis - z * y_axis.dot(z)
        if y.length < 1e-4:
            y = z.orthogonal()
        y.normalize()
        x = y.cross(z)
        target = Matrix((x, y, z)).transposed().to_quaternion()
        c = _q(self._frame(n))
        self.basis[n][1] = c.inverted() @ target

    def pos(self, n) -> Vector:
        return self.posed[n].translation.copy()

    def solve(self, pose: dict, base: dict = None) -> dict:
        """Pose-bone basis for a pose. With base (e.g. a frame of an action), only the parts the
        pose names are solved; everything else keeps the base values."""
        if base is None:
            p = self.neutral()
            p.update(pose)
            self.basis = {n: [Vector(), Quaternion(), 1.0] for n in self.order}
        else:
            p = dict(pose)
            self.basis = {n: [base[n][0].copy(), base[n][1].copy(), 1.0] for n in self.order}
        self.posed = {}
        handlers = self._handlers()
        for n in self.order:
            h = handlers.get(n)
            if h and (base is None or any(k in p for k in h[0])):
                h[1](p)
            if n == NECK:
                self.basis[n][2] = self.head_scale
            self._fk(n)
        return {n: (v[0].copy(), v[1].copy(), v[2]) for n, v in self.basis.items()}

    def _handlers(self):
        """bone -> (pose keys it reads, solver)."""
        h = {"spine": (("hips", "hips_rot"), self._hips), NECK: (("head",), self._neck)}
        for n in SPINE:
            h[n] = (("chest",), self._spine_bone(n))
        for s in ARM:
            reach = ("hand." + s, "hand_rel." + s)
            h[ARM[s][0]] = (("shrug." + s,), self._shoulder_fn(s))
            h[ARM[s][1]] = (reach, self._upper_arm_fn(s))
            h[ARM[s][2]] = (reach, self._forearm_fn(s))
            h[ARM[s][3]] = (("blade." + s, "blade_rel." + s), self._hand_fn(s))
            h[ARM[s][4]] = (("curl." + s,), self._fingers_fn(s))
            h[LEG[s][0]] = (("foot." + s,), self._thigh_fn(s))
            h[LEG[s][1]] = (("foot." + s,), self._shin_fn(s))
            h[LEG[s][2]] = (("foot." + s, "heel." + s), self._foot_fn(s))
        return h

    def chest_rot(self) -> Quaternion:
        """How far the upper spine is turned from rest (valid once the spine is solved)."""
        n = SPINE[-1]
        return _q(self.posed[n]) @ _q(self.rest[n]).inverted()

    def _hips(self, p):
        n = "spine"
        rest_rot = self.rest[n].to_3x3()
        self.basis[n][0] = rest_rot.inverted() @ p.get("hips", Vector())
        self._delta(n, rot(*p.get("hips_rot", (0, 0, 0))))

    def _spine_bone(self, n):
        def f(p):
            turn, lean, tilt = p.get("chest", (0, 0, 0))
            self._delta(n, rot(turn / 4.0, lean / 4.0, tilt / 4.0))
        return f

    def _neck(self, p):
        self._delta(NECK, rot(*p.get("head", (0, 0, 0))))

    def _shoulder_fn(self, s):
        def f(p):
            shrug = p.get("shrug." + s, 0.0)   # degrees, raises the shoulder
            if shrug:
                axis = FWD if s == "L" else BACK
                self._delta(ARM[s][0], Quaternion(axis, math.radians(shrug)))
        return f

    def _reach(self, s, p) -> Vector:
        """Wrist target: absolute (hand.S) or relative to the shoulder in the chest's frame (hand_rel.S)."""
        if "hand_rel." + s in p:
            return self._frame(ARM[s][1]).translation + self.chest_rot() @ p["hand_rel." + s]
        return p["hand." + s]

    def _upper_arm_fn(self, s):
        def f(p):
            start = self._frame(ARM[s][1]).translation
            a, b = self.arm_len[s]
            target = self._reach(s, p)
            p["_wrist." + s] = target
            pole = p.get("elbow." + s, BACK)
            if "hand_rel." + s in p:
                pole = self.chest_rot() @ pole
            elbow = two_bone(start, target, a, b, pole)
            self._aim(ARM[s][1], elbow - start)
        return f

    def _forearm_fn(self, s):
        def f(p):
            start = self._frame(ARM[s][2]).translation
            self._aim(ARM[s][2], p["_wrist." + s] - start)
        return f

    def _hand_fn(self, s):
        def f(p):
            if "blade." + s not in p and "blade_rel." + s not in p:
                return
            fore = self.posed[ARM[s][2]].to_3x3().normalized() @ Vector((0.0, 1.0, 0.0))
            if "blade_rel." + s in p:
                # given for a forearm hanging straight down; swings along with the forearm
                blade = DOWN.rotation_difference(fore) @ p["blade_rel." + s]
            else:
                blade = p["blade." + s]
                if "hand_rel." + s in p:
                    blade = self.chest_rot() @ blade
            if "fingers." + s in p:
                self._orient(ARM[s][3], p["fingers." + s], blade)
            else:
                # least wrist rotation that points the thumb (and the weapon) along the blade
                n = ARM[s][3]
                c = _q(self._frame(n))
                cur = c @ Vector((0.0, 0.0, 1.0))
                self.basis[n][1] = c.inverted() @ cur.rotation_difference(blade.normalized()) @ c
        return f

    def _fingers_fn(self, s):
        def f(p):
            curl = p.get("curl." + s, 0.0)
            # positive curl folds the fingers towards the palm (about the knuckle axis, bone Z)
            self.basis[ARM[s][4]][1] = Quaternion(Vector((0.0, 0.0, 1.0)), math.radians(-curl * PALM_SIGN[s]))
        return f

    def _thigh_fn(self, s):
        def f(p):
            start = self._frame(LEG[s][0]).translation
            a, b = self.leg_len[s]
            yaw = p.get("hips_rot", (0, 0, 0))[0] + p.get("toe_yaw." + s, 0.0) * (1.0 if s == "R" else -1.0)
            knee_pole = p.get("knee." + s, dir_(yaw, 0.0))
            knee = two_bone(start, p["foot." + s], a, b, knee_pole)
            self._aim(LEG[s][0], knee - start)
        return f

    def _shin_fn(self, s):
        def f(p):
            start = self._frame(LEG[s][1]).translation
            self._aim(LEG[s][1], p["foot." + s] - start)
        return f

    def _foot_fn(self, s):
        def f(p):
            # keep the foot's rest orientation in the world, turned out by toe_yaw and lifted at the heel
            n = LEG[s][2]
            rest_q = _q(self.rest[n])
            yaw = p.get("toe_yaw." + s, 0.0) * (1.0 if s == "L" else -1.0)
            lift = p.get("heel." + s, 0.0)
            side_axis = rot(-yaw) @ LEFT
            target = Quaternion(side_axis, math.radians(lift)) @ rot(-yaw) @ rest_q
            c = _q(self._frame(n))
            self.basis[n][1] = c.inverted() @ target
        return f


def lerp_pose(a: dict, b: dict, t: float) -> dict:
    """Blend two pose dictionaries (vectors lerp, angle tuples lerp, scalars lerp)."""
    out = {}
    for k in set(a) | set(b):
        if k not in a:
            out[k] = b[k]
        elif k not in b:
            out[k] = a[k]
        else:
            va, vb = a[k], b[k]
            if isinstance(va, Vector):
                if k.startswith("blade") or k.startswith("elbow") or k.startswith("knee") or k.startswith("fingers"):
                    out[k] = va.normalized().slerp(vb.normalized(), t, va.normalized()) if va.angle(vb, 0) < 3.1 else va.lerp(vb, t)
                else:
                    out[k] = va.lerp(vb, t)
            elif isinstance(va, tuple):
                out[k] = tuple(x + (y - x) * t for x, y in zip(va, vb))
            else:
                out[k] = va + (vb - va) * t
    return out
