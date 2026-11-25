#!/usr/bin/env python3
"""Watched checks: warn first, block on the 3rd flag (Dave 25 Nov 2026, docs/RULINGS.md R-TEAM-WARN-TO-BLOCK).

Runs on every PR and every push to dev or main (.github/workflows/merge_check.yml). The checks are tools/hooks/agent_warn.py's
findings() (a bare print() in client code, a key or password, a machine's private file); a new watched check is one more name there.
A check is flagged once for each change that adds at least one problem it finds. The count is read from the branch's own history, so
nothing is stored and nobody can reset it: every first-parent commit since START that the check flags, plus this change if it flags.
Flags 1 and 2 only warn, and the second warning lists the lines to fix before a third. The change that would be the 3rd flag is
blocked, and so is every change while the check has 3 flags in history and a line they added is still there.
    python3 tools/warn_watch.py [BASE]          BASE defaults to $MERGE_CHECK_BASE, else origin/dev
"""
import importlib.util, os, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
START = "2026-11-25T19:30:00Z"   # watching began (Dave's ruling); earlier commits are not counted
BLOCK_AT = 3                     # Dave: "flagged 3 times": the flag that makes a check block

spec = importlib.util.spec_from_file_location("agent_warn", ROOT / "tools/hooks/agent_warn.py")
aw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aw)


def annotate(kind, path, line, msg):
    print(f"::{kind} file={path},line={max(line, 1)}::{msg}" if os.environ.get("GITHUB_ACTIONS") else f"{kind.upper()} {path}:{line}: {msg}")


def still_there(check, path, text):
    """Where a line an earlier flag added still is (line number), or 0 once it is fixed."""
    p = ROOT / path
    if not p.is_file():
        return 0
    if check == "private-file":
        return 1
    lines = p.read_text(encoding="utf-8", errors="replace").splitlines()
    return lines.index(text) + 1 if text in lines else 0


def watch(base, head="HEAD"):
    """Returns the number of blocking problems; prints warnings and errors."""
    aw.ROOT, aw.STRICT = ROOT, True
    history = {}   # check -> [(commit, path, line text)]
    for row in aw.git("rev-list", "--first-parent", "--parents", f"--since={START}", base).splitlines():
        sha, *parents = row.split()
        if parents:
            for check, path, _, text, _ in aw.findings(f"{parents[0]}..{sha}"):
                history.setdefault(check, []).append((sha, path, text))
    now = aw.findings(f"{aw.git('merge-base', base, head).strip()}..{head}")
    blocking = 0
    for check in sorted({f[0] for f in now} | set(history)):
        mine = [f for f in now if f[0] == check]
        before = len({sha for sha, _, _ in history.get(check, [])})
        flags = before + (1 if mine else 0)
        left = [(sha, path, text, n) for sha, path, text in history.get(check, []) if (n := still_there(check, path, text))]
        block = flags >= BLOCK_AT and (mine or before >= BLOCK_AT)
        for _, path, line, _, msg in mine:
            if block:
                annotate("error", path, line, f"{msg} (check '{check}': flag {flags}, it blocks from {BLOCK_AT})")
            else:
                annotate("warning", path, line, f"{msg} (watched check '{check}': flag {flags}; it blocks at {BLOCK_AT})")
        if block or flags == BLOCK_AT - 1:
            for sha, path, text, n in left:
                where = f"flagged in {sha[:8]}" + ("" if check == "secret" else f": {text.strip()[:120]}")   # a secret's text stays out of the log
                if block:
                    annotate("error", path, n, f"check '{check}' blocks: fix this line, {where}")
                else:
                    annotate("warning", path, n, f"check '{check}' has {flags} flags, one more blocks: fix this line, {where}")
        blocking += (len(mine) + len(left)) if block else 0
    print(f"warn watch: {len(now)} found in this change; flags so far " + (", ".join(f"{c} {len({s for s, _, _ in v})}" for c, v in sorted(history.items())) or "none")
          + f"; a check blocks at {BLOCK_AT} flags; {blocking} blocking")
    return blocking


def main(argv):
    base = argv[1] if len(argv) > 1 else os.environ.get("MERGE_CHECK_BASE") or "origin/dev"
    try:
        return 1 if watch(base) else 0
    except RuntimeError as e:   # a check that cannot read the history or the diff must not pass
        print(f"::error::warn watch could not run against {base}: {e}")
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
