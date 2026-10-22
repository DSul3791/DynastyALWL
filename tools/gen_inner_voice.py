#!/usr/bin/env python3
"""Render every inner-voice line once per voice set with Kokoro (Apache 2.0), text to voice, into
assets/audio/inner_voice/<set id>/<line id>.ogg (mono Vorbis, about 15 to 20 KB a line).

Needs: pip install kokoro-onnx soundfile numpy, plus kokoro-v1.0.onnx and voices-v1.0.bin from
https://github.com/thewh1teagle/kokoro-onnx/releases (model-files-v1.0). Line ids are the first 8 hex of the text's md5, the same as
the server (server_items.gd voice_line_id), so a changed line only re-renders itself.

  python3 tools/gen_inner_voice.py --model DIR [--only SET_ID] [--force]
"""
import argparse, hashlib, json, os, sys

import numpy as np
import soundfile as sf
from kokoro_onnx import Kokoro

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="folder holding kokoro-v1.0.onnx and voices-v1.0.bin")
    ap.add_argument("--only", help="render one set id only")
    ap.add_argument("--force", action="store_true", help="re-render lines that already have a file")
    args = ap.parse_args()
    sets = json.load(open(os.path.join(ROOT, "data/items/inner_voice_sets.json")))
    lines = json.load(open(os.path.join(ROOT, "data/items/inner_voice.json")))
    texts = [t for kind, group in lines.items() if isinstance(group, list) for t in group]
    kokoro = Kokoro(os.path.join(args.model, "kokoro-v1.0.onnx"), os.path.join(args.model, "voices-v1.0.bin"))
    made = 0

    for family, temperaments in sets["families"].items():
        for temperament, voices in temperaments.items():
            for n, voice in enumerate(voices):
                set_id = "%s_%s_%d" % (family, temperament, n)

                if args.only and args.only != set_id:
                    continue

                out_dir = os.path.join(ROOT, "assets/audio/inner_voice", set_id)
                os.makedirs(out_dir, exist_ok=True)

                for text in texts:
                    line_id = hashlib.md5(text.encode("utf-8")).hexdigest()[:8]
                    path = os.path.join(out_dir, line_id + ".ogg")

                    if os.path.exists(path) and not args.force:
                        continue

                    samples, rate = kokoro.create(text, voice=voice["voice"], speed=voice["speed"], lang=voice["lang"])
                    samples = np.asarray(samples, dtype=np.float32)
                    peak = float(np.max(np.abs(samples))) or 1.0
                    sf.write(path, samples / peak * 0.8, rate, format="OGG", subtype="VORBIS")
                    made += 1

                print(set_id, "done")

    print("rendered", made, "files")


if __name__ == "__main__":
    sys.exit(main())
