#!/usr/bin/env python3
"""Turn one of Dave's baked item models (one mesh, three textures: colour, metallic-roughness, normal) into the game's mesh: the Simple snare
(Dave 22 Nov 2026, Basic_Rabbit_Snare_80k.glb, "sized appropriately for catching rabbits").

Dave's scanned-style meshes cut their texture into thousands of small islands, so a seam-keeping cut (tools/stations/prepare_station_model.py)
stops near 25,000 triangles, and a cut across the seams smears one island's colour over another (measured on the snare: over half its area).
For a small item placed many times this rebakes instead:

1. Welds the corners that share a position, and cuts the shape alone with meshoptimizer (tools/items/simplify_shape.mjs) to TARGET triangles.
2. Lays out new texture coordinates for the cut mesh (xatlas).
3. Bakes each new texel from the nearest point of Dave's full mesh: its colour and metallic-roughness, and its normal map turned from his
   surface into the cut one (so the detail the cut takes out stays in the shading). Pads past the island edges so mipmaps do not bleed.
4. Scales it so its size along one axis is the item's metres, its floor on y 0 and centred on the pivot (+Y up, as the file is), and writes
   OUT.glb, its .import and its textures as OUT_<texture>.png with their .import files (VRAM Compressed; one-sided: Cast Shadow On).

Usage: python3 -I tools/items/prepare_item_model.py ITEM SOURCE.glb OUT.glb --node-modules DIR
ITEM is a key of ITEMS. DIR is a folder whose node_modules holds meshoptimizer 0.25.0 (npm i meshoptimizer@0.25.0 in it).
Needs numpy, Pillow, scipy, xatlas (pip install scipy xatlas) and node.
"""
import argparse
import io
import os
import subprocess
import sys
import tempfile

import numpy as np
import xatlas
from PIL import Image
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(HERE, "hair"))
sys.path.insert(0, os.path.join(HERE, "stations"))
from prepare_hair import Glb, write_imports  # noqa: E402  (the same reader and import files as the hair and the stations)
import prepare_station_model as stations  # noqa: E402

# fit: (axis, metres) the model is scaled to. target: triangles. max_error: the cut's allowed shape error, a share of the model's size.
# texture: px of the baked textures. samples: points per triangle of Dave's mesh the bake looks up. thin: a box (x, y min and max, in the file's
# units) holding a thin part cut on its own with its share of the triangles, as the shape error alone flattens a cord a few mm thick.
ITEMS = {
    # A rabbit snare: the loop a fist across (about 11 cm) with its bottom a hand (about 12 cm) above the ground (Shooting UK, MeatEater,
    # Wildwood: see docs/design/ANIMAL_ROUTINES_TRAILS_TRAPPING.md). In Dave's file the loop is 0.33 of 1.52 units high, so the frame stands
    # 0.5 m (0.63 m wide): a rabbit (0.45 m long in the game) puts its head through the loop.
    "simple_snare": {"node": "SimpleSnare", "material": "SimpleSnare", "fit": (1, 0.5), "target": 5000, "max_error": 0.01, "texture": 1024, "samples": 6,
                     "thin": ((-0.173, -0.421, 0.116, 0.435), 0.25)},   # the noose hanging free under the crossbar
}


def _frames(pos, tris, uv, nor):
    """Per triangle: tangent and bitangent (the directions u and v grow along) made square to the corners' mean normal."""
    a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
    ta, tb, tc = uv[tris[:, 0]], uv[tris[:, 1]], uv[tris[:, 2]]
    e1, e2, d1, d2 = b - a, c - a, tb - ta, tc - ta
    det = d1[:, 0] * d2[:, 1] - d2[:, 0] * d1[:, 1]
    det = np.where(np.abs(det) < 1e-12, 1e-12, det)
    t = (e1 * d2[:, 1:2] - e2 * d1[:, 1:2]) / det[:, None]
    bt = (e2 * d1[:, 0:1] - e1 * d2[:, 0:1]) / det[:, None]
    n = nor[tris].mean(1)
    n /= np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12)
    t -= n * (t * n).sum(1, keepdims=True)
    t /= np.maximum(np.linalg.norm(t, axis=1, keepdims=True), 1e-12)
    hand = np.sign((np.cross(n, t) * bt).sum(1, keepdims=True))
    return t, np.cross(n, t) * np.where(hand == 0, 1, hand)


def _sample(img, uv):
    """Bilinear colour of img (h, w, c float) at uv (n, 2); v runs down the image, as in glTF."""
    h, w = img.shape[:2]
    x = np.clip(uv[:, 0] * w - 0.5, 0, w - 1)
    y = np.clip(uv[:, 1] * h - 0.5, 0, h - 1)
    x0, y0 = np.floor(x).astype(int), np.floor(y).astype(int)
    x1, y1 = np.minimum(x0 + 1, w - 1), np.minimum(y0 + 1, h - 1)
    fx, fy = (x - x0)[:, None], (y - y0)[:, None]
    return img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x1] * fx * (1 - fy) + img[y1, x0] * (1 - fx) * fy + img[y1, x1] * fx * fy


