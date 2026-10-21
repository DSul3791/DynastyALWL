#!/usr/bin/env python3
"""Fails if a key or mouse button bound in code is missing from CONTROLS.md (first column of the tables).
Run before pushing any change that adds or changes an input: python3 tools/check_controls.py"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
LABELS = {  # Godot key constant -> word that must appear in a CONTROLS.md control cell
    "KEY_SPACE": "Space", "KEY_CTRL": "Ctrl", "KEY_SHIFT": "Shift", "KEY_ESCAPE": "Esc",
    "KEY_SLASH": "/", "KEY_TAB": "Tab", "KEY_PLUS": "+", "KEY_EQUAL": "+", "KEY_MINUS": "-", "KEY_KP_ADD": "numpad",
    "KEY_KP_SUBTRACT": "numpad", "KEY_BRACKETRIGHT": "]", "KEY_BRACKETLEFT": "[",
    "MOUSE_BUTTON_LEFT": "Left click", "MOUSE_BUTTON_RIGHT": "Right click",
    "MOUSE_BUTTON_MIDDLE": "Middle click", "MOUSE_BUTTON_WHEEL_UP": "Wheel", "MOUSE_BUTTON_WHEEL_DOWN": "Wheel",
}
IGNORE = {"KEY_WRAPPED_X", "KEY_WRAPPED_Z", "KEY_SOURCE_REVISION", "KEY_SOURCE_REGION", "KEY_LOGICAL_REGION", "KEY_FILE"}
SKIP_DIRS = {"addons", "native", "tools", ".godot"}

def label(const):
    if const in LABELS:
        return LABELS[const]
    m = re.fullmatch(r"KEY_([A-Z])", const)
    if m:
        return m.group(1)
    m = re.fullmatch(r"KEY_(\d|F\d+)", const)
    if m:
        return m.group(1)
    return None

cells = []
for line in (ROOT / "CONTROLS.md").read_text(encoding="utf-8").splitlines():
    if line.startswith("|") and not line.startswith("|---"):
        cells.append(line.split("|")[1].strip())
text = "\n".join(cells)

def present(word):
    if len(word) == 1 and word.isalnum():  # single letters and digits: match as a standalone token
        return re.search(r"(?<![A-Za-z0-9])" + re.escape(word) + r"(?![A-Za-z0-9])", text) is not None
    return word in text

used = {}
for path in ROOT.rglob("*.gd"):
    if SKIP_DIRS & set(path.relative_to(ROOT).parts):
        continue
    for n, line in enumerate(path.read_text(encoding="utf-8", errors="ignore").splitlines(), 1):
        for const in re.findall(r"\b(KEY_[A-Z0-9_]+|MOUSE_BUTTON_[A-Z_]+)\b", line):
            if const not in IGNORE and not const.startswith("MOUSE_BUTTON_MASK"):
                used.setdefault(const, f"{path.relative_to(ROOT)}:{n}")

bad = []
for const, where in sorted(used.items()):
    word = label(const)
    if word is None:
        bad.append(f"{const} ({where}): add it to LABELS in tools/check_controls.py and to CONTROLS.md")
    elif not present(word):
        bad.append(f"{const} ({where}): '{word}' is not in the first column of CONTROLS.md")
for b in bad:
    print("CONTROLS.md missing:", b)
print("controls check:", "FAILED" if bad else "ok", f"({len(used)} bindings in code)")
sys.exit(1 if bad else 0)
