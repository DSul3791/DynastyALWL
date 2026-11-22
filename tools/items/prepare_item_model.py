#!/usr/bin/env python3
"""Turn one of Dave's baked item models (one mesh, three textures: colour, metallic-roughness, normal) into the game's mesh, as
tools/stations/prepare_station_model.py does for the stations, without the coals: the Simple snare (Dave 22 Nov 2026, Basic_Rabbit_Snare_80k.glb,
"sized appropriately for catching rabbits").

1. Cuts it with meshoptimizer (tools/stations/simplify_mesh.mjs), keeping every texture seam.
2. Scales it so its size along one axis is the item's metres, its floor on y 0 and centred on the pivot (+Y up, as the file is).
3. Scales the textures to TEXTURE px and makes the material one-sided (Cast Shadow On, not Double-Sided: Dave's mesh rule).
4. Writes OUT.glb, its .import and its three textures as OUT_<texture>.png with their .import files (VRAM Compressed).

Usage: python3 -I tools/items/prepare_item_model.py ITEM SOURCE.glb OUT.glb --node-modules DIR
ITEM is a key of ITEMS. DIR is a folder whose node_modules holds meshoptimizer 0.25.0 (npm i meshoptimizer@0.25.0 in it). Needs numpy, Pillow, node.
"""
import argparse
import io
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(HERE, "hair"))
sys.path.insert(0, os.path.join(HERE, "stations"))
from prepare_hair import Glb, write_imports  # noqa: E402  (the same reader and import files as the hair and the stations)
import prepare_station_model as stations  # noqa: E402

# fit: (axis, metres) the model is scaled to. target: triangles asked of the simplifier (seams stop it higher). texture: px.
ITEMS = {
    # A rabbit snare: the loop a fist across (about 11 cm) with its bottom a hand (about 12 cm) above the ground (Shooting UK, MeatEater,
    # Wildwood: see docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md). In Dave's file the loop is 0.33 of 1.52 units high, so the frame stands
    # 0.5 m (0.63 m wide): a rabbit (0.45 m long in the game) puts its head through the loop.
    "simple_snare": {"node": "SimpleSnare", "material": "SimpleSnare", "fit": (1, 0.5), "target": 6000, "max_error": 0.04, "texture": 1024},
}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("item", choices=sorted(ITEMS))
    ap.add_argument("source")
    ap.add_argument("out")
    ap.add_argument("--node-modules", required=True)
    args = ap.parse_args()
    it = ITEMS[args.item]

    src = Glb(args.source)
    prim = src.j["meshes"][0]["primitives"][0]
    pos = src.accessor(prim["attributes"]["POSITION"]).astype(np.float32)
    nor = src.accessor(prim["attributes"]["NORMAL"]).astype(np.float32)
    uv = src.accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float32)
    tris = src.accessor(prim["indices"]).astype(np.uint32).reshape(-1, 3)
    mat = src.j["materials"][prim.get("material", 0)]
    tex_of = {name: src.j["textures"][slot["index"]]["source"] for name, slot in
              [("texture_0", mat["pbrMetallicRoughness"]["baseColorTexture"]), ("texture_0_metallic_roughness", mat["pbrMetallicRoughness"]["metallicRoughnessTexture"]),
               ("normal", mat["normalTexture"])]}

    with tempfile.TemporaryDirectory() as tmp:
        files = [os.path.join(tmp, n) for n in ("pos.bin", "uv.bin", "idx.bin", "out.bin")]
        pos.tofile(files[0])
        uv.tofile(files[1])
        tris.tofile(files[2])
        local = os.path.join(os.path.abspath(args.node_modules), "simplify_mesh.mjs")
        open(local, "w").write(open(os.path.join(HERE, "stations", "simplify_mesh.mjs")).read())
        report = subprocess.run(["node", local, *files, str(it["target"]), str(it["max_error"])], check=True, capture_output=True, text=True).stdout
        print("simplified:", report.strip())
        kept = np.fromfile(files[3], np.uint32).reshape(-1, 3)

    used = np.unique(kept)
    remap = np.full(len(pos), -1, np.int64)
    remap[used] = np.arange(len(used))
    pos, nor, uv, kept = pos[used], nor[used], uv[used], remap[kept].astype(np.uint32)

    lo, hi = pos.min(0), pos.max(0)
    axis, metres = it["fit"]
    scale = metres / float(hi[axis] - lo[axis])
    shift = np.array([-(lo[0] + hi[0]) * 0.5, -lo[1], -(lo[2] + hi[2]) * 0.5], np.float32)
    out_pos = ((pos + shift) * scale).astype(np.float32)

    size = it["texture"]

    def png(index, mode="RGB"):
        buf = io.BytesIO()
        src.image(index).convert(mode).resize((size, size), Image.LANCZOS).save(buf, "PNG", optimize=True)
        return buf.getvalue()

    pngs = {"normal": png(tex_of["normal"]), "texture_0": png(tex_of["texture_0"]), "texture_0_metallic_roughness": png(tex_of["texture_0_metallic_roughness"])}
    black = io.BytesIO()
    Image.new("RGB", (4, 4), (0, 0, 0)).save(black, "PNG")
    pngs["emissive"] = black.getvalue()   # stations.write_glb wants one; a 4 px black one glows nowhere
    stations.write_glb(args.out, out_pos, nor, uv, kept, pngs, np.zeros(3), np.zeros(3), it["node"], it["material"])
    write_imports(args.out, pngs)
    dims = out_pos.max(0) - out_pos.min(0)
    print("written %s: %d triangles, %.2f x %.2f x %.2f m (w x h x d)" % (args.out, len(kept), dims[0], dims[1], dims[2]))


if __name__ == "__main__":
    main()
