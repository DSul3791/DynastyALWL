#!/usr/bin/env python3
"""Turn one of Dave's baked station models into the game's mesh: the Improved smithy (Dave 21 Nov 2026, "sized so it fits in 3/4 of the
width of a foundation"), the Primitive kiln (Dave 21 Nov 2026, "sized so its longest side is a minimum 2.74 meters") and the
Primitive smithy (Dave 21 Nov 2026: most things "fit neatly into 3/4 or half of a foundation size").

Each file is one baked mesh (+Y up, the fire opening toward +Z) with three 4096 textures. This:

1. Cuts it with meshoptimizer (tools/stations/simplify_mesh.mjs), keeping every texture seam: the textures are many small islands, and a cut
   across a seam smeared the smithy's coals' orange over its stone.
2. Scales it so its size along one axis is the station's metres, its floor on y 0 and centred on the pivot, so the game uses it as it is.
3. Takes the painted coals or embers out of the colour (dark ash in their place) into an emission texture, so the game can make them cold or
   glowing (BuildingLook.forge_state for the smithy, inventory_view._make_primitive_kiln for the kiln). The coals are the hot paint on the
   triangles in the station's hearth box, nothing else.
4. Scales the textures to 2048 and makes the material one-sided (Cast Shadow On, not Double-Sided: Dave's mesh rule).
5. Adds empty "Fire" (on the coals) and "Smoke" (the chimney top) nodes, which inventory_view._forge_glb hangs the light, flames and smoke on.

Usage: python3 -I tools/stations/prepare_station_model.py STATION SOURCE.glb OUT.glb --node-modules DIR
STATION is a key of STATIONS (improved_smithy -> assets/stations/improved_smithy.glb, primitive_kiln -> assets/stations/primitive_kiln.glb,
primitive_smithy -> assets/stations/primitive_smithy.glb).
DIR is a folder whose node_modules holds meshoptimizer 0.25.0 (npm i meshoptimizer@0.25.0 in it). Needs numpy and Pillow, and node.
Writes OUT.glb, its .import and its four textures as OUT_<texture>.png with their .import files (VRAM Compressed), as tools/hair/prepare_hair.py.
"""
import argparse
import io
import json
import os
import struct
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

sys.path.insert(0, os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "hair"))
from prepare_hair import Glb, write_imports  # noqa: E402  (the same reader and import files as the hair)

TEXTURE_SIZE = 2048
ASH = 0.3   # the colour left where coals were painted: their brightness times this, greyed (cold ash)

# Per station. Boxes and points are in Dave's units (x, y, z). fit: (axis, metres) the model is scaled to. target: triangles asked of the
# simplifier (the seams stop it higher). hearth: the triangles (by their middle) whose paint may be coals. hot: (k, s) of coal_strength.
STATIONS = {
    "improved_smithy": {
        "node": "Smithy", "material": "ImprovedSmithy",
        "fit": (0, 3.0),                     # 3 m wide: 3/4 of a 4 m log or brick foundation
        "target": 15000, "max_error": 0.05,  # stops at about 37,000
        "hearth": ((-0.28, 0.28), (-0.2, 0.12), (-0.45, 0.1)),
        "fire": (0.02, -0.07, -0.15),        # the coal bed's middle
        "smoke": (0.0, 0.53, -0.30),         # the chimney's top
        "hot": (1.2, 0.8),
    },
    "primitive_smithy": {
        "node": "Smithy", "material": "PrimitiveSmithy",
        "fit": (2, 3.0),                     # its length, front to back, the longest side: 3/4 of a 4 m foundation (Dave: 3/4 or half)
        "target": 15000, "max_error": 0.05,
        "hearth": ((-0.22, 0.2), (-0.1, 0.2), (-0.66, -0.2)),   # the inside of the forge's mouth: its fire-lit clay and the coal bed
        "fire": (-0.05, 0.0, -0.42),         # the coal bed's middle
        "smoke": (-0.007, 0.41, -0.506),     # the chimney's top
        "hot": (1.5, 0.5),                   # the forge's clay outside is orange too, so only the redder lit paint in the mouth
    },
    "primitive_kiln": {
        "node": "Kiln", "material": "PrimitiveKiln",
        "fit": (2, 2.74),                    # its length, the longest side: Dave's minimum, 2.74 m
        "target": 15000, "max_error": 0.05,  # stops at about 20,000
        "hearth": ((-0.24, 0.24), (-0.345, -0.06), (-0.75, 0.95)),   # the charcoal bed along the tunnel's floor
        "fire": (0.0, -0.27, 0.6),           # the embers' middle, inside the mouth
        "smoke": (0.0, 0.34, -0.75),         # the chimney's top, at the back
        "hot": (1.75, 0.4),                  # stricter than the smithy's: the kiln's clay is orange too, its embers redder and brighter
    },
}

