#!/usr/bin/env python3
"""Which tests does a diff need? (gate fix, 25 Oct 2026; Steve. Change and wide plans: 22 Nov 2026.)
   python3 tools/tests_for_diff.py <base> <head>         the CHANGE plan, one JSON line (see below), exit 0: what a PR runs before dev
   python3 tools/tests_for_diff.py --paths a b c          the same for a list of changed paths (a hub edit then adds its core list only)
   python3 tools/tests_for_diff.py <base> <head> --wide   the WIDE plan: every test that reaches a changed file through any chain of
                                                          loads (the dev sweep over a batch of merges; also works with --paths)
   python3 tools/tests_for_diff.py <base> <head> --all    every fast test (the unknown-change answer)
   python3 tools/tests_for_diff.py <base> <head> --full   every test, slow lane included (nightly, before main; also works with --paths)
   python3 tools/tests_for_diff.py <base> <head> --all --no-slow   every fast and timing test, no slow lane (main gate Lane A; Lane B runs the slow lane)
   python3 tools/tests_for_diff.py --print-lanes          the lanes with the serial list worked out (JSON)
   python3 tools/tests_for_diff.py --check-lanes          names in tools/test_lanes.json that are not tests (exit 1)
   python3 tools/tests_for_diff.py --explain TEST         the files and directory prefixes the scan found for one test
   python3 tools/tests_for_diff.py --same-change OLD NEW [BASE]   exit 0 when NEW's own change (from where it left BASE, default
                                                          origin/dev) is the same patch as OLD's: a clean merge of dev into a reviewed
                                                          branch; review and test results carry over (TEST_GATES.md)
Output: {"plan":"change|wide|all|full","class":"docs|data|code|bake","fast":[...],"timing":[...],"slow":[...],"pictures":[paths],"checks":[...],"pin":bool,"why":{test or lane: reason}}
Rules (tools/test_lanes.json): docs-only diff = no tests. CHANGE plan: a test is chosen when the test itself, or a helper script in
src/worldgen/tools it uses, loads a changed path directly (preload, load, res:// strings, class_name use, directories and path-prefix
strings); a hub (a file 100+ tests load directly) adds its core list and the tests that name what the diff changed in it. WIDE plan:
the same scan followed through every chain of loads. Both add the always set, the item group, the path rules and the extra inputs; a
path nobody knows, a project.godot edit, or a test file the scan cannot read means ALL fast tests: more, never fewer.
Fast = every test_*.gd in the test folders (TEST_DIRS: src/worldgen/tools and src/water2) that is not timing or slow. Diff is `git diff --name-only M head` where M is
`git merge-base base head`: the head's own changes since it left base, as `git diff base...head` (19 Nov 2026: a two-dot diff against a
dev that had moved on also selected the tests for dev's newer commits, which the head does not even contain). When base is an ancestor of
head (a trial merge, main, the last green commit) M is base and nothing changes; with no merge base the plain two-dot diff is kept."""
import fnmatch, json, os, re, subprocess, sys, zlib

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The gate's test folders. A test is named without folder or .gd, so a name must be unique across them (--check-lanes says if not).
# tools/run_one_test.sh and tools/local_check.sh look in the same folders, in this order. src/water2 joined 9 Nov 2026 (its tests had
# never been selected).
TEST_DIRS = ("src/worldgen/tools", "src/water2")
LANES_PATH = os.path.join(ROOT, "tools", "test_lanes.json")
SCAN_EXT = (".gd", ".tscn", ".tres", ".json")
RES = re.compile(r'"res://([^"\\\s]*)"')
CLASS_DECL = re.compile(r'^class_name\s+(\w+)', re.M)
# Shared test helpers (held_tool.gd, craft_hand.gd): in a change plan what a helper loads counts as loaded by the test that uses it.
HELPER_DIR = "src/worldgen/tools/"
FUNC = re.compile(r'^\s*(?:static\s+)?func\s+(\w+)')
TOP_DECL = re.compile(r'^(?:@\w+(?:\([^)]*\))?\s+)*(?:static\s+)?(?:const|var|signal|enum|class)\s+(\w+)')
ENGINE_CALLS = {"_init", "_ready", "_process", "_physics_process", "_notification", "_enter_tree", "_exit_tree", "_input", "_unhandled_input", "_to_string"}


