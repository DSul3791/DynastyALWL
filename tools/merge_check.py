#!/usr/bin/env python3
"""Pre-merge guard (BP fix 1 of RETRO_DAY2, Dave 2026-10-23: yes). Run it on the merged tree BEFORE you push.
   python3 tools/merge_check.py            (from the repo root; exit 0 = all clear, exit 1 = problems listed)
Checks: conflict markers, unique item numbers, next_number above the highest, unique ACT_ action ids, unique protocol/build
numbers, JSON files parse (no key twice in an object), build NUMBER not lower than before, no NEW crash reports or telemetry logs tracked, .uid for new scripts.
It does not run Godot (warning count and headless loads stay with tools/local_check.sh on a machine with Godot)."""
import json, os, re, subprocess, sys

# What to compare against: the CI sets MERGE_CHECK_BASE to the commit before the push, so a later push cannot make a finished run fail.
# Locally (no MERGE_CHECK_BASE) it compares against origin/dev, where PRs merge, as the CI does for a PR to dev (origin/<base>); against
# origin/main a file added and deleted since the last release looked untouched, and a deletion passed here but failed in the CI (#1574).
def _default_base() -> str:
    for ref in ["origin/dev", "origin/main"]:
        if subprocess.run(["git", "rev-parse", "--verify", "--quiet", ref], capture_output=True).returncode == 0:
            return ref
    return "origin/main"

BASE = os.environ.get("MERGE_CHECK_BASE") or _default_base()
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
    if f.endswith((".md", ".png", ".ogg", ".wav", ".glb", ".dat", ".sqlite", ".idx", ".json.gz")) or f.startswith("assets/animals/") or not os.path.isfile(f):   # the models: 2.6 GB of LFS binaries
        continue
    try:
        txt = open(f, encoding="utf-8", errors="ignore").read()
    except OSError:
        continue
    if re.search(r"^(<<<<<<< |>>>>>>> )", txt, re.M) or re.search(r"^=======$", txt, re.M) and "<<<<<<<" in txt:
        bad("conflict marker in %s" % f)

# 1b. the animal models (Git LFS) are real files or absent, never LFS pointer stubs: Godot would see a model that cannot load
for f in sh("git", "ls-files", "assets/animals").splitlines():
    if not f.endswith(".import") and os.path.isfile(f) and os.path.getsize(f) < 1024:
        with open(f, "rb") as stub:
            if stub.read(40).startswith(b"version https://git-lfs"):
                bad("%s is a Git LFS pointer, not the model: run git lfs pull, or leave the models out with tools/skip_models.sh" % f)
                break

# 2. JSON parses, with no key twice in one object (the later one silently wins in Godot and Python: a doubled wild_rose seed, PR #1569)
def _no_twice(pairs, where):
    seen = set()

    for key, _ in pairs:
        if key in seen:
            bad("JSON key twice in one object: %s %r" % (where, key))

        seen.add(key)

    return dict(pairs)


for f in sh("git", "ls-files", "data").splitlines():
    if f.endswith(".json") and os.path.isfile(f):
        try:
            json.load(open(f, encoding="utf-8"), object_pairs_hook=lambda pairs, f=f: _no_twice(pairs, f))
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
#    Replaced code requires a declared live replacement. Document expiry additionally requires verified seven-day
#    integration/recovery receipts. Other files keep their existing removal safeguards.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import deletion_rules
import doc_retirement
if sh("git", "rev-parse", "--verify", "-q", BASE).strip():
    _deleted = sh("git", "diff", "--no-renames", "--name-only", "--diff-filter=D", BASE).splitlines()
    _added = sh("git", "diff", "--no-renames", "--name-only", "--diff-filter=A", BASE).splitlines()
    _modified = sh("git", "diff", "--name-only", "--diff-filter=M", BASE).splitlines()
    _prior_retirements = sh("git", "show", BASE + ":" + doc_retirement.MANIFEST)
    try:
        _retirement_data = doc_retirement.load('.')
        _retirement_events = doc_retirement.integration_events(_retirement_data)
        _retirement_errors, _expired_docs = doc_retirement.validate(
            '.', _retirement_data, _deleted, integrations=_retirement_events,
            previous=json.loads(_prior_retirements) if _prior_retirements.strip() else None)
        _retirement_touched = set(_deleted) & {e[k] for b in _retirement_data['batches'] for e in b['entries'] for k in ('original','retired')}
        if _retirement_touched and not _retirement_errors:
            _retirement_errors, _expired_docs = doc_retirement.validate(
                '.', _retirement_data, _deleted, integrations=_retirement_events,
                previous=json.loads(_prior_retirements) if _prior_retirements.strip() else None,
                protected=doc_retirement.active_work('.'))
    except (ValueError, OSError) as exc:
        _retirement_errors, _expired_docs = [str(exc)], set()
    for msg in _retirement_errors:
        bad(msg)
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
                                                _head_read, _game, _removals, _modified, _expired_docs):
        bad(msg)
    # looks: a look entry that was in BASE must still be in data/items/looks.json
    renames = json.load(open("data/items/id_renames.json", encoding="utf-8")).get("renames", {}) if os.path.isfile("data/items/id_renames.json") else {}   # outside the try: a broken file fails loudly
    try:
        old = json.loads(sh("git", "show", BASE + ":data/items/looks.json"))["items"]
        new = json.load(open("data/items/looks.json", encoding="utf-8"))["items"]
        for k in sorted(set(old) - set(new)):
            if renames.get(k, "") in new:   # an approved id rename (data/items/id_renames.json, Dave 16 Nov 2026): the look moved to the new id
                continue
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

