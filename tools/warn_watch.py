#!/usr/bin/env python3
"""Watched checks: each problem line is flagged every time a change touches its file; on its 3rd flag that change is blocked until the
problem is fixed or removed (Dave 25 Nov 2026, docs/RULINGS.md R-TEAM-WARN-TO-BLOCK).

Runs on every PR and every push to dev or main (.github/workflows/merge_check.yml). The checks are tools/hooks/agent_warn.py's
line_problems() (a bare print() in client code, a key or password) and its private files; a new watched check is one more name there.
A problem is one line (check, file, text). A change that touches the file flags each problem the file holds after the change. Its count
is read from the branch's own history, so nothing is stored and nobody can reset it: the first-parent commits since START that touched
the file while the line was in it, plus this change. Flags 1 and 2 warn; the 3rd blocks. Fixed or removed, the line is gone and so is
its count. A key, password or private file blocks on first sight: Dave, 25 Nov 2026, "passwords and keys shouldn't ever be in the code."
    python3 tools/warn_watch.py [BASE]          BASE defaults to $MERGE_CHECK_BASE, else origin/dev
"""
import importlib.util, os, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
START = "2026-11-25T19:30:00Z"   # watching began (Dave's ruling); earlier commits are not counted
BLOCK_AT = 3                     # Dave: "if it gets flagged 3 times it gets blocked and fixed"
AT_ONCE = {"secret", "private-file"}   # Dave: "passwords and keys shouldn't ever be in the code.": block on the first flag

spec = importlib.util.spec_from_file_location("agent_warn", ROOT / "tools/hooks/agent_warn.py")
aw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aw)


def annotate(kind, path, line, msg):
    print(f"::{kind} file={path},line={max(line, 1)}::{msg}" if os.environ.get("GITHUB_ACTIONS") else f"{kind.upper()} {path}:{line}: {msg}")


def touched(a, b):
    return set(aw.git("diff", "--name-only", "--no-renames", "--diff-filter=d", a, b).splitlines())


def problems(paths):
    """(check, path, line number, line text, message) for each problem in the given files as they are now."""
    out = []
    for path in sorted(paths):
        p = ROOT / path
        if path in aw.PRIVATE_FILES and p.is_file():
            out.append(("private-file", path, 1, "", f"{path} is a machine's private file: take it out of the repo"))
        if not p.is_file() or p.suffix not in (".gd", ".py", ".json", ".md", ".cfg", ".txt", ".sh", ".yml", ".yaml", ".env", ".tscn", ".tres"):
            continue
        for n, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
            out += [(check, path, n, line, msg) for check, msg in aw.line_problems(path, line)]
    return out


def watch(base, head="HEAD"):
    """Returns the number of blocking problems; prints warnings and errors."""
    aw.ROOT, aw.STRICT = ROOT, True
    history = []   # (commit, files it touched), first parent only
    for row in aw.git("rev-list", "--first-parent", "--parents", f"--since={START}", base).splitlines():
        sha, *parents = row.split()
        if parents:
            history.append((sha, touched(parents[0], sha)))
    found = problems(touched(aw.git("merge-base", base, head).strip(), head))
    held = {}   # (commit, path) -> its lines
    blocking = 0
    for check, path, line, text, msg in found:
        flags = 1
        for sha, files in history:
            if path in files:
                if (sha, path) not in held:
                    held[(sha, path)] = set(aw.git("show", f"{sha}:{path}").splitlines())
                flags += check == "private-file" or text in held[(sha, path)]
        if check in AT_ONCE or flags >= BLOCK_AT:
            blocking += 1
            why = "blocks on first sight" if check in AT_ONCE else f"flag {flags}: blocked until it is fixed or removed"
            annotate("error", path, line, f"{msg} ({why})")
        else:
            annotate("warning", path, line, f"{msg} (flag {flags}; the {BLOCK_AT}rd change that touches it is blocked until it is fixed)")
    print(f"warn watch: {len(found)} problems in the files this change touches; {blocking} blocking")
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
