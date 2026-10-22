#!/usr/bin/env python3
"""Plays every sound slot once, offline, and flags clipping, silence, a loop seam click, an edge click and a wrong loudness.

Run: python3 tools/slot_audit.py [--md] [--strict]      also runs as `python3 tools/sound_check.py --only slots`

"Plays" = decodes the file the game would load for each slot (a recording in assets/audio/recorded/ wins over the generated
one, as SoundStage._find does; every `_N` variant is checked) and measures it. Failures (exit 1):
  clipped    3 or more samples in a row at full scale (>= 0.995): a flat-topped wave, audible crackle
  silent     active RMS below -45 dB, or under 50 ms long
  seam       a loop whose end does not meet its start (a jump over twice its biggest ordinary sample step, or a level step over 6 dB across the seam)
  loud       active RMS more than 20 dB from the median of its group (folder); soft groups such as breaths sit lower by design, so only a gross outlier fails
Warnings: peak above -0.3 dB, a one-shot that starts or ends off zero (click), DC offset over 0.02, loudness 8 to 20 dB off
its group, a one-shot over 15 s or a loop over 60 s. With --md the table is written to /mnt/project-files/sound/SLOT_AUDIT.md.
"""
import os
import re
import statistics
import subprocess
import sys

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AUDIO = os.path.join(ROOT, "assets", "audio")
sys.path.insert(0, AUDIO)
import make_manifest as mm  # noqa: E402

SR = 22050
SKIP = ("wing_grain",)          # raw grains the take-off bursts are built from, never played alone
WARN_DB, FAIL_DB = 8.0, 20.0


def decode(path):
    raw = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def active_rms(x):
    win = SR // 20
    n = len(x) // win

    if n == 0:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2) if len(x) else 0.0) + 1e-9)

    blocks = np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, axis=1))
    active = blocks[20 * np.log10(blocks + 1e-9) > -50.0]
    return 20 * np.log10(np.sqrt(np.mean(active ** 2)) + 1e-9) if len(active) else -99.0


def collect():
    """{slot: (source, [paths])} with the recorded files winning, and the set of slots that are loops."""
    found = {}

    for base, source in ((AUDIO, "generated"), (os.path.join(AUDIO, "recorded"), "recorded")):
        for folder, dirs, files in os.walk(base):
            if source == "generated" and os.path.relpath(folder, AUDIO).split(os.sep)[0] == "recorded":
                continue

            for f in sorted(files):
                m = re.match(r"^(.+?)(?:_\d+)?\.ogg$", f)

                if m and not m.group(1).startswith(SKIP):
                    slot = m.group(1)
                    group = os.path.relpath(folder, base)
                    found.setdefault((slot, group), {}).setdefault(source, []).append(os.path.join(folder, f))

    loops = {slot for slot, _g, desc, supply, _p in mm.SLOTS if "loop" in (supply + " " + desc).lower().replace("no loop", "").replace("not a loop", "")}
    chosen = {}

    for key, by_source in found.items():
        source = "recorded" if "recorded" in by_source else "generated"
        chosen[key] = (source, by_source[source])

    return chosen, loops


def judge(slot, is_loop, x):
    fails, warns = [], []
    seconds = len(x) / SR
    rms = active_rms(x)
    peak = 20 * np.log10(np.max(np.abs(x)) + 1e-9) if len(x) else -99.0

    if seconds < 0.05 or rms < -45.0:
        fails.append("silent (%.2f s, %.0f dB)" % (seconds, rms))
        return fails, warns, rms, peak

    flat, run = 0, 0

    for hit in np.abs(x) >= 0.995:
        run = run + 1 if hit else 0
        flat = max(flat, run)

    if flat >= 3:
        fails.append("clipped (%d samples in a row at full scale)" % flat)
    elif peak > -0.3:
        warns.append("peak %.1f dB" % peak)

    if abs(float(np.mean(x))) > 0.02:
        warns.append("DC offset %.3f" % np.mean(x))

    ceiling = float(np.max(np.abs(x)))

    if is_loop:
        jump = abs(float(x[0]) - float(x[-1]))
        edge = SR // 10
        step = abs(20 * np.log10(np.sqrt(np.mean(x[-edge:] ** 2)) + 1e-9) - 20 * np.log10(np.sqrt(np.mean(x[:edge] ** 2)) + 1e-9))

        usual = float(np.percentile(np.abs(np.diff(x)), 99.5))        # the biggest ordinary sample-to-sample step

        if jump > 2.0 * usual and jump > 0.1 * ceiling:
            fails.append("seam click (jump %.2f, biggest ordinary step %.2f)" % (jump, usual))
        elif step > 6.0:
            fails.append("seam level step %.1f dB" % step)

        if seconds > 60.0:
            warns.append("loop is %.0f s" % seconds)
    else:
        if abs(float(x[0])) > 0.05 * ceiling or abs(float(x[-1])) > 0.05 * ceiling:
            warns.append("starts or ends off zero (click)")

        if seconds > 15.0:
            warns.append("one-shot is %.0f s" % seconds)

    return fails, warns, rms, peak


def main():
    chosen, loops = collect()
    rows = []

    for (slot, group), (source, paths) in sorted(chosen.items()):
        for path in paths:
            x = decode(path)
            fails, warns, rms, peak = judge(slot, slot in loops, x)
            rows.append({"slot": slot, "group": group, "source": source, "file": os.path.relpath(path, AUDIO), "rms": rms, "peak": peak,
                         "fails": fails, "warns": warns, "loop": slot in loops})

    medians = {}

    for g in {r["group"] for r in rows}:
        values = [r["rms"] for r in rows if r["group"] == g and r["rms"] > -45]
        medians[g] = statistics.median(values) if values else 0.0

    for r in rows:
        off = r["rms"] - medians[r["group"]]
        r["off"] = off

        if r["rms"] > -45:
            if abs(off) > FAIL_DB:
                r["fails"].append("loud: %+.1f dB from its group" % off)
            elif abs(off) > WARN_DB:
                r["warns"].append("%+.1f dB from its group" % off)

    failed = [r for r in rows if r["fails"]]
    warned = [r for r in rows if r["warns"] and not r["fails"]]

    for r in failed + (warned if "--strict" in sys.argv else []):
        print("%s  %-44s %s" % ("FAIL" if r["fails"] else "warn", r["file"], "; ".join(r["fails"] + r["warns"])))

    print("slot audit: %d files, %d loops, %d failed, %d warnings" % (len(rows), sum(1 for r in rows if r["loop"]), len(failed), len(warned)))

    if "--md" in sys.argv:
        out = ["# Slot audit (tools/slot_audit.py)", "",
               "Every sound the game would load, checked for clipping, silence, loop seams and loudness against its group. %d files, %d failed, %d warnings." % (len(rows), len(failed), len(warned)), "",
               "| file | source | loop | RMS dB | peak dB | vs group | problems |", "|---|---|---|---|---|---|---|"]

        for r in sorted(rows, key=lambda r: (not r["fails"], not r["warns"], r["file"])):
            if r["fails"] or r["warns"]:
                out.append("| %s | %s | %s | %.1f | %.1f | %+.1f | %s |" % (r["file"], r["source"], "yes" if r["loop"] else "", r["rms"], r["peak"], r["off"], "; ".join(r["fails"] + r["warns"])))

        with open("/mnt/project-files/sound/SLOT_AUDIT.md", "w") as f:
            f.write("\n".join(out) + "\n")

    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
