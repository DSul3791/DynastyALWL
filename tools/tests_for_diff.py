#!/usr/bin/env python3
"""Which tests does a diff need? (gate fix, 25 Oct 2026; Steve.)
   python3 tools/tests_for_diff.py <base> <head>         one JSON line (see below), exit 0
   python3 tools/tests_for_diff.py --paths a b c          the same for a list of changed paths
   python3 tools/tests_for_diff.py <base> <head> --all    every fast test (the nightly / unknown-change answer)
   python3 tools/tests_for_diff.py --print-lanes          the lanes with the serial list worked out (JSON)
   python3 tools/tests_for_diff.py --check-lanes          names in tools/test_lanes.json that are not tests (exit 1)
   python3 tools/tests_for_diff.py --explain TEST         the files and directory prefixes the scan found for one test
Output: {"class":"docs|data|code|bake","fast":[...],"timing":[...],"slow":[...],"pictures":[paths],"checks":[...],"pin":bool,"why":{test or lane: reason}}
Rules (tools/test_lanes.json): docs-only diff = no tests; a test is chosen when the files it loads (followed through preload, load,
res:// strings, class_name use, directories and path-prefix strings) include a changed path; the always set, the item group, the path
rules and the extra inputs add to that; a path nobody knows, or a test file the scan cannot read, means ALL fast tests: more, never fewer.
Fast = every src/worldgen/tools/test_*.gd that is not timing or slow. Diff is `git diff --name-only base head` (two dots: the exact
tree difference, the gate passes the trial-merge base)."""
import fnmatch, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_DIR = "src/worldgen/tools"
LANES_PATH = os.path.join(ROOT, "tools", "test_lanes.json")
SCAN_EXT = (".gd", ".tscn", ".tres", ".json")
RES = re.compile(r'"res://([^"\\\s]*)"')
CLASS_DECL = re.compile(r'^class_name\s+(\w+)', re.M)


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


def all_tests():
    names = []
    full = os.path.join(ROOT, TEST_DIR)
    for fn in sorted(os.listdir(full)):
        if fn.startswith("test_") and fn.endswith(".gd"):
            names.append(fn[:-3])
    return names


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
        text = read(f"{TEST_DIR}/{t}.gd") or ""
        if writes_fixed_files(text) and t not in out:
            out.append(t)
    return [t for t in out if t in tests]


def changed_paths(base, head):
    out = subprocess.run(["git", "diff", "--name-only", base, head], cwd=ROOT, capture_output=True, text=True)
    if out.returncode != 0:
        raise SystemExit("git diff failed: " + out.stderr.strip())
    return [p for p in out.stdout.splitlines() if p]


def select(paths, lanes, force_all=False):
    tests = all_tests()
    fast_all, timing_all, slow_all = lane_sets(lanes, tests)
    why = {}
    result = {"class": "docs", "fast": [], "timing": [], "slow": [], "pictures": [], "checks": [], "pin": False, "why": why}
    live = [p for p in paths if not matches(p, lanes["docs_globs"] + lanes.get("offline_globs", []))]

    if not paths:
        why["diff"] = "empty diff: no tests"
        return result
    if not live and not force_all:
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

    scan = Scan()
    closures = {}
    for t in tests:
        rel = f"{TEST_DIR}/{t}.gd"
        text = read(rel)
        if text is None:
            add(["@all_fast"], "cannot read " + rel)
            continue
        closures[t] = scan.closure(rel)
    live_set = set(live)
    for t, (files, prefixes) in closures.items():
        hit = next((p for p in live if p in files or any(p.startswith(x) for x in prefixes if x)), None)
        if hit:
            add([t], "loads " + hit)

    if any(matches(p, lanes["item_group"]["paths"]) for p in live):
        pats = lanes["item_group"]["name_patterns"]
        add([t for t in tests if any(x in t for x in pats)], "item data changed: whole item group")
        for c in lanes["item_group"].get("checks", []):
            if c not in result["checks"]:
                result["checks"].append(c)

    for rule in lanes["path_rules"] + lanes["extra_inputs"]:
        hit = next((p for p in live if matches(p, rule["paths"])), None)
        if hit:
            add(rule["tests"], rule["why"] + ": " + hit)
            for c in rule.get("checks", []):
                if c not in result["checks"]:
                    result["checks"].append(c)
            if rule.get("pin"):
                result["pin"] = True

    slow_hit = next((p for p in live if matches(p, lanes["slow_triggers"]) and not matches(p, lanes.get("slow_exclude", []))), None)
    if slow_hit or result["class"] == "bake":
        add(slow_all, "slow lane: " + (slow_hit or "bake class"))
    if result["class"] == "bake":
        result["pin"] = True

    for p in live:
        m = re.match(re.escape(TEST_DIR) + r"/(test_\w+)\.gd$", p)
        if m and m.group(1) in tests:
            add([m.group(1)], "the test itself changed")

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
        names = set(lanes["timing"] + lanes["retry"] + lanes["slow"] + lanes["always"] + lanes.get("serial_extra", []))
        for rule in lanes["path_rules"] + lanes["extra_inputs"]:
            names |= {n for n in rule["tests"] if n != "@all_fast"}
        missing = sorted(n for n in names if n not in tests)
        for n in missing:
            print("not a test (no src/worldgen/tools/%s.gd): %s" % (n, n))
        print("lanes: %d names checked, %d missing" % (len(names), len(missing)))
        return 1 if missing else 0
    if "--explain" in argv:
        t = argv[argv.index("--explain") + 1]
        files, prefixes = Scan().closure(f"{TEST_DIR}/{t}.gd")
        print(json.dumps({"files": sorted(files), "prefixes": sorted(prefixes)}, indent=1))
        return 0
    force_all = "--all" in argv
    argv = [a for a in argv if a != "--all"]
    if argv and argv[0] == "--paths":
        paths = argv[1:]
    elif len(argv) >= 2:
        paths = changed_paths(argv[0], argv[1])
    else:
        print(__doc__)
        return 2
    print(json.dumps(select(paths, lanes, force_all), separators=(",", ":")))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
