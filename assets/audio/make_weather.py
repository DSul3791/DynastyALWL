"""Makes placeholder weather sounds for src/client/weather_sounds.gd.

Run: python3 assets/audio/make_weather.py   (needs numpy and ffmpeg)
Writes assets/audio/weather/<name>.ogg: seamless loops rain_light, rain_heavy, rain_leaves
(rain pattering on foliage), rain_water (rain on a pond or river), rain_stone, rain_mud, rain_litter and
rain_snow (rain on that ground under the player), wind_storm (a howling
gale), and three one-shot thunder_N rolls. Recordings go in assets/audio/recorded/weather/
under the same names (thunder_N and the loops may have _N variants); the game prefers them.
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sounds import soft_limit, SR, add, band, env, freqs, highpass, lowpass, noise  # noqa: E402
from make_water import normalize, shaped_noise, slow_swell  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weather")


def write_ogg(name, x):
    os.makedirs(OUT, exist_ok=True)
    data = (np.clip(soft_limit(x), -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", wav, "-fflags", "+bitexact", "-flags:a", "+bitexact", "-c:a", "libvorbis",
                        "-q:a", "4", os.path.join(OUT, name + ".ogg")], check=True)


def drops(rng, n, rate, center, octaves, decay, gain=1.0):
    """Tiny noise ticks (rain drops hitting something), wrapped around the loop end."""
    out = np.zeros(n)
    m = int(decay * 6 * SR)
    t = np.arange(m) / SR

    for _ in range(int(rate * n / SR)):
        tick = shaped_noise(rng, m, lambda f: band(f, center * rng.uniform(0.7, 1.4), octaves)) * np.exp(-t / decay)
        idx = (rng.integers(0, n) + np.arange(m)) % n
        out[idx] += tick * rng.pareto(4.0) * gain

    return out


# Owner 2026-10-20: the rain had a "sheeting" sound like brushing a horse. That was the steady broadband
# hiss bed under the drops (4.5 to 5.5 kHz noise). The beds are gone: rain is now only drops (many fine
# ticks and some larger plops, random in time and level), plus a low soft body in heavy rain.

def rain_light(rng, n):
    fine = drops(rng, n, 420, 4200, 1.0, 0.003)
    fine /= np.std(fine) + 1e-9
    plops = drops(rng, n, 60, 2200, 0.8, 0.009)
    plops /= np.std(plops) + 1e-9
    return normalize((0.8 * fine + 0.5 * plops) * slow_swell(rng, n, 0.12, (2, 4, 7)))


def rain_heavy(rng, n):
    fine = drops(rng, n, 1000, 3600, 1.1, 0.003)
    fine /= np.std(fine) + 1e-9
    plops = drops(rng, n, 160, 2000, 0.8, 0.008)
    plops /= np.std(plops) + 1e-9
    body = shaped_noise(rng, n, lambda f: band(f, 300, 1.0) * highpass(f, 90, 2))
    body /= np.std(body)
    return normalize((0.8 * fine + 0.6 * plops + 0.25 * body) * slow_swell(rng, n, 0.15, (2, 5, 9)))


def rain_leaves(rng, n):
    d = drops(rng, n, 380, 2200, 0.9, 0.007)
    d /= np.std(d) + 1e-9
    big = drops(rng, n, 50, 1500, 0.7, 0.012)
    big /= np.std(big) + 1e-9
    return normalize((0.9 * d + 0.4 * big) * slow_swell(rng, n, 0.1, (3, 6, 8)))


def rain_water(rng, n):
    fine = drops(rng, n, 300, 3000, 1.0, 0.004)
    fine /= np.std(fine) + 1e-9
    pits = drops(rng, n, 120, 1800, 0.7, 0.012)
    pits /= np.std(pits) + 1e-9
    return normalize((0.5 * fine + 0.8 * pits) * slow_swell(rng, n, 0.1, (3, 5, 8)))


# Rain on the ground under the player (build 210): only drops, no steady bed (the sheeting rule above).
# Stone: sharp bright ticks, nearly no body. Mud: soft low plops. Leaf litter: patter with a dry rustle.
# Snow: very faint muffled taps, the snow swallows the rain.

def rain_stone(rng, n):
    fine = drops(rng, n, 700, 5200, 1.0, 0.0025)
    fine /= np.std(fine) + 1e-9
    tick = drops(rng, n, 120, 3200, 0.7, 0.005)
    tick /= np.std(tick) + 1e-9
    return normalize((0.9 * fine + 0.6 * tick) * slow_swell(rng, n, 0.1, (2, 5, 8)))


def rain_mud(rng, n):
    plop = drops(rng, n, 150, 900, 0.7, 0.014)
    plop /= np.std(plop) + 1e-9
    soft = drops(rng, n, 300, 1800, 0.9, 0.006)
    soft /= np.std(soft) + 1e-9
    return normalize((0.9 * plop + 0.4 * soft) * slow_swell(rng, n, 0.1, (3, 5, 9)))


def rain_litter(rng, n):
    d = drops(rng, n, 420, 2600, 0.9, 0.006)
    d /= np.std(d) + 1e-9
    dry = drops(rng, n, 160, 3800, 0.8, 0.003)
    dry /= np.std(dry) + 1e-9
    return normalize((0.9 * d + 0.5 * dry) * slow_swell(rng, n, 0.1, (3, 6, 8)))


def rain_snow(rng, n):
    soft = drops(rng, n, 160, 1100, 0.9, 0.01)
    soft /= np.std(soft) + 1e-9
    return normalize(soft * slow_swell(rng, n, 0.1, (2, 4, 7)))


def wind_storm(rng, n):
    low = shaped_noise(rng, n, lambda f: lowpass(f, 500, 2) * highpass(f, 40, 2))
    low /= np.std(low)
    howl = shaped_noise(rng, n, lambda f: band(f, 650, 0.5) * highpass(f, 250, 2))
    howl /= np.std(howl)
    t = np.arange(n) / n
    sweep = 0.55 + 0.45 * np.sin(2 * np.pi * 3 * t + 1.0) * np.sin(2 * np.pi * 5 * t + 0.4)
    return normalize((low + 1.1 * howl * sweep) * slow_swell(rng, n, 0.35, (2, 3, 5)))


def thunder(rng, seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(rng, n, lambda f: band(f, 900, 1.5) * highpass(f, 200, 2)) * np.exp(-t / 0.12) * (t < 0.6)
    rumble = shaped_noise(rng, n, lambda f: lowpass(f, 220, 3) * highpass(f, 25, 2))
    rolls = np.zeros(n)

    for k in range(rng.integers(4, 8)):
        at = rng.uniform(0.1, seconds * 0.6)
        width = rng.uniform(0.6, 1.8)
        rolls += np.exp(-((t - at) / width) ** 2) * rng.uniform(0.4, 1.0)

    x = rumble / np.std(rumble) * (0.2 + rolls) * np.exp(-t / (seconds * 0.55)) + 1.4 * crack / (np.std(crack) + 1e-9) * 0.5
    x = x - np.mean(x)
    fade = int(0.03 * SR)
    x[:fade] *= np.linspace(0, 1, fade)
    x[-int(0.5 * SR):] *= np.linspace(1, 0, int(0.5 * SR))
    return np.tanh(x / np.max(np.abs(x)) * 1.6) * 0.8


def thunder_near(rng, seconds):
    """A close strike: a sharp, wide crack and a heavy thud, a short tumble."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    crack = shaped_noise(rng, n, lambda f: highpass(f, 150, 2) * lowpass(f, 5500, 1)) * np.exp(-t / 0.09)
    thud = shaped_noise(rng, n, lambda f: lowpass(f, 250, 3) * highpass(f, 30, 2)) * np.exp(-t / 0.5)
    tumble = shaped_noise(rng, n, lambda f: lowpass(f, 400, 2) * highpass(f, 40, 2)) * np.exp(-t / 1.1) * (0.5 + 0.5 * np.sin(2 * np.pi * 1.3 * t + rng.uniform(0, 6)))
    x = crack / np.std(crack) * 1.0 + thud / np.std(thud) * 0.9 + tumble / np.std(tumble) * 0.5
    x = x - np.mean(x)
    x[:int(0.002 * SR)] *= np.linspace(0, 1, int(0.002 * SR))
    x[-int(0.4 * SR):] *= np.linspace(1, 0, int(0.4 * SR))
    return np.tanh(x / np.max(np.abs(x)) * 1.8) * 0.85


