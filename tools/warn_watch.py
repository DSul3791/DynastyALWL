#!/usr/bin/env python3
"""Watched checks: each problem line is flagged every time a change touches its file; on its 3rd flag that change is blocked until the
problem is fixed or removed (Dave 25 Nov 2026, docs/RULINGS.md R-TEAM-WARN-TO-BLOCK).

Runs on every PR and every push to dev or main (.github/workflows/merge_check.yml). The checks are tools/hooks/agent_warn.py's
line_problems() (a bare print() in client code, a key or password) and its private files; a new watched check is one more name there.
A problem is one line (check, file, text without its indent). A change that touches the file flags each problem the file holds after the
change. Its count is read from the branch's own history, so nothing is stored and nobody can reset it: this change, plus each
first-parent commit since START that touched the file, newest first, back to the last one that left the line out (fixed or removed: its
count is gone). Flags 1 and 2 warn; the 3rd blocks. A key, password or private file blocks on first sight: Dave, 25 Nov 2026,
"passwords and keys shouldn't ever be in the code."
shortcut: a problem moved to another file or renamed starts again at flag 1; the same text twice in one file shares one count.
    python3 tools/warn_watch.py [BASE]          BASE defaults to $MERGE_CHECK_BASE, else origin/dev
"""
import importlib.util, os, pathlib, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
START = "2026-11-25T19:30:00Z"   # watching began (Dave's ruling); earlier commits are not counted
BLOCK_AT = 3                     # Dave: "if it gets flagged 3 times it gets blocked and fixed"
AT_ONCE = {"secret", "private-file"}   # Dave: "passwords and keys shouldn't ever be in the code.": block on the first flag
MAX_BYTES = 2_000_000            # larger files are data (tiles, packs), not code

spec = importlib.util.spec_from_file_location("agent_warn", ROOT / "tools/hooks/agent_warn.py")
aw = importlib.util.module_from_spec(spec)
spec.loader.exec_module(aw)


def annotate(kind, path, line, msg):
    print(f"::{kind} file={path},line={max(line, 1)}::{msg}" if os.environ.get("GITHUB_ACTIONS") else f"{kind.upper()} {path}:{line}: {msg}")


def text_at(rev, path):
    """The file's lines at rev, or None for a large or binary file."""
    if int(aw.git("cat-file", "-s", f"{rev}:{path}").strip() or 0) > MAX_BYTES:
        return None
    body = aw.git("show", f"{rev}:{path}")
    return None if "\0" in body else body.splitlines()


def problems(head, paths):
    """(check, path, line number, line text, message) for each problem in the given files at head."""
    out = []
    for path in sorted(paths):
        if path in aw.PRIVATE_FILES:
            out.append(("private-file", path, 1, "", f"{path} is a machine's private file: take it out of the repo"))
        for n, line in enumerate(text_at(head, path) or [], 1):
            out += [(check, path, n, line, msg) for check, msg in aw.line_problems(path, line)]
    return out


def history(base):
    """[(commit, {path: status})] newest first, first parent only, since START."""
    out = []
    for line in aw.git("-c", "core.quotepath=off", "log", "--first-parent", "--diff-merges=first-parent", "--no-renames", "--name-status",
                       "--format=@@%H", f"--since={START}", base).splitlines():
        if line.startswith("@@"):
            out.append((line[2:], {}))
        elif "\t" in line and out:
            status, path = line.split("\t", 1)
            out[-1][1][path] = status[:1]
    return out


def watch(base):
    """Returns the number of blocking problems; prints warnings and errors."""
    aw.ROOT, aw.STRICT = ROOT, True
    head = "HEAD"
    found = problems(head, aw.git("-c", "core.quotepath=off", "diff", "--name-only", "--no-renames", "--diff-filter=d",
                                  aw.git("merge-base", base, head).strip(), head).splitlines())
    past = history(base) if any(f[0] not in AT_ONCE for f in found) else []
    held = {}   # (commit, path) -> its stripped lines
    blocking = 0
    for check, path, line, text, msg in found:
        flags = 1
        for sha, files in past if check not in AT_ONCE else []:
            if path not in files:
                continue
            if files[path] == "D":
                break
            if (sha, path) not in held:
                held[(sha, path)] = {l.strip() for l in text_at(sha, path) or []}
            if text.strip() not in held[(sha, path)]:
                break   # fixed or removed then: what came before does not count
            flags += 1
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