def load_lanes():
    with open(LANES_PATH, encoding="utf-8") as f:
        return json.load(f)


def glob_re(pattern):
    out, i = "", 0
    while i < len(pattern):
        c = pattern[i]
        if pattern.startswith("**/", i):
            out += "(?:.*/)?"
            i += 3
            continue
        if pattern.startswith("**", i):
            out += ".*"
            i += 2
            continue
        if c == "*":
            out += "[^/]*"
        elif c == "?":
            out += "[^/]"
        else:
            out += re.escape(c)
        i += 1
    return re.compile("^" + out + "$")


def matches(path, patterns):
    return any(glob_re(p).match(path) for p in patterns)


def read(path):
    try:
        with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def tests_by_folder():
    """{folder: [test names]} for every test folder."""
    out = {}
    for d in TEST_DIRS:
        full = os.path.join(ROOT, d)
        out[d] = sorted(fn[:-3] for fn in os.listdir(full) if fn.startswith("test_") and fn.endswith(".gd"))
    return out


def all_tests():
    return sorted({n for names in tests_by_folder().values() for n in names})


def test_path(name):
    """The test's file, relative to the root: the first test folder that has it."""
    for d in TEST_DIRS:
        rel = f"{d}/{name}.gd"
        if os.path.isfile(os.path.join(ROOT, rel)):
            return rel
    return f"{TEST_DIRS[0]}/{name}.gd"


class Scan:
    """Direct dependencies of each file, cached: exact files and directory prefixes."""

    def __init__(self):
        self.classes = {}
        for base in ("src", "scenes", "tools"):
            for dirpath, _, files in os.walk(os.path.join(ROOT, base)):
                for fn in files:
                    if fn.endswith(".gd"):
                        rel = os.path.relpath(os.path.join(dirpath, fn), ROOT).replace(os.sep, "/")
                        text = read(rel) or ""
                        m = CLASS_DECL.search(text)
                        if m:
                            self.classes[m.group(1)] = rel
        self.cache = {}

    def direct(self, rel):
        if rel in self.cache:
            return self.cache[rel]
        files, prefixes = set(), set()
        text = read(rel) if rel.endswith(SCAN_EXT) else None
        if text is not None and not (rel.endswith(".json") and len(text) > 2_000_000):
            for m in RES.finditer(text):
                p = m.group(1)
                if p == "" or p.endswith("/"):
                    prefixes.add(p)
                elif os.path.isdir(os.path.join(ROOT, p)):
                    prefixes.add(p + "/")
                else:
                    files.add(p)
                    # a string like res://data/x/%s.json or "res://data/sound/" + name: the directory is a dependency too
                    if "%" in p or "{" in p:
                        prefixes.add(p.rsplit("/", 1)[0] + "/" if "/" in p else "")
            for m in re.finditer(r'"res://([^"\\\s]*)"\s*\+', text):
                prefixes.add(m.group(1).rsplit("/", 1)[0] + "/" if "/" in m.group(1) else "")
            if rel.endswith(".gd"):
                for name, where in self.classes.items():
                    if where != rel and re.search(r'\b' + re.escape(name) + r'\b', text):
                        files.add(where)
        self.cache[rel] = (files, prefixes)
        return self.cache[rel]

    def near(self, rel, hubs=()):
        """What a test loads directly, with the loads of the src/worldgen/tools helpers it uses (a helper is part of the test).
        Hubs are left out: the change plan handles them by their core list and the names the diff touched."""
        files, prefixes, todo, seen = set(), set(), [rel], set()
        while todo:
            cur = todo.pop()
            if cur in seen:
                continue
            seen.add(cur)
            f, p = self.direct(cur)
            prefixes |= p
            for x in f:
                if x in hubs:
                    continue
                files.add(x)
                if x.startswith(HELPER_DIR) and not os.path.basename(x).startswith("test_") and x.endswith(".gd"):
                    todo.append(x)
        return files, prefixes, seen

    def closure(self, rel):
        seen, prefixes, todo = set(), set(), [rel]
        while todo:
            cur = todo.pop()
            if cur in seen:
                continue
            seen.add(cur)
            f, p = self.direct(cur)
            prefixes |= p
            todo.extend(x for x in f if x not in seen and x.endswith(SCAN_EXT))
            seen |= {x for x in f if not x.endswith(SCAN_EXT)}
        return seen, prefixes