def thunder_far(rng, seconds):
    """A distant strike: only a long, low grumble, no crack."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rumble = shaped_noise(rng, n, lambda f: lowpass(f, 140, 3) * highpass(f, 25, 2))
    rolls = np.zeros(n)

    for k in range(rng.integers(3, 6)):
        rolls += np.exp(-((t - rng.uniform(0.5, seconds * 0.7)) / rng.uniform(0.8, 2.0)) ** 2) * rng.uniform(0.4, 1.0)

    x = rumble / np.std(rumble) * (0.15 + rolls) * np.minimum(t / 0.6, 1.0) * np.exp(-t / (seconds * 0.5))
    x[-int(0.6 * SR):] *= np.linspace(1, 0, int(0.6 * SR))
    return np.tanh(x / np.max(np.abs(x)) * 1.4) * 0.8


def rain_drip(rng):
    """One fat drop falling from a leaf: a soft tick and a short watery plink."""
    n = int(0.35 * SR)
    out = np.zeros(n)
    m = int(0.02 * SR)
    tick = noise(rng, m, lambda f: band(f, 3000, 1.0) * highpass(f, 800)) * env(m, 0.0005, 0.005)
    add(out, tick / (np.max(np.abs(tick)) + 1e-9) * 0.5, 0.0)
    d = int(0.12 * SR)
    t = np.arange(d) / SR
    f0 = rng.uniform(500, 900)
    plink = np.sin(2 * np.pi * np.cumsum(f0 * (1.0 + 1.2 * t / 0.12)) / SR) * np.exp(-t / 0.025)
    add(out, plink * 0.7, 0.004)
    out[-int(0.05 * SR):] *= np.linspace(1, 0, int(0.05 * SR))
    return out * (0.7 / (np.max(np.abs(out)) + 1e-9))


def main():
    rng = np.random.default_rng(20261020)
    for name, make, seconds in (("rain_light", rain_light, 14), ("rain_heavy", rain_heavy, 14),
                                ("rain_leaves", rain_leaves, 16), ("rain_water", rain_water, 14),
                                ("wind_storm", wind_storm, 16)):
        write_ogg(name, make(rng, seconds * SR))
    for v, seconds in enumerate((7.0, 9.0, 6.0)):
        write_ogg("thunder_%d" % v, thunder(rng, seconds))
    for v in range(3):
        write_ogg("thunder_near_%d" % v, thunder_near(rng, 3.5))
        write_ogg("thunder_far_%d" % v, thunder_far(rng, 11.0))

    for v in range(4):
        write_ogg("rain_drip_%d" % v, rain_drip(rng))

    # Added last, from their own generator, so the sounds above stay the same files when this runs again.
    ground = np.random.default_rng(20261032)

    for name, make in (("rain_stone", rain_stone), ("rain_mud", rain_mud), ("rain_litter", rain_litter), ("rain_snow", rain_snow)):
        write_ogg(name, make(ground, 14 * SR))

    print("Wrote 22 weather sounds to %s" % OUT)


if __name__ == "__main__":
    main()