Image.MAX_IMAGE_PIXELS = None


def coal_strength(colour, hearth_mask, k, s):
    """0 to 1 per texel: how much of the paint is glowing coal (red well above k times the green, blue under s times the red), inside the hearth's islands."""
    c = np.asarray(colour, np.float32)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    hot = np.clip((r - k * g) / 25.0, 0.0, 1.0) * np.clip((r - 40.0) / 40.0, 0.0, 1.0) * np.clip((r * s - b) / 20.0, 0.0, 1.0)
    return hot * hearth_mask


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("station", choices=sorted(STATIONS))
    ap.add_argument("source")
    ap.add_argument("out")
    ap.add_argument("--node-modules", required=True)
    args = ap.parse_args()
    st = STATIONS[args.station]

    src = Glb(args.source)
    prim = src.j["meshes"][0]["primitives"][0]
    pos = src.accessor(prim["attributes"]["POSITION"]).astype(np.float32)
    nor = src.accessor(prim["attributes"]["NORMAL"]).astype(np.float32)
    uv = src.accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float32)
    tris = src.accessor(prim["indices"]).astype(np.uint32).reshape(-1, 3)
    mat = src.j["materials"][prim["material"]]
    tex_of = {name: src.j["textures"][slot["index"]]["source"] for name, slot in
              [("texture_0", mat["pbrMetallicRoughness"]["baseColorTexture"]), ("texture_0_metallic_roughness", mat["pbrMetallicRoughness"]["metallicRoughnessTexture"]),
               ("normal", mat["normalTexture"])]}

    # 1. Simplify.
    with tempfile.TemporaryDirectory() as tmp:
        files = [os.path.join(tmp, n) for n in ("pos.bin", "uv.bin", "idx.bin", "out.bin")]
        pos.tofile(files[0])
        uv.tofile(files[1])
        tris.tofile(files[2])
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "simplify_mesh.mjs")
        # An ES module finds its packages from where it lies, so the script is run from a copy in the folder that holds node_modules.
        local = os.path.join(os.path.abspath(args.node_modules), "simplify_mesh.mjs")
        open(local, "w").write(open(script).read())
        report = subprocess.run(["node", local, *files, str(st["target"]), str(st["max_error"])], check=True, capture_output=True, text=True).stdout
        print("simplified:", report.strip())
        kept = np.fromfile(files[3], np.uint32).reshape(-1, 3)

    used = np.unique(kept)
    remap = np.full(len(pos), -1, np.int64)
    remap[used] = np.arange(len(used))
    middles = pos[kept].mean(axis=1)
    inside = np.ones(len(kept), bool)

    for axis, (low, high) in enumerate(st["hearth"]):
        inside &= (middles[:, axis] >= low) & (middles[:, axis] <= high)

    hearth_tris = kept[inside]
    other_tris = kept[~inside]
    pos, nor, uv, kept = pos[used], nor[used], uv[used], remap[kept].astype(np.uint32)

    # 2. Size and place: the fit's metres along its axis, floor on 0, centred.
    lo, hi = pos.min(0), pos.max(0)
    axis, metres = st["fit"]
    scale = metres / float(hi[axis] - lo[axis])
    shift = np.array([-(lo[0] + hi[0]) * 0.5, -lo[1], -(lo[2] + hi[2]) * 0.5], np.float32)
    place = lambda p: ((np.asarray(p, np.float32) + shift) * scale).astype(np.float32)
    out_pos = place(pos)

    # 3 and 4. Textures: 2048, the coals out of the colour into the emission.
    colour = src.image(tex_of["texture_0"]).convert("RGB").resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)
    mask = Image.new("L", (TEXTURE_SIZE, TEXTURE_SIZE), 0)
    draw = ImageDraw.Draw(mask)
    src_uv = src.accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float32)

    for tri in hearth_tris:
        draw.polygon([(float(src_uv[i][0]) * TEXTURE_SIZE, float(src_uv[i][1]) * TEXTURE_SIZE) for i in tri], fill=255)

    mask = mask.filter(ImageFilter.MaxFilter(3))   # the islands' edge texels, which mipmaps blend in ...
    others = Image.new("L", (TEXTURE_SIZE, TEXTURE_SIZE), 0)
    draw = ImageDraw.Draw(others)

    for tri in other_tris:
        draw.polygon([(float(src_uv[i][0]) * TEXTURE_SIZE, float(src_uv[i][1]) * TEXTURE_SIZE) for i in tri], fill=255)

    # ... but never a texel another part of the model is painted with (the bench and the bellows have islands beside the hearth's).
    hearth = (np.asarray(mask, np.float32) / 255.0) * (np.asarray(others) == 0)
    hot = coal_strength(colour, hearth, *st["hot"])[..., None]
    c = np.asarray(colour, np.float32)
    ash = np.repeat(c.mean(axis=2, keepdims=True) * ASH, 3, axis=2) * np.array([1.0, 0.95, 0.9], np.float32)
    base = np.clip(c * (1.0 - hot) + ash * hot, 0, 255).astype(np.uint8)
    emission = np.clip(c * hot, 0, 255).astype(np.uint8)
    print("coal texels: %d (%.2f%% of the texture)" % (int((hot > 0.5).sum()), 100.0 * float((hot > 0.5).mean())))

    def png(img):
        buf = io.BytesIO()
        img.save(buf, "PNG", optimize=True)
        return buf.getvalue()

    pngs = {
        "normal": png(src.image(tex_of["normal"]).convert("RGB").resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)),
        "texture_0": png(Image.fromarray(base)),
        "texture_0_metallic_roughness": png(src.image(tex_of["texture_0_metallic_roughness"]).convert("RGB").resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)),
        "emissive": png(Image.fromarray(emission)),
    }
    write_glb(args.out, out_pos, nor, uv, kept, pngs, place(st["fire"]), place(st["smoke"]), st["node"], st["material"])
    write_imports(args.out, pngs)
    size = out_pos.max(0) - out_pos.min(0)
    print("written %s: %d triangles, %.2f x %.2f x %.2f m (w x h x d), fire %s, smoke %s" % (args.out, len(kept), size[0], size[1], size[2],
                                                                                         place(st["fire"]).round(3).tolist(), place(st["smoke"]).round(3).tolist()))