def writes_fixed_files(text):
    """A test that writes a file outside user:// (a literal res:// or relative path) must not run twice at once."""
    for m in re.finditer(r'FileAccess\.open\(\s*"([^"]+)"\s*,\s*FileAccess\.(?:WRITE|READ_WRITE)', text):
        if not m.group(1).startswith("user://"):
            return True
    return False


def lane_sets(lanes, tests):
    slow = [t for t in lanes["slow"] if t in tests]
    timing = [t for t in lanes["timing"] if t in tests and t not in slow]
    fast = [t for t in tests if t not in slow and t not in timing]
    return fast, timing, slow


def serial_list(lanes, tests):
    out = list(lanes["timing"]) + list(lanes.get("serial_extra", []))
    for t in tests:
        text = read(test_path(t)) or ""
        if writes_fixed_files(text) and t not in out:
            out.append(t)
    return [t for t in out if t in tests]


def owners(lines):
    """For each line of a GDScript file, the top-level name it belongs to (function, constant, variable, signal, enum or class).
    An annotation on its own line (@rpc(...) above a func) belongs to the name it annotates: an @rpc edit changes that function."""
    out, cur, pending = [], None, []
    for i, line in enumerate(lines):
        m = FUNC.match(line) if not line[:1].isspace() else None
        d = TOP_DECL.match(line)
        if m:
            cur = m.group(1)
        elif d:
            cur = d.group(1)
        elif line.startswith("@"):
            pending.append(i)
            out.append(None)
            continue
        elif line.strip() and not line[:1].isspace() and not line.startswith("#"):
            cur = None
        for j in pending:
            out[j] = cur if (m or d) else None
        pending = []
        out.append(cur)
    return out


def changed_names(base, head, path, cwd=ROOT):
    """The names in one script whose lines head changed since it left base, and, for a private name, the functions that call it
    (followed up to public names: tests call the public ones). None when git cannot say (a new or deleted file)."""
    mb = diff_base(base, head, cwd)
    diff = subprocess.run(["git", "diff", "-U0", mb, head, "--", path], cwd=cwd, capture_output=True, text=True)
    new = subprocess.run(["git", "show", "%s:%s" % (head, path)], cwd=cwd, capture_output=True, text=True)
    old = subprocess.run(["git", "show", "%s:%s" % (mb, path)], cwd=cwd, capture_output=True, text=True)
    if diff.returncode != 0 or new.returncode != 0 or old.returncode != 0:
        return None
    lines, old_lines = new.stdout.splitlines(), old.stdout.splitlines()
    own, old_own = owners(lines), owners(old_lines)
    names = set()
    for m in re.finditer(r'^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', diff.stdout, re.M):
        o0, oc, n0, nc = int(m.group(1)), int(m.group(2) or 1), int(m.group(3)), int(m.group(4) or 1)
        for i in range(max(n0, 1), n0 + max(nc, 1)):   # nc == 0: a pure deletion, after line n0
            if i <= len(own) and own[i - 1]:
                names.add(own[i - 1])
        for i in range(max(o0, 1), o0 + oc):           # removed lines: what they belonged to (a deleted function too)
            if i <= len(old_own) and old_own[i - 1]:
                names.add(old_own[i - 1])
    bodies = {}
    for line, o in zip(lines, own):
        bodies.setdefault(o, []).append(line)
    todo = [n for n in names if n.startswith("_")]
    while todo:
        n = todo.pop()
        call = re.compile(r'\b' + re.escape(n) + r'\b')
        for f, body in bodies.items():
            if f and f not in names and call.search("\n".join(body[1:] if body and FUNC.match(body[0]) else body)):
                names.add(f)
                if f.startswith("_"):
                    todo.append(f)
    # engine callbacks and very short names (add, get) cannot be matched to tests by their text; the hub's core list covers them
    return {n for n in names if n not in ENGINE_CALLS and len(n) >= 4}


