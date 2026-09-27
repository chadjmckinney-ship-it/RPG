"""Pack Meshy's per-animation .glb downloads into one .glb per character.

Meshy exports every animation as a full copy of the character: mesh, skin and three
textures (12-20 MB) around a few KB of motion. This keeps one body and moves every
clip onto it, so a character is one file the size of a single download instead of
60-120 MB of repeats, and the game loads one body instead of one per clip.

    python tools/meshy_pack.py maren C:/Users/Chad/Downloads/Maren.zip
    python tools/meshy_pack.py oswin C:/Users/Chad/Downloads/oswin C:/Users/Chad/Downloads/oswin_attack.glb

Sources are folders, .zip files or single .glb files. Writes characters/<id>/<id>.glb
(or --out <dir>/<id>/<id>.glb). Refuses a file whose body differs from the first one,
drops Meshy's 2-frame bind-pose clips (under 0.2 s, the game ignores them anyway) and
keeps every other clip under its Meshy name. Textures larger than 2048 px (Meshy's
4096 px metal/roughness map) are shrunk to 2048; --max-texture 0 copies the body byte
for byte instead.
"""
import argparse
import copy
import hashlib
import io
import json
import struct
import sys
import zipfile
from pathlib import Path

MIN_CLIP = 0.2
COMP_SIZE = {5120: 1, 5121: 1, 5122: 2, 5123: 2, 5125: 4, 5126: 4}
TYPE_N = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT2": 4, "MAT3": 9, "MAT4": 16}
ARRAY_BUFFER, ELEMENT_ARRAY_BUFFER = 34962, 34963
GLB_MAGIC, CHUNK_JSON, CHUNK_BIN = 0x46546C67, 0x4E4F534A, 0x004E4942
# Extensions whose data lives in buffers this script does not know how to copy.
UNSUPPORTED = {"KHR_draco_mesh_compression", "EXT_meshopt_compression"}


class Glb:
    def __init__(self, name, data):
        self.name = name
        magic, version, length = struct.unpack_from("<III", data, 0)
        if magic != GLB_MAGIC or version != 2:
            raise SystemExit(f"{name}: not a glTF 2.0 binary")
        off, self.json, self.bin = 12, None, b""
        while off < length:
            clen, ctype = struct.unpack_from("<II", data, off)
            chunk = data[off + 8 : off + 8 + clen]
            if ctype == CHUNK_JSON:
                self.json = json.loads(chunk.decode("utf-8"))
            elif ctype == CHUNK_BIN:
                self.bin = chunk
            off += 8 + clen
        if self.json is None:
            raise SystemExit(f"{name}: no JSON chunk")
        if len(self.json.get("buffers", [])) > 1 or any("uri" in b for b in self.json.get("buffers", [])):
            raise SystemExit(f"{name}: external buffers are not supported")
        bad = UNSUPPORTED & set(self.json.get("extensionsUsed", []))
        if bad:
            raise SystemExit(f"{name}: uses {', '.join(sorted(bad))}, which this script cannot repack")

    def view_bytes(self, vi):
        bv = self.json["bufferViews"][vi]
        start = bv.get("byteOffset", 0)
        return self.bin[start : start + bv["byteLength"]]

    def accessor_bytes(self, ai):
        """The accessor's elements, tightly packed."""
        a = self.json["accessors"][ai]
        if "sparse" in a:
            raise SystemExit(f"{self.name}: sparse accessor {ai} is not supported")
        comp = COMP_SIZE[a["componentType"]]
        if a["type"].startswith("MAT") and comp < 4:
            raise SystemExit(f"{self.name}: padded matrix accessor {ai} is not supported")
        elem = comp * TYPE_N[a["type"]]
        if "bufferView" not in a:
            return bytes(elem * a["count"])
        bv = self.json["bufferViews"][a["bufferView"]]
        stride = bv.get("byteStride") or elem
        base = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        if stride == elem:
            return self.bin[base : base + elem * a["count"]]
        return b"".join(self.bin[base + i * stride : base + i * stride + elem] for i in range(a["count"]))

    def body_signature(self):
        """Hash of everything but the animations: mesh, skin, skeleton, materials, textures."""
        js, h = self.json, hashlib.sha256()
        for m in js.get("meshes", []):
            for p in m["primitives"]:
                for k in sorted(p["attributes"]):
                    h.update(k.encode())
                    h.update(self.accessor_bytes(p["attributes"][k]))
                if "indices" in p:
                    h.update(self.accessor_bytes(p["indices"]))
                for t in p.get("targets", []):
                    for k in sorted(t):
                        h.update(self.accessor_bytes(t[k]))
        for s in js.get("skins", []):
            h.update(json.dumps(s.get("joints")).encode())
            if "inverseBindMatrices" in s:
                h.update(self.accessor_bytes(s["inverseBindMatrices"]))
        for im in js.get("images", []):
            h.update(self.view_bytes(im["bufferView"]) if "bufferView" in im else im.get("uri", "").encode())
        for key in ("nodes", "materials", "textures", "samplers", "scenes"):
            h.update(json.dumps(js.get(key, []), sort_keys=True).encode())
        return h.hexdigest()

    def clip_length(self, anim):
        longest = 0.0
        for s in anim["samplers"]:
            acc = self.json["accessors"][s["input"]]
            if acc.get("max"):
                longest = max(longest, acc["max"][0])
            else:
                raw = self.accessor_bytes(s["input"])
                if raw:
                    longest = max(longest, struct.unpack_from("<f", raw, len(raw) - 4)[0])
        return longest


