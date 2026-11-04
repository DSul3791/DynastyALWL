#!/usr/bin/env python3
"""Find recipe costs in the first-hour guides that disagree with data/items/recipes.json (Dino, 3 Nov 2026).

Two heuristics, warnings only, exit 1 if any:
  1. "#N ... <count> <ingredient>" where N is a recipe number.
  2. "<recipe name> ... <count> <ingredient>" for the first-hour recipes (within 70 characters after the name).
Usage: python3 tools/guide_vs_recipe.py [file.md ...]
"""
import json, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
GUIDES = ["PLAYTHROUGH_GUIDE.md", "FIRST_DAY_GUIDE.md", "TUTORIAL_FIRST_30_MIN.md", "MORNING_PLAYTEST_CHECKLIST.md",
          "MORNING_PLAYTEST_CHECKLIST_FULL.md", "FIRST_HOUR_FOOD.md"]
WORDS = {"stone": r"stones?", "stick": r"sticks?", "twine": r"twine", "plant_fibre": r"(?:plant )?fibre",
         "leaves": r"leaves", "thatch": r"thatch", "clay": r"clay", "log": r"logs?", "tallow": r"tallow"}
NAMES = {"lean-to": "lean_to_kit", "rough bed": "rough_bed_kit", "stone axe": "stone_axe", "campfire kit": "campfire",
         "fishing rod": "fishing_rod", "torch": "torch", "stone knife": "stone_knife", "camp bench": "workbench_kit"}

recipes = json.load(open(ROOT / "data/items/recipes.json", encoding="utf8"))["recipes"]
by_number = {int(r["number"]): r for r in recipes.values()}


def mismatches(recipe, seg):
    for iid, count in recipe["needs"]:
        if iid not in WORDS:
            continue
        m = re.search(r"(\d+)\s+" + WORDS[iid] + r"\b", seg, re.I)
        if m and int(m.group(1)) != int(count):
            yield m.group(0), count


bad = 0
for name in sys.argv[1:] or GUIDES:
    path = ROOT / name
    if not path.exists():
        continue
    for ln, line in enumerate(path.read_text(encoding="utf8").splitlines(), 1):
        for m in re.finditer(r"#(\d+)\b[^#|\n]{0,80}", line):
            r = by_number.get(int(m.group(1)))
            if r:
                for said, want in mismatches(r, m.group(0)):
                    print(f"{name}:{ln}: recipe #{m.group(1)} ({r['name']}): says '{said}', data {want}")
                    bad += 1
        low = line.lower()
        for label, rid in NAMES.items():
            for m in re.finditer(re.escape(label), low):
                for said, want in mismatches(recipes[rid], line[m.end():m.end() + 70].split("|")[0]):
                    print(f"{name}:{ln}: {label}: says '{said}', data {want}")
                    bad += 1

print(f"{bad} mismatch(es)")
sys.exit(1 if bad else 0)
