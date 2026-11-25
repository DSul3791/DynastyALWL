#!/usr/bin/env python3
"""Watched checks: warn first, block on the 3rd flag (Dave 25 Nov 2026, docs/RULINGS.md R-TEAM-WARN-TO-BLOCK).

Runs on every PR and every push to dev or main (.github/workflows/merge_check.yml). The checks are tools/hooks/agent_warn.py's diff
checks (a bare print() in client code, a key or password, a machine's private file). A check is flagged once for each change that adds
at least one problem it finds. The count is read from the branch's own history, so nothing is stored and nobody can reset it: every
first-parent commit since START that the check flags, plus this change if it flags. Flags 1 and 2 only warn. From the 3rd it
blocks: this change may not add the problem, and every line the earlier flags added must be fixed (gone from the file) first.
    python3 tools/warn_watch.py [BASE]          BASE defaults to $MERGE_CHECK_BASE, else origin/dev
"""
import importlib.util, os, pathlib, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
START = "2026-11-25T19:30:00Z"   # watching began (Dave's ruling); earlier commits are not counted
BLOCK_AT = 3                     # Dave: "flagged 3 times": the flag that makes a check block

spec = importlib.util.spec_from_file_location("agent_warn", ROOT / "tools/hooks/agent_warn.py")
aw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aw)


def git(*args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)}: {r.stderr.strip()[:200]}")
    return r.stdout


def annotate(kind, path, line, msg):
    print(f"::{kind} file={path},line={max(line, 1)}::{msg}" if os.environ.get("GITHUB_ACTIONS") else f"{kind.upper()} {path}:{line}: {msg}")


def watch(base, head="HEAD"):
    """Returns the number of blocking problems; prints warnings and errors."""
    aw.ROOT = ROOT
    history = {}   # check -> [(commit, path, line text)]
    for sha in git("rev-list", "--first-parent", f"--since={START}", base).split():
        parents = git("rev-list", "--parents", "-n", "1", sha).split()[1:]
        if not parents:
            continue
        for check, path, _, text, _ in aw.findings(f"{parents[0]}..{sha}"):
            history.setdefault(check, []).append((sha, path, text))
    now = aw.findings(f"{git('merge-base', base, head).strip()}..{head}")
    blocking = 0
    for check in sorted({f[0] for f in now} | set(history)):
        mine = [f for f in now if f[0] == check]
        flags = len({sha for sha, _, _ in history.get(check, [])}) + (1 if mine else 0)
        if flags < BLOCK_AT:
            for _, path, line, _, msg in mine:
                annotate("warning", path, line, f"{msg} (watched check '{check}': flag {flags}; it blocks at {BLOCK_AT})")
            continue
        for _, path, line, _, msg in mine:
            blocking += 1
            annotate("error", path, line, f"{msg} (check '{check}' has been flagged {flags} times: it now blocks)")
        for sha, path, text in history.get(check, []):
            if check != "private-file" and (ROOT / path).is_file() and text in (ROOT / path).read_text(encoding="utf-8", errors="replace").splitlines():
                blocking += 1
                annotate("error", path, 1, f"check '{check}' now blocks: fix this line flagged in {sha[:8]}: {text.strip()[:120]}")
    print(f"warn watch: {len(now)} found in this change; flags so far " + (", ".join(f"{c} {len({s for s, _, _ in v})}" for c, v in sorted(history.items())) or "none")
          + f"; a check blocks at {BLOCK_AT} flags; {blocking} blocking")
    return blocking


def main(argv):
    base = argv[1] if len(argv) > 1 else os.environ.get("MERGE_CHECK_BASE") or "origin/dev"
    return 1 if watch(base) else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
