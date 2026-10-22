#!/usr/bin/env python3
"""Render every NPC dialogue line once per NPC voice with Kokoro (Apache 2.0), text to voice, into
assets/audio/npc_voice/<voice_id>/<hash8>.ogg (mono Vorbis, level about -23 dBFS RMS, silence trimmed) and a manifest.json.

Text is the trigger (Dave 2026-10-21): the client asks for a line by its text and voice details; the file name is the hash
of those, so a prebaked line is only text that hits the cache sooner. Hash: first 8 hex of md5('k2|<voice_id>|<speed:.2f>|<pitch:.2f>|<text>')
with the text trimmed and whitespace collapsed (npc_voice.gd does the same). Pauses, per-phrase variation and voice blending: tools/npc_voice_render.py.

Lines come from data/npcs/dialogue/<npc>.json: every bark (greeting, farewell, idle, complaint, cooldown, info) and every
node text (a string or an array), for the NPC's voice_id (data/npcs/npcs.json "voice"), settings in data/npcs/voices.json (Kokoro voice, lang, speed, pitch).

  python3 tools/gen_npc_voice.py --model DIR [--only VOICE_ID] [--force]
"""
import argparse, hashlib, json, os, re, sys

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from npc_voice_render import render_line   # the one render module (phrases, pauses, variation, blending), shared with live lines


def norm(text):
    return re.sub(r"\s+", " ", text.strip())


def line_hash(model, voice_id, speed, pitch, text):
    return hashlib.md5(("%s|%s|%.2f|%.2f|%s" % (model, voice_id, speed, pitch, norm(text))).encode("utf-8")).hexdigest()[:8]


def texts_of(doc):
    found = []

    for group in doc.get("barks", {}).values():
        found.extend(group)

    for node in doc.get("nodes", {}).values():
        t = node.get("text", "")

        if isinstance(t, list):
            found.extend(t)
        elif isinstance(t, str) and t and not t.startswith("$"):
            found.append(t)

    return [norm(x) for x in found if isinstance(x, str) and x and not x.startswith("$")]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--only")
    ap.add_argument("--force", action="store_true")
    args = ap.parse_args()
    sets = json.load(open(os.path.join(ROOT, "data/npcs/voices.json")))
    sets.setdefault("model", "k2")
    sets.setdefault("default", {"voice": "bm_george", "lang": "en-gb", "speed": 0.95, "pitch": 1.0})
    npcs = json.load(open(os.path.join(ROOT, "data/npcs/npcs.json")))["npcs"]
    kokoro = Kokoro(os.path.join(args.model, "kokoro-v1.0.onnx"), os.path.join(args.model, "voices-v1.0.bin"))
    manifest = {}
    made = 0

    for npc in npcs:
        voice_id = npc.get("voice", npc["id"])

        if args.only and args.only != voice_id:
            continue

        path = os.path.join(ROOT, "data/npcs/dialogue", npc["id"] + ".json")

        if not os.path.exists(path):
            continue

        spec = sets["voices"].get(voice_id, sets["default"])
        out_dir = os.path.join(ROOT, "assets/audio/npc_voice", voice_id)
        os.makedirs(out_dir, exist_ok=True)
        entries = manifest.setdefault(voice_id, {})

        for text in sorted(set(texts_of(json.load(open(path))))):
            h = line_hash(sets["model"], voice_id, spec["speed"], spec.get("pitch", 1.0), text)
            out = os.path.join(out_dir, h + ".ogg")

            if not os.path.exists(out) or args.force:
                samples, rate = render_line(kokoro, spec, voice_id, text)
                loud = np.where(np.abs(samples) > 0.003)[0]

                if loud.size:
                    samples = samples[max(loud[0] - int(0.04 * rate), 0): loud[-1] + int(0.12 * rate)]

                rms = float(np.sqrt(np.mean(samples ** 2))) or 1.0
                samples = samples * (10 ** (-23.0 / 20.0) / rms)
                samples = np.clip(samples, -0.95, 0.95)
                sf.write(out, samples, rate, format="OGG", subtype="VORBIS")
                made += 1

            entries[h] = {"text": text, "bytes": os.path.getsize(out)}

        print(voice_id, len(entries), "lines")

    json.dump(manifest, open(os.path.join(ROOT, "assets/audio/npc_voice/manifest.json"), "w"), indent=1, ensure_ascii=False)
    total = sum(e["bytes"] for v in manifest.values() for e in v.values())
    print("rendered", made, "files; total", total // 1024, "KB")


if __name__ == "__main__":
    main()
