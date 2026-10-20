"""Checks the sound pack against its manifest: python3 assets/audio/validate_pack.py [--strict]

Reports, from assets/audio/make_manifest.py's SLOTS table and the files on disk:
  MISSING      a slot with no recording and no generated sound (priority shown); the footstep
               surfaces with no recorded left/right files
  OVERSIZED    a sound file over WARN_KB (warning) or ERROR_KB (error), or the recorded folder
               over TOTAL_MB; big files cost memory and download size (see ARCHITECTURE_BUDGET.md)
  UNREFERENCED a sound file whose name matches no slot or footstep surface (a leftover or a typo;
               the game will never play it)
  STALE        sound_manifest.json differs from what the folders hold now (run make_manifest.py)
  UNPAIRED     a footstep surface with only left or only right files, or uneven counts
Exit status 1 when there are errors (oversized beyond ERROR_KB, unreferenced, unpaired); with
--strict, missing slots and warnings count as errors too. Run it before committing sounds.
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import make_manifest as mm  # noqa: E402

WARN_KB = 400
ERROR_KB = 2500
TOTAL_MB = 40
SKIP_DIRS = {"__pycache__"}
EXTS = (".ogg", ".wav")


def sound_files():
    """Every sound file as (path relative to assets/audio, size in bytes)."""
    found = []

    for folder, dirs, files in os.walk(HERE):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]

        for f in files:
            if f.endswith(EXTS):
                path = os.path.join(folder, f)
                found.append((os.path.relpath(path, HERE), os.path.getsize(path)))

    return found


def base_name(file_name):
    """clip_3.ogg -> clip; step_grass_left_1.ogg -> step_grass_left."""
    return re.sub(r"_\d+$", "", os.path.splitext(file_name)[0])


def main():
    strict = "--strict" in sys.argv
    errors, warnings, notes = [], [], []
    slot_names = {name for name, *_ in mm.SLOTS}
    step_names = {"step_%s_%s" % (surface, side) for surface, _ in mm.STEPS for side in ("left", "right")}
    step_names |= {"step_%s" % surface for surface, _ in mm.STEPS}   # generated sets (floors/) have no left/right
    files = sound_files()

    for name, group, where, supply, priority in mm.SLOTS:
        state, count = mm.status(name, group)

        if state == "empty":
            warnings.append("MISSING %s (priority %d): no recording and no generated sound (%s)" % (name, priority, where.split(":")[0]))

    for surface, where in mm.STEPS:
        sides = {side: len([f for f, _ in files if re.search(r"(^|/)step_%s_%s_\d+\.(ogg|wav)$" % (surface, side), f)]) for side in ("left", "right")}

        if sides["left"] == 0 and sides["right"] == 0:
            warnings.append("MISSING step_%s: no recorded left and right footsteps" % surface)
        elif sides["left"] != sides["right"]:
            errors.append("UNPAIRED step_%s: %d left files, %d right files" % (surface, sides["left"], sides["right"]))

    total = 0

    for path, size in files:
        in_recorded = path.startswith("recorded" + os.sep)
        total += size if in_recorded else 0
        kb = size / 1024.0

        if kb > ERROR_KB:
            errors.append("OVERSIZED %s: %.0f KB (limit %d KB)" % (path, kb, ERROR_KB))
        elif kb > WARN_KB:
            warnings.append("OVERSIZED %s: %.0f KB (over %d KB; fine for a long loop, check anything else)" % (path, kb, WARN_KB))

        base = base_name(os.path.basename(path))

        if base not in slot_names and base not in step_names:
            errors.append("UNREFERENCED %s: no slot or footstep named %s in make_manifest.py" % (path, base))

    if total / 1048576.0 > TOTAL_MB:
        errors.append("OVERSIZED recorded folder: %.1f MB (limit %d MB)" % (total / 1048576.0, TOTAL_MB))

    manifest_path = os.path.join(HERE, "sound_manifest.json")

    if not os.path.exists(manifest_path):
        errors.append("STALE sound_manifest.json is missing: run make_manifest.py")
    else:
        stored = json.load(open(manifest_path))
        by_name = {row["name"]: row for row in stored.get("slots", [])}

        for name, group, where, supply, priority in mm.SLOTS:
            state, count = mm.status(name, group)
            row = by_name.get(name)

            if row is None or row["state"] != state or row["variants"] != count:
                warnings.append("STALE manifest row for %s (file says %s, folders hold %s x%d): run make_manifest.py" % (
                    name, row["state"] + " x%d" % row["variants"] if row else "nothing", state, count))

    notes.append("%d sound files, %.1f MB in recorded/, %d slots, %d footstep surfaces" % (len(files), total / 1048576.0, len(slot_names), len(mm.STEPS)))

    for line in errors:
        print("ERROR   " + line)

    for line in warnings:
        print("WARNING " + line)

    for line in notes:
        print("OK      " + line)

    print("%d errors, %d warnings" % (len(errors), len(warnings)))
    sys.exit(1 if errors or (strict and warnings) else 0)


if __name__ == "__main__":
    main()
