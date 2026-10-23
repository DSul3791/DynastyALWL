#!/usr/bin/env python3
"""Post one card to Dave's QA page (BP-T47). Appends to questions/QUESTIONS.md on claude/generator-v2 and pushes.

Usage:
  python3 tools/qa_post.py --id my-card --kind check --title "Should X do Y?" \
      --note "What it means in plain words." --rec "Yes because Z." [--dry-run]
  --kind check   Yes/No plus a Why-not box (decisions and questions, ONE question per card)
  --kind test    "Please test this, look for X": Yes it worked / No, plus a Notes box (steps as --note lines)
  --kind picture "Please take a picture of this": Picture taken / not taken, plus Notes
  --kind text    a typed answer (only when a typed answer is truly needed)
  --note         repeatable: one short line each; when Dave must DO something write numbered steps "1. ...", "2. ..."
  --rec          your recommendation and why (REQUIRED for check and text; use "X because Y")
Rules checked here: id unique and short (letters, digits, dashes), title one line, a recommendation, test/picture need at least one numbered step.
It only ever APPENDS. It never edits or removes a card (Dave may be answering). The Guru reviews format and duplicates.
"""
import argparse, re, subprocess, sys, time

BRANCH = "claude/generator-v2"
QF = "questions/QUESTIONS.md"
AF = "questions/ANSWERS.md"


def sh(*a, check=True):
    r = subprocess.run(a, capture_output=True, text=True)
    if check and r.returncode:
        sys.exit("git failed: %s\n%s" % (" ".join(a), r.stderr.strip()))
    return r


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--id", required=True)
    p.add_argument("--kind", required=True, choices=["check", "test", "picture", "text"])
    p.add_argument("--title", required=True)
    p.add_argument("--note", action="append", default=[])
    p.add_argument("--rec", default="")
    p.add_argument("--dry-run", action="store_true")
    a = p.parse_args()

    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{1,40}", a.id):
        sys.exit("id: lowercase letters, digits and dashes, 2 to 41 characters")
    if "\n" in a.title or "|" in a.title:
        sys.exit("title: one line, no | character")
    if a.kind in ("check", "text") and not a.rec.strip():
        sys.exit("--rec is required: your recommendation and why (BP-T47)")
    if a.kind in ("test", "picture") and not any(re.match(r"\d+\. ", n) for n in a.note):
        sys.exit("test and picture cards need numbered steps as --note \"1. ...\" (exact action, point form)")
    for n in a.note:
        if "\n" in n:
            sys.exit("each --note is one line")

    import os, tempfile, shutil
    url = sh("git", "remote", "get-url", "origin").stdout.strip()
    tmp = tempfile.mkdtemp(prefix="qa_post_")   # a throwaway clone: your own branch and files are never touched
    try:
        for attempt in range(4):
            shutil.rmtree(tmp, ignore_errors=True)
            sh("git", "clone", "-q", "--depth", "1", "--branch", BRANCH, url, tmp)
            os.chdir(tmp)
            q = open(QF, encoding="utf-8").read()
            ids = set(re.findall(r"^## ([^ |]+) \|", q, re.M))
            if a.id in ids:
                sys.exit("id %s is already on the page" % a.id)
            try:
                ans = open(AF, encoding="utf-8").read()
                recent = re.findall(r"^## ([^ |]+) \|", ans, re.M)[-300:]
                if a.id in recent:
                    sys.exit("id %s was answered recently; use a new id and say what changed" % a.id)
            except FileNotFoundError:
                pass
            lines = ["", "## %s | %s" % (a.id, a.title)]
            lines += [(n if n.startswith("Image: ") else "Note: " + n) for n in a.note]  # a bare "Image: path" line is what the page turns into a picture
            if a.rec.strip():
                lines.append("Note: " + (a.rec.strip() if a.rec.lower().startswith("tyler") else "Recommendation: " + a.rec.strip()))
            lines.append({"check": "[check]", "test": "[test]", "picture": "[picture]", "text": "[text]"}[a.kind])
            block = "\n".join(lines) + "\n"
            if a.dry_run:
                print(block)
                return
            with open(QF, "a", encoding="utf-8") as f:
                f.write(("" if q.endswith("\n") else "\n") + block)
            sh("git", "add", QF)
            sh("git", "-c", "user.name=QA poster", "-c", "user.email=qa@example.invalid", "commit", "-q", "-m", "QA card: %s (BP-T47)" % a.id)
            r = sh("git", "push", "-q", "origin", "HEAD:" + BRANCH, check=False)
            if r.returncode == 0:
                print("posted %s" % a.id)
                return
            time.sleep(2 * (attempt + 1))
    finally:
        os.chdir("/")
        shutil.rmtree(tmp, ignore_errors=True)
    sys.exit("push kept failing; try again in a minute")


main()
