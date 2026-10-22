#!/usr/bin/env python3
"""Swaps a supplied recording in for a generated placeholder sound.

Run: python3 assets/audio/swap_recording.py INPUT SLOT [options]      (needs numpy and ffmpeg)

  INPUT   any audio file ffmpeg reads (wav, mp3, m4a, ogg, flac)
  SLOT    a sound name from make_manifest.py, for example cook_sizzle, treewind_pine, place_chest,
          or step_dirt_left (footsteps are one file per foot: run it once for left and once for right)

What it does, so a recording only has to be dropped in:
  1. makes it mono, trims silence at both ends (or --start S / --end S seconds), warns when it is long
  2. one-shots get a 3 ms fade in and a 40 ms fade out; with --loop the tail is cross-faded into the head so
     the sound repeats without a click (use for the *_loop and wind, water, treewind, room, fire slots)
  3. sets the loudness: the active RMS of the slot's generated placeholder (so the level the game tuned stays right),
     or -18.5 dB when there is none; the peak never goes over -1 dB (use --db X to choose a level yourself)
  4. writes recorded/<group>/<slot>_N.ogg (the next free N; --replace first removes the slot's old recordings)
  5. adds a CREDITS.csv row when none covers it (--author --source --licence --attribution --url) and runs
     make_manifest.py, make_credits.py and validate_pack.py
--dry-run prints what would happen and writes nothing. The recording wins over the generated sound the next time the game runs.
"""
import argparse
import csv
import datetime
import fnmatch
import os
import re
import subprocess
import sys
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import loudness_report as lr  # noqa: E402
import make_manifest as mm  # noqa: E402

SR = 44100
DEFAULT_RMS_DB = -18.5
PEAK_LIMIT_DB = -1.0
SILENCE_DB = -50.0
PAD_S = 0.02


# EQ presets (ffmpeg filters) learned from Dave's brook recording (2026-10-20): the raw file read as "constant wind" because of
# low rumble and too little pebble sparkle. Applied automatically to the water slots; --preset none turns it off.
PRESETS = {
    "water": "highpass=f=260,equalizer=f=4500:t=q:w=1:g=5",
    "water_wide": "highpass=f=120,equalizer=f=4500:t=q:w=1:g=3",
}
SLOT_PRESET = {"water_brook": "water", "water_river": "water_wide", "water_fall": "water_wide"}
PRESET_RMS_DB = {"water": -23.8}      # active RMS aimed for when the placeholder level is not the right target


def decode(path, af=None):
    cmd = ["ffmpeg", "-nostdin", "-loglevel", "error", "-i", path] + (["-af", af] if af else []) + ["-ac", "1", "-ar", str(SR), "-f", "f32le", "-"]
    raw = subprocess.run(cmd,
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).astype(np.float64)


def find_slot(name):
    """(group folder, is_step) of a slot or footstep name, or None."""
    for slot, group, *_ in mm.SLOTS:
        if slot == name:
            return group, False

    match = re.match(r"^step_(\w+?)_(left|right)$", name)

    if match and match.group(1) in [s for s, _ in mm.STEPS]:
        return "", True

    return None


def trim(x, start, end):
    if start is not None or end is not None:
        a = int((start or 0.0) * SR)
        b = int(end * SR) if end is not None else len(x)
        return x[a:b]

    win = SR // 50
    n = len(x) // win

    if n == 0:
        return x

    db = 20 * np.log10(np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, axis=1)) + 1e-9)
    loud = np.nonzero(db > SILENCE_DB)[0]

    if len(loud) == 0:
        return x

    pad = int(PAD_S * SR)
    return x[max(loud[0] * win - pad, 0):min((loud[-1] + 1) * win + pad, len(x))]


