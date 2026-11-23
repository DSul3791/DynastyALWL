"""Heard levels against each other: python3 assets/audio/level_pass.py [--md]

How loud each everyday sound reaches the ears in a reference scene, and whether an approaching animal still stands out over the beds
(the coordinator, 23 Nov 2026: "no everyday sound drowns an approaching animal"). For each sound it adds:
  the clip's active RMS (measured from the files, loudness_report.py levels; recorded files win over generated),
  the level the game plays it at (volume_db, read from the code and data named in SOURCES), and
  the distance gain of Godot's inverse-distance falloff, 20 log10(unit_size / distance), with the sum capped at the voice's max_db.
Beds and own sounds are flat (no distance). All buses are at their default 0 dB (Esc > Settings sliders at full).
Not counted: the distance low-pass (makes far sounds duller, not quieter in this sum), cover muffling, the rear cue (-1.5 dB),
the voice budget. So this compares levels, it is not a mix: judge the final by ear.
The check: an approaching animal's step at STEP_AT_M and its warning call at CALL_AT_M must not sit more than MASK_DB under
any everyday bed or own walking step. --md writes assets/audio/LEVELS.md.
"""
import json
import math
import os
import re
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import loudness_report as L  # noqa: E402

STEP_AT_M = 20.0          # an animal walking up is first worth hearing about here
CALL_AT_M = 40.0          # a warning growl or snort this far off
MASK_DB = 3.0             # a short transient a few dB under a steady bed is still picked out; more than this is drowned
SOURCES = {
    "steps": "data/sound/step_levels.json (surface_db, gait_db)",
    "animal steps": "src/client/slot_sounds.gd play: volume 0 dB at strength 1, unit 6 m, max_db 3 (Godot default)",
    "calls": "src/client/creature_sounds.gd KINDS db and unit; max_db = db + NEAR_RISE_DB (max NEAR_MAX_DB)",
    "blows": "src/client/hit_sounds.gd BASE_DB, unit 8 m",
    "wind": "src/client/sound_stage.gd wind_low: WIND_LIFT_DB + 0.8 x (0.0035 + 0.006 x strength)",
    "rain": "src/client/weather_sounds.gd LOOP_DB",
    "insects": "src/client/insect_bed.gd BED_DB at full level",
    "beds": "data/sound/batch2_slots.json weather_bed and time_bed slots that are on (status filled), src/client/ambience_slots.gd BED_TRIM_DB at full level",
}


def read(path):
    return open(os.path.join(ROOT, path)).read()


def const_dict(text, name):
    m = re.search(r"const %s := \{(.*?)\}\n" % name, text, re.S)
    return {k: float(v) for k, v in re.findall(r'"(\w+)": (-?[\d.]+)', m.group(1))} if m else {}


def const_num(text, name):
    m = re.search(r"const %s := (-?[\d.]+)" % name, text)
    return float(m.group(1))


def rms_table():
    out = {}

    for (group, name), kinds in sorted(L.collect().items()):
        kind = "recorded" if "recorded" in kinds else "generated"
        out.setdefault(name, float(np.mean([L.levels(L.decode(p))[0] for p in kinds[kind]])))

    return out


def heard(rms, volume_db, unit=None, distance=None, max_db=3.0):
    gain = 0.0 if unit is None else 20.0 * math.log10(unit / max(distance, 0.1))
    return rms + min(volume_db + gain, max_db)


