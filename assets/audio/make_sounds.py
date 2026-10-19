"""Makes the first sound set in code: footsteps for each kind of ground, grass
brushing against the legs, and two wind loops.

Run: python3 assets/audio/make_sounds.py   (needs numpy and ffmpeg)
Writes .ogg files next to this file. They are placeholders made from shaped
noise and tiny resonances, because the cloud sessions cannot reach free sound
libraries. Swap in real recordings (CC0 or bought) under the same names
whenever they exist; the game picks up every variant named name_N.ogg.

Footsteps are built the way a real step sounds: a heel strike (a low thump and
a click), the surface's own texture (crushed blades, sand, gravel pings, leaf
crackle, mud squelch, snow crunch, splash), then a softer toe roll. Each file
is normalized; the game sets each surface's loudness (sound_stage.gd).
The wind loops are shaped noise whose colour and loudness drift with slow
gusts; the gust shape repeats exactly over the loop, so they loop without a seam.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
SR = 44100
VARIANTS = 5


# ---------------------------------------------------------------- helpers

def freqs(n):
    return np.fft.rfftfreq(n, 1.0 / SR)


def shape(signal, gain):
    """Filters a signal by a magnitude response given per rfft bin."""
    spec = np.fft.rfft(signal)
    return np.fft.irfft(spec * gain, len(signal))


def band(f, center, octaves):
    """Smooth band in log frequency, `octaves` wide at about 60 % height."""
    f = np.maximum(f, 1.0)
    return np.exp(-0.5 * (np.log2(f / center) / octaves) ** 2)


def lowpass(f, cut, order=2):
    return 1.0 / np.sqrt(1.0 + (f / cut) ** (2 * order))


def highpass(f, cut, order=2):
    f = np.maximum(f, 1e-3)
    return 1.0 / np.sqrt(1.0 + (cut / f) ** (2 * order))


def noise(rng, n, gain_fn):
    return shape(rng.standard_normal(n), gain_fn(freqs(n)))


def env(n, attack, decay, start=0):
    """Fast attack then exponential decay, times in seconds."""
    t = (np.arange(n) - start) / SR
    out = np.where(t < 0, 0.0, np.where(t < attack, t / max(attack, 1e-6), np.exp(-(t - attack) / decay)))
    return out


def add(dst, src, at):
    i = int(at * SR)
    if i >= len(dst):
        return
    m = min(len(src), len(dst) - i)
    dst[i:i + m] += src[:m]


def ping(freq, decay, length=None):
    length = length or decay * 6
    t = np.arange(int(length * SR)) / SR
    return np.sin(2 * np.pi * freq * t) * np.exp(-t / decay)


def thump(rng, length, f0, decay, click_cut=1200.0):
    """Heel strike: a falling low tone and a dull click."""
    n = int(length * SR)
    t = np.arange(n) / SR
    f = f0 * (1.0 + 0.6 * np.exp(-t / 0.012))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / decay)
    click = noise(rng, n, lambda fr: lowpass(fr, click_cut, 2) * highpass(fr, 60)) * env(n, 0.001, 0.012)
    click /= np.max(np.abs(click)) + 1e-9
    return tone + 0.7 * click


def grains(rng, n, count, start, spread, make, decay_share=0.4):
    """Many small sounds, densest just after `start`, thinning over `spread` s."""
    out = np.zeros(n)
    for _ in range(count):
        at = start + rng.exponential(spread * decay_share)
        if at > start + spread:
            at = start + rng.uniform(0, spread)
        g = make() * rng.pareto(2.5) * 0.4
        add(out, g, at)
    return out


def burst(rng, length, center, octaves):
    """A tiny noise grain."""
    n = max(int(length * SR), 8)
    g = noise(rng, n, lambda f: band(f, center, octaves)) * np.hanning(n)
    return g / (np.max(np.abs(g)) + 1e-9)


def finish(x, peak=0.9):
    x = x - np.mean(x)
    n = len(x)
    fade = min(int(0.01 * SR), n // 4)
    x[-fade:] *= np.linspace(1, 0, fade)
    return x * (peak / (np.max(np.abs(x)) + 1e-9))


def write_ogg(name, x, quality=4):
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "s.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis",
                        "-q:a", str(quality), os.path.join(HERE, name + ".ogg")], check=True)


# ---------------------------------------------------------------- footsteps

def step_base(rng, length, f0, decay, heel=1.0, toe=0.45, click_cut=1200.0):
    """Heel and toe thumps; returns (signal, toe time)."""
    n = int(length * SR)
    out = np.zeros(n)
    add(out, heel * thump(rng, 0.12, f0 * rng.uniform(0.9, 1.1), decay, click_cut), 0.004)
    toe_at = rng.uniform(0.07, 0.11)
    add(out, toe * thump(rng, 0.1, f0 * rng.uniform(1.0, 1.25), decay * 0.7, click_cut), toe_at)
    return out, toe_at


def step_grass(rng):
    out, toe = step_base(rng, 0.42, 75, 0.022, heel=0.55, toe=0.25, click_cut=700)
    n = len(out)
    blades = lambda: burst(rng, rng.uniform(0.002, 0.006), rng.uniform(1500, 4000), 0.6)
    crush = grains(rng, n, 90, 0.005, 0.14, blades) + 0.6 * grains(rng, n, 50, toe, 0.12, blades)
    swish = noise(rng, n, lambda f: band(f, 2400, 1.0)) * env(n, 0.03, 0.08, int(0.01 * SR))
    return finish(out / 3.0 + 0.35 * crush + 0.08 * swish)


def step_dirt(rng):
    out, toe = step_base(rng, 0.36, 82, 0.03, heel=1.0, toe=0.5, click_cut=900)
    n = len(out)
    body = noise(rng, n, lambda f: lowpass(f, 700, 2) * highpass(f, 80)) * env(n, 0.002, 0.04)
    grit = grains(rng, n, 30, 0.005, 0.1, lambda: burst(rng, 0.003, rng.uniform(1000, 2500), 0.7))
    return finish(out / 2.5 + 0.25 * body / (np.max(np.abs(body)) + 1e-9) + 0.2 * grit)


def step_sand(rng):
    out, toe = step_base(rng, 0.5, 65, 0.03, heel=0.45, toe=0.3, click_cut=500)
    n = len(out)
    sandy = lambda: burst(rng, rng.uniform(0.003, 0.008), rng.uniform(700, 2200), 0.8)
    crunch = grains(rng, n, 220, 0.008, 0.2, sandy, 0.6) + 0.7 * grains(rng, n, 140, toe, 0.18, sandy, 0.6)
    slide = noise(rng, n, lambda f: band(f, 1400, 1.4)) * env(n, 0.06, 0.07, int(toe * SR))
    return finish(out / 3.0 + 0.3 * crunch + 0.05 * slide)


def step_gravel(rng):
    out, toe = step_base(rng, 0.42, 80, 0.025, heel=0.8, toe=0.4)
    n = len(out)
    stone = lambda: ping(rng.uniform(1200, 5000), rng.uniform(0.0015, 0.005))
    pings = grains(rng, n, 260, 0.004, 0.11, stone) + 0.8 * grains(rng, n, 180, toe, 0.12, stone)
    roll = noise(rng, n, lambda f: band(f, 2500, 1.2)) * env(n, 0.005, 0.06)
    return finish(out / 3.5 + 0.35 * pings + 0.05 * roll)


def step_stone(rng):
    n = int(0.32 * SR)
    out = np.zeros(n)
    toe = rng.uniform(0.07, 0.1)
    for at, amp in ((0.003, 1.0), (toe, 0.55)):
        click = noise(rng, int(0.01 * SR), lambda f: highpass(f, 900) * lowpass(f, 4500)) * env(int(0.01 * SR), 0.0005, 0.0025)
        click /= np.max(np.abs(click)) + 1e-9
        ring = sum(ping(rng.uniform(380, 950), rng.uniform(0.012, 0.03), 0.12) * rng.uniform(0.3, 0.6) for _ in range(3))
        add(out, amp * click, at)
        add(out, amp * 0.5 * ring, at)
        add(out, amp * 0.5 * thump(rng, 0.08, 95, 0.012, 1500), at)
    scuff = noise(rng, n, lambda f: band(f, 2200, 1.0)) * env(n, 0.02, 0.03, int((toe + 0.01) * SR))
    return finish(out + 0.04 * scuff)


def step_leaves(rng):
    out, toe = step_base(rng, 0.48, 70, 0.025, heel=0.5, toe=0.3, click_cut=600)
    n = len(out)
    crack = lambda: burst(rng, rng.uniform(0.0008, 0.0025), rng.uniform(2000, 5500), 0.8)
    crackle = grains(rng, n, 160, 0.006, 0.2, crack, 0.5) + 0.7 * grains(rng, n, 90, toe, 0.18, crack, 0.5)
    rustle = noise(rng, n, lambda f: band(f, 2600, 1.3)) * env(n, 0.04, 0.09)
    return finish(out / 3.0 + 0.4 * crackle + 0.06 * rustle)


def step_mud(rng):
    out, toe = step_base(rng, 0.5, 60, 0.04, heel=0.9, toe=0.2, click_cut=450)
    n = len(out)
    t = np.arange(n) / SR
    sweep_f = 110 + 160 * np.exp(-t / 0.05)
    squelch = np.sin(2 * np.pi * np.cumsum(sweep_f) / SR) * env(n, 0.006, 0.05)
    squelch *= 0.6 + 0.4 * noise(rng, n, lambda f: lowpass(f, 60, 1)) / 0.05
    wet = noise(rng, n, lambda f: lowpass(f, 500, 2) * highpass(f, 70)) * env(n, 0.003, 0.06)
    lift_at = toe + rng.uniform(0.12, 0.18)
    m = int(0.09 * SR)
    tt = np.arange(m) / SR
    suck = np.sin(2 * np.pi * np.cumsum(300 + 700 * tt / tt[-1]) / SR) * np.hanning(m)
    pop = ping(rng.uniform(500, 800), 0.006, 0.03)
    add(out, 0.25 * suck, lift_at)
    add(out, 0.35 * pop, lift_at + 0.085)
    wet /= np.max(np.abs(wet)) + 1e-9
    return finish(out / 2.0 + 0.35 * squelch / (np.max(np.abs(squelch)) + 1e-9) + 0.3 * wet)


def step_snow(rng):
    out, toe = step_base(rng, 0.45, 70, 0.025, heel=0.35, toe=0.2, click_cut=500)
    n = len(out)
    flake = lambda: burst(rng, rng.uniform(0.002, 0.005), rng.uniform(1200, 3500), 0.6)
    crunch = np.zeros(n)
    for _ in range(340):
        at = 0.01 + rng.beta(1.6, 3.0) * 0.24
        add(crunch, flake() * rng.uniform(0.2, 1.0), at)
    squeak = ping(rng.uniform(900, 1300), 0.03, 0.1) * 0.15
    add(crunch, squeak, 0.05)
    return finish(out / 4.0 + 0.3 * crunch)


def step_water(rng):
    n = int(0.6 * SR)
    out = np.zeros(n)
    splash = noise(rng, n, lambda f: band(f, 2000, 1.3) * highpass(f, 300)) * env(n, 0.006, 0.09)
    slosh = noise(rng, n, lambda f: lowpass(f, 600, 2) * highpass(f, 60)) * env(n, 0.03, 0.18)
    splash /= np.max(np.abs(splash)) + 1e-9
    slosh /= np.max(np.abs(slosh)) + 1e-9
    out += 0.7 * splash + 0.45 * slosh
    for _ in range(rng.integers(8, 15)):
        f0 = rng.uniform(450, 1800)
        d = rng.uniform(0.012, 0.035)
        m = int(d * 5 * SR)
        tt = np.arange(m) / SR
        bubble = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 4.0 * tt)) / SR) * np.exp(-tt / d)
        add(out, rng.uniform(0.1, 0.35) * bubble, rng.uniform(0.01, 0.3))
    return finish(out)


SURFACES = {
    "grass": step_grass,
    "dirt": step_dirt,
    "sand": step_sand,
    "gravel": step_gravel,
    "stone": step_stone,
    "leaves": step_leaves,
    "mud": step_mud,
    "snow": step_snow,
    "water": step_water,
}


# ---------------------------------------------------------------- grass brushing

def brush(rng, length, center, body):
    """Blades sweeping over boots and trousers: a soft swell of airy noise."""
    n = int(length * SR)
    t = np.arange(n) / SR
    rise = rng.uniform(0.25, 0.35) * length
    shape_env = np.where(t < rise, np.sin(0.5 * np.pi * t / rise) ** 2, np.exp(-(t - rise) / (0.28 * length)))
    air = noise(rng, n, lambda f: (band(f, center, 1.0) + body * band(f, center * 0.4, 0.8)) * lowpass(f, 6000, 2))
    air /= np.max(np.abs(air)) + 1e-9
    flick = lambda: burst(rng, rng.uniform(0.002, 0.006), rng.uniform(2500, 5000), 0.5)
    flicks = np.zeros(n)
    for _ in range(70):
        at = rng.beta(2.0, 3.0) * length
        add(flicks, flick() * rng.uniform(0.1, 0.6), at)
    return finish(air * shape_env + 0.25 * flicks * shape_env)


# ---------------------------------------------------------------- wind

def wind_loop(rng, seconds, layer):
    """A seamless wind loop. `layer` "low" is the broad body of the wind,
    "gust" the airy, whistling top that rises with each gust."""
    n = int(seconds * SR)
    win = 4096
    hop = win // 4
    frames = n // hop
    n = frames * hop
    window = np.hanning(win + 1)[:-1]
    f = np.fft.rfftfreq(win, 1.0 / SR)
    white = rng.standard_normal(n)
    out = np.zeros(n)
    # Gust shape: slow sines that each fit a whole number of times in the loop.
    phases = rng.uniform(0, 2 * np.pi, 4)
    cycles = [1, 2, 3, 7] if layer == "low" else [2, 3, 5, 9]
    weights = [0.45, 0.3, 0.17, 0.08]
    whistle_cycles = [1, 2]
    for k in range(frames):
        start = k * hop
        idx = (start + np.arange(win)) % n
        x = (start + win / 2) / n
        g = sum(w * np.sin(2 * np.pi * c * x + p) for w, c, p in zip(weights, cycles, phases))
        g = 0.5 + 0.5 * g / sum(weights)          # 0 calm .. 1 gust peak
        spec = np.fft.rfft(white[idx] * window)
        pink = 1.0 / np.sqrt(np.maximum(f, 20.0))
        if layer == "low":
            cut = 220 + 520 * g
            gain = pink * lowpass(f, cut, 2) * highpass(f, 35, 2) * (0.45 + 0.55 * g)
        else:
            center = 700 + 900 * g
            gain = pink * band(f, center, 1.4) * highpass(f, 200, 2)
            # Two faint whistles drifting in pitch, strongest in the gusts.
            for j, c in enumerate(whistle_cycles):
                wf = 620 + 260 * j + 120 * np.sin(2 * np.pi * c * x + phases[j])
                gain = gain + 0.35 * pink * band(f, wf, 0.04) * g ** 2
            gain = gain * (0.15 + 0.85 * g ** 1.5)
        frame = np.fft.irfft(spec * gain, win) * window
        out[idx] += frame
    out /= 1.5  # hann squared at quarter hop sums to 1.5
    out -= np.mean(out)
    return out * (0.8 / (np.max(np.abs(out)) + 1e-9))


# ---------------------------------------------------------------- main

def main():
    rng = np.random.default_rng(20261019)
    made = []
    for name, make in SURFACES.items():
        for v in range(VARIANTS):
            write_ogg("step_%s_%d" % (name, v), make(rng))
            made.append("step_%s_%d" % (name, v))
    for v in range(4):
        write_ogg("grass_brush_%d" % v, brush(rng, rng.uniform(0.38, 0.5), 2200, 0.2))
        write_ogg("grass_brush_tall_%d" % v, brush(rng, rng.uniform(0.6, 0.8), 1600, 0.5))
        made += ["grass_brush_%d" % v, "grass_brush_tall_%d" % v]
    write_ogg("wind_low", wind_loop(rng, 24.0, "low"), 3)
    write_ogg("wind_gust", wind_loop(rng, 31.0, "gust"), 3)
    made += ["wind_low", "wind_gust"]
    print("Wrote %d sounds to %s" % (len(made), HERE))


if __name__ == "__main__":
    main()
