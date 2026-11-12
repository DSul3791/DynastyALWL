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


def run(deleted, added=(), head=None, base=None, users=None, removals="", modified=()):
    head = head or {}
    base = base or {}
    return dr.deletion_problems(list(deleted), list(added), lambda p: p in head, lambda p: base.get(p, ""),
                                lambda p: head.get(p, ""), users or {}, removals, list(modified))


OLD = "class_name OldMover\nextends Node\n"
B = {"src/move/old_mover.gd": OLD}
NEW = {"src/move/new_mover.gd": "class_name NewMover\n"}
REPL = dr.REPLACED_HEADING + " (x)\n| deleted path | replaced by | who | date | why |\n|---|---|---|---|---|\n" \
       "| src/move/old_mover.gd | src/move/new_mover.gd | Claude | 12 Nov | rewrite |\n"

# --- code replaced by new code (Decision 61) ---
check("replaced code, declared, unused", run(["src/move/old_mover.gd"], base=B, head=NEW, added=["src/move/new_mover.gd"], users=NEW, removals=REPL), True)
check("doc mention is not a use", run(["src/move/old_mover.gd"], base=B, head=NEW, added=["src/move/new_mover.gd"], removals=REPL,
                                      users=dict(NEW, **{"docs/knowledge/move.md": "see res://src/move/old_mover.gd",
                                                         "docs/ai-team/x/evidence.json": '"src/move/old_mover.gd"'})), True)
check("class_name taken over", run(["src/move/old_mover.gd"], base=B, head=NEW, added=["src/move/new_mover.gd"], removals=REPL,
                                   users={"src/move/mover.gd": "class_name OldMover\n", "src/a.gd": "var m := OldMover.new()"}), True)
check("replacement missing at HEAD", run(["src/move/old_mover.gd"], base=B, removals=REPL), False, "without approval")
check("unreplaced, unreferenced test script", run(["src/zz/tools/test_foo.gd"], base={"src/zz/tools/test_foo.gd": "extends SceneTree"}),
      False, "without approval")
check("unreplaced test moved aside and recorded", run(["src/zz/tools/test_foo.gd"],
      head={"proposed_removals/src/zz/tools/test_foo.gd.removed": ""},
      removals="| src/zz/tools/test_foo.gd | Claude | 12 Nov | obsolete | none |"), True)
check("code used by res:// path", run(["src/move/old_mover.gd"], base=B, head=NEW, added=["src/move/new_mover.gd"], removals=REPL,
                                      users={"scenes/p.tscn": 'path="res://src/move/old_mover.gd"'}), False, "still used")
check("code used by class_name", run(["src/move/old_mover.gd"], base=B, head=NEW, added=["src/move/new_mover.gd"], removals=REPL,
                                     users={"src/a.gd": "var m := OldMover.new()"}), False, "still used")
check("code used by uid", run(["src/x.gd"], base={"src/x.gd": "extends Node\n", "src/x.gd.uid": "uid://abc123\n"},
                              users={"scenes/s.tscn": '[ext_resource uid="uid://abc123"]'}), False, "still used")
check("autoload is a use", run(["src/g.gd"], base={"src/g.gd": "extends Node\n"},
                               users={"project.godot": 'G="*res://src/g.gd"'}), False, "still used")
check("runner script is a use", run(["src/zz/tools/validate_x.gd"],
                                    users={"tools/zz_check.sh": "--script res://src/zz/tools/validate_x.gd"}), False, "still used")
check("python bake is a use", run(["src/zz/tools/export_x.gd"],
                                  users={"tools/zz/run_chain.py": '"src/zz/tools/export_x.gd"'}), False, "still used")
check("x.gd is not x.gdshader", run(["src/move/old_mover.gd"], base=B, head=NEW, added=["src/move/new_mover.gd"], removals=REPL,
                                    users={"scenes/p.tscn": 'res://src/move/old_mover.gdshader'}), True)
# --- documents are archived ---
check("doc archived under same path", run(["docs/OLD_PLAN.md"], added=["docs/archive/2026-11/docs/OLD_PLAN.md"]), True)
check("doc archived flat, same content", run(["docs/OLD_PLAN.md"], added=["docs/archive/2026-11/OLD_PLAN.md"],
                                             base={"docs/OLD_PLAN.md": "plan"}, head={"docs/archive/2026-11/OLD_PLAN.md": "plan"}), True)
