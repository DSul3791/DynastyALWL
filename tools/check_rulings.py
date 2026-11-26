#!/usr/bin/env python3
"""Dave's rulings stay one per subject and replaced rules stay gone (docs/ai-team/CONSTITUTION.md, "Rulings").

Checks docs/RULINGS.md (one line per R- key, each dated and marked rule, suggestion or unclear, no struck-through text) and
that no phrase in docs/retired_rules.json appears in an active file. Active = tracked .md and .json files outside the history
folders below. A retired phrase replaced by a suggestion only prints a NOTE (Dave 26 Nov 2026, R-CORE-RULES-VS-SUGGESTIONS:
only his explicit rules block). Exit 0 clean, 1 with one line per problem.
    python3 tools/check_rulings.py [repo root]
"""
import json, pathlib, re, subprocess, sys

HISTORY = ("docs/archive/", "proposed_removals/", "BugsList_Fixed.md", "docs/RULINGS.md", "docs/retired_rules.json")
SUFFIXES = (".md", ".json")   # .gd next, with the last two hub comments (terrain_net.gd, server_animals.gd)
LINE = re.compile(r"^- \*\*(R-[A-Z0-9-]+)\*\* · (\d{1,2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4}) · (rule|suggestion|unclear) · ")
NOTES = []   # what check() found on suggestions: printed, never blocking


def softened(old_text: str, new_text: str) -> list:
    """A rule turned suggestion or unclear with the same date: a mark flipped to get past a check. A rule changes only by a new dated
    line in Dave's words (docs/RULINGS.md), so a new date is not caught here, nor is a deleted line; unclear to suggestion is the
    coordinator settling a line, also not caught."""
    def marks(text):
        return {m.group(1): (m.group(2), m.group(4)) for m in map(LINE.match, text.splitlines()) if m}
    was = marks(old_text)
    return [f"{key} went from rule to {kind} with the same date: a rule changes only by a new dated line in Dave's words"
            for key, (date, kind) in marks(new_text).items() if was.get(key) == (date, "rule") and kind != "rule"]


def frozen_files(root: pathlib.Path) -> set:
    try:
        manifest = json.loads((root / "docs/retirements.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return set()
    return {str(e.get("retired", "")) for b in manifest.get("batches", []) for e in b.get("entries", []) if isinstance(e, dict)}


def kinds(root: pathlib.Path) -> dict:
    """R-key -> rule, suggestion or unclear, from docs/RULINGS.md."""
    out = {}
    for line in (root / "docs/RULINGS.md").read_text(encoding="utf-8").splitlines():
        m = LINE.match(line)
        if m:
            out.setdefault(m.group(1), m.group(4))
    return out


def problems(root: pathlib.Path) -> list:
    out = []
    keys = {}
    kind = kinds(root)
    NOTES.clear()
    for n, line in enumerate((root / "docs/RULINGS.md").read_text(encoding="utf-8").splitlines(), 1):
        if "~~" in line:
            out.append(f"docs/RULINGS.md:{n}: struck-through text: delete the old rule instead")
        if not line.startswith("- **R-"):
            continue
        m = LINE.match(line)
        if not m:
            out.append(f"docs/RULINGS.md:{n}: a ruling line needs '- **R-KEY** · 25 Nov 2026 · rule|suggestion|unclear · words'")
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
    frozen = frozen_files(root)   # history checkpoints docs/retirements.json freezes: merge_check fails any edit to them
    for rel in files:
        if not rel.endswith(SUFFIXES) or rel.startswith(HISTORY) or rel in frozen:
            continue
        try:
            text = (root / rel).read_text(encoding="utf-8").lower()
        except (OSError, UnicodeDecodeError):
            continue
        for r in retired:
            if r["phrase"].lower() in text:
                line = f"{rel}: still states a replaced rule ('{r['phrase']}', replaced by {r['replaced_by']})"
                (NOTES if kind.get(r["replaced_by"]) == "suggestion" else out).append(line)
    return out


if __name__ == "__main__":
    found = problems(pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "."))
    for p in found:
        print(p)
    for p in NOTES:
        print("NOTE " + p + " [a suggestion: tidy it, does not block]")
    if not found:
        print("rulings: one line per subject, no replaced rule left in active docs")
    sys.exit(1 if found else 0)
