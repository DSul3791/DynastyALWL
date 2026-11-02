"""One stitched preview clip per sound group, for Dave to judge by ear: python3 assets/audio/make_review_clips.py OUT_DIR [--per N]

Takes up to N slots (default 5) from each folder under assets/audio (recorded files win), puts 0.6 s of silence between them,
levels each to about -20 dB RMS so the group is comparable, and writes OUT_DIR/<group>.mp3 plus OUT_DIR/INDEX.md listing the
order of the slots in each preview. Needs ffmpeg.
"""
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
SKIP = {"__pycache__", "recorded", "inner_voice", "npc_voice", "treewind"}


def slots(folder):
    found = {}
    rec = os.path.join(HERE, "recorded", os.path.basename(folder))
    for base in (folder, rec):
        if os.path.isdir(base):
            for f in sorted(os.listdir(base)):
                if f.endswith(".ogg"):
                    found[re.sub(r"_\d+$", "", f[:-4])] = os.path.join(base, f)
    return found


def main():
    out = sys.argv[1]
    per = int(sys.argv[sys.argv.index("--per") + 1]) if "--per" in sys.argv else 5
    os.makedirs(out, exist_ok=True)
    index = ["# Sound review clips", ""]
    for g in sorted(os.listdir(HERE)):
        folder = os.path.join(HERE, g)
        if g in SKIP or not os.path.isdir(folder):
            continue
        picks = list(slots(folder).items())
        step = max(1, len(picks) // per)
        picks = picks[::step][:per]
        if not picks:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            parts = []
            for i, (name, path) in enumerate(picks):
                part = os.path.join(tmp, "%d.wav" % i)
                subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-i", path, "-ac", "1", "-ar", "22050", "-af", "loudnorm=I=-20:TP=-2", part], check=True)
                parts.append(part)
            sil = os.path.join(tmp, "sil.wav")
            subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "anullsrc=r=22050:cl=mono", "-t", "0.6", sil], check=True)
            lst = os.path.join(tmp, "list.txt")
            with open(lst, "w") as f:
                for p in parts:
                    f.write("file '%s'\nfile '%s'\n" % (p, sil))
            subprocess.run(["ffmpeg", "-nostdin", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-b:a", "96k", os.path.join(out, g + ".mp3")], check=True)
        index.append("- **%s.mp3**: %s" % (g, ", ".join(n for n, _ in picks)))
    with open(os.path.join(out, "INDEX.md"), "w") as f:
        f.write("\n".join(index) + "\n")
    print("Wrote %d previews to %s" % (len(index) - 2, out))


if __name__ == "__main__":
    main()
