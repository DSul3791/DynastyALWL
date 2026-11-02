"""Licence audit: python3 assets/audio/check_credits.py [--strict]

Every sound file under assets/audio must be covered by a CREDITS.csv row (pattern is a glob relative to
recorded/ or to assets/audio/ itself), unless a make_*.py script in this folder generates its folder.
Lists uncovered files by folder, and rows whose licence is still TODO. Exit 1 with --strict if anything is listed.
Complements validate_pack.py (which checks recorded/ only).
"""
import csv
import fnmatch
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
AUDIO_EXT = (".ogg", ".wav", ".mp3")


def files():
    for base, dirs, names in os.walk(HERE):
        dirs[:] = [d for d in dirs if d != "__pycache__"]
        for n in names:
            if n.lower().endswith(AUDIO_EXT):
                yield os.path.relpath(os.path.join(base, n), HERE).replace(os.sep, "/")


def main():
    with open(os.path.join(HERE, "CREDITS.csv"), newline="", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    patterns = [q for r in rows for q in r["pattern"].split("|")]
    generated = set()
    for n in os.listdir(HERE):
        if n.startswith("make_") and n.endswith(".py"):
            with open(os.path.join(HERE, n), encoding="utf-8") as f:
                text = f.read()
            for d in os.listdir(HERE):
                if os.path.isdir(os.path.join(HERE, d)) and d != "recorded" and ('"%s"' % d in text or "'%s'" % d in text or "/%s/" % d in text):
                    generated.add(d)
    missing = {}
    for rel in files():
        top = rel.split("/")[0]
        local = rel[len("recorded/"):] if rel.startswith("recorded/") else rel
        covered = any(fnmatch.fnmatch(local, p) or fnmatch.fnmatch(local, p + ".*") or fnmatch.fnmatch(local.rsplit(".", 1)[0], p) or fnmatch.fnmatch(local.rsplit(".", 1)[0].rsplit("_", 1)[0], p) for p in patterns)
        stem = rel.rsplit(".", 1)[0]
        if not covered and "/" not in rel and any(stem in open(os.path.join(HERE, m), encoding="utf-8").read() for m in os.listdir(HERE) if m.startswith("make_") and m.endswith(".py")):
            continue                                              # a top-level file written by a make_ script
        if not covered and (rel.startswith("recorded/") or top not in generated):
            missing.setdefault(top, []).append(rel)
    todo = [r["pattern"] for r in rows if r["licence"] == "TODO" or "TODO" in r["source"] or "TODO" in r["url"]]
    for top in sorted(missing):
        print("NO CREDITS ROW  %s: %d files: %s" % (top, len(missing[top]), ", ".join(missing[top][:4])))
    for p in todo:
        print("TODO SOURCE     %s" % p)
    print("%d folders with unlicensed files, %d rows with a TODO" % (len(missing), len(todo)))
    return 1 if (missing or todo) and "--strict" in sys.argv else 0


if __name__ == "__main__":
    sys.exit(main())
