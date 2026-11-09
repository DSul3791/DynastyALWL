#!/usr/bin/env python3
"""Bring item icons into assets/ui/item_icons/ with their Godot .import files (inventory redesign step 5; Kathleen, 9 Nov 2026).

The icon bake (tools/icon_bake.gd) writes one 128 x 128 PNG per item id on Dave's PC; the painted ones come from
tools/paint_basic_icons.py. This copies a folder of them in, checks each one, and writes the .png.import file Godot would write,
so InventoryLook.icon_for finds them (ResourceLoader.exists needs the .import) without an editor import first.

    python3 tools/import_item_icons.py SOURCE_DIR        copy SOURCE_DIR/*.png in (painted icons already here are kept)
    python3 tools/import_item_icons.py --imports-only    write missing .import files for the PNGs already in the folder

It prints what it copied, what it skipped and why, and which items still have no icon (they show the hatched "?" tile).
"""
import argparse
import hashlib
import json
import os
import random
import shutil
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEST = os.path.join(ROOT, "assets", "ui", "item_icons")
RES_DIR = "res://assets/ui/item_icons/"
ITEMS = os.path.join(ROOT, "data", "items", "items.json")
PAINTED = ("log", "stick", "stone")          # painted by tools/paint_basic_icons.py: a baked file of the same name never replaces them
UID_CHARS = "abcdefghijklmnopqrstuvwxy012345678"   # Godot's resource uid alphabet (base 34)

IMPORT = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{name}.png-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res}"
dest_files=["res://.godot/imported/{name}.png-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
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
detect_3d/compress_to=1
"""


def item_ids():
    with open(ITEMS, encoding="utf-8") as f:
        data = json.load(f)

    items = data.get("items", data) if isinstance(data, dict) else data
    rows = items.items() if isinstance(items, dict) else ((str(i.get("id")), i) for i in items)
    return sorted(k for k, v in rows if not (isinstance(v, dict) and v.get("retired")))


def new_uid(name):
    rng = random.Random(hashlib.sha1(("item_icon:" + name).encode()).digest())   # the same uid every run for the same icon
    return rng.choice("bcd") + "".join(rng.choice(UID_CHARS) for _ in range(12))


def write_import(name):
    path = os.path.join(DEST, name + ".png.import")

    if os.path.isfile(path):
        return False

    res = RES_DIR + name + ".png"
    md5 = hashlib.md5(res.encode()).hexdigest()
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write(IMPORT.format(uid=new_uid(name), name=name, md5=md5, res=res))
    return True


def check(path):
    with Image.open(path) as im:
        if im.size != (128, 128):
            return "is %dx%d, not 128 x 128" % im.size
        if im.mode not in ("RGBA", "LA", "P"):
            return "has no alpha (mode %s)" % im.mode
    return ""


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source", nargs="?")
    parser.add_argument("--imports-only", action="store_true")
    args = parser.parse_args()
    os.makedirs(DEST, exist_ok=True)
    ids = set(item_ids())
    copied, skipped = 0, []

    if not args.imports_only:
        if not args.source or not os.path.isdir(args.source):
            sys.exit("give the folder of baked icons (or --imports-only)")

        for file in sorted(os.listdir(args.source)):
            name, ext = os.path.splitext(file)

            if ext.lower() != ".png":
                continue
            if name not in ids:
                skipped.append((file, "is not an item id in items.json"))
                continue
            if name in PAINTED and os.path.isfile(os.path.join(DEST, file)):
                skipped.append((file, "is painted (tools/paint_basic_icons.py); the painted one stays"))
                continue

            problem = check(os.path.join(args.source, file))

            if problem:
                skipped.append((file, problem))
                continue

            shutil.copyfile(os.path.join(args.source, file), os.path.join(DEST, file))
            copied += 1

    imports = sum(write_import(os.path.splitext(f)[0]) for f in sorted(os.listdir(DEST)) if f.endswith(".png"))
    have = {os.path.splitext(f)[0] for f in os.listdir(DEST) if f.endswith(".png")}
    print("copied %d icons, wrote %d .import files, %d icons in %s" % (copied, imports, len(have), os.path.relpath(DEST, ROOT)))

    for file, why in skipped:
        print("skipped %s: %s" % (file, why))

    missing = sorted(ids - have)
    print("%d of %d items still have no icon (the hatched '?' tile)%s" % (len(missing), len(ids), ": " + ", ".join(missing[:40]) + (" ..." if len(missing) > 40 else "") if missing else ""))


if __name__ == "__main__":
    main()
