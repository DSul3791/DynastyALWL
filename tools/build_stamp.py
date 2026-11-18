#!/usr/bin/env python3
"""Write res://build_stamp.json for a release export (server/client split step A1, Dave 18 Nov 2026: the build number is automatic).

The build number is the commit count of the checked-out commit (`git rev-list --count HEAD`). Releases are cut from main, so it is
main's count: it only goes up and any full clone gives the same number. Nobody types it. src/shared/build_stamp.gd reads the file;
editor runs have none. The file is gitignored; a stamp left behind after a pull names another commit and the game ignores it.

  python3 tools/build_stamp.py            write build_stamp.json at the repository root, print the stamp
  python3 tools/build_stamp.py --print    print the stamp only
"""
import datetime
import json
import os
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def git(*args):
    return subprocess.run(["git", "-C", ROOT, *args], check=True, capture_output=True, text=True).stdout.strip()


def stamp():
    # A shallow clone counts only the commits it fetched, which would give a smaller number than the build before it.
    if git("rev-parse", "--is-shallow-repository") == "true":
        sys.exit("build_stamp: this clone is shallow; the commit count would be wrong (run git fetch --unshallow)")

    return {
        "build": int(git("rev-list", "--count", "HEAD")),
        "commit": git("rev-parse", "HEAD"),
        "date": datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    }


def main():
    row = stamp()
    text = json.dumps(row, indent="\t") + "\n"

    if "--print" not in sys.argv[1:]:
        with open(os.path.join(ROOT, "build_stamp.json"), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

    print(text, end="")


if __name__ == "__main__":
    main()
