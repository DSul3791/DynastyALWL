"""The clips in each animal model file, read without Godot, and a check that every clip models.json names is in its file.

  python3 tools/model_clips.py                 check: each clip named in data/animals/models.json (a row's "clips") is in its file's list
  python3 tools/model_clips.py --scan          read every assets/animals .fbx (the file itself, or the Git LFS object behind its pointer:
                                               `git -c lfs.fetchexclude= lfs fetch -I "assets/animals/**/*.fbx" origin HEAD` first in a clone
                                               that skips the models) and write data/animals/model_clips.json: {res path: [[clip, seconds], ...]}

The list lets a thread with no models (a plain clone skips them: tools/skip_models.sh) map a state to a clip by name (Dave 23 Nov 2026:
animals "like really bad animatronics"; every server state gets a real clip). A binary FBX holds each clip as an AnimationStack object
whose name is "Armature|Clip" and whose LocalStop is its length in FBX time (46186158000 a second). Names are what the game's own
_clip_full matches: the part after the last "|". A clip missing from the list fails the check; Godot reports a missing one only as a
log line when the model is drawn.
"""
import json
import os
import struct
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MODELS = os.path.join(ROOT, "data/animals/models.json")
LIST = os.path.join(ROOT, "data/animals/model_clips.json")
KTIME = 46186158000.0


def _node(f, ver):
    if ver >= 7500:
        end, nprops, _ = struct.unpack("<QQQ", f.read(24))
    else:
        end, nprops, _ = struct.unpack("<III", f.read(12))

    name = f.read(f.read(1)[0]).decode("latin1")

    if end == 0:
        return None

    props = []

    for _ in range(nprops):
        t = f.read(1)

        if t in (b"S", b"R"):
            raw = f.read(struct.unpack("<I", f.read(4))[0])
            props.append(raw.decode("utf8", "replace") if t == b"S" else raw)
        elif t == b"L":
            props.append(struct.unpack("<q", f.read(8))[0])
        elif t == b"I":
            props.append(struct.unpack("<i", f.read(4))[0])
        elif t == b"D":
            props.append(struct.unpack("<d", f.read(8))[0])
        elif t == b"F":
            props.append(struct.unpack("<f", f.read(4))[0])
        elif t == b"Y":
            props.append(struct.unpack("<h", f.read(2))[0])
        elif t == b"C":
            props.append(f.read(1)[0])
        elif t in (b"f", b"d", b"l", b"i", b"b", b"c"):
            _, _, size = struct.unpack("<III", f.read(12))
            f.seek(size, 1)
            props.append(None)
        else:
            raise ValueError("unknown FBX property type %r" % t)

    kids = []

    while f.tell() < end:
        kid = _node(f, ver)

        if kid is None:
            break

        kids.append(kid)

    f.seek(end)
    return name, props, kids


def clips_of(path):
    """[[clip, seconds], ...] of one binary FBX file, in file order."""
    with open(path, "rb") as f:
        if not f.read(23).startswith(b"Kaydara FBX Binary"):
            raise ValueError("not a binary FBX (an LFS pointer? run git lfs pull)")

        ver = struct.unpack("<I", f.read(4))[0]

        while True:
            node = _node(f, ver)

            if node is None:
                return []

            if node[0] != "Objects":
                continue

            out = []

            for obj in node[2]:
                if obj[0] != "AnimationStack":
                    continue

                stop = 0.0

                for kid in obj[2]:
                    if kid[0] == "Properties70":
                        for p in kid[2]:
                            if p[1] and p[1][0] == "LocalStop":
                                stop = p[1][4] / KTIME

                out.append([obj[1][1].split("\x00")[0].split("|")[-1], round(stop, 2)])

            return out


def _real_file(rel):
    """The FBX bytes' path: the file in the tree, or the LFS object its pointer names."""
    path = os.path.join(ROOT, rel)

    if os.path.isfile(path) and os.path.getsize(path) > 1024:
        return path

    pointer = subprocess.run(["git", "-C", ROOT, "show", "HEAD:" + rel], capture_output=True, text=True).stdout

    for line in pointer.splitlines():
        if line.startswith("oid sha256:"):
            oid = line.split(":", 1)[1].strip()
            return os.path.join(ROOT, ".git", "lfs", "objects", oid[0:2], oid[2:4], oid)

    return path


def scan():
    tracked = subprocess.run(["git", "-C", ROOT, "ls-files", "assets/animals"], capture_output=True, text=True).stdout.splitlines()
    found = {}
    skipped = 0

    for rel in sorted(t for t in tracked if t.lower().endswith(".fbx")):
        try:
            found["res://" + rel] = clips_of(_real_file(rel))
        except (OSError, ValueError, struct.error, IndexError) as e:
            print("skipped %s: %s" % (rel, e))
            skipped += 1

    if skipped:
        print("model clips: %d files could not be read: the list is not written (fetch the LFS objects first)" % skipped)
        sys.exit(1)

    with open(LIST, "w", encoding="utf8") as f:
        f.write("{\n" + ",\n".join("\t%s: %s" % (json.dumps(k), json.dumps(found[k], ensure_ascii=False)) for k in sorted(found)) + "\n}\n")

    print("model clips: %d files written to %s" % (len(found), os.path.relpath(LIST, ROOT)))


def _rows(species):
    for kind, row in species.items():
        yield kind, row

        if isinstance(row.get("young_model"), dict):
            yield kind + " young", dict(row, **row["young_model"])

        for i, look in enumerate(row.get("variants", []) if isinstance(row.get("variants"), list) else []):
            if isinstance(look, dict):
                yield "%s variant %d" % (kind, i), dict(row, **look)


def check():
    listed = json.load(open(LIST, encoding="utf8"))
    species = json.load(open(MODELS, encoding="utf8"))["species"]
    bad = []
    checked = 0
    unlisted = set()

    for kind, row in _rows(species):
        scene = str(row.get("scene", ""))

        if scene not in listed:
            unlisted.add(scene)
            continue

        names = {c[0] for c in listed[scene]} | {c[0].replace(".", "_") for c in listed[scene]}      # a row may name Idle_Breathing.001 as Idle_Breathing_001 (the lioness row)

        for role, wanted in (row.get("clips") or {}).items():
            for clip in wanted if isinstance(wanted, list) else [wanted]:
                checked += 1

                if not str(clip).startswith("gait_") and str(clip) not in names:
                    bad.append("%s role %s: no clip %r in %s" % (kind, role, clip, scene))

    for line in bad:
        print("FAIL " + line)

    print("model clips: %d named clips checked, %d missing; %d model files not in the list (a .glb, or a new file: run --scan): %s" % (checked, len(bad), len(unlisted), ", ".join(sorted(unlisted))))
    return 1 if bad else 0


if __name__ == "__main__":
    if len(sys.argv) >= 2 and sys.argv[1] == "--scan":
        scan()
    else:
        sys.exit(check())
