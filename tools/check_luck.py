#!/usr/bin/env python3
"""Fails on a raw random draw in server code that skips the luck function (job 77, Dave 2026-10-21: luck applies to ALL rolls).
A draw (randf, randi, randf_range, randi_range, rand_from_seed, randomize) in the server files is allowed only in
src/shared/luck.gd or on a line marked `# luck-exempt: <reason>` (world layout and regrowth that no player takes part in,
the creation roll, the fate stream). Run: python3 tools/check_luck.py"""
import re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SERVER = ["src/stream", "scenes/terrain_server", "src/water"]
DRAW = re.compile(r"\b(randf|randi|randf_range|randi_range|rand_from_seed|randomize)\s*\(")


def main() -> int:
    bad = []
    for folder in SERVER:
        for path in sorted((ROOT / folder).rglob("*.gd")):
            for number, line in enumerate(path.read_text().split("\n"), 1):
                code = line.split("#", 1)[0]
                if DRAW.search(code) and "luck-exempt:" not in line:
                    bad.append(f"{path.relative_to(ROOT)}:{number}: {line.strip()}")
    for entry in bad:
        print("raw random call without luck:", entry)
    print("luck check:", "FAIL" if bad else "ok")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
