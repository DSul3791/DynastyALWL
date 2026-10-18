"""Draws tree models dumped by src/worldgen/tools/tree_mesh_dump.gd into a PNG,
without a graphics card: a small z-buffered software renderer using the real
leaf and bark textures and roughly the game's foliage tint and lighting.

Run: python3 tools/render_trees.py MESHES.json OUT.png [--elev=DEG] [--px=PIXELS_PER_M]
Each model is drawn side on (or from the given elevation), left to right, with a
1.8 m figure for scale.
"""
import json
import math
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TEX = os.path.join(HERE, "..", "assets", "trees")


def natural(c):
    g = 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2]
    return np.array([(g + (x - g) * 0.72) * 0.9 for x in c[:3]])


def load(name):
    return np.asarray(Image.open(os.path.join(TEX, name)).convert("RGBA"), dtype=np.float32) / 255.0


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    opts = dict(a[2:].split("=", 1) for a in sys.argv[1:] if a.startswith("--") and "=" in a)
    elev = math.radians(float(opts.get("elev", 8)))
    px = float(opts.get("px", 14))
    models = json.load(open(args[0]))
    tex = {"conifer": load("leaf_conifer.png"), "broad": load("leaf_broad.png"), "palm": load("leaf_palm.png"), "bark": load("bark.png")}
    widths = []
    for m in models:
        xs = np.concatenate([np.array(s["v"]).reshape(-1, 3)[:, 0] for s in m["surfaces"]])
        widths.append(max(4.0, (xs.max() - xs.min()) * 1.1 + 1.0))
    top = max(m["height"] for m in models) * 1.08 + 1
    W = int(sum(widths) * px) + 40
    H = int(top * px * math.cos(elev) + 60)
    img = np.zeros((H, W, 3), np.float32)
    sky = np.linspace(1.0, 0.0, H)[:, None]
    img[:] = (np.array([0.62, 0.74, 0.86]) * sky + np.array([0.86, 0.88, 0.84]) * (1 - sky))[:, None, :]
    ground = int(H - 30)
    img[ground:] = [0.36, 0.40, 0.25]
    zbuf = np.full((H, W), np.inf, np.float32)
    light = np.array([0.5, 0.75, 0.45]); light /= np.linalg.norm(light)
    ox = 20.0
    ce, se = math.cos(elev), math.sin(elev)

    def project(p, cx):
        # Camera looks along +z, tilted down by elev.
        y = p[:, 1] * ce - p[:, 2] * se
        z = p[:, 1] * se + p[:, 2] * ce
        return np.stack([cx + p[:, 0] * px, ground - y * px, z], 1)

    for m, w in zip(models, widths):
        cx = ox + w * px * 0.5
        tint = natural(m["color"]) * 1.5 * 0.92
        for s in m["surfaces"]:
            v = np.array(s["v"]).reshape(-1, 3)
            n = np.array(s["n"]).reshape(-1, 3)
            uv = np.array(s["uv"]).reshape(-1, 2)
            col = np.array(s["c"]).reshape(-1, 4)
            idx = np.array(s["i"]).reshape(-1, 3)
            P = project(v, cx)
            mat = s["material"]
            T = tex.get(mat, tex["conifer"])
            th, tw = T.shape[:2]
            for tri in idx:
                a, b, c = P[tri]
                x0, x1 = int(max(0, min(a[0], b[0], c[0]))), int(min(W - 1, max(a[0], b[0], c[0]) + 1))
                y0, y1 = int(max(0, min(a[1], b[1], c[1]))), int(min(H - 1, max(a[1], b[1], c[1]) + 1))
                if x1 <= x0 or y1 <= y0:
                    continue
                den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
                if abs(den) < 1e-9:
                    continue
                gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
                l0 = ((b[1] - c[1]) * (gx - c[0]) + (c[0] - b[0]) * (gy - c[1])) / den
                l1 = ((c[1] - a[1]) * (gx - c[0]) + (a[0] - c[0]) * (gy - c[1])) / den
                l2 = 1 - l0 - l1
                inside = (l0 >= 0) & (l1 >= 0) & (l2 >= 0)
                if not inside.any():
                    continue
                z = l0 * a[2] + l1 * b[2] + l2 * c[2]
                t_uv = l0[..., None] * uv[tri[0]] + l1[..., None] * uv[tri[1]] + l2[..., None] * uv[tri[2]]
                if mat == "bark":
                    tu = (t_uv[..., 0] % 1.0) * (tw - 1)
                    tv = (t_uv[..., 1] % 1.0) * (th - 1)
                else:
                    tu = np.clip(t_uv[..., 0], 0, 1) * (tw - 1)
                    tv = np.clip(t_uv[..., 1], 0, 1) * (th - 1)
                texel = T[tv.astype(int), tu.astype(int)]
                ok = inside & (texel[..., 3] >= 0.5)
                sub = zbuf[y0:y1, x0:x1]
                ok &= z < sub
                if not ok.any():
                    continue
                vc = col[tri[0]][:3]
                nn = n[tri].mean(0)
                nn /= max(np.linalg.norm(nn), 1e-6)
                if mat == "bark":
                    albedo = texel[..., :3] * vc * 1.8
                    shade = 0.45 + 0.55 * max(0.0, float(nn @ light))
                else:
                    albedo = texel[..., :3] * vc * tint
                    shade = 0.5 + 0.5 * abs(float(nn @ light))
                rgb = np.clip(albedo * shade * 1.15, 0, 1)
                sub[ok] = z[ok]
                img[y0:y1, x0:x1][ok] = rgb[ok]
        # A 1.8 m figure for scale, standing beside the tree.
        fx = int(cx + w * px * 0.42)
        img[int(ground - 1.8 * px):ground, fx - max(1, int(px * 0.2)):fx + max(1, int(px * 0.2))] = [0.75, 0.25, 0.2]
        ox += w * px
    Image.fromarray((img * 255).astype(np.uint8)).save(args[1])
    print("wrote", args[1], W, "x", H)


if __name__ == "__main__":
    main()
