#!/usr/bin/env python3
"""Turn Dave's Improved smithy model into the game's mesh (Dave 21 Nov 2026: a better model for the Improved smithy, "sized so it fits in 3/4 of
the width of a foundation").

His file is one baked mesh of about 150,000 triangles with three 4096 textures: the forge with its chimney, a bellows on the left, the anvil on
a stump in front and a work bench on the right, all on a flagstone floor (+Y up, the fire opening toward +Z). This:

1. Cuts it to about 37,000 triangles with meshoptimizer (tools/stations/simplify_mesh.mjs), keeping every texture seam: a cut to 15,000 smeared
   the coals' orange across the stone, because the texture is many small islands.
2. Scales it to WIDTH_M across (3/4 of a 4 m foundation), its floor on y 0 and centred on the pivot, in metres, so the game uses it as it is.
3. Takes the painted coals out of the colour (dark ash in their place) and puts them in an emission texture, so the game can make them cold, glow
   red or flare (BuildingLook.forge_state: Dave 21 Nov 2026, "red coals when idle and flare really bright while making stuff").
   The coals are the orange paint on the triangles in the hearth (HEARTH box), nothing else.
4. Scales the textures to 2048 and makes the material one-sided (Cast Shadow On, not Double-Sided: Dave's mesh rule).
5. Adds empty "Fire" (on the coals) and "Smoke" (the chimney top) nodes, which inventory_view._forge_glb hangs the light, flames and smoke on.

Usage: python3 -I tools/stations/prepare_improved_smithy.py SOURCE.glb assets/stations/improved_smithy.glb --node-modules DIR
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

WIDTH_M = 3.0                 # Dave: 3/4 of the width of a foundation (log and brick foundations are 4 m)
TARGET_TRIANGLES = 15000      # asked of the simplifier; the seams stop it at about 37,000
MAX_ERROR = 0.05              # the simplifier's limit, a share of the model's size
TEXTURE_SIZE = 2048
HEARTH = ((-0.28, 0.28), (-0.2, 0.12), (-0.45, 0.1))   # the hearth in Dave's units (x, y, z ranges): the triangles (by their middle) whose paint may be coals
FIRE_AT = (0.02, -0.07, -0.15)    # the coal bed's middle, Dave's units
SMOKE_AT = (0.0, 0.53, -0.30)     # the chimney's top, Dave's units
ASH = 0.3                     # the colour left where coals were painted: their brightness times this, greyed (cold ash)

Image.MAX_IMAGE_PIXELS = None


def coal_strength(colour, hearth_mask):
    """0 to 1 per texel: how much of the paint is glowing coal (orange to yellow, red well above green, little blue), inside the hearth's islands."""
    c = np.asarray(colour, np.float32)
    r, g, b = c[..., 0], c[..., 1], c[..., 2]
    hot = np.clip((r - 1.2 * g) / 25.0, 0.0, 1.0) * np.clip((r - 40.0) / 40.0, 0.0, 1.0) * np.clip((r * 0.8 - b) / 20.0, 0.0, 1.0)
    return hot * hearth_mask


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("source")
    ap.add_argument("out")
    ap.add_argument("--node-modules", required=True)
    args = ap.parse_args()

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
        report = subprocess.run(["node", local, *files, str(TARGET_TRIANGLES), str(MAX_ERROR)], check=True, capture_output=True, text=True).stdout
        print("simplified:", report.strip())
        kept = np.fromfile(files[3], np.uint32).reshape(-1, 3)

    used = np.unique(kept)
    remap = np.full(len(pos), -1, np.int64)
    remap[used] = np.arange(len(used))
    middles = pos[kept].mean(axis=1)
    inside = np.ones(len(kept), bool)

    for axis, (low, high) in enumerate(HEARTH):
        inside &= (middles[:, axis] >= low) & (middles[:, axis] <= high)

    hearth_tris = kept[inside]
    other_tris = kept[~inside]
    pos, nor, uv, kept = pos[used], nor[used], uv[used], remap[kept].astype(np.uint32)

    # 2. Size and place: WIDTH_M across, floor on 0, centred.
    lo, hi = pos.min(0), pos.max(0)
    scale = WIDTH_M / float(hi[0] - lo[0])
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
    hot = coal_strength(colour, hearth)[..., None]
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
    write_glb(args.out, out_pos, nor, uv, kept, pngs, place(FIRE_AT), place(SMOKE_AT))
    write_imports(args.out, pngs)
    size = out_pos.max(0) - out_pos.min(0)
    print("written %s: %d triangles, %.2f x %.2f x %.2f m (w x h x d), fire %s, smoke %s" % (args.out, len(kept), size[0], size[1], size[2],
                                                                                         place(FIRE_AT).round(3).tolist(), place(SMOKE_AT).round(3).tolist()))


def write_glb(path, pos, nor, uv, tris, pngs, fire, smoke):
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
        "asset": {"version": "2.0", "generator": "Dynasty tools/stations/prepare_improved_smithy.py"},
        "scene": 0, "scenes": [{"nodes": [0, 1, 2]}],   # all at the top, where inventory_view._forge_glb looks for Fire and Smoke (as in Dave's forges)
        "nodes": [{"name": "Smithy", "mesh": 0}, {"name": "Fire", "translation": [float(v) for v in fire]}, {"name": "Smoke", "translation": [float(v) for v in smoke]}],
        "meshes": [{"name": "Smithy", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"name": "ImprovedSmithy", "doubleSided": False, "normalTexture": {"index": 0},
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
