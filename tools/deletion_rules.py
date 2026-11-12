#!/usr/bin/env python3
"""Deletion rules for tools/merge_check.py (section 7), kept apart so tools/test_deletion_rules.py can test them.

Source: Dave's explicit clarification of Decision 61, 12 Nov 2026 (recorded in RULES.md and docs/ai-team/DECISION_AUTHORITY.md):
  - Code replaced by new code is deleted, not kept behind flags or as dead code. Checked here: the deletion is declared in the
    "Replaced code" table of proposed_removals/REMOVALS.md with a replacement path that exists, and nothing still uses the old
    file (its res:// or bare path, its uid, or its class_name in game files, runner scripts or CI).
  - This does not allow deleting unrelated assets, user work, historical documents or anything the game still needs.
    Code with no declared replacement is "other unused" and goes through the proposed-removal procedure like any other file.
  - Documents are archived (git mv to docs/archive/YYYY-MM/...), never deleted; nothing in docs/archive/ is ever deleted.
  - Other unused files go through the proposed-removal procedure: a copy under proposed_removals/ plus a REMOVALS.md row.
Limits (check these by hand in review): uses built from strings at run time ("res://dir/" + name), directory scans and relative
preload() paths are not seen.
"""
import os
import re

CODE_EXT = (".gd", ".gdshader", ".shader")
DOC_EXT = (".md",)
KEEP_EXT = (".glb", ".gltf", ".obj", ".fbx", ".png", ".jpg", ".jpeg", ".webp", ".svg", ".tga", ".exr", ".hdr", ".dds", ".ogg", ".wav", ".mp3",
            ".tscn", ".tres") + CODE_EXT + DOC_EXT
KEEP_DIRS = ("art/", "assets/", "design/", "docs/", "items/", "src/", "scenes/", "worlds/", "data/")
ARCHIVE = "docs/archive/"
# Copies and records whose loss is not a loss: the removal area itself, Library mirrors and task evidence. ARCHIVE is NOT here.
SKIP_PREFIX = ("proposed_removals/", "docs/mirror/", "questions/", "evidence/", "results/")
# Files that can use a code file: the game's own files, runner scripts and CI. Docs that mention a path are not uses.
USE_EXT = (".gd", ".tscn", ".tres", ".gdshader", ".shader", ".godot", ".cfg", ".json", ".import",
           ".sh", ".py", ".yml", ".yaml", ".bat", ".cmd", ".ps1")
NOT_USERS = ("docs/", "proposed_removals/", "evidence/", "results/")
REPLACED_HEADING = "## Replaced code"


def _rows(text):
    """Cells of the markdown table rows in text (header and separator rows dropped)."""
    out = []
    for line in text.splitlines():
        if line.startswith("|") and not re.match(r"^\|[\s\-|:]+\|$", line):
            out.append([c.strip().strip("`") for c in line.strip().strip("|").split("|")])
    return out


def _covers(cell, path):
    """True if a ledger cell names path itself, its folder (ending in '/'), or its exact file name."""
    for item in re.split(r",\s*", cell):
        item = item.strip().strip("`")
        if item and (item == path or (item.endswith("/") and path.startswith(item)) or item == os.path.basename(path)):
            return True
    return False


def replacement_for(path, removals_text, head_exists):
    """The declared, existing replacement of deleted code file path, or None."""
    if REPLACED_HEADING not in removals_text:
        return None
    section = removals_text.split(REPLACED_HEADING, 1)[1].split("\n## ", 1)[0]
    for cells in _rows(section):
        if len(cells) >= 2 and cells[0] == path:
            for repl in re.split(r",\s*", cells[1]):
                repl = repl.strip().strip("`")
                if repl and head_exists(repl):
                    return repl
    return None


def _live_use(path, base_text, base_uid, use_files):
    """Name of a file that still uses deleted code file path, or None."""
    # Bare path also matches res://path and --script res://path; the end boundary keeps x.gd from matching x.gdshader.
    needles = [re.compile(re.escape(path) + r"(?![\w.])")]
    if base_uid:
        needles.append(re.compile(re.escape(base_uid) + r"(?!\w)"))
    cls = re.search(r"^class_name\s+(\w+)", base_text or "", re.M)
    cls_re = None
    if cls:
        name = cls.group(1)
        # A replacement may take over the same class_name; then uses of the name point at the new file.
        if not any(f.endswith(".gd") and re.search(r"^class_name\s+%s\b" % name, t, re.M) for f, t in use_files.items()):
            cls_re = re.compile(r"\b%s\b" % name)
    for f, t in use_files.items():
        if f.startswith(NOT_USERS):
            continue
        if any(n.search(t) for n in needles) or (cls_re and f.endswith((".gd", ".tscn", ".tres")) and cls_re.search(t)):
            return f
    return None


def deletion_problems(deleted, added, head_exists, base_read, head_read, use_files, removals_text):
    """Problems for files deleted since BASE.
    deleted: paths in BASE gone from HEAD; added: paths in HEAD not in BASE; head_exists(p) -> bool;
    base_read(p) / head_read(p) -> text of p at BASE / HEAD ('' if absent); use_files: {path: text} of HEAD files with USE_EXT;
    removals_text: HEAD proposed_removals/REMOVALS.md ('' if absent)."""
    out = []
    archived = [a for a in added if a.startswith(ARCHIVE)]
    ledger = _rows(removals_text.split(REPLACED_HEADING, 1)[0])
    for f in sorted(deleted):
        if f.startswith(ARCHIVE):
            out.append("historical document deleted: %s (nothing in docs/archive/ is deleted; restore it)" % f)
            continue
        is_doc = f.endswith(DOC_EXT) and ("/" not in f or f.startswith(KEEP_DIRS))
        if f.startswith(SKIP_PREFIX) or not (is_doc or (f.endswith(KEEP_EXT) and f.startswith(KEEP_DIRS))):
            continue
        if is_doc:
            old = base_read(f)
            ok = any(a.endswith("/" + f) or (os.path.basename(a) == os.path.basename(f) and head_read(a) == old)
                     for a in archived)
            if not ok:
                out.append("document deleted instead of archived: %s (git mv it to docs/archive/YYYY-MM/%s; documents are never "
                           "deleted)" % (f, f))
            continue
        if f.endswith(CODE_EXT):
            user = _live_use(f, base_read(f), (base_read(f + ".uid") or "").strip(), use_files)
            if user:
                out.append("deleted code is still used: %s (by %s). Replaced code is deleted only once nothing uses it "
                           "(Decision 61, Dave 12 Nov 2026)" % (f, user))
                continue
            if replacement_for(f, removals_text, head_exists):
                continue
            # No declared replacement: it is an "other unused file" and takes the proposed-removal route below.
        suffix = ".removed" if f.endswith((".gd", ".tscn", ".tres")) else ""
        if not (head_exists("proposed_removals/" + f + suffix) or head_exists("proposed_removals/" + f)):
            extra = (" or, if new code replaced it, add a row to the '%s' table in proposed_removals/REMOVALS.md naming the "
                     "replacement" % REPLACED_HEADING) if f.endswith(CODE_EXT) else ""
            out.append("deleted without approval: %s (move it to proposed_removals/%s%s and add a row to "
                       "proposed_removals/REMOVALS.md%s)" % (f, f, suffix, extra))
            continue
        if not any(cells and _covers(cells[0], f) for cells in ledger):
            out.append("moved to proposed_removals/ without a REMOVALS.md row: %s (add path, who, date, why, replaced by)" % f)
    return out
