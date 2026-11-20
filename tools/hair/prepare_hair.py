#!/usr/bin/env python3
"""Turn a Meshy hair model into a game hair mesh fitted to Body 1's head (Dave 20 Nov 2026: hair styles in the character creator).

Meshy's hair files hold a whole bald mannequin head with the hair on it, normalised to a box about 1.9 units tall. This keeps only the hair and
fits it to Dynasty_Base_Male.glb's head in model space (metres, +Y up, facing +Z), so the game hangs it on the head bone with no other numbers:

1. The head is cut out by colour: the mannequin is pale grey and the hair is dark, so the colour texture gets an alpha channel (clear where pale)
   cut by the material (alpha scissor), and triangles wholly pale are dropped.
   Where the hair has bald gaps, Body 1's own scalp is copied a little outward as a cap in the hair's colour.
2. A box fit (width and depth of the skull above the ears, and the crown) moves the hair onto Body 1's head and keeps its shape; any part that
   would then sit inside Body 1's head is pushed straight out from the head's centre to CLEARANCE_M above the skin. Nothing hangs below the
   nape (NAPE_Y), where Meshy paints the mannequin's neck dark too: the hair ends there in an even line.
3. The three textures are scaled to 2048 (Dave ordered 2K, Meshy made 4K; the 4K originals stay in his Downloads) and the material is made
   one-sided (docs/design/CHARACTER_MESHES.md: one-sided faces; the hair is a closed shell over the scalp, so its back faces never show).

Usage: python3 -I tools/hair/prepare_hair.py SOURCE.glb OUT.glb [--male assets/character/Humanoid/Dynasty_Base_Male.glb]
Needs numpy and Pillow. Writes OUT.glb, its .import, its three textures as OUT_<texture>.png with their .import files (VRAM Compressed), and prints the fit.
"""
import argparse
import hashlib
import io
import json
import os
import struct
import sys

import numpy as np
from PIL import Image

OPAQUE_BELOW = 95.0      # paint darker than this (mean RGB) is hair, fully opaque; the mannequin's grey is about 165 to 190, the hair 30 to 65
CLEAR_FROM = 135.0       # paint this pale or paler is the mannequin's skin, fully clear; the alpha ramps between, and the material cuts at half
CLEARANCE_M = 0.004      # hair sits at least this far out from Body 1's scalp
CAP_CLEARANCE_M = 0.002  # the cap (2b) sits this far out from the skin, under the hair
HOLE_BINS = 3            # bald gaps up to about this many direction bins (3.75 degrees each) across are filled by the dark cap
NAPE_REACH_M = 0.012     # how far below NAPE_Y a triangle may reach and still be kept (lifted to the line)
NAPE_Y = 1.505           # Body 1 model space: nothing of the hair below this (the chin is at 1.495, the nape about the same)
TEXTURE_SIZE = 2048
HEAD_REACH_M = 0.16      # another body's head and neck: its points this close to the head's centre line, seen from above
HEAD_FROM_Y = 1.45       # Body 1's head and neck vertices start here (model space, metres); the shoulders are below
SKULL_FROM_Y = 1.61      # Body 1's skull above the ears (FITTING_NOTE.md: 0.145 wide, 0.191 deep from about y 1.61 up)
CENTRE_DROP = 0.10       # the radial centre sits this far under the crown, at about ear height
BINS = 48                # radius grid: BINS rows from the top pole down, 2 * BINS round

COMPONENT = {5126: np.float32, 5125: np.uint32, 5123: np.uint16, 5121: np.uint8}
WIDTH = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