def rows():
    rms = rms_table()
    steps = json.load(open(os.path.join(ROOT, "data/sound/step_levels.json")))
    creature = read("src/client/creature_sounds.gd")
    kinds = {k: (float(db), float(unit)) for k, db, unit in re.findall(r'"(\w+)": \{"calls".*?"db": (-?[\d.]+).*?"unit": ([\d.]+)', creature)}
    rise, near_max = const_num(creature, "NEAR_RISE_DB"), const_num(creature, "NEAR_MAX_DB")
    hits_db = const_num(read("src/client/hit_sounds.gd"), "BASE_DB")
    lift = const_num(read("src/client/sound_stage.gd"), "WIND_LIFT_DB")
    loops = const_dict(read("src/client/weather_sounds.gd"), "LOOP_DB")
    insect_db = const_num(read("src/client/insect_bed.gd"), "BED_DB")
    trims = const_dict(read("src/client/ambience_slots.gd"), "BED_TRIM_DB")
    walk = float(steps["gait_db"][0])
    run = float(steps["gait_db"][2])
    out = []

    def own_step(surface, gait_db, label):
        out.append(("everyday", label, heard(rms["step_%s_left" % surface], float(steps["surface_db"][surface]) + gait_db)))

    own_step("grass", walk, "own step, walking on grass")
    own_step("leaves", walk, "own step, walking on dry leaves")
    own_step("gravel", walk, "own step, walking on gravel")
    own_step("leaves", run, "own step, running on dry leaves (loud on purpose)")
    out.append(("everyday", "wind, a light breeze (strength 0.3)", heard(rms["wind_low"], lift + 20.0 * math.log10(0.8 * (0.0035 + 0.006 * 0.3)))))
    out.append(("everyday", "wind, strong (strength 1)", heard(rms["wind_low"], lift + 20.0 * math.log10(0.8 * (0.0035 + 0.006 * 1.0)))))
    # Rain as src/shared/rain_audio.gd layers it in the open: a drizzle (rain 0.25) plays rain_light at 0.5, steady rain (0.5) at 1.
    out.append(("everyday", "drizzle in the open (rain 0.25)", heard(rms["rain_light"], loops["rain_light"] + 20.0 * math.log10(0.5))))
    out.append(("weather", "steady rain in the open (rain 0.5; allowed to drown things)", heard(rms["rain_light"], loops["rain_light"])))
    out.append(("weather", "heavy rain (allowed to drown things)", heard(rms["rain_heavy"], loops["rain_heavy"])))
    out.append(("everyday", "summer insects, full", heard(rms["insect_bed"], insect_db)))
    beds = json.load(open(os.path.join(ROOT, "data/sound/batch2_slots.json")))
    beds = beds.get("slots", beds)

    for slot in sorted(beds):
        entry = beds[slot]

        if entry.get("layer") in ("weather_bed", "time_bed") and entry.get("status") == "filled" and not entry.get("test_only") and slot in rms:
            where = "/".join(entry.get("tags", {}).get("biome", [])) or "any"
            out.append(("everyday", "%s bed (%s, %s), full" % (slot, where, entry.get("tags", {}).get("time", "")), heard(rms[slot], trims.get(slot, 0.0))))

    for animal, clip in (("wolf", "wolf_step"), ("deer", "deer_step"), ("moose", "moose_step"), ("fox", "fox_step")):
        out.append(("animal step", "%s step at %.0f m" % (animal, STEP_AT_M), heard(rms[clip], 0.0, 6.0, STEP_AT_M)))

    for animal, clip in (("wolf", "wolf_growl"), ("bear", "bear_growl"), ("deer", "deer_snort"), ("moose", "moose_snort")):
        db, unit = kinds[animal]
        out.append(("animal call", "%s warning (%s) at %.0f m" % (animal, clip, CALL_AT_M), heard(rms[clip], db, unit, CALL_AT_M, min(db + rise, near_max))))

    out.append(("work", "another player's axe on wood at 10 m", heard(rms["hit_axe_wood"], hits_db, 8.0, 10.0)))
    out.append(("work", "another player's axe on wood at 30 m", heard(rms["hit_axe_wood"], hits_db, 8.0, 30.0)))
    return out


def main():
    table = rows()
    everyday = [r for r in table if r[0] == "everyday"]
    loudest = max(everyday, key=lambda r: r[2])
    lines = ["# Heard levels (make with `python3 assets/audio/level_pass.py --md`)", "",
             "dB at the ears in a reference scene: clip RMS + play level + distance falloff (see the script's notes). Buses at 0 dB.", "",
             "| kind | sound | heard dB |", "|---|---|---|"]
    lines += ["| %s | %s | %.1f |" % r for r in sorted(table, key=lambda r: -r[2])]
    lines += ["", "Loudest everyday sound: %s, %.1f dB." % (loudest[1], loudest[2]), ""]
    bad = []

    for kind, label, level in table:
        if kind in ("animal step", "animal call") and level < loudest[2] - MASK_DB:
            bad.append("%s %.1f dB is %.1f dB under %s" % (label, level, loudest[2] - level, loudest[1]))

    lines += ["Drowned (more than %.0f dB under the loudest everyday sound): %s" % (MASK_DB, "; ".join(bad) if bad else "none"), ""]
    lines += ["Sources: " + "; ".join("%s: %s" % kv for kv in SOURCES.items())]
    text = "\n".join(lines) + "\n"

    if "--md" in sys.argv:
        open(os.path.join(HERE, "LEVELS.md"), "w").write(text)
        print("Wrote assets/audio/LEVELS.md")
    else:
        print(text)

    if "--check" in sys.argv:
        sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