def make_loop(x):
    fade = min(int(1.0 * SR), len(x) // 5)
    t = np.linspace(0.0, np.pi / 2, fade)
    body = x[:-fade].copy()
    body[:fade] = body[:fade] * np.sin(t) + x[-fade:] * np.cos(t)      # equal-power cross-fade of the tail into the head
    return body


def fade_edges(x):
    a, b = int(0.003 * SR), min(int(0.04 * SR), len(x) // 4)
    x = x.copy()
    x[:a] *= np.linspace(0, 1, a)
    x[-b:] *= np.linspace(1, 0, b)
    return x


def active_rms(x):
    """Active RMS in dB: the average over the 50 ms windows louder than -50 dB (as loudness_report.py)."""
    win = SR // 20
    n = len(x) // win

    if n == 0:
        return 20 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-9)

    blocks = np.sqrt(np.mean(x[:n * win].reshape(n, win) ** 2, axis=1))
    active = blocks[20 * np.log10(blocks + 1e-9) > SILENCE_DB]
    return 20 * np.log10(np.sqrt(np.mean(active ** 2)) + 1e-9) if len(active) else -99.0


def target_rms(slot, group):
    """Active RMS (dB) of the slot's generated placeholder, else the project default."""
    folder = os.path.join(HERE, group) if group else HERE
    values = []

    if os.path.isdir(folder):
        for f in sorted(os.listdir(folder)):
            if re.match(r"^%s(_\d+)?\.ogg$" % re.escape(slot), f):
                values.append(lr.levels(lr.decode(os.path.join(folder, f)))[0])

    return float(np.median(values)) if values else DEFAULT_RMS_DB


def band_db(x, lo, hi):
    """Level (dB, relative to full scale RMS) of the part of x between lo and hi Hz."""
    spec = np.abs(np.fft.rfft(x)) / max(len(x), 1)
    freq = np.fft.rfftfreq(len(x), 1.0 / SR)
    return 10 * np.log10(np.sum(spec[(freq >= lo) & (freq < hi)] ** 2) * 2 + 1e-12)


def write_ogg(path, x):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)

    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")

        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())

        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4", path], check=True)


