"""Prints the footstep loudness table (dB per surface and gait) from data/sound/step_levels.json.

Run: python3 tools/step_levels.py [--md]   (--md writes sound/STEP_LEVELS.md next to the project files if /mnt/project-files exists)
Final level of a step = surface_db + gait_db + surface_gait_db[surface][gait]; tune (soil, rock, ore), crouch, snow hush
and a per-step random of about -1.5 to +1 dB come on top in the game. All step recordings sit within 0.6 dB of each
other (assets/audio/LOUDNESS.md, about -18.5 dB RMS), so these numbers are the whole story.
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
data = json.load(open(os.path.join(ROOT, "data", "sound", "step_levels.json")))
gait = data["gait_db"]
extra = data.get("surface_gait_db", {})
rows = []

for group in ("surface_db", "floor_db"):
    for name, base in data[group].items():
        add = extra.get(name, [0.0, 0.0, 0.0])
        rows.append((group.split("_")[0], name, [base + gait[g] + add[g] for g in range(3)]))

lines = ["# Footstep loudness (dB) by surface and gait", "",
         "From `data/sound/step_levels.json` (edit that file and restart the game; this table is made by `python3 tools/step_levels.py --md`).",
         "Quieter is more negative. Walk, jog and run are the gaits; a crouch is 6 dB softer on top, snow hush up to 3 dB softer.", "",
         "| kind | surface | walk | jog | run |", "|---|---|---|---|---|"]

for kind, name, levels in rows:
    lines.append("| %s | %s | %.1f | %.1f | %.1f |" % (kind, name, *levels))

quietest = min(rows, key=lambda r: r[2][0])
loudest = max(rows, key=lambda r: r[2][2])
lines += ["", "Gait levels %s; pitch %s; puddle splash %.1f dB." % (gait, data["gait_pitch"], data["puddle_db"]),
          "Quietest walk: %s %s at %.1f dB. Loudest run: %s %s at %.1f dB. Spread of walks: %.1f dB." % (quietest[1], "(%s)" % quietest[0], quietest[2][0], loudest[1], "(%s)" % loudest[0], loudest[2][2], max(r[2][0] for r in rows) - quietest[2][0])]
text = "\n".join(lines) + "\n"
print(text)

if "--md" in sys.argv and os.path.isdir("/mnt/project-files/sound"):
    open("/mnt/project-files/sound/STEP_LEVELS.md", "w").write(text)
    print("wrote /mnt/project-files/sound/STEP_LEVELS.md")
