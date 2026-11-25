#!/usr/bin/env python3
"""Warn-only checks a Claude Code hook runs before a git commit or push (tools/hooks/warn.sh, .claude/settings.json).

commit: lines being committed that add a bare print() to client code (use FreezeWatch.printer.line: a print on the main thread
        stalls the client, D-LAG-1) or that look like a key, token or password (the repos are public).
push:   tools/check_rulings.py and tools/check_dave_rules.py, the rule checks merge_check runs.
Prints one JSON object for Claude Code when something is found, nothing otherwise. Never blocks: exit 0 always.
    python3 tools/hooks/agent_warn.py commit|push
"""
import json, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
CLIENT = re.compile(r"^(src/client/|scenes/terrain_client/).*\.gd$")   # the game client; server, bot and tool scripts may print
PRINTS_ON_PURPOSE = {"src/client/lag_run.gd"}   # LAGRUN lines a lane reads
PRINT = re.compile(r"^\s*print\(")
SECRETS = [
    (re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----"), "a private key"),
    (re.compile(r"\b(ghp|gho|ghs|github_pat)_[A-Za-z0-9_]{20,}"), "a GitHub token"),
    (re.compile(r"\bsk-ant-[A-Za-z0-9_-]{20,}"), "an Anthropic key"),
    (re.compile(r"\bAKIA[0-9A-Z]{16}\b"), "an AWS key"),
    (re.compile(r"""(?i)(password|passwd|secret|api_?key|admin_key|token)\w*["']?\s*:?[:=]\s*["'][^"'\s]{6,}["']"""), "a password or key value"),
]
PRIVATE_FILES = ("data/admin.json", "export.cfg", "export_credentials.cfg", ".env")


def git(*args):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


DIFF = ("diff", "HEAD", "--no-color", "--no-ext-diff", "--src-prefix=a/", "--dst-prefix=b/")   # the same shape whatever the machine's git config


def added_lines():
    """(path, line) for every line added against HEAD to a tracked file, staged or not (a `git commit -a` commits both). Files not yet
    added are not seen: in `git add . && git commit` the hook runs before the add."""
    path, in_hunk, out = "", False, []
    for line in git(*DIFF, "--unified=0").splitlines():
        if line.startswith("diff --git "):
            path, in_hunk = "", False
        elif not in_hunk and line.startswith("+++ "):
            name = line[4:].strip().strip('"')
            path = name[2:] if name.startswith("b/") else ""
        elif line.startswith("@@"):
            in_hunk = True
        elif in_hunk and line.startswith("+") and path:
            out.append((path, line[1:]))
    return out


def commit_findings():
    found = []
    changed = set(git(*DIFF, "--name-only").splitlines())
    for f in PRIVATE_FILES:
        if f in changed:
            found.append(f"{f} is a machine's private file: keep it out of the commit")
    for path, line in added_lines():
        if CLIENT.match(path) and path not in PRINTS_ON_PURPOSE and PRINT.match(line):
            found.append(f"{path}: a bare print() in client code; use FreezeWatch.printer.line")
        for rx, what in SECRETS:
            if rx.search(line):
                found.append(f"{path}: this line looks like {what}; the repos are public")
    return found


def push_findings():
    found = []
    for tool in ("tools/check_rulings.py", "tools/check_dave_rules.py"):
        r = subprocess.run([sys.executable, "-I", tool], cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if r.returncode != 0:
            bad = [l for l in r.stdout.splitlines() if l.startswith("FAIL")][:8] or [r.stdout.strip()[-300:] or r.stderr.strip()[-300:]]
            found.append(f"{tool} fails: " + " | ".join(bad))
    return found


def main(argv):
    mode = argv[1] if len(argv) > 1 else ""
    try:
        found = commit_findings() if mode == "commit" else push_findings() if mode == "push" else []
    except Exception as e:   # a warning tool must never get in the way
        found = [f"the {mode} check could not run ({type(e).__name__}: {e})"]
    if found:
        text = f"Warning before git {mode} (warn only, nothing blocked):\n- " + "\n- ".join(found[:20])
        print(json.dumps({"systemMessage": text, "hookSpecificOutput": {"hookEventName": "PreToolUse", "additionalContext": text}}))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
