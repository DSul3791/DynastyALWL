"""Loudness table for every sound file: python3 assets/audio/loudness_report.py [--md]

Decodes each .ogg under assets/audio (recorded/ and generated) with ffmpeg and prints, per group,
the active RMS (average over the loud part, windows above -50 dB) and the peak, both in dBFS, plus
the file's loudness spread inside its group. For footsteps it also adds the game's per-surface level
(SURFACE_DB in src/client/sound_stage.gd) to give the level you actually hear before the gait,
and lists surfaces that sit more than STEP_SPREAD_DB from the median. With --md the table is
written as assets/audio/LOUDNESS.md.
"""
import os
import re
import statistics
import subprocess
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
SR = 22050
STEP_SPREAD_DB = 3.0
GROUP_SPREAD_DB = 8.0


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR),
                          "-f", "f32le", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32)


def levels(x):
    if len(x) == 0:
        return -99.0, -99.0
    win = SR // 20
    n = len(x) // win
    peak = 20 * np.log10(np.max(np.abs(x)) + 1e-9)

    if n == 0:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9), peak

    blocks = np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, axis=1))
    db = 20 * np.log10(blocks + 1e-9)
    active = blocks[db > -50]

    if len(active) == 0:
        return -99.0, peak

    return 20 * np.log10(np.sqrt(np.mean(active ** 2)) + 1e-9), peak


def surface_db():
    text = open(os.path.join(ROOT, "src/client/sound_stage.gd")).read()
    block = text[text.index("const SURFACE_DB := {"):]
    block = block[:block.index("}")]
    return {k: float(v) for k, v in re.findall(r'"(\w+)":\s*(-?[\d.]+)', block)}


def event_db():
    """Nature call levels at the source (EVENTS in src/client/ambient_life.gd)."""
    text = open(os.path.join(ROOT, "src/client/ambient_life.gd")).read()
    return {n: float(d) for n, d in re.findall(r'\{"name": "(\w+)".*?"db": (-?[\d.]+)', text)}


def collect():
    found = {}

    for base, kind in ((os.path.join(HERE, "recorded"), "recorded"), (HERE, "generated")):
        for folder, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d not in ("recorded", "__pycache__")] if kind == "generated" else dirs

            for f in files:
                if not f.endswith(".ogg"):
                    continue

                rel = os.path.relpath(folder, HERE)
                group = rel.replace("recorded" + os.sep, "").replace("recorded", "") or "."
                name = re.sub(r"_\d+$", "", f[:-4])
                found.setdefault((group or ".", name), {}).setdefault(kind, []).append(os.path.join(folder, f))

    return found


def main():
    rows = []

    for (group, name), kinds in sorted(collect().items()):
        kind = "recorded" if "recorded" in kinds else "generated"
        stats = [levels(decode(p)) for p in kinds[kind]]
        rows.append((group, name, kind, len(stats), float(np.mean([s[0] for s in stats])), float(max(s[1] for s in stats))))

    out = ["# Loudness table (make with `python3 assets/audio/loudness_report.py --md`)", "",
           "Active RMS and peak in dBFS per slot (recorded files win over generated). Steps add the game's surface level.", ""]
    by_group = {}

    for row in rows:
        by_group.setdefault(row[0], []).append(row)

    for group, items in by_group.items():
        median = statistics.median(r[4] for r in items)
        out.append("## %s (median %.1f dB)" % (group, median))
        out.append("")
        out.append("| slot | source | files | RMS dB | peak dB | vs median |")
        out.append("|---|---|---|---|---|---|")

        for g, name, kind, count, rms, peak in items:
            flag = " **outlier**" if abs(rms - median) > GROUP_SPREAD_DB else ""
            out.append("| %s | %s | %d | %.1f | %.1f | %+.1f%s |" % (name, kind, count, rms, peak, rms - median, flag))

        out.append("")

    steps = {}
    surfaces = surface_db()

    for g, name, kind, count, rms, peak in rows:
        m = re.match(r"step_(\w+?)_(left|right)$", name)

        if m and m.group(1) in surfaces:
            steps.setdefault(m.group(1), []).append(rms)

    out.append("## Footsteps as heard (file RMS + SURFACE_DB, before gait)")
    out.append("")
    out.append("| surface | file RMS | SURFACE_DB | heard |")
    out.append("|---|---|---|---|")
    heard = {}

    for surface, values in sorted(steps.items()):
        rms = float(np.mean(values))
        heard[surface] = rms + surfaces[surface]
        out.append("| %s | %.1f | %+.1f | %.1f |" % (surface, rms, surfaces[surface], heard[surface]))

    if heard:
        median = statistics.median(heard.values())
        out.append("")
        out.append("Median %.1f dB. Surfaces more than %.0f dB off (a deliberate hierarchy: soft grass, crunchy leaves; judge by ear): %s" % (
            median, STEP_SPREAD_DB, ", ".join("%s (%+.1f)" % (k, v - median)
                                              for k, v in sorted(heard.items()) if abs(v - median) > STEP_SPREAD_DB) or "none"))

    calls = event_db()
    out.append("")
    out.append("## Nature calls as played (file RMS + the call's level at the source, before distance)")
    out.append("")
    out.append("| call | file RMS | EVENTS db | played |")
    out.append("|---|---|---|---|")
    played = {}

    for g, name, kind, count, rms, peak in rows:
        if g == "ambient" and name in calls:
            played[name] = rms + calls[name]
            out.append("| %s | %.1f | %+.1f | %.1f |" % (name, rms, calls[name], played[name]))

    if played:
        median = statistics.median(played.values())
        out.append("")
        out.append("Median %.1f dB. More than %.0f dB off: %s" % (
            median, GROUP_SPREAD_DB / 2, ", ".join("%s (%+.1f)" % (k, v - median) for k, v in sorted(played.items()) if abs(v - median) > GROUP_SPREAD_DB / 2) or "none"))

    text = "\n".join(out) + "\n"

    if "--md" in sys.argv:
        open(os.path.join(HERE, "LOUDNESS.md"), "w").write(text)
        print("Wrote assets/audio/LOUDNESS.md (%d slots)" % len(rows))
    else:
        print(text)


if __name__ == "__main__":
    main()