def _pad(img, filled, rounds=16):
    """Spreads the baked texels outward into the empty ones, a texel a round, so mipmaps and filtering at island edges read the island's colour."""
    img, filled = img.copy(), filled.copy()
    for _ in range(rounds):
        acc = np.zeros_like(img)
        cnt = np.zeros(filled.shape, np.float32)
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            f = np.roll(filled, (dy, dx), (0, 1))
            acc += np.roll(img, (dy, dx), (0, 1)) * f[..., None]
            cnt += f
        grow = (~filled) & (cnt > 0)
        img[grow] = acc[grow] / cnt[grow][:, None]
        filled |= grow
    return img


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
    pos = src.accessor(prim["attributes"]["POSITION"]).astype(np.float64)
    nor = src.accessor(prim["attributes"]["NORMAL"]).astype(np.float64)
    uv = src.accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float64)
    tris = src.accessor(prim["indices"]).astype(np.int64).reshape(-1, 3)
    mat = src.j["materials"][prim.get("material", 0)]
    tex_of = {name: src.j["textures"][slot["index"]]["source"] for name, slot in
              [("texture_0", mat["pbrMetallicRoughness"]["baseColorTexture"]), ("texture_0_metallic_roughness", mat["pbrMetallicRoughness"]["metallicRoughnessTexture"]),
               ("normal", mat["normalTexture"])]}
    images = {k: np.asarray(src.image(i).convert("RGB"), np.float32) / 255.0 for k, i in tex_of.items()}

    # 1. Weld and cut the shape.
    weld, inv = np.unique(pos.round(5), axis=0, return_inverse=True)
    welded = inv.ravel()[tris]
    welded = welded[(welded[:, 0] != welded[:, 1]) & (welded[:, 1] != welded[:, 2]) & (welded[:, 0] != welded[:, 2])]
    parts = [(welded, it["target"], [])]
    if "thin" in it:
        (x0, y0, x1, y1), share = it["thin"]
        mid = weld[welded].mean(1)
        inside = (mid[:, 0] > x0) & (mid[:, 0] < x1) & (mid[:, 1] > y0) & (mid[:, 1] < y1)
        parts = [(welded[inside], int(it["target"] * share), ["LockBorder"]), (welded[~inside], it["target"] - int(it["target"] * share), ["LockBorder"])]
    cuts = []
    with tempfile.TemporaryDirectory() as tmp:
        local = os.path.join(os.path.abspath(args.node_modules), "simplify_shape.mjs")
        open(local, "w").write(open(os.path.join(HERE, "items", "simplify_shape.mjs")).read())
        for part, target, flags in parts:
            files = [os.path.join(tmp, n) for n in ("pos.bin", "idx.bin", "out.bin")]
            weld.astype(np.float32).tofile(files[0])
            part.astype(np.uint32).tofile(files[1])
            report = subprocess.run(["node", local, *files, str(target), str(it["max_error"]), *flags], check=True, capture_output=True, text=True).stdout
            print("simplified %d triangles:" % len(part), report.strip())
            cuts.append(np.fromfile(files[2], np.uint32).reshape(-1, 3).astype(np.int64))
    cut = np.concatenate(cuts)
    used = np.unique(cut)
    remap = np.full(len(weld), -1, np.int64)
    remap[used] = np.arange(len(used))
    low_pos, cut = weld[used], remap[cut]
    fn = np.cross(low_pos[cut[:, 1]] - low_pos[cut[:, 0]], low_pos[cut[:, 2]] - low_pos[cut[:, 0]])   # smooth normals, by area
    low_nor = np.zeros_like(low_pos)
    for k in range(3):
        np.add.at(low_nor, cut[:, k], fn)
    low_nor /= np.maximum(np.linalg.norm(low_nor, axis=1, keepdims=True), 1e-12)

    # 2. New texture coordinates.
    size = it["texture"]
    atlas = xatlas.Atlas()
    atlas.add_mesh(low_pos.astype(np.float32), cut.astype(np.uint32), low_nor.astype(np.float32))
    pack = xatlas.PackOptions()
    pack.resolution = size
    pack.padding = 4
    pack.bilinear = True
    atlas.generate(pack_options=pack)
    vmap, ltris, luv = atlas[0]
    ltris = ltris.astype(np.int64)
    lpos, lnor, luv = low_pos[vmap], low_nor[vmap], luv.astype(np.float64)
    luv[:, 1] = 1.0 - luv[:, 1]   # xatlas counts v up the image, glTF down it

    # 3. Bake. Dave's mesh as many points, each with its texture coordinate and its surface frame (normal, tangent, bitangent).
    rng = np.random.default_rng(7)
    s = it["samples"]
    bary = rng.dirichlet((1, 1, 1), (len(tris), s))
    pts = np.einsum("tsk,tkd->tsd", bary, pos[tris]).reshape(-1, 3)
    pts_uv = np.einsum("tsk,tkd->tsd", bary, uv[tris]).reshape(-1, 2)
    pts_n = np.einsum("tsk,tkd->tsd", bary, nor[tris]).reshape(-1, 3)
    pts_n /= np.maximum(np.linalg.norm(pts_n, axis=1, keepdims=True), 1e-12)
    ht, hb = _frames(pos, tris, uv, nor)
    pts_t, pts_b = np.repeat(ht, s, 0), np.repeat(hb, s, 0)
    tree = cKDTree(pts)

    lt, lb = _frames(lpos, ltris, luv, lnor)
    texel_xyz, texel_n, texel_t, texel_b, texel_at = [], [], [], [], []
    for f in range(len(ltris)):
        corner = luv[ltris[f]] * size - 0.5
        x0, y0 = np.floor(corner.min(0)).astype(int)
        x1, y1 = np.ceil(corner.max(0)).astype(int)
        gx, gy = np.meshgrid(np.arange(max(x0, 0), min(x1, size - 1) + 1), np.arange(max(y0, 0), min(y1, size - 1) + 1))
        g = np.stack([gx.ravel(), gy.ravel()], 1).astype(np.float64)
        a, b, c = corner
        m = np.array([[b[0] - a[0], c[0] - a[0]], [b[1] - a[1], c[1] - a[1]]])
        if abs(np.linalg.det(m)) < 1e-12:
            continue
        w12 = np.linalg.solve(m, (g - a).T).T
        w = np.column_stack([1 - w12.sum(1), w12])
        inside = (w >= -0.02).all(1)   # a hair past the edge, so seams are filled on both sides
        if not inside.any():
            continue
        w, g = w[inside], g[inside].astype(int)
        texel_xyz.append(w @ lpos[ltris[f]])
        n = w @ lnor[ltris[f]]
        texel_n.append(n / np.maximum(np.linalg.norm(n, axis=1, keepdims=True), 1e-12))
        texel_t.append(np.repeat(lt[f:f + 1], len(w), 0))
        texel_b.append(np.repeat(lb[f:f + 1], len(w), 0))
        texel_at.append(g)
    xyz, tn, tt, tb, at = (np.concatenate(v) for v in (texel_xyz, texel_n, texel_t, texel_b, texel_at))
    _, near = tree.query(xyz, workers=-1)
    src_uv = pts_uv[near]

    filled = np.zeros((size, size), bool)
    filled[at[:, 1], at[:, 0]] = True
    out = {}
    for key in ("texture_0", "texture_0_metallic_roughness"):
        img = np.zeros((size, size, 3), np.float32)
        img[at[:, 1], at[:, 0]] = _sample(images[key], src_uv)
        out[key] = _pad(img, filled)
    # The normal: Dave's tangent-space normal into world space by his surface's frame, then into the cut surface's frame.
    nt = _sample(images["normal"], src_uv) * 2.0 - 1.0
    world = pts_t[near] * nt[:, 0:1] + pts_b[near] * nt[:, 1:2] + pts_n[near] * nt[:, 2:3]
    world /= np.maximum(np.linalg.norm(world, axis=1, keepdims=True), 1e-12)
    local = np.column_stack([(world * tt).sum(1), (world * tb).sum(1), (world * tn).sum(1)])
    local[:, 2] = np.maximum(local[:, 2], 0.05)
    local /= np.linalg.norm(local, axis=1, keepdims=True)
    img = np.zeros((size, size, 3), np.float32)
    img[..., 2] = 1.0
    img[at[:, 1], at[:, 0]] = local * 0.5 + 0.5
    out["normal"] = _pad(img, filled)

    def png(arr):
        buf = io.BytesIO()
        Image.fromarray((np.clip(arr, 0, 1) * 255 + 0.5).astype(np.uint8), "RGB").save(buf, "PNG", optimize=True)
        return buf.getvalue()

    pngs = {k: png(v) for k, v in out.items()}
    black = io.BytesIO()
    Image.new("RGB", (4, 4), (0, 0, 0)).save(black, "PNG")
    pngs["emissive"] = black.getvalue()   # stations.write_glb wants one; a 4 px black one glows nowhere

    # 4. Scale and write.
    lo, hi = lpos.min(0), lpos.max(0)
    axis, metres = it["fit"]
    scale = metres / float(hi[axis] - lo[axis])
    shift = np.array([-(lo[0] + hi[0]) * 0.5, -lo[1], -(lo[2] + hi[2]) * 0.5])
    out_pos = ((lpos + shift) * scale).astype(np.float32)
    stations.write_glb(args.out, out_pos, lnor.astype(np.float32), luv.astype(np.float32), ltris.astype(np.uint32), pngs, np.zeros(3), np.zeros(3),
                       it["node"], it["material"])
    write_imports(args.out, pngs)
    dims = out_pos.max(0) - out_pos.min(0)
    print("written %s: %d triangles, %d corners, %d texels baked, %.2f x %.2f x %.2f m (w x h x d)" % (
        args.out, len(ltris), len(lpos), len(at), dims[0], dims[1], dims[2]))


if __name__ == "__main__":
    main()