check("basename collision is not archiving", run(["docs/knowledge/README.md"], added=["docs/archive/2026-11/README.md"],
      base={"docs/knowledge/README.md": "a"}, head={"docs/archive/2026-11/README.md": "b"}), False, "instead of archived")
check("doc deleted", run(["docs/OLD_PLAN.md"]), False, "instead of archived")
check("root rulebook deleted", run(["PROTOCOL.md"]), False, "instead of archived")
check("doc not via proposed_removals", run(["design/notes.md"], head={"proposed_removals/design/notes.md": ""}), False, "archived")
check("archive md deleted", run(["docs/archive/2026-10/x.md"]), False, "historical document")
check("archive txt deleted", run(["docs/archive/2026-10/docs/bake31/island_table.txt"]), False, "historical document")
# --- other files: proposed-removal procedure ---
check("asset deleted", run(["assets/tex/rock.png"]), False, "without approval")
check("asset moved, no record", run(["assets/tex/rock.png"], head={"proposed_removals/assets/tex/rock.png": ""}), False, "REMOVALS.md")
check("asset moved, only prose mentions it", run(["assets/tex/rock.png"], head={"proposed_removals/assets/tex/rock.png": ""},
      removals="We may drop assets/tex/rock.png later."), False, "REMOVALS.md")
check("asset moved, near-name row", run(["assets/tex/rock.png"], head={"proposed_removals/assets/tex/rock.png": ""},
      removals="| assets/tex/bedrock.png | Claude | 12 Nov | unused | none |"), False, "REMOVALS.md")
check("asset moved and recorded", run(["assets/tex/rock.png"], head={"proposed_removals/assets/tex/rock.png": ""},
                                      removals="| assets/tex/rock.png | Claude | 12 Nov | unused | none |"), True)
check("scene moved, folder recorded", run(["scenes/old/a.tscn"], head={"proposed_removals/scenes/old/a.tscn.removed": ""},
                                          removals="| scenes/old/ | Claude | 12 Nov | old | new |"), True)
check("resource deleted outright", run(["worlds/base/strat.tres"]), False, "without approval")
check("scene deleted outright", run(["scenes/old/a.tscn"]), False, "without approval")
check("unguarded paths", run(["tools/old.py", "docs/mirror/x.md", "README.txt"]), True)

# --- second-round review cases ---
check("replacement not changed in this diff", run(["src/move/old_mover.gd"], base=B, head=NEW, removals=REPL), False, "without approval")
check("replacement changed (modified) counts", run(["src/move/old_mover.gd"], base=B, head=NEW, removals=REPL,
                                                  modified=["src/move/new_mover.gd"]), True)
check("replacement that is a doc", run(["src/move/old_mover.gd"], base=B, head={"README.md": ""}, added=["README.md"],
      removals=REPL.replace("src/move/new_mover.gd", "README.md")), False, "without approval")
check("ledger row after the Replaced section", run(["assets/tex/rock.png"], head={"proposed_removals/assets/tex/rock.png": ""},
      removals=REPL + "\n## Later clean-up\n| path | who | date | why | replaced by |\n|---|---|---|---|---|\n"
               "| assets/tex/rock.png | Claude | 13 Nov | unused | none |\n"), True)
check("root doc archive collision", run(["RULES.md"], added=["docs/archive/2026-11/RULES.md"],
      base={"RULES.md": "a"}, head={"docs/archive/2026-11/RULES.md": "b"}), False, "instead of archived")
check("root doc archived with same content", run(["RULES.md"], added=["docs/archive/2026-11/RULES.md"],
      base={"RULES.md": "a"}, head={"docs/archive/2026-11/RULES.md": "a"}), True)
check("agent definition deleted", run([".claude/agents/old-role.md"]), False, "instead of archived")
check("code moved aside but still used", run(["src/zz/y.gd"], head={"proposed_removals/src/zz/y.gd.removed": ""},
      removals="| src/zz/y.gd | Claude | 12 Nov | unused | none |", users={"scenes/s.tscn": "res://src/zz/y.gd"}), False, "still used")

print("deletion rules: %d failures" % len(fails))
sys.exit(1 if fails else 0)