ps1 = subprocess.run([sys.executable, "tools/check_ps1.py"], capture_output=True, text=True)
if ps1.returncode != 0:   # Dave's PC runs Windows PowerShell 5.1 and nothing here can run it: a script that does not parse fails there first
    for line in ps1.stdout.splitlines():
        bad("PowerShell: " + line)
    if not ps1.stdout.strip():
        bad("PowerShell check crashed: " + ps1.stderr[-200:])

looks = subprocess.run([sys.executable, "tools/check_look_names.py"], capture_output=True, text=True)
if looks.returncode != 0:
    for line in looks.stdout.splitlines()[1:]:
        bad("look name: " + line)

clips = subprocess.run([sys.executable, "tools/model_clips.py"], capture_output=True, text=True)      # every clip models.json names is in its model file
if clips.returncode != 0:
    for line in clips.stdout.splitlines():
        if line.startswith("FAIL "):
            bad("animal clip: " + line[5:])
    if "FAIL " not in clips.stdout:
        bad("animal clip check crashed: " + clips.stderr[-200:])

text = subprocess.run([sys.executable, "tools/text_vs_recipe.py"], capture_output=True, text=True)
if text.returncode != 0:   # player-facing numbers (encyclopedia, hints, goals) must match the recipes and blueprints
    for line in text.stdout.splitlines()[:-1]:
        bad("text vs recipe: " + line)

shown = subprocess.run([sys.executable, "tools/check_player_text.py"], capture_output=True, text=True)
if shown.returncode != 0:   # text the game shows (descriptions, hints, goals) names only real things, with the amounts they really ask for (coordinator 23 Nov 2026)
    rows = [line for line in shown.stdout.splitlines() if ": " in line and not line.startswith("player text:")]
    for line in rows:
        bad("player text: " + line)
    if not rows:   # the check itself failed: never pass silently
        bad("player text check failed: " + " | ".join(shown.stderr.strip().splitlines()[-3:]))

goal_gaps = subprocess.run([sys.executable, "tools/goal_station_audit.py"], capture_output=True, text=True)
if goal_gaps.returncode != 0:   # every goal comes after the goals that build the stations it needs (Dave 17 Nov 2026, the Hoe report)
    for line in goal_gaps.stdout.splitlines()[:-1]:
        bad("goal order: " + line)

goal_stage = subprocess.run([sys.executable, "tools/goal_stage_audit.py"], capture_output=True, text=True)
if goal_stage.returncode != 0:   # every goal is reachable with its own stage's metals (Dave 21 Nov 2026: materials "available ... at every stage of the goals")
    late = [line for line in goal_stage.stdout.splitlines() if line.startswith("LATE")]
    for line in late:
        bad("goal stage: " + line)
    if not late:   # the audit itself failed (a data change it cannot read): never pass silently
        bad("goal stage audit failed: " + " | ".join(goal_stage.stderr.strip().splitlines()[-3:]))

reach = subprocess.run([sys.executable, "tools/encyclopedia_reach.py", "--check"], capture_output=True, text=True)
if reach.returncode != 0:   # encyclopedia obtainable_now must follow the data (stale rows found on dev 22 Nov 2026)
    if "out of date" in reach.stdout:
        bad("encyclopedia_reach: encyclopedia.json is out of date (python3 tools/encyclopedia_reach.py --write)")
    else:   # the script itself failed (a data change it cannot read): show why
        bad("encyclopedia_reach failed: " + " | ".join(reach.stderr.strip().splitlines()[-3:]))

no_use = subprocess.run([sys.executable, "tools/progression_check.py", "--unmarked"], capture_output=True, text=True)
if no_use.returncode != 0:   # an item with no use yet must say so in the player's text (coordinator 23 Nov 2026: testers file it as a bug)
    rows = no_use.stdout.split("## 11")[1].splitlines()[1:] if "## 11" in no_use.stdout else []
    bad("no use yet and not marked: " + (", ".join(l[2:] for l in rows if l.startswith("- ")) or " | ".join(no_use.stderr.strip().splitlines()[-3:])) +
        " (give it a use, or end its description with \"Nothing uses it yet.\")")

placeable = subprocess.run([sys.executable, "tools/placeables_check.py"], capture_output=True, text=True)
if placeable.returncode != 0:   # every placeable item must be placeable (Dave 5 Nov 2026)
    for line in placeable.stdout.splitlines()[1:]:
        bad("placeable: " + line.strip())

# Recipes heavier than a pack (tools/carry_audit.py) are no warning: a craft takes from stock within 12 m (craft_stock.gd, Dave 10 Nov 2026).

export = subprocess.run([sys.executable, "tools/export_check.py"], capture_output=True, text=True)
if export.returncode != 0:   # a release build would lack a file it loads or carry what it must not (server/client split C2); fix server-only creep with --write
    bad("export_check: " + " | ".join([l.strip() for l in export.stdout.splitlines() if l.startswith("  - ")] + export.stderr.strip().splitlines()[-3:]))

master = subprocess.run([sys.executable, "tools/item_master.py", "--check"], capture_output=True, text=True)
if master.returncode != 0:   # a warning only: the master list lives outside the repo (tech/ITEM_MASTER.md)
    print("WARNING:", master.stdout.strip())

if problems:
    print("MERGE CHECK FAILED:")
    for p in problems:
        print(" -", p)
    sys.exit(1)
print("merge check: all clear (incl. duplicate GDScript names; no Godot checks here: run tools/local_check.sh on a machine with Godot)")