class Packer:
    """Builds the output buffer, copying only what the merged file references."""

    def __init__(self):
        self.bin = bytearray()
        self.views, self.accessors, self.memo = [], [], {}

    def add_view(self, data, target=None, stride=None):
        self.bin += b"\0" * (-len(self.bin) % 4)
        view = {"buffer": 0, "byteOffset": len(self.bin), "byteLength": len(data)}
        if target:
            view["target"] = target
        if stride:
            view["byteStride"] = stride
        self.bin += data
        self.views.append(view)
        return len(self.views) - 1

    def add_accessor(self, src, ai, target=None):
        key = (id(src), ai, target)
        if key in self.memo:
            return self.memo[key]
        acc = copy.deepcopy(src.json["accessors"][ai])
        if "bufferView" in acc:
            data = src.accessor_bytes(ai)
            elem = COMP_SIZE[acc["componentType"]] * TYPE_N[acc["type"]]
            stride = None
            if target == ARRAY_BUFFER and elem % 4:
                # glTF wants every vertex element on a 4-byte boundary.
                stride = elem + (-elem % 4)
                data = b"".join(data[i * elem : (i + 1) * elem] + b"\0" * (stride - elem) for i in range(acc["count"]))
            acc["bufferView"] = self.add_view(data, target, stride)
            acc.pop("byteOffset", None)
        self.accessors.append(acc)
        self.memo[key] = len(self.accessors) - 1
        return self.memo[key]


def shrink_image(data, mime, limit):
    from PIL import Image

    img = Image.open(io.BytesIO(data))
    if max(img.size) <= limit:
        return data, mime, None
    old = img.size
    if img.mode not in ("RGB", "RGBA", "L", "LA"):
        img = img.convert("RGBA")
    scale = limit / max(img.size)
    img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    out = io.BytesIO()
    if mime == "image/jpeg":
        img.save(out, "JPEG", quality=92)
    else:
        img.save(out, "PNG", optimize=True)
        mime = "image/png"
    return out.getvalue(), mime, (old, img.size)


def load_sources(paths):
    found = []
    for raw in paths:
        p = Path(raw)
        if p.is_dir():
            found += [(f.name, f.read_bytes()) for f in sorted(p.glob("*.glb"))]
        elif p.suffix.lower() == ".zip":
            with zipfile.ZipFile(p) as z:
                found += [(Path(n).name, z.read(n)) for n in sorted(z.namelist()) if n.lower().endswith(".glb")]
        elif p.suffix.lower() == ".glb":
            found.append((p.name, p.read_bytes()))
        else:
            raise SystemExit(f"{raw}: not a folder, .zip or .glb")
    if not found:
        raise SystemExit("no .glb files found in the sources")
    return [Glb(n, d) for n, d in sorted(found, key=lambda t: t[0].lower())]