class Glb:
    def __init__(self, path):
        data = open(path, "rb").read()
        json_len = struct.unpack("<I", data[12:16])[0]
        self.j = json.loads(data[20:20 + json_len])
        at = 20 + json_len
        bin_len = struct.unpack("<I", data[at:at + 4])[0]
        self.bin = data[at + 8:at + 8 + bin_len]

    def accessor(self, index):
        a = self.j["accessors"][index]
        view = self.j["bufferViews"][a["bufferView"]]
        kind = COMPONENT[a["componentType"]]
        n = WIDTH[a["type"]]
        start = view.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = view.get("byteStride", 0)
        size = np.dtype(kind).itemsize * n

        if stride and stride != size:
            raw = np.frombuffer(self.bin, np.uint8, count=stride * (a["count"] - 1) + size, offset=start)
            picks = np.arange(a["count"])[:, None] * stride + np.arange(size)[None]
            return raw[picks].copy().view(kind).reshape(a["count"], n)

        return np.frombuffer(self.bin, kind, count=a["count"] * n, offset=start).reshape(a["count"], n).copy()

    def image(self, index):
        view = self.j["bufferViews"][self.j["images"][index]["bufferView"]]
        start = view.get("byteOffset", 0)
        return Image.open(io.BytesIO(self.bin[start:start + view["byteLength"]]))

    def positions(self):
        return np.concatenate([self.accessor(p["attributes"]["POSITION"]).astype(float) for m in self.j["meshes"] for p in m["primitives"]])


def surface_samples(points, tris, count, rng, uvs=None):
    """Points spread over the triangles by area, so a coarse mesh still fills every direction bin. With uvs, also each point's texture coordinate."""
    a, b, c = points[tris[:, 0]], points[tris[:, 1]], points[tris[:, 2]]
    area = np.linalg.norm(np.cross(b - a, c - a), axis=1)
    pick = rng.choice(len(tris), size=count, p=area / area.sum())
    u, v = rng.random(count), rng.random(count)
    flip = u + v > 1.0
    u[flip], v[flip] = 1.0 - u[flip], 1.0 - v[flip]
    at = a[pick] + (b[pick] - a[pick]) * u[:, None] + (c[pick] - a[pick]) * v[:, None]

    if uvs is None:
        return at

    ua, ub, uc = uvs[tris[pick, 0]], uvs[tris[pick, 1]], uvs[tris[pick, 2]]
    return at, ua + (ub - ua) * u[:, None] + (uc - ua) * v[:, None]


def grow(mask, steps):
    for _ in range(steps):
        rows = mask | np.roll(mask, 1, 1) | np.roll(mask, -1, 1)
        mask = rows.copy()
        mask[1:] |= rows[:-1]
        mask[:-1] |= rows[1:]
    return mask


def shrink(mask, steps):
    return ~grow(~mask, steps)


def bin_of(dirs):
    theta = np.arccos(np.clip(dirs[:, 1], -1.0, 1.0))
    phi = np.arctan2(dirs[:, 0], dirs[:, 2])
    row = np.clip((theta / np.pi * BINS).astype(int), 0, BINS - 1)
    col = np.clip(((phi + np.pi) / (2.0 * np.pi) * 2 * BINS).astype(int), 0, 2 * BINS - 1)
    return row, col


def radius_grid(points, centre, keep_max, fill=True):
    """Radius of the surface in each direction from centre: the outermost sample (Body 1's head) or the innermost (the mannequin's scalp).
    Empty bins take their nearest filled neighbour (unless fill is off), then the grid is smoothed once so a stray sample does not make a dent."""
    offsets = points - centre
    r = np.linalg.norm(offsets, axis=1)
    row, col = bin_of(offsets / r[:, None])
    grid = np.full((BINS, 2 * BINS), -np.inf if keep_max else np.inf)

    if keep_max:
        np.maximum.at(grid, (row, col), r)
    else:
        np.minimum.at(grid, (row, col), r)

    filled = np.isfinite(grid)

    if not fill:
        return grid       # empty bins stay -inf / inf: "nothing in this direction"

    while not filled.all():
        grown = grid.copy()

        for dr, dc in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted = np.roll(np.roll(grid, dr, 0), dc, 1)
            take = ~filled & np.isfinite(shifted)
            grown[take] = shifted[take]

        grid = grown
        filled = np.isfinite(grid)

    padded = np.concatenate([grid[:, -1:], grid, grid[:, :1]], 1)
    smooth = grid.copy()

    for r0 in range(BINS):
        rows = padded[max(0, r0 - 1):r0 + 2]
        for c0 in range(2 * BINS):
            smooth[r0, c0] = np.median(rows[:, c0:c0 + 3])

    return smooth


