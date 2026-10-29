#!/usr/bin/env python3
"""Pre-merge guard (BP fix 1 of RETRO_DAY2, Dave 2026-10-23: yes). Run it on the merged tree BEFORE you push.
   python3 tools/merge_check.py            (from the repo root; exit 0 = all clear, exit 1 = problems listed)
Checks: conflict markers, unique item numbers, next_number above the highest, unique ACT_ action ids, unique protocol/build
numbers, JSON files parse, build NUMBER not lower than before, no NEW crash reports or telemetry logs tracked, .uid for new scripts.
It does not run Godot (warning count and headless loads stay with tools/local_check.sh on a machine with Godot)."""
import json, os, re, subprocess, sys

# What to compare against: the CI sets MERGE_CHECK_BASE to the commit before the push, so a later push cannot make a finished run fail.
BASE = os.environ.get("MERGE_CHECK_BASE") or "origin/main"

problems = []


def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout


def bad(msg):
    problems.append(msg)


# 1. conflict markers in code and data (not in .md, which may quote them)
for f in sh("git", "ls-files").splitlines():
    if f.endswith((".md", ".png", ".ogg", ".wav", ".glb", ".dat", ".sqlite", ".idx", ".json.gz")) or not os.path.isfile(f):
        continue
    try:
        txt = open(f, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    if re.search(r"^(<<<<<<< |>>>>>>> )", txt, re.M) or re.search(r"^=======$", txt, re.M) and "<<<<<<<" in txt:
        bad("conflict marker in %s" % f)

# 2. JSON parses
for f in sh("git", "ls-files", "data").splitlines():
    if f.endswith(".json") and os.path.isfile(f):
        try:
            json.load(open(f, encoding="utf-8"))
        except Exception as e:
            bad("JSON does not parse: %s (%s)" % (f, str(e)[:80]))

# 3. item numbers unique, next_number above the highest
try:
    items = json.load(open("data/items/items.json", encoding="utf-8"))
    nums = []

    def walk(x):
        if isinstance(x, dict):
            if isinstance(x.get("number"), int):
                nums.append((x["number"], x.get("name", "?")))
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    walk(items)
    seen = {}
    for n, name in nums:
        if n in seen:
            bad("item number %d used twice (%s and %s)" % (n, seen[n], name))
        seen[n] = name
    nxt = items.get("next_number")
    if nxt is not None and nums and nxt <= max(n for n, _ in nums):
        bad("items.json next_number is %s but the highest number is %d (set it to %d)" % (nxt, max(n for n, _ in nums), max(n for n, _ in nums) + 1))
except FileNotFoundError:
    pass

# 4. action ids unique
net = "src/stream/terrain_net.gd"
if os.path.isfile(net):
    txt = open(net, encoding="utf-8").read()
    ids = {}
    for name, val in re.findall(r"^const (ACT_[A-Z0-9_]+)\s*:=\s*(\d+)", txt, re.M):
        if val in ids:
            bad("action id %s used by both %s and %s" % (val, ids[val], name))
        ids[val] = name
    m = re.search(r"^const PROTOCOL_VERSION\s*:=\s*(\d+)", txt, re.M)
    if m:
        print("protocol", m.group(1))

# 5. build number not going backwards
b = "src/shared/build.gd"
if os.path.isfile(b):
    cur = int(re.search(r"NUMBER\s*:=\s*(\d+)", open(b).read()).group(1))
    old = sh("git", "show", BASE + ":" + b)
    m = re.search(r"NUMBER\s*:=\s*(\d+)", old)
    if m and cur < int(m.group(1)):
        bad("build NUMBER %d is lower than origin's %s" % (cur, m.group(1)))
    print("build", cur)

# 6. crash reports and telemetry logs must not be NEW in the index
tracked_now = set(sh("git", "ls-files", "crash_reports").split())
tracked_orig = set(l.split("\t")[-1] for l in sh("git", "ls-tree", "-r", BASE, "crash_reports").splitlines())
for f in sorted(tracked_now - tracked_orig):
    bad("new crash report or telemetry log tracked: %s (git rm --cached it)" % f)
for f in sh("git", "ls-files", "-o", "--exclude-standard").splitlines():
    if f.endswith((".gd", ".tscn", ".shader", ".gdshader")) and not os.path.exists(f + ".uid") and f.endswith(".gd"):
        bad("new script without .uid: %s (commit its .uid)" % f)


# 7. Dave's rule (25 Oct 2026): nothing is deleted. A model, image, sound, art, design, scene, resource or code file that was in BASE and
#    is gone from the tree must be present under proposed_removals/ (scripts, scenes, resources with ".removed" added) with a line in REMOVALS.md.
KEEP_EXT = (".glb", ".gltf", ".obj", ".fbx", ".png", ".jpg", ".jpeg", ".webp", ".svg", ".tga", ".exr", ".hdr", ".dds", ".ogg", ".wav", ".mp3",
            ".tscn", ".tres", ".gd", ".gdshader", ".shader", ".md")
KEEP_DIRS = ("art/", "assets/", "design/", "docs/", "items/", "src/", "scenes/", "worlds/", "data/")
SKIP_PREFIX = ("proposed_removals/", "docs/mirror/", "docs/archive/", "questions/", "evidence/", "results/")
if sh("git", "rev-parse", "--verify", "-q", BASE).strip():
    for f in sh("git", "diff", "--name-only", "--diff-filter=D", BASE).splitlines():
        if f.startswith(SKIP_PREFIX) or not (f.endswith(KEEP_EXT) and f.startswith(KEEP_DIRS)):
            continue
        suffix = ".removed" if f.endswith((".gd", ".tscn", ".tres", ".uid")) else ""
        if not (os.path.isfile("proposed_removals/" + f + suffix) or os.path.isfile("proposed_removals/" + f)):
            bad("deleted without approval (Dave's rule): %s (move it to proposed_removals/%s%s and add a line to proposed_removals/REMOVALS.md)" % (f, f, suffix))
    # looks: a look entry that was in BASE must still be in data/items/looks.json
    try:
        old = json.loads(sh("git", "show", BASE + ":data/items/looks.json"))["items"]
        new = json.load(open("data/items/looks.json", encoding="utf-8"))["items"]
        for k in sorted(set(old) - set(new)):
            bad("look removed from data/items/looks.json: %s (retire it, do not delete it)" % k)
    except Exception:
        pass

dupes = subprocess.run([sys.executable, "tools/check_dupe_names.py"], capture_output=True, text=True)
if dupes.returncode != 0:
    for line in dupes.stdout.splitlines():
        if not line.startswith("dupe names:"):
            bad("duplicate GDScript name: " + line)

looks = subprocess.run([sys.executable, "tools/check_look_names.py"], capture_output=True, text=True)
if looks.returncode != 0:
    for line in looks.stdout.splitlines()[1:]:
        bad("look name: " + line)

master = subprocess.run([sys.executable, "tools/item_master.py", "--check"], capture_output=True, text=True)
if master.returncode != 0:   # a warning only: the master list lives outside the repo (tech/ITEM_MASTER.md)
    print("WARNING:", master.stdout.strip())

if problems:
    print("MERGE CHECK FAILED:")
    for p in problems:
        print(" -", p)
    sys.exit(1)
print("merge check: all clear (incl. duplicate GDScript names; no Godot checks here: run tools/local_check.sh on a machine with Godot)")