def pack(files, max_texture=None):
    base = files[0]
    sig = base.body_signature()
    for f in files[1:]:
        if f.body_signature() != sig:
            raise SystemExit(f"{f.name} has a different body from {base.name} (other mesh, rig or textures); "
                             "pack it separately")
    js = copy.deepcopy(base.json)
    out = Packer()

    for mesh in js.get("meshes", []):
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: out.add_accessor(base, ai, ARRAY_BUFFER) for k, ai in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = out.add_accessor(base, prim["indices"], ELEMENT_ARRAY_BUFFER)
            if "targets" in prim:
                prim["targets"] = [{k: out.add_accessor(base, ai, ARRAY_BUFFER) for k, ai in t.items()}
                                   for t in prim["targets"]]
    for skin in js.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = out.add_accessor(base, skin["inverseBindMatrices"])

    resized = []
    for img in js.get("images", []):
        if "bufferView" not in img:
            continue
        data, mime = base.view_bytes(img["bufferView"]), img.get("mimeType", "image/png")
        if max_texture:
            data, mime, change = shrink_image(data, mime, max_texture)
            if change:
                resized.append((img.get("name", "?"), change))
        img["bufferView"], img["mimeType"] = out.add_view(data), mime

    # Every file's node list is identical (checked above), so channel targets carry over as-is.
    anims, seen, dropped = [], {}, 0
    for src in files:
        for anim in src.json.get("animations", []):
            if src.clip_length(anim) < MIN_CLIP:
                dropped += 1
                continue
            motion = hashlib.sha256()
            for s in anim["samplers"]:
                motion.update(src.accessor_bytes(s["input"]) + src.accessor_bytes(s["output"]))
            motion = motion.hexdigest()
            name = anim.get("name") or Path(src.name).stem
            if name in seen:
                if seen[name] == motion:
                    continue
                n = 2
                while f"{name}_{n}" in seen:
                    n += 1
                name = f"{name}_{n}"
            seen[name] = motion
            anims.append({
                "name": name,
                "samplers": [{"input": out.add_accessor(src, s["input"]),
                              "output": out.add_accessor(src, s["output"]),
                              "interpolation": s.get("interpolation", "LINEAR")} for s in anim["samplers"]],
                "channels": [{"sampler": c["sampler"], "target": dict(c["target"])} for c in anim["channels"]],
            })

    js["animations"] = anims
    js["accessors"], js["bufferViews"] = out.accessors, out.views
    js["buffers"] = [{"byteLength": len(out.bin)}]
    js.setdefault("asset", {"version": "2.0"})
    js["asset"]["generator"] = (js["asset"].get("generator", "") + " + meshy_pack").strip(" +")
    return js, bytes(out.bin), anims, dropped, resized


def write_glb(path, js, bin_):
    j = json.dumps(js, separators=(",", ":")).encode("utf-8")
    j += b" " * (-len(j) % 4)
    b = bin_ + b"\0" * (-len(bin_) % 4)
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as fh:
        fh.write(struct.pack("<III", GLB_MAGIC, 2, 12 + 8 + len(j) + 8 + len(b)))
        fh.write(struct.pack("<II", len(j), CHUNK_JSON) + j)
        fh.write(struct.pack("<II", len(b), CHUNK_BIN) + b)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("id", help="the game's id for the character, e.g. maren")
    ap.add_argument("sources", nargs="+", help="Meshy downloads: folders, .zip files or .glb files")
    ap.add_argument("--out", default=str(Path(__file__).resolve().parent.parent / "characters"),
                    help="characters folder (default: the project's characters/)")
    ap.add_argument("--max-texture", type=int, default=2048,
                    help="shrink textures larger than this many px (default 2048; 0 keeps them as they are)")
    ap.add_argument("--force", action="store_true", help="replace an existing <id>.glb")
    args = ap.parse_args()

    target = Path(args.out) / args.id / f"{args.id}.glb"
    if target.exists() and not args.force:
        raise SystemExit(f"{target} exists; pass --force to replace it")
    files = load_sources(args.sources)
    js, bin_, anims, dropped, resized = pack(files, args.max_texture)
    write_glb(target, js, bin_)

    before = sum(len(f.bin) for f in files) / 1048576
    after = target.stat().st_size / 1048576
    print(f"{target}  {after:.1f} MB  (from {len(files)} files, {before:.1f} MB of buffers)")
    for a in anims:
        print(f"  clip {a['name']}")
    if dropped:
        print(f"  dropped {dropped} bind-pose clip(s) under {MIN_CLIP} s")
    for name, (old, new) in resized:
        print(f"  texture {name}: {old[0]}x{old[1]} -> {new[0]}x{new[1]}")


if __name__ == "__main__":
    main()
