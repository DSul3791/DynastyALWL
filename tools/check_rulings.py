#!/usr/bin/env python3
"""Dave's rulings stay one per subject and replaced rules stay gone (docs/ai-team/CONSTITUTION.md, "Rulings").

Checks docs/RULINGS.md (one line per R- key, each dated, no struck-through text) and that no phrase in
docs/retired_rules.json appears in an active file. Active = tracked .md and .json files outside the history
folders below. Exit 0 clean, 1 with one line per problem.
    python3 tools/check_rulings.py [repo root]
"""
import json, pathlib, re, subprocess, sys

HISTORY = ("docs/archive/", "proposed_removals/", "BugsList_Fixed.md", "docs/RULINGS.md", "docs/retired_rules.json")
SUFFIXES = (".md", ".json")
LINE = re.compile(r"^- \*\*(R-[A-Z0-9-]+)\*\* · (\d{1,2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4}) · ")


def problems(root: pathlib.Path) -> list:
    out = []
    keys = {}
    for n, line in enumerate((root / "docs/RULINGS.md").read_text(encoding="utf-8").splitlines(), 1):
        if "~~" in line:
            out.append(f"docs/RULINGS.md:{n}: struck-through text: delete the old rule instead")
        if not line.startswith("- **R-"):
            continue
        m = LINE.match(line)
        if not m:
            out.append(f"docs/RULINGS.md:{n}: a ruling line needs '- **R-KEY** · 25 Nov 2026 · words'")
            continue
        if m.group(1) in keys:
            out.append(f"docs/RULINGS.md:{n}: {m.group(1)} is already on line {keys[m.group(1)]}: replace that line, do not add a second")
        keys.setdefault(m.group(1), n)
    retired = json.loads((root / "docs/retired_rules.json").read_text(encoding="utf-8"))["retired"]
    for r in retired:
        if r["replaced_by"] not in keys:
            out.append(f"docs/retired_rules.json: '{r['phrase']}' names {r['replaced_by']}, which is not in docs/RULINGS.md")
    listed = subprocess.run(["git", "ls-files"], cwd=root, capture_output=True, text=True)
    if listed.returncode != 0:
        return out + ["git ls-files failed: run from the repository"]
    files = listed.stdout.splitlines()
    for rel in files:
        if not rel.endswith(SUFFIXES) or rel.startswith(HISTORY):
            continue
        try:
            text = (root / rel).read_text(encoding="utf-8").lower()
        except (OSError, UnicodeDecodeError):
            continue
        for r in retired:
            if r["phrase"].lower() in text:
                out.append(f"{rel}: still states a replaced rule ('{r['phrase']}', replaced by {r['replaced_by']})")
    return out


if __name__ == "__main__":
    found = problems(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "."))
    for p in found:
        print(p)
    if not found:
        print("rulings: one line per subject, no replaced rule left in active docs")
    sys.exit(1 if found else 0)