def write_glb(path, pos, nor, uv, tris, pngs, fire, smoke, node, material):
    blobs = []
    views = []

    def add(data, target=None):
        start = sum(len(b) for b in blobs)
        blobs.append(data + b"\0" * ((4 - len(data) % 4) % 4))
        view = {"buffer": 0, "byteOffset": start, "byteLength": len(data)}
        if target:
            view["target"] = target
        views.append(view)
        return len(views) - 1

    nor = nor / np.maximum(np.linalg.norm(nor, axis=1, keepdims=True), 1e-8)
    accessors = [
        {"bufferView": add(pos.tobytes(), 34962), "componentType": 5126, "count": len(pos), "type": "VEC3", "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
        {"bufferView": add(nor.astype(np.float32).tobytes(), 34962), "componentType": 5126, "count": len(nor), "type": "VEC3"},
        {"bufferView": add(uv.tobytes(), 34962), "componentType": 5126, "count": len(uv), "type": "VEC2"},
        {"bufferView": add(tris.ravel().tobytes(), 34963), "componentType": 5125, "count": int(tris.size), "type": "SCALAR"},
    ]
    names = ["normal", "texture_0", "texture_0_metallic_roughness", "emissive"]   # each becomes OUT_<name>.png on import
    images = [{"name": n, "mimeType": "image/png", "bufferView": add(pngs[n])} for n in names]
    doc = {
        "asset": {"version": "2.0", "generator": "Dynasty tools/stations/prepare_station_model.py"},
        "scene": 0, "scenes": [{"nodes": [0, 1, 2]}],   # all at the top, where inventory_view._forge_glb looks for Fire and Smoke (as in Dave's forges)
        "nodes": [{"name": node, "mesh": 0}, {"name": "Fire", "translation": [float(v) for v in fire]}, {"name": "Smoke", "translation": [float(v) for v in smoke]}],
        "meshes": [{"name": node, "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"name": material, "doubleSided": False, "normalTexture": {"index": 0},
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 1}, "metallicRoughnessTexture": {"index": 2}},
                       "emissiveTexture": {"index": 3}, "emissiveFactor": [1.0, 1.0, 1.0]}],
        "textures": [{"source": i, "sampler": 0} for i in range(4)],
        "samplers": [{"magFilter": 9729, "minFilter": 9987}],
        "images": images, "accessors": accessors, "bufferViews": views,
        "buffers": [{"byteLength": sum(len(b) for b in blobs)}],
    }
    js = json.dumps(doc, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    body = b"".join(blobs)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(js) + 8 + len(body)))
        f.write(struct.pack("<II", len(js), 0x4E4F534A) + js)
        f.write(struct.pack("<II", len(body), 0x004E4942) + body)


if __name__ == "__main__":
    main()
