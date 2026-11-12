#!/usr/bin/env python3
"""Pre-merge guard (BP fix 1 of RETRO_DAY2, Dave 2026-10-23: yes). Run it on the merged tree BEFORE you push.
   python3 tools/merge_check.py            (from the repo root; exit 0 = all clear, exit 1 = problems listed)
Checks: conflict markers, unique item numbers, next_number above the highest, unique ACT_ action ids, unique protocol/build
numbers, JSON files parse, build NUMBER not lower than before, no NEW crash reports or telemetry logs tracked, .uid for new scripts.
It does not run Godot (warning count and headless loads stay with tools/local_check.sh on a machine with Godot)."""
import json, os, re, subprocess, sys

# What to compare against: the CI sets MERGE_CHECK_BASE to the commit before the push, so a later push cannot make a finished run fail.
BASE = os.environ.get("MERGE_CHECK_BASE") or "origin/main"
# Compare from the merge base, not the tip of main (three-dot). A branch made before a later merge to main would otherwise
# look as if it deleted every file main has gained since (false "deleted without approval", seen on #528 and #553).
# When BASE is already an ancestor of HEAD the merge base is BASE itself, so a push to main checks exactly as before.
_mb = subprocess.run(["git", "merge-base", BASE, "HEAD"], capture_output=True, text=True).stdout.strip()
if _mb:
    BASE = _mb

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


# 7. Deletions (Decision 61 as clarified by Dave, 12 Nov 2026; rules and their source in tools/deletion_rules.py):
#    replaced code is deleted when its replacement is declared in REMOVALS.md and nothing uses it; documents are archived,
#    never deleted; everything else goes to proposed_removals/ with a REMOVALS.md row. Tests: tools/test_deletion_rules.py.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import deletion_rules
if sh("git", "rev-parse", "--verify", "-q", BASE).strip():
    _deleted = sh("git", "diff", "--name-only", "--diff-filter=D", BASE).splitlines()
    _added = sh("git", "diff", "--name-only", "--diff-filter=AR", BASE).splitlines()
    _modified = sh("git", "diff", "--name-only", "--diff-filter=M", BASE).splitlines()
    _game = {}
    for f in (sh("git", "ls-files").splitlines() if _deleted else []):   # read game files only when something was deleted
        if f.endswith(deletion_rules.USE_EXT) and os.path.isfile(f):
            try:
                _game[f] = open(f, encoding="utf-8", errors="ignore").read()
            except OSError:
                pass
    _removals = open("proposed_removals/REMOVALS.md", encoding="utf-8").read() if os.path.isfile("proposed_removals/REMOVALS.md") else ""
    def _head_read(p):
        try:
            return open(p, encoding="utf-8", errors="ignore").read()
        except OSError:
            return ""
    for msg in deletion_rules.deletion_problems(_deleted, _added, os.path.isfile, lambda p: sh("git", "show", BASE + ":" + p),
                                                _head_read, _game, _removals, _modified):
        bad(msg)
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

shaders = subprocess.run([sys.executable, "tools/check_shader_comments.py"], capture_output=True, text=True)
if shaders.returncode != 0:   # headless gates never compile shaders, so a '#' comment only fails in a windowed client (#416)
    for line in shaders.stdout.splitlines():
        bad("shader: " + line)

looks = subprocess.run([sys.executable, "tools/check_look_names.py"], capture_output=True, text=True)
if looks.returncode != 0:
    for line in looks.stdout.splitlines()[1:]:
        bad("look name: " + line)

text = subprocess.run([sys.executable, "tools/text_vs_recipe.py"], capture_output=True, text=True)
if text.returncode != 0:   # player-facing numbers (encyclopedia, hints, goals) must match the recipes and blueprints
    for line in text.stdout.splitlines()[:-1]:
        bad("text vs recipe: " + line)

placeable = subprocess.run([sys.executable, "tools/placeables_check.py"], capture_output=True, text=True)
if placeable.returncode != 0:   # every placeable item must be placeable (Dave 5 Nov 2026)
    for line in placeable.stdout.splitlines()[1:]:
        bad("placeable: " + line.strip())

carry = subprocess.run([sys.executable, "tools/carry_audit.py"], capture_output=True, text=True)
if carry.returncode != 0:   # a warning only until Dave picks the heavy-kits fix (docs/HEAVY_KITS_OPTIONS.md)
    print("WARNING: carry_audit: %d recipe(s) over the carry cap (python3 tools/carry_audit.py)" % sum(1 for l in carry.stdout.split("OVER CAP")[1].split("SLOWING")[0].splitlines() if " kg  recipe " in l))

master = subprocess.run([sys.executable, "tools/item_master.py", "--check"], capture_output=True, text=True)
if master.returncode != 0:   # a warning only: the master list lives outside the repo (tech/ITEM_MASTER.md)
    print("WARNING:", master.stdout.strip())

if problems:
    print("MERGE CHECK FAILED:")
    for p in problems:
        print(" -", p)
    sys.exit(1)
print("merge check: all clear (incl. duplicate GDScript names; no Godot checks here: run tools/local_check.sh on a machine with Godot)")
