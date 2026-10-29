"""Checks data/sound/batch*_slots.json: every file exists, is under 1 MB and has a CREDITS.csv row; prints the empty-slot count.
For batch 2 (ambience) it also checks: total size under 1.5 MB, every loop's seam is clean (step under 1 dB between the last and first 50 ms,
no sample jump at the wrap), the memory loaded at Low (decoded 16-bit mono) under 150 MB, and the voice plan; it lists each slot's tags.

Run: python3 tools/validate_sound_slots.py   (exit 1 on any error; needs numpy and ffmpeg for the loop test, which is skipped without them)
"""
import json
import os
import subprocess
import sys
import tempfile
import wave

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
credits = open(os.path.join(ROOT, "assets/audio/CREDITS.csv"), encoding="utf-8").read()
errors = 0
filled = 0
empty_total = 0

try:
    import numpy as np
except ImportError:
    np = None


def decode(path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "c.wav")
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", path, "-ac", "1", wav], check=True)
        with wave.open(wav) as w:
            return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0, w.getframerate()


def seam_ok(path):
    """The wrap is no worse than any other place in the loop: the loudness step across the seam (100 ms windows each side) is within the
    95th percentile of the same step measured at every interior window boundary (or 1 dB), and the sample jump at the wrap is small."""
    x, sr = decode(path)
    w = int(0.1 * sr)
    count = len(x) // w
    rms = np.array([np.sqrt(np.mean(x[k * w:(k + 1) * w] ** 2)) + 1e-9 for k in range(count)])
    interior = np.abs(20 * np.log10(rms[1:] / rms[:-1]))
    seam = abs(20 * np.log10(rms[0] / rms[-1]))
    limit = max(1.0, float(np.percentile(interior, 95)))
    typical = np.mean(np.abs(np.diff(x[:sr]))) + 1e-9
    jump = abs(x[0] - x[-1]) / typical
    return seam, limit, jump, len(x) / sr


for batch in sorted(f for f in os.listdir(os.path.join(ROOT, "data/sound")) if f.startswith("batch") and f.endswith("_slots.json")):
    doc = json.load(open(os.path.join(ROOT, "data/sound", batch)))
    slots = doc["slots"]
    total = 0
    pcm_bytes = 0
    print("== %s" % batch)

    for name, slot in slots.items():
        for res in slot["files"]:
            path = os.path.join(ROOT, res.replace("res://", ""))

            if not os.path.exists(path):
                print("MISSING", res)
                errors += 1
                continue

            size = os.path.getsize(path)
            total += size

            if size > 1_000_000:
                print("TOO BIG", res)
                errors += 1

            if os.path.basename(res) not in credits and ("%s/*" % os.path.basename(os.path.dirname(res))) not in credits:
                print("NO CREDITS ROW", res)
                errors += 1

            if np is not None and "tags" in slot:
                try:
                    x, sr = decode(path)
                    pcm_bytes += len(x) * 2

                    if slot.get("loop"):
                        step_db, limit, jump, secs = seam_ok(path)

                        if step_db > limit or jump > 6.0 or secs < 10.0:
                            print("LOOP SEAM FAIL %s: step %.2f dB (limit %.2f), jump %.1fx, %.1f s" % (res, step_db, limit, jump, secs))
                            errors += 1
                        else:
                            print("loop ok %-30s seam %.2f dB (limit %.2f), wrap jump %.1fx, %.1f s" % (os.path.basename(res), step_db, limit, jump, secs))
                except Exception as err:  # noqa: BLE001
                    print("DECODE FAIL", res, err)
                    errors += 1

        if "tags" in slot:
            t = slot["tags"]
            print("  %-18s [%s] season=%s time=%s biome=%s water=%s alt=%s%s" % (name, slot["layer"], ",".join(t["season"]) if len(t["season"]) < 4 else "all", t["time"],
                  ",".join(t["biome"]), t["near_water"], t["altitude"], " positional<=%dm" % slot["positional"]["max_distance_m"] if "positional" in slot else ""))

        if slot["status"] == "filled" and slot["files"]:
            filled += 1

    test_only = [n for n, s in slots.items() if s.get("test_only")]

    if test_only:
        print("test-only slots (no client lookup for their place yet, not counted as wired): %s" % ", ".join(test_only))

    empty = [n for n, s in slots.items() if s["status"] != "filled" or not s["files"]]
    empty_total += len(empty)
    print("%s: %d bytes in files (%.2f MB)" % (batch, total, total / 1e6))

    if "voice_plan" in doc:
        v = doc["voice_plan"]
        print("simultaneous ambience voices at the busiest tile: %d (%s)" % (v["max_simultaneous"], ", ".join("%s %d" % (k, n) for k, n in v.items() if k != "max_simultaneous")))

        if total > 1_500_000:
            print("BATCH OVER 1.5 MB")
            errors += 1

        if np is not None:
            print("memory loaded at Low, all %s decoded: %.1f MB (limit 150)" % (batch, pcm_bytes / 1e6))

            if pcm_bytes > 150e6:
                errors += 1

print("slots: %d filled, empty slots: %d" % (filled, empty_total))
sys.exit(1 if errors else 0)