def changed_rows(base, head, path, cwd=ROOT):
    """The row ids (item, recipe, structure ...) whose value head changed, added or removed in one data JSON file since it left base.
    A row is a key of a top-level object of objects, or one level down ({"recipes": {id: {...}}}). None when the file is new, deleted,
    unreadable, or changed outside its rows (a new top-level key or a plain value): the caller then takes the whole item group."""
    mb = diff_base(base, head, cwd)
    out = []
    for rev in (mb, head):
        r = subprocess.run(["git", "show", "%s:%s" % (rev, path)], cwd=cwd, capture_output=True, text=True)
        if r.returncode != 0:
            return None
        try:
            out.append(json.loads(r.stdout))
        except ValueError:
            return None
    old, new = out
    if not isinstance(old, dict) or not isinstance(new, dict) or set(old) != set(new):
        return None if old != new else set()

    def is_rows(d):
        return isinstance(d, dict) and bool(d) and all(isinstance(v, dict) for v in d.values())
    ids = set()
    for k in new:
        x, y = old[k], new[k]
        if x == y or k == "next_number" or (isinstance(x, str) and isinstance(y, str) and "note" in k):
            continue   # the next free number moves with every new row; a note is text
        if not (is_rows(x) and is_rows(y)):
            return None   # a rule value, not rows
        ids.update(i for i in set(x) | set(y) if x.get(i) != y.get(i))
    return {i for i in ids if len(i) >= 3}


# Where head left base (git merge-base), so only head's own changes are diffed; base itself when they share no history (more, never fewer).
def diff_base(base, head, cwd=ROOT):
    out = subprocess.run(["git", "merge-base", base, head], cwd=cwd, capture_output=True, text=True)
    return out.stdout.strip() if out.returncode == 0 and out.stdout.strip() else base


def patch_id(base, head, cwd=ROOT):
    """git patch-id of head's own change since it left base: equal ids = the same change, whatever dev did around it."""
    diff = subprocess.run(["git", "diff", "--binary", "--no-ext-diff", diff_base(base, head, cwd), head], cwd=cwd, capture_output=True)
    if diff.returncode != 0:
        return None
    if not diff.stdout:
        return "empty"
    out = subprocess.run(["git", "patch-id", "--stable"], cwd=cwd, input=diff.stdout, capture_output=True)
    return out.stdout.split()[0].decode() if out.returncode == 0 and out.stdout else None


