"""Checks a recorded animal clip for background noise and clarity, then trims and converts it to ogg.

Usage: python3 tools/clip_check.py in.mp3 [--out assets/audio/recorded/creatures/wolf_howl_0.ogg]
Prints peak, clipping, noise floor, signal-to-noise (loud 95th percentile frame vs quiet 10th percentile frame), duration of the
call, and PASS or FAIL with reasons. With --out and a PASS it writes the trimmed (start and end silence removed, 0.05 s fades) mono ogg.
"""
import argparse
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 44100
MIN_SNR_DB = 25.0
MAX_FLOOR_DB = -50.0
MAX_CLIP = 0.001


def load(path):
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "c.wav")
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", str(SR), wav], check=True)
        with wave.open(wav) as w:
            return np.frombuffer(w.readframes(w.getnframes()), np.int16).astype(np.float64) / 32768.0


def db(v):
    return 20.0 * np.log10(max(v, 1e-9))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("path")
    ap.add_argument("--out")
    a = ap.parse_args()
    x = load(a.path)
    hop = int(0.05 * SR)
    frames = np.array([np.sqrt(np.mean(x[i:i + hop] ** 2)) for i in range(0, len(x) - hop, hop)])
    floor, loud = np.percentile(frames, 10), np.percentile(frames, 95)
    snr = db(loud) - db(floor)
    clip = float(np.mean(np.abs(x) > 0.99))
    active = frames > floor * 10 ** (12 / 20)
    idx = np.where(active)[0]
    print("file %s: %.1f s, peak %.1f dB, clipped %.3f %%, noise floor %.1f dB, call level %.1f dB, SNR %.1f dB" % (
        os.path.basename(a.path), len(x) / SR, db(np.max(np.abs(x))), clip * 100, db(floor), db(loud), snr))
    why = []
    if snr < MIN_SNR_DB:
        why.append("noisy: SNR %.1f dB under %.0f" % (snr, MIN_SNR_DB))
    if db(floor) > MAX_FLOOR_DB:
        why.append("noise floor %.1f dB above %.0f" % (db(floor), MAX_FLOOR_DB))
    if clip > MAX_CLIP:
        why.append("clipping")
    if len(idx) == 0 or len(idx) * 0.05 < 1.5:
        why.append("call shorter than 1.5 s of clear sound")
    if why:
        print("FAIL: " + "; ".join(why))
        return 1
    print("PASS")
    if a.out:
        s, e = max(idx[0] * hop - hop * 4, 0), min((idx[-1] + 1) * hop + hop * 8, len(x))
        y = x[s:e]
        f = int(0.05 * SR)
        y[:f] *= np.linspace(0, 1, f)
        y[-f:] *= np.linspace(1, 0, f)
        y *= 0.8 / (np.max(np.abs(y)) + 1e-9)
        with tempfile.TemporaryDirectory() as tmp:
            wav = os.path.join(tmp, "o.wav")
            with wave.open(wav, "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(SR)
                w.writeframes((y * 32767).astype(np.int16).tobytes())
            os.makedirs(os.path.dirname(a.out), exist_ok=True)
            subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", a.out], check=True)
        print("wrote %s (%.1f s)" % (a.out, len(y) / SR))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