def main():
    ap = argparse.ArgumentParser(description="Swap a supplied recording in for a generated sound")
    ap.add_argument("input")
    ap.add_argument("slot")
    ap.add_argument("--loop", action="store_true", help="make the sound loop without a click")
    ap.add_argument("--start", type=float, help="seconds to cut from the start (else silence is trimmed)")
    ap.add_argument("--end", type=float, help="seconds to cut the end at")
    ap.add_argument("--db", type=float, help="active RMS level to set, dB (default: the placeholder's)")
    ap.add_argument("--preset", choices=sorted(PRESETS) + ["none"], help="EQ preset (default: water slots get a water preset)")
    ap.add_argument("--replace", action="store_true", help="remove the slot's existing recordings first")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--no-check", action="store_true", help="skip make_manifest and validate_pack afterwards")
    ap.add_argument("--author", default="TODO")
    ap.add_argument("--source", default="TODO")
    ap.add_argument("--licence", default="TODO")
    ap.add_argument("--attribution", default="TODO")
    ap.add_argument("--url", default="")
    args = ap.parse_args()

    found = find_slot(args.slot)

    if found is None:
        sys.exit("Unknown slot %r: use a name from make_manifest.py (python3 assets/audio/make_manifest.py lists them in sound_manifest.json)" % args.slot)

    group, is_step = found
    preset = args.preset or SLOT_PRESET.get(args.slot, "none")
    raw = decode(args.input)
    x = decode(args.input, PRESETS[preset]) if preset != "none" else raw
    original = len(x) / SR
    x = trim(x, args.start, args.end)

    if len(x) < int(0.05 * SR):
        sys.exit("Nothing left after trimming (%.2f s of sound)" % (len(x) / SR))

    x = make_loop(x) if args.loop else fade_edges(x)
    seconds = len(x) / SR
    warnings = []

    if seconds > (60.0 if args.loop else 15.0):
        warnings.append("%.1f s is long for %s; consider --end" % (seconds, "a loop" if args.loop else "a one-shot"))

    rms_before = active_rms(x)
    target = args.db if args.db is not None else PRESET_RMS_DB.get(preset, target_rms(args.slot, group))
    gain = 10 ** ((target - rms_before) / 20)
    peak = np.max(np.abs(x)) * gain

    if peak > 10 ** (PEAK_LIMIT_DB / 20):
        gain *= 10 ** (PEAK_LIMIT_DB / 20) / peak
        warnings.append("peak limited to %.0f dB: this recording is much peakier than the placeholder, so it will sound quieter than the %.1f dB aimed for" % (PEAK_LIMIT_DB, target))

    x = x * gain
    folder = os.path.join(HERE, "recorded", group) if group else os.path.join(HERE, "recorded")
    existing = sorted(f for f in os.listdir(folder) if re.match(r"^%s(_\d+)?\.(ogg|wav)$" % re.escape(args.slot), f)) if os.path.isdir(folder) else []
    taken = [int(m.group(1)) for f in existing for m in [re.match(r"^.*_(\d+)\.", f)] if m]
    number = 0 if args.replace else (max(taken) + 1 if taken else 0)
    out_path = os.path.join(folder, "%s_%d.ogg" % (args.slot, number))
    if preset != "none":
        print("preset %s (%s)\n  before: active RMS %.1f dB, peak %.1f dB, low band (<260 Hz) %.1f dB, 4-5 kHz band %.1f dB" % (
            preset, PRESETS[preset], active_rms(raw), 20 * np.log10(np.max(np.abs(raw)) + 1e-9), band_db(raw, 20, 260), band_db(raw, 4000, 5000)))
    print("%s -> %s: %.1f s of %.1f s kept%s, level %.1f -> %.1f dB active RMS, peak %.1f dB" % (
        os.path.basename(args.input), os.path.relpath(out_path, HERE), seconds, original, ", looped" if args.loop else "",
        rms_before, active_rms(x), 20 * np.log10(np.max(np.abs(x)) + 1e-9)))

    for line in warnings:
        print("WARNING " + line)

    if args.dry_run:
        print("dry run: nothing written")
        return

    os.makedirs(folder, exist_ok=True)

    if args.replace:
        for f in existing:
            os.remove(os.path.join(folder, f))

    write_ogg(out_path, x)
    pattern = ("%s/%s*" % (group, args.slot)) if group else ("%s*" % args.slot)
    credits_path = os.path.join(HERE, "CREDITS.csv")
    if not _covered(group, args.slot, credits_path):
        with open(credits_path, "a", newline="", encoding="utf-8") as f:
            csv.writer(f, lineterminator="\n").writerow([pattern, args.slot, args.author, args.source, args.licence, args.attribution, args.url, datetime.date.today().isoformat()])

        print("Added a CREDITS.csv row for %s (source and licence %s)" % (pattern, "TODO: fill in before release" if "TODO" in (args.source, args.licence) else "set"))

    if not args.no_check:
        for script in ("make_manifest.py", "make_credits.py", "validate_pack.py"):
            run = subprocess.run([sys.executable, os.path.join(HERE, script)], capture_output=True, text=True)
            tail = [l for l in run.stdout.splitlines() if l.startswith(("Manifest", "Wrote", "0 errors")) or "errors" in l or l.startswith("ERROR")]
            print("%s: %s" % (script, "; ".join(tail[-3:]) if tail else "ok"))


def _covered(group, slot, credits_path):
    rel = ("%s/%s_0.ogg" % (group, slot)) if group else ("%s_0.ogg" % slot)

    with open(credits_path, newline="", encoding="utf-8") as f:
        return any(fnmatch.fnmatch(rel, row["pattern"]) for row in csv.DictReader(f))


if __name__ == "__main__":
    main()