def changed_paths(base, head, cwd=ROOT):
    out = subprocess.run(["git", "diff", "--name-only", "--no-renames", diff_base(base, head, cwd), head], cwd=cwd, capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit("git diff failed: " + out.stderr.strip())
    return [p for p in out.stdout.splitlines() if p]


def select(paths, lanes, force_all=False, full=False, wide=False, names=None, item_ids=None):
    """names: {hub path: names the diff changed in it} (changed_names); None or a missing path = that hub's core list only."""
    tests = all_tests()
    fast_all, timing_all, slow_all = lane_sets(lanes, tests)
    why = {}
    result = {"plan": "full" if full else "all" if force_all else "wide" if wide else "change", "class": "docs", "fast": [], "timing": [], "slow": [], "pictures": [], "checks": [], "pin": False, "why": why}
    tooling = [p for p in paths if matches(p, lanes.get("tooling_globs", []))]
    watched = [g for rule in lanes["extra_inputs"] for g in rule["paths"]]   # a doc a test reads (CONTROLS.md) is not "docs only"
    live = [p for p in paths if p not in tooling and (matches(p, watched) or not matches(p, lanes["docs_globs"] + lanes.get("offline_globs", [])))]
    if tooling:
        # Gate tooling (lane lists, runner, selector) is checked by the lane check and the selftest, not by game tests.
        result["checks"] += ["lanes", "selftest"]
        why["tooling"] = "gate tooling changed: lane check and selftest: " + tooling[0]

    if not paths:
        why["diff"] = "empty diff: no tests"
        return result
    if not live and not force_all:
        if tooling:
            result["class"] = "tools"
        else:
            why["diff"] = "docs only: no tests"
        return result

    bake_re = re.compile(lanes["bake_regex"])
    if any(bake_re.search(p) for p in live):
        result["class"] = "bake"
    elif all(p.startswith("data/") for p in live):
        result["class"] = "data"
    else:
        result["class"] = "code"

    chosen = set()
    keep = set()   # release tests kept in the plan: baked data or the test itself changed

    def add(names, reason):
        for n in names:
            if n == "@all_fast":
                for f in fast_all:
                    chosen.add(f)
                why.setdefault("all fast tests", reason)
            elif n in tests:
                chosen.add(n)
                why.setdefault(n, reason)

    if force_all:
        add(["@all_fast"], "--all")

    unknown = [p for p in live if not (p.startswith(tuple(lanes["known_prefixes"])) or p in lanes["known_files"])]
    if unknown:
        add(["@all_fast"], "unknown path: " + unknown[0])

    if any(matches(p, lanes["shared_all"]) for p in live):
        add(["@all_fast"], "shared base file changed")

    add(lanes["always"], "always set")

    hubs = [rule for rule in lanes.get("hubs", [])]
    hub_files = {p for rule in hubs for p in rule["paths"]}
    scan = Scan()
    closures, texts = {}, {}
    for t in tests:
        rel = test_path(t)
        text = read(rel)
        if text is None:
            add(["@all_fast"], "cannot read " + rel)
            continue
        if wide:
            closures[t] = scan.closure(rel)
        else:
            files, prefixes, own = scan.near(rel, hub_files)
            closures[t] = (files, prefixes)
            texts[t] = "\n".join(read(x) or "" for x in sorted(own))
    for t, (files, prefixes) in closures.items():
        hit = next((p for p in live if (wide or p not in hub_files) and (p in files or any(p.startswith(x) for x in prefixes if x))), None)
        if hit:
            add([t], ("loads " if wide else "loads directly ") + hit)

    for rule in hubs:
        hit = next((p for p in live if p in rule["paths"]), None)
        if not hit:
            continue
        add(rule["tests"], rule["why"] + ": " + hit)
        if wide:
            continue
        if names is not None and hit in names and names[hit] is None:
            add(["@all_fast"], "hub added, deleted or unreadable in the diff: " + hit)
            continue
        changed = (names or {}).get(hit)
        if not changed:
            why.setdefault("hub " + hit, "core list only (" + ("no diff to read names from" if names is None else "no matchable name changed") + "; the dev sweep runs the wide plan)")
            continue
        cap = lanes.get("name_max_tests", 40)
        for n in sorted(changed):
            word = re.compile(r'\b' + re.escape(n) + r'\b')
            users = [t for t, text in texts.items() if word.search(text)]
            if len(users) > cap:
                # a name nearly every test uses: a fixed spread of cap of them (same pick on every run), the rest in the dev sweep
                users = sorted(users, key=lambda t: zlib.crc32((n + t).encode()))[:cap]
                why.setdefault("hub name " + n, "named by more than %d tests: %d of them, the rest in the dev sweep" % (cap, cap))
            add(users, "names %s, changed in %s" % (n, hit))

    group = lanes["item_group"]
    item_hits = [p for p in live if matches(p, group["paths"]) and not matches(p, group.get("skip_paths", []))]
    if item_hits:
        # Changed item, recipe or structure rows (item_ids): only the tests that name a changed id, like a hub's names. A change that
        # is not a set of rows (a new top-level section, a file git cannot read, too many rows, --paths, --wide) takes the whole group.
        rows = [(item_ids or {}).get(p) for p in item_hits]
        ids = set().union(*[r for r in rows if r]) if rows and all(r is not None for r in rows) else None
        if not wide and ids is not None and 0 < len(ids) <= group.get("max_ids", 25):
            cap = lanes.get("name_max_tests", 40)
            for n in sorted(ids):
                word = re.compile(r'\b' + re.escape(n) + r'\b')
                users = [t for t, text in texts.items() if word.search(text)]
                if len(users) > cap:
                    users = sorted(users, key=lambda t: zlib.crc32((n + t).encode()))[:cap]
                    why.setdefault("item " + n, "named by more than %d tests: %d of them, the rest in the dev sweep" % (cap, cap))
                add(users, "names %s, changed in %s" % (n, item_hits[0]))
            why.setdefault("item group", "%d changed rows: the tests naming them, the rest of the group in the dev sweep" % len(ids))
        else:
            # whole name parts only: "eat" picks test_eat_once, not test_animals_weather or test_death
            pats = group["name_patterns"]
            add([t for t in tests if any(("_" + x) in ("_" + t[5:]) for x in pats)], "item data changed: whole item group")
        for c in group.get("checks", []):
            if c not in result["checks"]:
                result["checks"].append(c)

    for rule in lanes["path_rules"] + lanes["extra_inputs"]:
        hit = next((p for p in live if matches(p, rule["paths"])), None)
        if hit:
            add(rule["tests"], rule["why"] + ": " + hit)
            if rule in lanes["extra_inputs"]:
                keep.update(rule["tests"])
            for c in rule.get("checks", []):
                if c not in result["checks"]:
                    result["checks"].append(c)
            if rule.get("pin"):
                result["pin"] = True

    slow_hit = next((p for p in live if matches(p, lanes["slow_triggers"]) and not matches(p, lanes.get("slow_exclude", []))), None)
    # slow_mode "closure" (default): per commit only the slow tests that load a changed file (chosen above) or baked data (extra_inputs);
    # the whole slow lane runs with --full (nightly, before main). slow_mode "always": every slow trigger starts all of it.
    if full or lanes.get("slow_mode", "closure") == "always":
        if slow_hit or result["class"] == "bake" or full:
            add(slow_all, "slow lane: " + (slow_hit or ("bake class" if result["class"] == "bake" else "--full")))
        if full:
            add(["@all_fast"], "--full")
    if result["class"] == "bake":
        result["pin"] = True

    for p in live:
        m = re.match(r"(?:" + "|".join(re.escape(d) for d in TEST_DIRS) + r")/(test_\w+)\.gd$", p)
        if m and m.group(1) in tests:
            add([m.group(1)], "the test itself changed")
            keep.add(m.group(1))

    # Release tests (big tests on the real baked tiles, minutes each; small fast tests cover their code): picked only when baked data or the test
    # itself changed, or with --full. tools/release_check.sh runs them all by hand before a release.
    if not full:
        for t in lanes.get("release", []):
            if t in chosen and t not in keep:
                chosen.discard(t)
                why.pop(t, None)

    result["pictures"] = [p for p in live if matches(p, lanes["picture_paths"])]
    result["fast"] = [t for t in fast_all if t in chosen]
    result["timing"] = [t for t in timing_all if t in chosen or any(p.startswith("src/") for p in live) and t in lanes["always"]]
    result["slow"] = [t for t in slow_all if t in chosen]
    # timing tests are cheap but flaky: they run whenever their own closure is touched (already in chosen) or a src/ change is big (shared base)
    if "all fast tests" in why:
        result["timing"] = list(timing_all)
    return result


def main(argv):
    lanes = load_lanes()
    if "--print-lanes" in argv:
        tests = all_tests()
        fast, timing, slow = lane_sets(lanes, tests)
        print(json.dumps({"fast": fast, "timing": timing, "slow": slow, "serial": serial_list(lanes, tests), "retry": lanes["retry"], "timeout_s": lanes["timeout_s"]}))
        return 0
    if "--check-lanes" in argv:
        tests = set(all_tests())
        names = set(lanes["timing"] + lanes["retry"] + lanes["slow"] + lanes.get("release", []) + lanes["always"] + lanes.get("serial_extra", []))
        for rule in lanes["path_rules"] + lanes["extra_inputs"] + lanes.get("hubs", []):
            names |= {n for n in rule["tests"] if n != "@all_fast"}
        missing = sorted(n for n in names if n not in tests)
        # every file that hub_min_tests or more tests load directly needs a hub entry (a core list), or a change plan would run no
        # tests for it beyond the always set
        scan, count, listed = Scan(), {}, {p for rule in lanes.get("hubs", []) for p in rule["paths"]}
        for t in sorted(tests):
            for f in scan.near(test_path(t))[0]:
                count[f] = count.get(f, 0) + 1
        unlisted = sorted(f for f, n in count.items() if n >= lanes.get("hub_min_tests", 100) and f not in listed)
        for f in unlisted:
            print("hub without a core list in test_lanes.json hubs (%d tests load it directly): %s" % (count[f], f))
        for n in missing:
            print("not a test (no %s.gd in %s): %s" % (n, " or ".join(TEST_DIRS), n))
        seen, twice = {}, []
        for d, found in tests_by_folder().items():
            for n in found:
                if n in seen:
                    twice.append(n)
                    print("test name in two folders (%s and %s): %s" % (seen[n], d, n))
                seen[n] = d
        print("lanes: %d names checked, %d missing; %d tests in %d folders, %d names twice" % (len(names), len(missing), len(seen), len(TEST_DIRS), len(twice)))
        return 1 if missing or twice or unlisted else 0
    if "--explain" in argv:
        t = argv[argv.index("--explain") + 1]
        files, prefixes = Scan().closure(test_path(t))
        print(json.dumps({"files": sorted(files), "prefixes": sorted(prefixes)}, indent=1))
        return 0
    if "--same-change" in argv:
        i = argv.index("--same-change")
        old, new = argv[i + 1], argv[i + 2]
        base = argv[i + 3] if len(argv) > i + 3 else "origin/dev"
        ids = [patch_id(base, h) for h in (old, new)]
        same = ids[0] is not None and ids[0] == ids[1]
        print(json.dumps({"same": same, "old": ids[0], "new": ids[1], "base": base}))
        return 0 if same else 1
    full = "--full" in argv
    force_all = "--all" in argv or full
    wide = "--wide" in argv
    no_slow = "--no-slow" in argv   # main gate Lane A: the slow lane runs once, on Lane B (TEST_GATES.md "Main gate jobs")
    argv = [a for a in argv if a not in ("--all", "--full", "--wide", "--no-slow")]
    names = item_ids = None
    if argv and argv[0] == "--paths":
        paths = argv[1:]
    elif len(argv) >= 2:
        paths = changed_paths(argv[0], argv[1])
        hub_files = {p for rule in lanes.get("hubs", []) for p in rule["paths"]}
        names = {p: changed_names(argv[0], argv[1], p) for p in paths if p in hub_files}
        group = lanes["item_group"]
        item_ids = {p: changed_rows(argv[0], argv[1], p) for p in paths if p.endswith(".json") and matches(p, group["paths"])}
    else:
        print(__doc__)
        return 2
    plan = select(paths, lanes, force_all, full, wide, names, item_ids)
    if no_slow and plan.get("slow"):
        plan["why"]["slow lane"] = "left out with --no-slow (run on Lane B): " + ", ".join(plan["slow"])
        plan["slow"] = []
    print(json.dumps(plan, separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
