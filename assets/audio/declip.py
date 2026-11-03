"""Brings clipping clips back under full scale (loudness_report.py --check FAIL "clips").

Run: python3 assets/audio/declip.py weather/rain_roof treewind/treewind_dry ...   (needs numpy and ffmpeg)
Each name is a path under assets/audio/ without .ogg, or a slot: name_0.ogg, name_1.ogg ... are all fixed. The clip is decoded, scaled so its peak sits at
TARGET_DB, and written back as Ogg Vorbis q4 (bitexact). A clip already at or under the target is left alone.
Vorbis overshoots its input a little when it decodes, so the target leaves a 1 dB margin.
Generators that wrote these files should be rerun with a lower peak before they overwrite the fix.
"""
import os
import subprocess
import sys
import tempfile

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from loudness_report import decode as report_decode  # noqa: E402

ROOT = os.path.dirname(os.path.abspath(__file__))
TARGET_DB = -1.0


def decode(path):
    out = subprocess.run(["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path, "-f", "f32le", "-"], capture_output=True, check=True).stdout
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries", "stream=channels,sample_rate", "-of", "csv=p=0", path],
                           capture_output=True, text=True, check=True).stdout.strip().split(",")
    return np.frombuffer(out, np.float32), int(probe[0]), int(probe[1])


def measured_peak_db(path):
    """The higher of the file's own peak and loudness_report.py's (mono at 22050 Hz, which can read a little higher)."""
    x = decode(path)[0]
    report = report_decode(path)
    peak = max(float(np.max(np.abs(x))) if x.size else 0.0, float(np.max(np.abs(report))) if report.size else 0.0)
    return 20 * np.log10(peak + 1e-12)


def fix(name):
    path = os.path.join(ROOT, name + ".ogg")
    peak_db = measured_peak_db(path)

    if peak_db <= TARGET_DB:
        print("ok     %s peak %.1f dB" % (name, peak_db))
        return

    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "x.ogg")
        gain_db = TARGET_DB - peak_db

        for _ in range(6):   # the encoder overshoots by a different amount each time: from the original, a little more each try
            subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", path, "-af", "volume=%.2fdB" % gain_db, "-fflags", "+bitexact",
                            "-flags:a", "+bitexact", "-c:a", "libvorbis", "-q:a", "4", out], check=True)
            after = measured_peak_db(out)

            if after <= TARGET_DB + 0.05:
                break

            gain_db -= after - TARGET_DB + 0.1

        os.replace(out, path)

    print("fixed  %s peak %.1f -> %.1f dB (%.1f dB)" % (name, peak_db, after, gain_db))


def files_of(name):
    if os.path.exists(os.path.join(ROOT, name + ".ogg")):
        return [name]

    folder, base = os.path.split(name)
    found = sorted(f[:-4] for f in os.listdir(os.path.join(ROOT, folder)) if f.startswith(base + "_") and f[len(base) + 1:-4].isdigit() and f.endswith(".ogg"))
    return [os.path.join(folder, f) for f in found]


if __name__ == "__main__":
    for arg in sys.argv[1:]:
        names = files_of(arg)

        if not names:
            print("none   %s" % arg)

        for one in names:
            fix(one)
