"""Copy bought animal models into the project (they are never committed: /assets/animals/ is ignored).

For every row in data/animals/models.json with a "pack" folder, the folder's files (the .fbx and its Textures) are copied
into the folder of the row's scene. .blend files are skipped: a headless import cannot read them, and with one beside the
.fbx the import writes no .import file at all (MikeW, 7 Nov 2026). Files already there with the same size are left alone.

    python tools/install_animal_models.py --pack "C:/Users/david/Downloads/ultimate 3d animal pack" [--kinds=bear,deer] [--project=.]

Then import once (godot --headless --path . --import) and check with tools/creature_check.gd.
"""
import argparse, json, os, shutil, sys

ap = argparse.ArgumentParser()
ap.add_argument("--pack", default="C:/Users/david/Downloads/ultimate 3d animal pack")
ap.add_argument("--project", default=".")
ap.add_argument("--kinds", default="")
args = ap.parse_args()

rows = json.load(open(os.path.join(args.project, "data/animals/models.json"), encoding="utf8"))["species"]
want = [k for k in args.kinds.split(",") if k]
bad = 0

jobs = []
for kind, row in rows.items():
    jobs.append((kind, row))
    for v in row.get("variants", []) + ([row["young_model"]] if isinstance(row.get("young_model"), dict) else []):      # a look or a young model with its own file and pack folder (the rooster beside the hen, the calf)
        if "pack" in v and "scene" in v:
            jobs.append((kind, v))

for kind, row in jobs:
    if want and kind not in want:
        continue
    if "pack" not in row:
        print("%-14s no pack folder in its row: skipped" % kind)
        continue
    src = os.path.join(args.pack, row["pack"])
    dst = os.path.join(args.project, os.path.dirname(row["scene"].replace("res://", "")))
    scene = os.path.join(args.project, row["scene"].replace("res://", ""))
    if not os.path.isdir(src):
        print("%-14s MISSING in the pack: %s" % (kind, src))
        bad += 1
        continue
    copied = 0
    for base, _dirs, files in os.walk(src):
        for f in files:
            if f.lower().endswith((".blend", ".blend1")):
                continue
            s = os.path.join(base, f)
            d = os.path.join(dst, os.path.relpath(s, src))
            if os.path.exists(d) and os.path.getsize(d) == os.path.getsize(s):
                continue
            os.makedirs(os.path.dirname(d), exist_ok=True)
            shutil.copy2(s, d)
            copied += 1
    ok = os.path.exists(scene)
    print("%-14s %s  %d files copied%s" % (kind, dst, copied, "" if ok else "  SCENE NOT FOUND: " + row["scene"]))
    bad += 0 if ok else 1

sys.exit(1 if bad else 0)
