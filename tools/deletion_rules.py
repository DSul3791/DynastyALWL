#!/usr/bin/env python3
"""Deletion rules for tools/merge_check.py (section 7), kept apart so tools/test_deletion_rules.py can test them.

Source: Dave's explicit clarification of Decision 61, 12 Nov 2026 (recorded in RULES.md and docs/ai-team/DECISION_AUTHORITY.md):
  - Code replaced by new code is deleted, not kept behind flags or as dead code. Checked here: the deleted code file must have
    no live reference left in the game (res:// path, its uid, or its class_name in game files).
  - This does not allow deleting unrelated assets, user work, historical documents or anything the game still needs.
  - Documents are archived (git mv to docs/archive/YYYY-MM/), never deleted; files already in docs/archive/ stay.
  - Other unused files go through the proposed-removal procedure: a copy under proposed_removals/ plus a REMOVALS.md line.
"""
import os
import re

CODE_EXT = (".gd", ".gdshader", ".shader")
DOC_EXT = (".md",)
KEEP_EXT = (".glb", ".gltf", ".obj", ".fbx", ".png", ".jpg", ".jpeg", ".webp", ".svg", ".tga", ".exr", ".hdr", ".dds", ".ogg", ".wav", ".mp3",
            ".tscn", ".tres") + CODE_EXT + DOC_EXT
KEEP_DIRS = ("art/", "assets/", "design/", "docs/", "items/", "src/", "scenes/", "worlds/", "data/")
# Copies and records whose loss is not a loss: the removal area itself, Library mirrors and task evidence. docs/archive/ is NOT here:
# it holds the historical documents, which are never deleted.
SKIP_PREFIX = ("proposed_removals/", "docs/mirror/", "questions/", "evidence/", "results/")
# Files the game loads; a reference from one of these keeps a code file alive. Docs that mention a path are not references.
GAME_EXT = (".gd", ".tscn", ".tres", ".gdshader", ".shader", ".godot", ".cfg", ".json", ".import")


def _live_reference(path, base_text, base_uid, game_files):
    """Name of a game file that still uses deleted code file `path`, or None."""
    needles = ["res://" + path]
    if base_uid:
        needles.append(base_uid)
    cls = re.search(r"^class_name\s+(\w+)", base_text or "", re.M)
    cls_re = None
    if cls:
        name = cls.group(1)
        # A replacement may take over the same class_name; then uses of the name point at the new file.
        if not any(f.endswith(".gd") and re.search(r"^class_name\s+%s\b" % name, t, re.M) for f, t in game_files.items()):
            cls_re = re.compile(r"\b%s\b" % name)
    for f, t in game_files.items():
        if f.startswith(SKIP_PREFIX) or f.startswith("docs/archive/"):
            continue
        if any(n in t for n in needles) or (cls_re and f.endswith((".gd", ".tscn", ".tres")) and cls_re.search(t)):
            return f
    return None


def deletion_problems(deleted, added, head_exists, base_read, game_files, removals_text):
    """Problems for files deleted since BASE.
    deleted: paths in BASE gone from HEAD; added: paths in HEAD not in BASE; head_exists(p) -> bool;
    base_read(p) -> text of p at BASE ('' if absent); game_files: {path: text} of HEAD files with GAME_EXT;
    removals_text: HEAD proposed_removals/REMOVALS.md ('' if absent)."""
    out = []
    archived = {os.path.basename(a) for a in added if a.startswith("docs/archive/")}
    for f in sorted(deleted):
        if f.startswith(SKIP_PREFIX) or not (f.endswith(KEEP_EXT) and f.startswith(KEEP_DIRS)):
            continue
        if f.endswith(CODE_EXT):
            uid = (base_read(f + ".uid") or "").strip()
            user = _live_reference(f, base_read(f), uid, game_files)
            if user:
                out.append("deleted code is still used: %s (referenced by %s). Replaced code is deleted only once nothing uses it "
                           "(Decision 61, Dave 12 Nov 2026)" % (f, user))
            continue
        if f.endswith(DOC_EXT):
            if f.startswith("docs/archive/"):
                out.append("historical document deleted: %s (documents in docs/archive/ are kept; restore it)" % f)
            elif os.path.basename(f) not in archived:
                out.append("document deleted instead of archived: %s (git mv it to docs/archive/YYYY-MM/; documents are never "
                           "deleted)" % f)
            continue
        suffix = ".removed" if f.endswith((".tscn", ".tres")) else ""
        if not (head_exists("proposed_removals/" + f + suffix) or head_exists("proposed_removals/" + f)):
            out.append("deleted without approval: %s (move it to proposed_removals/%s%s and add a line to "
                       "proposed_removals/REMOVALS.md)" % (f, f, suffix))
            continue
        parents = [f[:i + 1] for i, c in enumerate(f) if c == "/"]
        if not any(k in removals_text for k in [f, os.path.basename(f)] + parents[1:]):
            out.append("moved to proposed_removals/ without a REMOVALS.md line: %s (add who, date, why, replaced by)" % f)
    return out
