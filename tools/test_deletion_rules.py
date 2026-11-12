#!/usr/bin/env python3
"""Tests for tools/deletion_rules.py (Decision 61 as clarified by Dave, 12 Nov 2026). Pure data, no git, no Godot.
Run: python3 tools/test_deletion_rules.py   (prints "deletion rules: N failures", exit code = N > 0)"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import deletion_rules as dr

fails = []


def check(name, problems, want_ok, contains=""):
    ok = not problems
    if ok != want_ok or (contains and not any(contains in p for p in problems)):
        fails.append(name)
        print("FAIL:", name, problems)


def run(deleted, added=(), head=(), base=None, game=None, removals=""):
    base = base or {}
    return dr.deletion_problems(list(deleted), list(added), lambda p: p in set(head), lambda p: base.get(p, ""),
                                game or {}, removals)


OLD = "class_name OldMover\nextends Node\n"
# Positive: replaced code with nothing left using it is deleted cleanly, no proposed_removals copy needed.
check("replaced code, no users", run(["src/move/old_mover.gd"], base={"src/move/old_mover.gd": OLD},
                                     game={"src/move/new_mover.gd": "class_name NewMover\n"}), True)
# Positive: a docs file that mentions the old path is not a live reference.
check("no game file uses it", run(["src/move/old_mover.gd"], base={"src/move/old_mover.gd": OLD},
                                       game={"data/x.json": "{}"}), True)
# Positive: the replacement took over the same class_name, so users of the name are fine.
check("class_name taken over", run(["src/move/old_mover.gd"], base={"src/move/old_mover.gd": OLD},
                                   game={"src/move/mover.gd": "class_name OldMover\n", "src/a.gd": "var m := OldMover.new()"}), True)
# Negative: code still loaded by path is something the game needs.
check("code used by res:// path", run(["src/move/old_mover.gd"], base={"src/move/old_mover.gd": OLD},
                                      game={"scenes/p.tscn": 'path="res://src/move/old_mover.gd"'}), False, "still used")
# Negative: code still used through its class_name.
check("code used by class_name", run(["src/move/old_mover.gd"], base={"src/move/old_mover.gd": OLD},
                                     game={"src/a.gd": "var m := OldMover.new()"}), False, "still used")
# Negative: code still used through its uid.
check("code used by uid", run(["src/x.gd"], base={"src/x.gd": "extends Node\n", "src/x.gd.uid": "uid://abc123\n"},
                              game={"scenes/s.tscn": '[ext_resource uid="uid://abc123"]'}), False, "still used")
# Negative: an autoload in project.godot is a use.
check("autoload is a use", run(["src/g.gd"], base={"src/g.gd": "extends Node\n"},
                               game={"project.godot": 'G="*res://src/g.gd"'}), False, "still used")
# Positive: a document moved to docs/archive/ (rename not detected) passes.
check("doc archived", run(["docs/OLD_PLAN.md"], added=["docs/archive/2026-11/OLD_PLAN.md"]), True)
# Negative: a document simply deleted.
check("doc deleted", run(["docs/OLD_PLAN.md"]), False, "instead of archived")
# Negative: a proposed_removals copy does not excuse deleting a document.
check("doc not via proposed_removals", run(["design/notes.md"], head=["proposed_removals/design/notes.md"]), False, "archived")
# Negative: historical documents in docs/archive/ are never deleted.
check("archive doc deleted", run(["docs/archive/2026-10/x.md"]), False, "historical document")
# Negative: an unrelated asset deleted outright.
check("asset deleted", run(["assets/tex/rock.png"]), False, "without approval")
# Negative: asset moved aside but not recorded.
check("asset moved, no record", run(["assets/tex/rock.png"], head=["proposed_removals/assets/tex/rock.png"]), False, "REMOVALS.md")
# Positive: asset moved aside and recorded.
check("asset moved and recorded", run(["assets/tex/rock.png"], head=["proposed_removals/assets/tex/rock.png"],
                                      removals="| assets/tex/rock.png | Claude | 12 Nov | unused | none |"), True)
# Positive: scene moved aside with .removed and recorded by folder.
check("scene moved, folder recorded", run(["scenes/old/a.tscn"], head=["proposed_removals/scenes/old/a.tscn.removed"],
                                          removals="| scenes/old/ | Claude | 12 Nov | old | new |"), True)
# Positive: files outside the guarded folders/types and Library mirrors are not this check's business.
check("unguarded paths", run(["tools/old.py", "docs/mirror/x.md", "README.txt"]), True)

print("deletion rules: %d failures" % len(fails))
sys.exit(1 if fails else 0)
