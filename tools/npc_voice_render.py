"""One render module for every NPC line, prebaked or live (Mandy 2026-10-21, Tyler Report 24: the voices sounded like AI, no natural pauses).

render_line(kokoro, spec, voice_id, text) -> (float32 mono samples, rate). All randomness is seeded from the voice id and the text, so the
same line always comes out the same (the cache key stays honest). What it does to a line:
  * splits it into sentences, and each sentence into phrases at commas, dashes and semicolons; each phrase is rendered on its own
  * puts measured silence between them: about 200 ms at a comma, 250 ms at a dash, 500-650 ms at a sentence end, 600-900 ms at an
    ellipsis, each randomised by 15 percent
  * varies speed and pitch per phrase by 4-6 percent, slows the last phrase of a sentence, and gives the whole line a mood of up to two
    semitones (calmer or brighter)
  * blends two voices when the spec has "blend": [[voice, weight], [voice, weight]]
  * now and then a quiet breath before a sentence
Reverb and EQ are NOT baked in: they sit on the NPC voice bus in the game (npc_voice.gd).
"""
import hashlib, random, re

import numpy as np

COMMA_MS = 200.0
DASH_MS = 250.0
SENTENCE_MS = (500.0, 650.0)
ELLIPSIS_MS = (600.0, 900.0)
JITTER = 0.15
PHRASE_VARIATION = 0.05
LAST_PHRASE_SLOWER = 0.93
MOOD_SEMITONES = (-0.6, 1.2)
BREATH_CHANCE = 0.2
BREATH_DB = -34.0


def seed_of(voice_id, text):
    return int(hashlib.md5(("k2|%s|%s" % (voice_id, text)).encode("utf-8")).hexdigest()[:8], 16)


def style_of(kokoro, spec):
    blend = spec.get("blend")

    if not blend:
        return spec["voice"]

    total = sum(float(w) for _, w in blend)
    mix = None

    for name, weight in blend:
        part = kokoro.get_voice_style(name) * (float(weight) / total)
        mix = part if mix is None else mix + part

    return mix


def split_line(text):
    """[(phrase text, pause after in ms before randomising, last phrase of its sentence)]"""
    out = []
    text = re.sub(r"\s+", " ", text.strip())
    # sentences end at . ! ? or an ellipsis; keep the mark with its sentence
    sentences = re.findall(r"[^.!?…]+(?:\.\.\.|…|[.!?])+|[^.!?…]+$", text)

    for sentence in sentences:
        sentence = sentence.strip()

        if not sentence:
            continue

        ellipsis = sentence.endswith("...") or sentence.endswith("…")
        end_pause = sum(ELLIPSIS_MS) / 2.0 if ellipsis else sum(SENTENCE_MS) / 2.0
        parts = re.split(r"([,;:]|\s[-—–]+\s|—)", sentence)
        phrases = []
        pending = ""

        for piece in parts:
            if piece is None:
                continue

            if piece in (",", ";", ":") or re.fullmatch(r"\s?[-—–]+\s?", piece or "x"):
                if pending.strip():
                    phrases.append([pending.strip() + (piece if piece in (",", ";", ":") else ""), DASH_MS if piece not in (",", ";", ":") else COMMA_MS])

                pending = ""
            else:
                pending += piece

        if pending.strip():
            phrases.append([pending.strip(), end_pause])
        elif phrases:
            phrases[-1][1] = end_pause

        for n, (phrase, pause) in enumerate(phrases):
            last = n == len(phrases) - 1
            out.append((phrase, end_pause if last else pause, last))

    return out


def shift_pitch(samples, semitones, rate):
    """Resample to move the pitch; the caller has already rendered slower by the same ratio, so the length comes out right."""
    ratio = 2.0 ** (semitones / 12.0)

    if abs(ratio - 1.0) < 1e-4:
        return samples

    n = max(int(len(samples) / ratio), 2)
    return np.interp(np.linspace(0, len(samples) - 1, n), np.arange(len(samples)), samples).astype(np.float32)


def trim(samples, rate):
    loud = np.where(np.abs(samples) > 0.01)[0]

    if not loud.size:
        return samples

    return samples[max(loud[0] - int(0.03 * rate), 0): loud[-1] + int(0.06 * rate)]


def breath(rng, rate):
    n = int(rate * rng.uniform(0.18, 0.3))
    noise = np.random.RandomState(rng.randrange(1 << 30)).randn(n).astype(np.float32)
    # a soft in-breath: noise through a running mean (low-pass) with a slow swell
    k = 24
    noise = np.convolve(noise, np.ones(k, dtype=np.float32) / k, mode="same")
    swell = np.sin(np.linspace(0.0, np.pi, n)).astype(np.float32) ** 2
    out = noise * swell
    peak = float(np.max(np.abs(out))) or 1.0
    return out / peak * (10 ** (BREATH_DB / 20.0))


def render_line(kokoro, spec, voice_id, text):
    rng = random.Random(seed_of(voice_id, text))
    voice = style_of(kokoro, spec)
    base_speed = float(spec.get("speed", 0.95))
    mood = rng.uniform(*MOOD_SEMITONES)
    pieces = []
    rate = 24000
    after_sentence = False

    for phrase, pause_ms, last in split_line(text):
        speed = base_speed * (1.0 + rng.uniform(-PHRASE_VARIATION, PHRASE_VARIATION))

        if last:
            speed *= LAST_PHRASE_SLOWER

        semitones = mood + rng.uniform(-0.5, 0.5) + (-0.4 if last else 0.0)
        ratio = 2.0 ** (semitones / 12.0)
        samples, rate = kokoro.create(phrase, voice=voice, speed=max(speed / ratio, 0.5), lang=spec.get("lang", "en-gb"))
        samples = shift_pitch(trim(np.asarray(samples, dtype=np.float32), rate), semitones, rate)

        if after_sentence and rng.random() < BREATH_CHANCE:
            pieces.append(breath(rng, rate))
            pieces.append(np.zeros(int(0.08 * rate), dtype=np.float32))

        pieces.append(samples)
        gap = pause_ms * (1.0 + rng.uniform(-JITTER, JITTER))
        pieces.append(np.zeros(int(gap * rate / 1000.0), dtype=np.float32))
        after_sentence = last

    if len(pieces) > 1:
        pieces.pop()   # no trailing pause

    return (np.concatenate(pieces) if pieces else np.zeros(1, dtype=np.float32)), rate