def male_head(path, rng):
    body = Glb(path)
    prim = body.j["meshes"][0]["primitives"][0]
    points = body.accessor(prim["attributes"]["POSITION"]).astype(float)
    tris = body.accessor(prim["indices"]).reshape(-1, 3)
    normals = body.accessor(prim["attributes"]["NORMAL"]).astype(float)
    tris = tris[(points[tris][:, :, 1] > HEAD_FROM_Y).all(1)]
    return points, normals, tris, surface_samples(points, tris, 300000, rng)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("out")
    parser.add_argument("--male", default="assets/character/Humanoid/Dynasty_Base_Male.glb")
    parser.add_argument("--also", nargs="*", default=["assets/character/Humanoid/Playercharacter_Female_01.glb"],
                        help="other body models (body_models.gd); the hair clears their heads too, carried by their hair_fit (body_fit.py)")
    args = parser.parse_args()
    rng = np.random.default_rng(7)

    src = Glb(args.source)
    meshes = src.j["meshes"]

    if len(meshes) != 1 or len(meshes[0]["primitives"]) != 1:
        sys.exit("expected one mesh with one primitive (a Meshy export)")

    prim = meshes[0]["primitives"][0]
    pos = src.accessor(prim["attributes"]["POSITION"]).astype(float)
    nor = src.accessor(prim["attributes"]["NORMAL"]).astype(float)
    uv = src.accessor(prim["attributes"]["TEXCOORD_0"]).astype(np.float32)
    tris = src.accessor(prim["indices"]).reshape(-1, 3).astype(np.int64)
    material = src.j["materials"][prim["material"]]
    pbr = material["pbrMetallicRoughness"]
    images = {
        "texture_0": src.image(src.j["textures"][pbr["baseColorTexture"]["index"]]["source"]),
        "texture_0_metallic_roughness": src.image(src.j["textures"][pbr["metallicRoughnessTexture"]["index"]]["source"]),
        "normal": src.image(src.j["textures"][material["normalTexture"]["index"]]["source"]),
    }

    # 1. Cut the mannequin out by colour. The colour texture gets an alpha channel, opaque where the paint is dark (hair) and clear where it is pale
    # (the mannequin's skin), with a short ramp between; the material cuts at half (alpha scissor), so the hairline follows the paint pixel by pixel.
    # A triangle that is pale under all of its corners and its middle is dropped; one at the hairline stays and the alpha cuts it.
    colour = np.asarray(images["texture_0"].convert("RGB").resize((1024, 1024), Image.BILINEAR)).astype(float)

    def shade(at):
        x = (np.clip(at[..., 0], 0.0, 1.0) * 1023).astype(int)
        y = (np.clip(at[..., 1], 0.0, 1.0) * 1023).astype(int)
        return colour[y, x].mean(-1)

    tri_uv = uv[tris]
    tri_shades = np.concatenate([shade(tri_uv), shade(tri_uv.mean(1))[:, None]], 1)
    pale = tri_shades.min(1) >= OPAQUE_BELOW + 0.5 * (CLEAR_FROM - OPAQUE_BELOW)       # every sample past the alpha cut
    hair = tris[~pale]

    # 2a. Box fit: the mannequin's scalp box onto Body 1's skull box (width, depth, crown). Height takes the mean of the two side scales.
    samples = surface_samples(pos, tris, 300000, rng)
    m_centre = np.array([0.0, pos[:, 1].max() - 0.45 * np.ptp(pos[:, 1]), 0.0])
    m_grid = radius_grid(samples, m_centre, keep_max=False)
    m_row, m_col = bin_of((samples - m_centre) / np.linalg.norm(samples - m_centre, axis=1, keepdims=True))
    scalp = samples[np.linalg.norm(samples - m_centre, axis=1) <= m_grid[m_row, m_col] * 1.01]
    upper = scalp[scalp[:, 1] > m_centre[1]]

    body_points, body_normals, body_tris, body_samples = male_head(args.male, rng)
    skull = body_samples[body_samples[:, 1] >= SKULL_FROM_Y]
    crown = body_samples[:, 1].max()
    sx = np.ptp(skull[:, 0]) / np.ptp(upper[:, 0])
    sz = np.ptp(skull[:, 2]) / np.ptp(upper[:, 2])
    scale = np.array([sx, 0.5 * (sx + sz), sz])
    shift = np.array([
        skull[:, 0].min() + 0.5 * np.ptp(skull[:, 0]) - scale[0] * (upper[:, 0].min() + 0.5 * np.ptp(upper[:, 0])),
        crown - scale[1] * upper[:, 1].max(),
        skull[:, 2].min() + 0.5 * np.ptp(skull[:, 2]) - scale[2] * (upper[:, 2].min() + 0.5 * np.ptp(upper[:, 2])),
    ])
    boxed = pos * scale + shift
    centre = np.array([0.5 * (skull[:, 0].min() + skull[:, 0].max()), crown - CENTRE_DROP, 0.5 * (skull[:, 2].min() + skull[:, 2].max())])
    # The other bodies' heads, carried into Body 1's space by their own fit (body_fit.py, the same numbers as their hair_fit), so the hair clears
    # every head, not only Body 1's (Body 2's neck stands further back: without this her nape showed through the hair, PC pictures 20 Nov 2026).
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from body_fit import fit  # noqa: E402

    every_head = [body_samples]

    for other in args.also:
        o_scale, o_offset = fit(args.male, other)
        o_points, _, o_tris, _ = male_head(other, rng)
        o_points = (o_points - o_offset) / o_scale
        o_samples = surface_samples(o_points, o_tris, 300000, rng)
        near = np.linalg.norm((o_samples - centre)[:, [0, 2]], axis=1) < HEAD_REACH_M      # the head and neck, not arms held out (Body 2 rests in a T)
        every_head.append(o_samples[near])

    all_grid = radius_grid(np.concatenate(every_head), centre, keep_max=True)

    def direction(points):
        offsets = points - centre
        r = np.linalg.norm(offsets, axis=1)
        row, col = bin_of(offsets / r[:, None])
        return offsets / r[:, None], r, row, col

    # 2b. The cap: Meshy's hair has bald gaps (between curls, thin patches) where the mannequin's pale scalp showed through. Under the hair and in
    # those gaps Body 1's own scalp is copied CAP_CLEARANCE_M out and drawn in the hair's colour. "Under the hair" is the directions from the head's
    # centre that hold hair, closed by HOLE_BINS (grown, then shrunk back), so gaps fill but the hairline does not move.
    hair_points, hair_point_uv = surface_samples(boxed, hair, 200000, rng, uv)
    shown = shade(hair_point_uv) < OPAQUE_BELOW + 0.5 * (CLEAR_FROM - OPAQUE_BELOW)      # only hair the alpha cut keeps
    has_hair = np.isfinite(radius_grid(hair_points[shown], centre, keep_max=True, fill=False))
    inside = shrink(shrink(grow(has_hair, HOLE_BINS), HOLE_BINS), 1)      # one bin in from the hairline, so the cap never shows past the hair
    _, _, v_row, v_col = direction(body_points)
    cap = body_tris[inside[v_row, v_col][body_tris].all(1)]
    cap_used = np.unique(cap)
    cap_dirs, cap_r, _, _ = direction(body_points[cap_used])
    dark = hair[tri_shades[~pale].max(1) < OPAQUE_BELOW]
    dark_shade = shade(uv[dark].mean(1))
    hair_uv = uv[dark[np.argsort(dark_shade)[len(dark_shade) // 2]]].mean(0).astype(np.float32)     # the middle of the fully opaque hair triangle of median shade

    # 2c. Push out: the box-fitted hair keeps its shape; any part that would sit inside Body 1's head is pushed out along the line from the head's
    # centre to CLEARANCE_M above the skin, so it stays over the cap.
    used = np.unique(hair)
    dirs, r, row, col = direction(boxed[used])
    hair_pos = centre + dirs * np.maximum(r, all_grid[row, col] + CLEARANCE_M)[:, None]
    normals = nor / scale       # normals follow the box fit (the inverse transpose of a scale); the push is left out
    normals /= np.linalg.norm(normals, axis=1, keepdims=True)
    _, _, cap_row, cap_col = direction(body_points[cap_used])
    cap_r = np.maximum(cap_r, all_grid[cap_row, cap_col])        # over every head, but no further out than it must be
    out_pos = np.concatenate([hair_pos, centre + cap_dirs * (cap_r + CAP_CLEARANCE_M)[:, None]]).astype(np.float32)
    out_nor = np.concatenate([normals[used], body_normals[cap_used]]).astype(np.float32)
    out_uv = np.concatenate([uv[used], np.repeat(hair_uv[None], len(cap_used), 0)]).astype(np.float32)
    remap = np.full(len(pos), -1, np.int64)
    remap[used] = np.arange(len(used))
    cap_remap = np.full(len(body_points), -1, np.int64)
    cap_remap[cap_used] = len(used) + np.arange(len(cap_used))
    out_tris = np.concatenate([remap[hair], cap_remap[cap]])

    # 3. The nape: Meshy paints the mannequin's neck dark too. Nothing hangs below NAPE_Y, so the hair never reaches into the neck when the head turns:
    # a triangle reaching more than NAPE_REACH_M below it goes, and the corners of the ones just across it are lifted to it, so the hair ends in an even
    # line rather than a ragged one (a longer reach would fold far-hanging strands up into flaps).
    out_tris = out_tris[(out_pos[out_tris][:, :, 1] >= NAPE_Y - NAPE_REACH_M).all(1)]
    out_pos[:, 1] = np.maximum(out_pos[:, 1], NAPE_Y)
    keep = np.unique(out_tris)
    squeeze = np.full(len(out_pos), -1, np.int64)
    squeeze[keep] = np.arange(len(keep))
    out_tris = squeeze[out_tris].astype(np.uint32)
    out_pos, out_nor, out_uv = out_pos[keep], out_nor[keep], out_uv[keep]

    pngs = {}
    for key, img in images.items():
        small = img.convert("RGB").resize((TEXTURE_SIZE, TEXTURE_SIZE), Image.LANCZOS)

        if key == "texture_0":
            lum = np.asarray(small).astype(float).mean(-1)
            alpha = np.clip((CLEAR_FROM - lum) / (CLEAR_FROM - OPAQUE_BELOW), 0.0, 1.0)
            small = small.convert("RGBA")
            small.putalpha(Image.fromarray((alpha * 255.0 + 0.5).astype(np.uint8)))

        buf = io.BytesIO()
        small.save(buf, "PNG", optimize=True)
        pngs[key] = buf.getvalue()

    write_glb(args.out, out_pos, out_nor, out_uv, out_tris, pngs)
    write_imports(args.out, pngs)
    print(json.dumps({
        "source_triangles": int(len(tris)), "mannequin_triangles_cut": int(pale.sum()), "cap_triangles": int(len(cap)), "triangles": int(len(out_tris)), "vertices": int(len(out_pos)),
        "box_scale": [round(float(v), 5) for v in scale], "box_shift": [round(float(v), 5) for v in shift],
        "hair_box_min": [round(float(v), 4) for v in out_pos.min(0)], "hair_box_max": [round(float(v), 4) for v in out_pos.max(0)],
    }, indent=1))


def write_glb(path, pos, nor, uv, tris, pngs):
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

    accessors = [
        {"bufferView": add(pos.tobytes(), 34962), "componentType": 5126, "count": len(pos), "type": "VEC3", "min": pos.min(0).tolist(), "max": pos.max(0).tolist()},
        {"bufferView": add(nor.tobytes(), 34962), "componentType": 5126, "count": len(nor), "type": "VEC3"},
        {"bufferView": add(uv.tobytes(), 34962), "componentType": 5126, "count": len(uv), "type": "VEC2"},
        {"bufferView": add(tris.ravel().tobytes(), 34963), "componentType": 5125, "count": int(tris.size), "type": "SCALAR"},
    ]
    names = ["normal", "texture_0", "texture_0_metallic_roughness"]       # the same image names as Meshy's file, so the extracted PNGs are named the same way
    images = [{"name": n, "mimeType": "image/png", "bufferView": add(pngs[n])} for n in names]
    doc = {
        "asset": {"version": "2.0", "generator": "Dynasty tools/hair/prepare_hair.py"},
        "scene": 0, "scenes": [{"nodes": [0]}],
        "nodes": [{"name": "Hair", "children": [1]}, {"name": "HairMesh", "mesh": 0}],       # an empty root over the mesh, so the mesh is never the scene root

        "meshes": [{"name": "Hair", "primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1, "TEXCOORD_0": 2}, "indices": 3, "material": 0}]}],
        "materials": [{"name": "Hair", "doubleSided": False, "alphaMode": "MASK", "alphaCutoff": 0.5, "normalTexture": {"index": 0},
                       "pbrMetallicRoughness": {"baseColorTexture": {"index": 1}, "metallicRoughnessTexture": {"index": 2}}}],
        "textures": [{"source": i, "sampler": 0} for i in range(3)],
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


# ---------------------------------------------------------------- Godot import settings (docs/design/CHARACTER_MESHES.md)
# The glb's three textures are extracted beside it on import, each VRAM Compressed with mipmaps (the normal map as a normal map). Godot never writes an extracted image
# whose .png.import already exists and takes the PNG on disk as current when the md5 in it matches the decoded pixels, so the PNGs and their .import files are written here
# with that md5, and every machine imports the hair the same way. Same settings as Body 2 (Playercharacter_Female_01).

TEXTURE_IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="{uid}"
path.s3tc="res://.godot/imported/{name}-{path_md5}.s3tc.ctex"
metadata={{
"imported_formats": ["s3tc_bptc"],
"vram_texture": true
}}
generator_parameters={{
"md5": "{pixels_md5}"
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{path_md5}.s3tc.ctex"]

[params]

compress/mode=2
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal_map}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

SCENE_IMPORT = """[remap]

importer="scene"
importer_version=1
type="PackedScene"
uid="{uid}"
path="res://.godot/imported/{name}-{path_md5}.scn"

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}-{path_md5}.scn"]

[params]

nodes/root_type=""
nodes/root_name=""
nodes/root_script=null
mesh_library/use_node_names_as_mesh_names=false
array_mesh/deduplicate_surfaces=true
nodes/apply_root_scale=true
nodes/root_scale=1.0
nodes/import_as_skeleton_bones=false
nodes/use_name_suffixes=true
nodes/use_node_type_suffixes=true
meshes/ensure_tangents=true
meshes/generate_lods=true
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/lightmap_texel_size=0.2
meshes/force_disable_compression=false
skins/use_named_skins=true
animation/import=false
animation/fps=30
animation/trimming=false
animation/remove_immutable_tracks=true
animation/import_rest_as_RESET=false
import_script/path=""
materials/extract=0
materials/extract_format=0
materials/extract_path=""
_subresources={{}}
gltf/naming_version=2
gltf/embedded_image_handling=1
gltf/texture_map_mode=1
"""


def res_path(path):
    """res:// path of a file in the repository (the project root is this file's ../..)."""
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    return "res://" + os.path.relpath(os.path.abspath(path), root).replace(os.sep, "/")


def uid_for(res):
    """A Godot resource uid (ResourceUID::id_to_text: base 34, a-y then 0-8; a "z" is rewritten by Godot, seen on the PC lane 20 Nov 2026),
    taken from the path so a rerun writes the same one."""
    n = int.from_bytes(hashlib.sha256(res.encode()).digest()[:8], "little") & 0x7FFFFFFFFFFFFFFF
    text = ""
    while True:
        c = n % 34
        text = (chr(ord("a") + c) if c < 25 else chr(ord("0") + c - 25)) + text
        n //= 34
        if n == 0:
            return "uid://" + text


def write_imports(glb_path, pngs):
    base = os.path.splitext(glb_path)[0]
    for key, data in pngs.items():
        png = base + "_" + key + ".png"
        with open(png, "wb") as f:
            f.write(data)
        res = res_path(png)
        pixels = Image.open(io.BytesIO(data)).tobytes()      # the decoded pixels as Godot reads them (RGB, or RGBA for the colour with its alpha)
        with open(png + ".import", "w", newline="\n") as f:
            f.write(TEXTURE_IMPORT.format(uid=uid_for(res), name=os.path.basename(png), path_md5=hashlib.md5(res.encode()).hexdigest(),
                                          pixels_md5=hashlib.md5(pixels).hexdigest(), res=res, normal_map=1 if key == "normal" else 0))
    res = res_path(glb_path)
    with open(glb_path + ".import", "w", newline="\n") as f:
        f.write(SCENE_IMPORT.format(uid=uid_for(res), name=os.path.basename(glb_path), path_md5=hashlib.md5(res.encode()).hexdigest(), res=res))


if __name__ == "__main__":
    main()
