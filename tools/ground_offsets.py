#!/usr/bin/env python3
"""Write each animal model look's ground offset into data/animals/models.json from a ground check report.

tools/ground_check.gd (run on a PC with a window) measures how far each model look's lowest foot stands off the ground as the game
draws it. Its report has one line per look and role:
    GROUND <kind> look <n> <role>[ <clip>] lowest <+m> m (min over the clip) bone_low <+m> m
This writes, per look (the row, or its variants[n]):
- "ground_m": minus the lowest point in the graze/stand role "0" (the rest pose if the model has no role 0), so the foot is on the ground.
- "ground_clips": {clip: metres} for a clip whose own lowest point differs from role 0's by more than CLIP_M, so that clip is put on the
  ground too (the moose's walk, the crow's Look2).
Rows sized by height (height_m, the goblins) are left alone: each one's size is rolled, and they stand within 3 cm.
  python3 tools/ground_offsets.py /mnt/project-files/ground_check.txt [--write]
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "data/animals/models.json"
CLIP_M = 0.02
LINE = re.compile(r"^GROUND (\S+) look (\d+) (\S+)(?: (.+?))? lowest ([+-][0-9.]+) m")


def read(report: Path) -> dict:
    looks: dict = {}
    for line in report.read_text(encoding="utf-8", errors="replace").splitlines():
        m = LINE.match(line.strip())
        if m:
            kind, look, role, clip, low = m.group(1), int(m.group(2)), m.group(3), (m.group(4) or "").strip(), float(m.group(5))
            looks.setdefault((kind, look), {})[role] = (clip, low)
    return looks


def offsets(roles: dict) -> tuple:
    base = roles.get("0", roles.get("rest"))[1]
    clips = {}
    for role, (clip, low) in roles.items():
        if role in ("rest", "0") or clip == "":
            continue
        if abs(low - base) > CLIP_M:
            clips[clip] = round(-(low - base), 3)
    return round(-base, 3), clips


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    looks = read(Path(sys.argv[1]))
    data = json.loads(MODELS.read_text(encoding="utf-8"))
    species = data["species"]
    done = 0
    for (kind, look), roles in sorted(looks.items()):
        row = species.get(kind)
        if not isinstance(row, dict) or "height_m" in row or not ("0" in roles or "rest" in roles):
            continue
        wild = [v for v in row.get("variants", []) if v.get("wild", True)]
        target = wild[look % len(wild)] if wild else row
        if not wild and look > 0:
            continue
        g, clips = offsets(roles)
        target["ground_m"] = g
        if clips:
            target["ground_clips"] = clips
        else:
            target.pop("ground_clips", None)
        done += 1
        print(f"{kind:14s} look {look}  ground_m {g:+.3f}  {clips if clips else ''}")
    print(f"{done} looks")
    if "--write" in sys.argv:
        MODELS.write_text(json.dumps(data, indent="\t", ensure_ascii=False) + "\n", encoding="utf-8")
        print("written", MODELS)
    return 0


if __name__ == "__main__":
    sys.exit(main())
