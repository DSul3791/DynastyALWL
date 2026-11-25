#!/usr/bin/env python3
"""Self-test for tools/check_rulings.py: a clean repo passes; a second line on a subject, a struck-through
line and a replaced phrase back in a doc each fail; a frozen checkpoint (docs/retirements.json) is skipped.   python3 -I tools/test_check_rulings.py"""
import json, pathlib, subprocess, sys, tempfile

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import check_rulings

fails = 0


def case(name, rulings, doc, expect, frozen=False):
    global fails
    with tempfile.TemporaryDirectory() as d:
        root = pathlib.Path(d)
        (root / "docs").mkdir()
        (root / "docs/RULINGS.md").write_text(rulings, encoding="utf-8")
        (root / "docs/design.md").write_text(doc, encoding="utf-8")
        (root / "docs/retired_rules.json").write_text(json.dumps({"retired": [{"phrase": "torch or not", "replaced_by": "R-A"}]}), encoding="utf-8")
        if frozen:   # docs/design.md is a frozen history checkpoint (docs/retirements.json): never edited, so never flagged
            (root / "docs/retirements.json").write_text(json.dumps({"batches": [{"entries": [{"retired": "docs/design.md"}]}]}), encoding="utf-8")
        subprocess.run(["git", "init", "-q"], cwd=root)
        subprocess.run(["git", "add", "."], cwd=root)
        got = len(check_rulings.problems(root))
        if got != expect:
            fails += 1
            print(f"FAIL {name}: {got} problems, expected {expect}")


ok = "- **R-A** · 25 Nov 2026 · fire keeps everything away.\n"
case("clean", ok, "Fire holds every animal.", 0)
case("second line", ok + "- **R-A** · 26 Nov 2026 · again.\n", "", 1)
case("struck through", ok + "~~old~~\n", "", 1)
case("old rule in a doc", ok, "The pack rushes, Torch or not.", 1)
case("undated line", "- **R-A** fire.\n", "", 2)
case("date without a day", "- **R-A** · Nov 2026 · fire.\n", "", 2)
case("mixed-case phrase", ok, "Torch Or Not", 1)   # bad line, and R-A then missing for the retired phrase
case("old rule in a frozen checkpoint", ok, "The pack rushes, Torch or not.", 0, frozen=True)
print("test_check_rulings: %s" % ("FAIL" if fails else "PASS"))
sys.exit(1 if fails else 0)
